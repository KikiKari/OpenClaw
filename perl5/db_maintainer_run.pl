#!/usr/bin/perl
# db_maintainer_run.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer_run.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Path qw(make_path);
use File::Copy;
use Digest::MD5;
use JSON;
use POSIX qw(strftime);
use Time::Piece;
use Time::Seconds;
use Cwd qw(abs_path);

my $WORKSPACE = "/workspace";
my $DB_DIR = "$WORKSPACE/db";
my $BACKUP_DIR = "$DB_DIR/backups";
my $LOG_DIR = "$WORKSPACE/logs/db-maintainer";
my $IMPORTANT_DIR = "$WORKSPACE/important";

# Verzeichnisse erstellen
make_path($BACKUP_DIR) unless -d $BACKUP_DIR;
make_path($LOG_DIR) unless -d $LOG_DIR;

package Logger {
    sub new {
        my $class = shift;
        my $self = {};
        bless $self, $class;
        return $self;
    }

    sub _log {
        my ($self, $level, $message) = @_;
        my $timestamp = strftime "%Y-%m-%d %H:%M:%S", localtime;
        my $line = "[$timestamp] [$level] $message\n";
        print $line;
        my $today = strftime "%Y-%m-%d", localtime;
        my $log_file = "$LOG_DIR/$today.log";
        open(my $fh, '>>', $log_file) or die "Could not open log file '$log_file': $!";
        print $fh $line;
        close $fh;
    }

    sub info { $_[0]->_log('INFO', $_[1]); }
    sub warn { $_[0]->_log('WARN', $_[1]); }
    sub error { $_[0]->_log('ERROR', $_[1]); }
}

package DatabaseMaintainer {
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
            open(my $fh, '<', $self->{state_file}) or die "Cannot read state file: $!";
            local $/;
            my $content = <$fh>;
            close $fh;
            return decode_json($content);
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
        open(my $fh, '>', $self->{state_file}) or die "Cannot write state file: $!";
        print $fh encode_json($state);
        close $fh;
    }

    sub get_file_hash {
        my ($self, $filepath) = @_;
        open(my $fh, '<', $filepath) or return undef;
        binmode($fh);
        my $digest = Digest::MD5->new;
        $digest->addfile($fh);
        close $fh;
        return $digest->hexdigest;
    }

    sub run_tree_command {
        my $self = shift;
        eval {
            local $SIG{ALRM} = sub { die "timeout\n" };
            alarm(60);
            my $output = `tree -a -L 6 "$WORKSPACE" 2>&1`;
            alarm(0);
            if ($? == 0) {
                $self->{logger}->info("tree -a -L 6 erfolgreich ausgeführt");
                return $output;
            } else {
                chomp $output;
                $self->{logger}->error("tree command fehlgeschlagen: $output");
                return undef;
            }
        };
        if ($@) {
            $self->{logger}->error("tree command Exception: $@");
            return undef;
        }
    }

    sub update_tree_file {
        my ($self, $tree_output) = @_;
        return 0 unless defined $tree_output;

        my $tree_file = "$IMPORTANT_DIR/openclaw-tree.txt";
        my $timestamp = localtime->strftime('%Y-%m-%dT%H:%M:%S');
        my $header = "# OpenClaw Workspace Tree\n# Generiert: $timestamp\n# Befehl: tree -a -L 6 $WORKSPACE\n# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n";

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

    sub find_md_files {
        my $self = shift;
        my @files;
        use File::Find;
        find(sub {
            return unless /\.md$/ && -f $_ && !-l $_;
            my $full_path = $File::Find::name;
            return if $full_path =~ m{/db/backups/} || $full_path =~ m{/node_modules/};
            push @files, $full_path;
        }, $WORKSPACE);
        return @files;
    }

    sub scan_documentations {
        my $self = shift;
        my @docs;
        my @files = $self->find_md_files();
        for my $file (@files) {
            my $rel_path = $file;
            $rel_path =~ s{^\Q$WORKSPACE\E/*}{};
            push @docs, {
                path => $rel_path,
                hash => $self->get_file_hash($file),
                mtime => (stat($file))[9]
            };
        }
        return @docs;
    }

    sub check_for_changes {
        my $self = shift;
        my $state = $self->load_state();
        my @current_docs = $self->scan_documentations();
        my @changes;
        my %current_hashes;

        for my $doc (@current_docs) {
            my $path = $doc->{path};
            $current_hashes{$path} = $doc->{hash};

            if (!exists $state->{file_hashes}{$path}) {
                push @changes, "NEW: $path";
            } elsif ($state->{file_hashes}{$path} ne $doc->{hash}) {
                push @changes, "CHANGED: $path";
            }
        }

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
            my $script = "$WORKSPACE/scripts/update_docs_db.py";
            my $output = `python3 "$script" 2>&1`;
            alarm(0);
            if ($? == 0) {
                $self->{logger}->info("docs.db aktualisiert");
                return 1;
            } else {
                chomp $output;
                $self->{logger}->error("DB-Update fehlgeschlagen: $output");
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
            my $script = "$WORKSPACE/scripts/tree_indexer_v2.py";
            my $output = `python3 "$script" 2>&1`;
            alarm(0);
            if ($? == 0) {
                $self->{logger}->info("tree.db v2 aktualisiert");
                return 1;
            } else {
                chomp $output;
                $self->{logger}->error("Tree-DB v2 fehlgeschlagen: $output");
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
        my $timestamp = localtime->strftime('%Y-%m-%d_%H-%M');

        for my $db_name ('docs.db', 'tree.db') {
            my $source = "$DB_DIR/$db_name";
            if (-f $source) {
                my $backup_name = "${timestamp}_${db_name}.bak";
                my $backup_path = "$BACKUP_DIR/$backup_name";
                copy($source, $backup_path) or die "Failed to copy $source to $backup_path: $!";
                $self->{logger}->info("Backup erstellt: $backup_name");
            }
        }

        return $timestamp;
    }

    sub cleanup_old_backups {
        my $self = shift;
        my $cutoff = localtime(time - ($self->{retention_days} * 86400));
        my $deleted = 0;

        for my $db_name ('docs.db', 'tree.db') {
            opendir(my $dh, $BACKUP_DIR) or die "Cannot open directory $BACKUP_DIR: $!";
            my @backups = grep { /\Q${db_name}.bak\E$/ && -f "$BACKUP_DIR/$_" } readdir($dh);
            closedir $dh;

            for my $backup (@backups) {
                eval {
                    if ($backup =~ /^(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2})_/) {
                        my ($date_part, $time_part) = ($1, $2);
                        my $backup_time_str = "${date_part}_${time_part}";
                        my $backup_time = Time::Piece->strptime($backup_time_str, '%Y-%m-%d_%H-%M');
                        if ($backup_time < $cutoff) {
                            unlink("$BACKUP_DIR/$backup") or die "Failed to delete $backup: $!";
                            $deleted++;
                            $self->{logger}->info("Altes Backup gelöscht: $backup");
                        }
                    } else {
                        $self->{logger}->warn("Konnte Backup-Datum nicht parsen: $backup");
                    }
                };
                if ($@) {
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

    sub run_cycle {
        my $self = shift;
        $self->{logger}->info("=" x 60);
        $self->{logger}->info("DB MAINTAINER CYCLE START");
        $self->{logger}->info("=" x 60);

        my $state = $self->load_state();

        # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
        $self->{logger}->info("Führe tree -a -L 8 aus...");
        my $tree_output = $self->run_tree_command();
        if (defined $tree_output) {
            $self->update_tree_file($tree_output);
            $state->{last_tree_update} = localtime->datetime;
        }

        # 2. tree.db aktualisieren (intern v2)
        $self->{logger}->info("Aktualisiere tree.db v2...");
        $self->update_tree_db_v2();

        # 3. Änderungen prüfen
        $self->{logger}->info("Prüfe auf Dokumentations-Änderungen...");
        my ($changes_ref, $current_hashes_ref) = $self->check_for_changes();
        my @changes = @$changes_ref;

        if (@changes) {
            $self->{logger}->info(scalar(@changes) . " Änderungen gefunden:");
            my $count = 0;
            for my $change (@changes) {
                last if $count++ >= 10;
                $self->{logger}->info("  - $change");
            }
            if (@changes > 10) {
                $self->{logger}->info("  ... und " . (scalar(@changes) - 10) . " weitere");
            }

            # 4. docs.db aktualisieren
            $self->{logger}->info("Aktualisiere docs.db...");
            if ($self->update_databases()) {
                $state->{last_check} = localtime->datetime;
                $state->{file_hashes} = $current_hashes_ref;
            }
        } else {
            $self->{logger}->info("Keine Dokumentations-Änderungen gefunden");
        }

        # 5. Prüfe ob Backup fällig (stündlich)
        my $last_backup = $state->{last_backup};
        my $do_backup = 0;

        if (defined $last_backup) {
            my $last_backup_time = Time::Piece->strptime($last_backup, '%Y-%m-%dT%H:%M:%S');
            my $diff = localtime - $last_backup_time;
            $do_backup = ($diff->seconds >= 3600);
        } else {
            $do_backup = 1;
        }

        if ($do_backup) {
            $self->{logger}->info("Erstelle stündliches Backup...");
            my $timestamp = $self->create_backup();
            $state->{last_backup} = localtime->datetime;

            # 6. Alte Backups aufräumen (3 Tage Retention)
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
}

sub main {
    my $maintainer = DatabaseMaintainer->new();
    eval {
        $maintainer->run_cycle();
    };
    if ($@) {
        $maintainer->{logger}->error("CRITICAL ERROR: $@");
        exit(1);
    }
}

main() if __FILE__ eq $0;
