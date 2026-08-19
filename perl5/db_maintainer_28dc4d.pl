#!/usr/bin/perl
# db_maintainer.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:skills/db-maintainer/scripts/db_maintainer.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON;
use File::Path qw(make_path);
use File::Copy;
use File::Find;
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);

=head1 Database Maintainer Sub-Agent

Automated database maintenance with 30min checks, hourly backups (3 days retention),
band tree command execution for important/openclaw-tree.txt

=cut

my $WORKSPACE = "/home/openclaw/.openclaw/workspace";
my $DB_DIR = "$WORKSPACE/db";
my $BACKUP_DIR = "$DB_DIR/backups";
my $LOG_DIR = "$WORKSPACE/logs/db-maintainer";
my $IMPORTANT_DIR = "$WORKSPACE/important";

# Create directories
make_path($BACKUP_DIR, {verbose => 0}) or die "Couldn't create $BACKUP_DIR: $!";
make_path($LOG_DIR, {verbose => 0}) or die "Couldn't create $LOG_DIR: $!";

package Logger;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub log {
    my ($self, $level, $message) = @_;
    my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime);
    my $line = "[$timestamp] [$level] $message\n";
    print $line;
    my $today = strftime('%Y-%m-%d', localtime);
    my $log_file = "$LOG_DIR/$today.log";
    open(my $fh, '>>', $log_file) or die "Could not open file '$log_file': $!";
    print $fh $line;
    close $fh;
}

sub info { $_[0]->log('INFO', $_[1]); }
sub warn { $_[0]->log('WARN', $_[1]); }
sub error { $_[0]->log('ERROR', $_[1]); }

package DatabaseMaintainer;

sub new {
    my $class = shift;
    my $self = {
        logger => Logger->new(),
        state_file => "$DB_DIR/maintainer_state.json",
        retention_days => 3
    };
    bless $self, $class;
    return $self;
}

sub load_state {
    my $self = shift;
    if (-f $self->{state_file}) {
        open(my $fh, '<', $self->{state_file}) or die "Could not open file '$self->{state_file}': $!";
        my $json_text = do { local $/; <$fh> };
        close $fh;
        return decode_json($json_text);
    }
    return {
        last_check => undef,
        last_backup => undef,
        last_tree_update => undef,
        file_hashes => {}
    };
}

sub save_state {
    my ($self, $state) = @_;
    open(my $fh, '>', $self->{state_file}) or die "Could not open file '$self->{state_file}': $!";
    print $fh encode_json($state);
    close $fh;
}

sub get_file_hash {
    my ($self, $filepath) = @_;
    if (-f $filepath) {
        open(my $fh, '<', $filepath) or return undef;
        binmode($fh);
        my $data = do { local $/; <$fh> };
        close $fh;
        return md5_hex($data);
    }
    return undef;
}

sub run_tree_command {
    my $self = shift;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(60);
        my @cmd = ('tree', '-a', '-L', '6', $WORKSPACE);
        open(my $pipe, '-|', @cmd) or die "Cannot run tree command: $!";
        my $output = do { local $/; <$pipe> };
        close $pipe;
        alarm(0);
        $self->{logger}->info("tree -a -L 6 erfolgreich ausgeführt");
        return $output;
    };
    if ($@) {
        if ($@ eq "timeout\n") {
            $self->{logger}->error("tree command timed out");
        } else {
            $self->{logger}->error("tree command fehlgeschlagen: $@");
        }
        return undef;
    }
}

sub update_tree_file {
    my ($self, $tree_output) = @_;
    return 0 unless defined $tree_output;
    
    my $tree_file = "$IMPORTANT_DIR/openclaw-tree.txt";
    my $header = "# OpenClaw Workspace Tree\n";
    $header .= "# Generiert: " . strftime('%Y-%m-%dT%H:%M:%S', localtime) . "\n";
    $header .= "# Befehl: tree -a -L 6 $WORKSPACE\n";
    $header .= "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n";
    
    eval {
        open(my $fh, '>', $tree_file) or die "Cannot write to $tree_file: $!";
        print $fh $header;
        print $fh $tree_output;
        close $fh;
        $self->{logger}->info("openclaw-tree.txt aktualisiert: $tree_file");
        return 1;
    };
    if ($@) {
        $self->{logger}->error("Fehler beim Schreiben von openclaw-tree.txt: $@");
        return 0;
    }
}

sub scan_documentations {
    my $self = shift;
    my @docs;
    my @patterns = ("$WORKSPACE/*.md", "$WORKSPACE/**/*.md");
    
    find(sub {
        return unless /\.md$/ && -f $_ && !-l $_;
        my $full_path = $File::Find::name;
        return if $full_path =~ m{/db/backups/} || $full_path =~ m{/node_modules/};
        my $relative_path = $full_path;
        $relative_path =~ s{^\Q$WORKSPACE\E/?}{};
        push @docs, {
            path => $relative_path,
            hash => $self->get_file_hash($full_path),
            mtime => (stat($_))[9]
        };
    }, $WORKSPACE);
    
    return \@docs;
}

sub check_for_changes {
    my $self = shift;
    my $state = $self->load_state();
    my $current_docs = $self->scan_documentations();
    
    my @changes;
    my %current_hashes;
    
    for my $doc (@$current_docs) {
        my $path = $doc->{path};
        $current_hashes{$path} = $doc->{hash};
        
        if (!exists $state->{file_hashes}{$path}) {
            push @changes, "NEW: $path";
        } elsif ($state->{file_hashes}{$path} ne $doc->{hash}) {
            push @changes, "CHANGED: $path";
        }
    }
    
    # Check for deleted files
    for my $old_path (keys %{$state->{file_hashes}}) {
        if (!exists $current_hashes{$old_path}) {
            push @changes, "DELETED: $old_path";
        }
    }
    
    return (\@changes, \%current_hashes);
}

sub update_databases {
    my $self = shift;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(60);
        system("python3", "$WORKSPACE/scripts/update_docs_db.py");
        alarm(0);
        if ($? == 0) {
            $self->{logger}->info("docs.db aktualisiert");
            return 1;
        } else {
            $self->{logger}->error("DB-Update fehlgeschlagen: $?");
            return 0;
        }
    };
    if ($@) {
        $self->{logger}->error("DB-Update Exception: $@");
        return 0;
    }
}

sub update_tree_db_v2 {
    my $self = shift;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(120);
        system("python3", "$WORKSPACE/scripts/tree_indexer_v2.py");
        alarm(0);
        if ($? == 0) {
            $self->{logger}->info("tree.db v2 aktualisiert");
            return 1;
        } else {
            $self->{logger}->error("Tree-DB v2 fehlgeschlagen: $?");
            return 0;
        }
    };
    if ($@) {
        $self->{logger}->error("Tree-DB v2 Exception: $@");
        return 0;
    }
}

sub create_backup {
    my $self = shift;
    my $timestamp = strftime('%Y-%m-%d_%H-%M', localtime);
    
    for my $db_name ('docs.db', 'tree.db') {
        my $source = "$DB_DIR/$db_name";
        if (-f $source) {
            my $backup_name = "${timestamp}_${db_name}.bak";
            my $backup_path = "$BACKUP_DIR/$backup_name";
            copy($source, $backup_path) or die "Copy failed: $!";
            $self->{logger}->info("Backup erstellt: $backup_name");
        }
    }
    
    return $timestamp;
}

sub cleanup_old_backups {
    my $self = shift;
    my $cutoff = time() - ($self->{retention_days} * 24 * 60 * 60);
    my $deleted = 0;
    
    for my $db_name ('docs.db', 'tree.db') {
        opendir(my $dh, $BACKUP_DIR) or die "Cannot opendir $BACKUP_DIR: $!";
        my @backups = grep { /\.bak$/ && /_$db_name\.bak$/ } readdir($dh);
        closedir $dh;
        
        for my $backup (@backups) {
            # Extract date from filename (Format: YYYY-MM-DD_HH-MM)
            if ($backup =~ /^(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2})/) {
                my $date_part = $1;
                my $time_part = $2;
                my $backup_time_str = "${date_part}_${time_part}";
                my $backup_timestamp = _parse_datetime($backup_time_str);
                
                if ($backup_timestamp && $backup_timestamp < $cutoff) {
                    unlink("$BACKUP_DIR/$backup") or warn "Could not delete $backup: $!";
                    $deleted++;
                    $self->{logger}->info("Altes Backup gelöscht: $backup");
                }
            } else {
                $self->{logger}->warn("Konnte Backup-Datum nicht parsen: $backup");
            }
        }
    }
    
    if ($deleted == 0) {
        $self->{logger}->info("Keine alten Backups zum Löschen");
    } else {
        $self->{logger}->info("$deleted alte Backups gelöscht (< 3 Tage)");
    }
}

sub _parse_datetime {
    my $datetime_str = shift;
    if ($datetime_str =~ /^(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})$/) {
        my ($year, $month, $day, $hour, $minute) = ($1, $2, $3, $4, $5);
        use Time::Local;
        return timelocal(0, $minute, $hour, $day, $month-1, $year);
    }
    return undef;
}

sub run_cycle {
    my $self = shift;
    $self->{logger}->info("=" x 60);
    $self->{logger}->info("DB MAINTAINER CYCLE START");
    $self->{logger}->info("=" x 60);
    
    my $state = $self->load_state();
    
    # 1. Run tree command and write to openclaw-tree.txt
    $self->{logger}->info("Führe tree -a -L 8 aus...");
    my $tree_output = $self->run_tree_command();
    if ($tree_output) {
        $self->update_tree_file($tree_output);
        $state->{last_tree_update} = strftime('%Y-%m-%dT%H:%M:%S', localtime);
    }
    
    # 2. Update tree.db (internal v2)
    $self->{logger}->info("Aktualisiere tree.db v2...");
    $self->update_tree_db_v2();
    
    # 3. Check for changes
    $self->{logger}->info("Prüfe auf Dokumentations-Änderungen...");
    my ($changes, $current_hashes) = $self->check_for_changes();
    
    if (@$changes) {
        $self->{logger}->info(scalar(@$changes) . " Änderungen gefunden:");
        my $count = 0;
        for my $change (@$changes) {
            last if $count++ >= 10;
            $self->{logger}->info("  - $change");
        }
        if (@$changes > 10) {
            $self->{logger}->info("  ... und " . (scalar(@$changes) - 10) . " weitere");
        }
        
        # 4. Update docs.db
        $self->{logger}->info("Aktualisiere docs.db...");
        if ($self->update_databases()) {
            $state->{last_check} = strftime('%Y-%m-%dT%H:%M:%S', localtime);
            $state->{file_hashes} = $current_hashes;
        }
    } else {
        $self->{logger}->info("Keine Dokumentations-Änderungen gefunden");
    }
    
    # 5. Check if backup is due (hourly)
    my $do_backup = 1;
    if ($state->{last_backup}) {
        my $last_backup_time = _parse_datetime($state->{last_backup});
        if ($last_backup_time) {
            my $now = time();
            $do_backup = ($now - $last_backup_time) >= 3600; # 1 hour in seconds
        }
    }
    
    if ($do_backup) {
        $self->{logger}->info("Erstelle stündliches Backup...");
        my $timestamp = $self->create_backup();
        $state->{last_backup} = strftime('%Y-%m-%dT%H:%M:%S', localtime);
        
        # 6. Clean up old backups (3 day retention)
        $self->{logger}->info("Räume alte Backups auf (3 Tage Retention)...");
        $self->cleanup_old_backups();
    } else {
        $self->{logger}->info("Backup nicht nötig (letztes < 1h)");
    }
    
    $self->save_state($state);
    
    $self->{logger}->info("=" x 60);
    $self->{logger}->info("DB MAINTAINER CYCLE END");
    $self->{logger}->info("=" x 60);
}

sub main {
    my $maintainer = DatabaseMaintainer->new();
    
    eval {
        $maintainer->run_cycle();
    };
    if ($@) {
        $maintainer->{logger}->error("CRITICAL ERROR: $@");
        exit 1;
    }
}

main() unless caller;
