#!/usr/bin/perl
# db_maintainer.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Spec;
use File::Path qw(make_path);
use File::Copy;
use Digest::MD5;
use JSON;
use POSIX qw(strftime);
use Cwd qw(abs_path);
use File::Basename;
use IPC::Run3;

=head1 NAME

Database Maintainer Sub-Agent

=head1 DESCRIPTION

Automated database maintenance with 30min checks, hourly backups (3 days retention),
band tree command execution for important/openclaw-tree.txt

=cut

my $script_dir = dirname(abs_path($0));
my $workspace = $ENV{'OPENCLAW_WORKSPACE'} // File::Spec->catdir($script_dir, '..');
$workspace = abs_path($workspace);

my $db_dir = $workspace;
my $backup_dir = File::Spec->catdir($workspace, 'db', 'backups');
my $log_dir = File::Spec->catdir($workspace, 'logs', 'db-maintainer');
my $important_dir = File::Spec->catdir($workspace, 'important');

# Verzeichnisse erstellen
make_path($backup_dir, { verbose => 0 }) unless -d $backup_dir;
make_path($log_dir, { verbose => 0 }) unless -d $log_dir;
make_path($important_dir, { verbose => 0 }) unless -d $important_dir;


package Logger {
    sub new {
        my ($class) = @_;
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
        my $log_file = File::Spec->catfile($log_dir, "$today.log");
        open(my $fh, '>>', $log_file) or die "Cannot open log file $log_file: $!";
        print $fh $line;
        close($fh);
    }

    sub info { shift->log('INFO', shift); }
    sub warn { shift->log('WARN', shift); }
    sub error { shift->log('ERROR', shift); }
}


package DatabaseMaintainer {
    sub new {
        my ($class) = @_;
        my $self = {
            logger => Logger->new(),
            state_file => File::Spec->catfile($db_dir, "maintainer_state.json"),
            retention_days => 3,
        };
        bless $self, $class;
        return $self;
    }

    sub load_state {
        my ($self) = @_;
        if (-f $self->{state_file}) {
            open(my $fh, '<', $self->{state_file}) or die "Cannot open state file: $!";
            local $/;
            my $json_text = <$fh>;
            close($fh);
            my $data = eval { decode_json($json_text) };
            return $data if $data;
        }
        return {
            last_check => undef,
            last_backup => undef,
            last_tree_update => undef,
            file_hashes => {},
        };
    }

    sub save_state {
        my ($self, $state) = @_;
        open(my $fh, '>', $self->{state_file}) or die "Cannot write state file: $!";
        print $fh to_json($state, { pretty => 1 });
        close($fh);
    }

    sub get_file_hash {
        my ($self, $filepath) = @_;
        return unless -f $filepath;
        open(my $fh, '<', $filepath) or return;
        binmode($fh);
        my $digest = Digest::MD5->new;
        while (read($fh, my $buffer, 8192)) {
            $digest->add($buffer);
        }
        close($fh);
        return $digest->hexdigest;
    }

    sub _python_tree_fallback {
        my ($self, $max_depth) = @_;
        $max_depth //= 8;
        my @lines = ($workspace);

        sub walk {
            my ($dirpath, $prefix, $depth, $lines_ref, $max_depth) = @_;
            return if $depth > $max_depth;
            opendir(my $dh, $dirpath) or return;
            my @entries = sort { (-d "$dirpath/$b") <=> (-d "$dirpath/$a") || $a cmp $b } readdir($dh);
            closedir($dh);
            for my $i (0..$#entries) {
                next if $entries[$i] eq '.' || $entries[$i] eq '..';
                my $entry = "$dirpath/" . $entries[$i];
                my $connector = ($i == $#entries) ? '└── ' : '├── ';
                push @$lines_ref, $prefix . $connector . $entries[$i];
                if (-d $entry && !-l $entry) {
                    my $extension = ($i == $#entries) ? '    ' : '│   ';
                    walk($entry, $prefix . $extension, $depth + 1, $lines_ref, $max_depth);
                }
            }
        }

        walk($workspace, '', 1, \@lines, $max_depth);
        return join("\n", @lines) . "\n";
    }

    sub run_tree_command {
        my ($self) = @_;
        my ($stdout, $stderr, $exit);
        eval {
            run3(['tree', '-a', '-L', '8', $workspace], \$stdout, \$stderr, \$exit);
        };
        if (!$@ && $exit == 0) {
            $self->{logger}->info("tree -a -L 8 erfolgreich ausgeführt");
            return $stdout;
        } else {
            $self->{logger}->warn("tree command fehlgeschlagen: " . ($stderr // '') . " – nutze Python-Fallback");
            return $self->_python_tree_fallback();
        }
    }

    sub update_tree_file {
        my ($self, $tree_output) = @_;
        return 0 unless defined $tree_output;
        my $tree_file = File::Spec->catfile($important_dir, "openclaw-tree.txt");
        my $header = "# OpenClaw Workspace Tree\n";
        $header .= "# Generiert: " . strftime('%Y-%m-%dT%H:%M:%S', localtime) . "\n";
        $header .= "# Befehl: tree -a -L 8 $workspace\n";
        $header .= "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n";

        open(my $fh, '>', $tree_file) or do {
            $self->{logger}->error("Fehler beim Schreiben von openclaw-tree.txt: $!");
            return 0;
        };
        print $fh $header;
        print $fh $tree_output;
        close($fh);
        $self->{logger}->info("openclaw-tree.txt aktualisiert: $tree_file");
        return 1;
    }

    sub scan_documentations {
        my ($self) = @_;
        my @docs;
        require File::Find;
        my @files;
        File::Find::find(sub {
            return unless /\.md$/ && -f $_ && !-l $_;
            my $rel_path = File::Spec->abs2rel($File::Find::name, $workspace);
            return if $rel_path =~ m{(?:^|/)db/backups/} || $rel_path =~ m{(?:^|/)node_modules/};
            push @files, $File::Find::name;
        }, $workspace);

        for my $file (@files) {
            my $rel_path = File::Spec->abs2rel($file, $workspace);
            push @docs, {
                path => $rel_path,
                hash => $self->get_file_hash($file),
                mtime => (stat($file))[9],
            };
        }
        return @docs;
    }

    sub check_for_changes {
        my ($self) = @_;
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

        # Prüfe auf gelöschte Dateien
        for my $old_path (keys %{$state->{file_hashes}}) {
            push @changes, "DELETED: $old_path" unless exists $current_hashes{$old_path};
        }

        return (\@changes, \%current_hashes);
    }

    sub update_databases {
        my ($self) = @_;
        my ($stdout, $stderr, $exit);
        eval {
            run3(['python3', File::Spec->catfile($workspace, 'scripts', 'update_docs_db.py')], \$stdout, \$stderr, \$exit);
        };

        if (!$@ && $exit == 0) {
            $self->{logger}->info("docs.db aktualisiert");
            return 1;
        } else {
            $self->{logger}->error("DB-Update fehlgeschlagen: " . ($stderr // ''));
            return 0;
        }
    }

    sub update_tree_db_v2 {
        my ($self) = @_;
        my ($stdout, $stderr, $exit);
        eval {
            run3(['python3', File::Spec->catfile($workspace, 'scripts', 'tree_indexer_v2.py')], \$stdout, \$stderr, \$exit);
        };

        if (!$@ && $exit == 0) {
            $self->{logger}->info("tree.db v2 aktualisiert");
            return 1;
        } else {
            $self->{logger}->error("Tree-DB v2 fehlgeschlagen: " . ($stderr // ''));
            return 0;
        }
    }

    sub create_backup {
        my ($self) = @_;
        my $timestamp = strftime('%Y-%m-%d_%H-%M', localtime);

        for my $db_name ('docs.db', 'tree.db') {
            my $source = File::Spec->catfile($db_dir, $db_name);
            if (-f $source) {
                my $backup_name = "${timestamp}_${db_name}.bak";
                my $backup_path = File::Spec->catfile($backup_dir, $backup_name);
                copy($source, $backup_path) or do {
                    $self->{logger}->error("Kopieren fehlgeschlagen: $source -> $backup_path: $!");
                    next;
                };
                $self->{logger}->info("Backup erstellt: $backup_name");
            }
        }

        return $timestamp;
    }

    sub cleanup_old_backups {
        my ($self) = @_;
        my $cutoff = time() - ($self->{retention_days} * 24 * 60 * 60);
        my $deleted = 0;

        for my $db_name ('docs.db', 'tree.db') {
            opendir(my $dh, $backup_dir) or next;
            my @backups = grep { /_\Q$db_name\E\.bak$/ } readdir($dh);
            closedir($dh);

            for my $backup (@backups) {
                my $full_path = File::Spec->catfile($backup_dir, $backup);
                next unless -f $full_path;
                if ($backup =~ /^(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2})_/) {
                    my ($date_part, $time_part) = ($1, $2);
                    my ($year, $month, $day) = split(/-/, $date_part);
                    my ($hour, $minute) = split(/-/, $time_part);
                    my $backup_time = mktime(0, $minute, $hour, $day, $month - 1, $year - 1900);
                    if ($backup_time < $cutoff) {
                        unlink($full_path) or do {
                            $self->{logger}->warn("Konnte Backup nicht löschen: $backup: $!");
                            next;
                        };
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

    sub run_cycle {
        my ($self) = @_;
        $self->{logger}->info("=" x 60);
        $self->{logger}->info("DB MAINTAINER CYCLE START");
        $self->{logger}->info("=" x 60);

        my $state = $self->load_state();

        # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
        $self->{logger}->info("Führe tree -a -L 8 aus...");
        my $tree_output = $self->run_tree_command();
        if ($tree_output) {
            $self->update_tree_file($tree_output);
            $state->{last_tree_update} = strftime('%Y-%m-%dT%H:%M:%S', localtime);
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
                $self->{logger}->info("  ... und " . (@changes - 10) . " weitere");
            }

            # 4. docs.db aktualisieren
            $self->{logger}->info("Aktualisiere docs.db...");
            if ($self->update_databases()) {
                $state->{last_check} = strftime('%Y-%m-%dT%H:%M:%S', localtime);
                $state->{file_hashes} = $current_hashes_ref;
            }
        } else {
            $self->{logger}->info("Keine Dokumentations-Änderungen gefunden");
        }

        # 5. Prüfe ob Backup fällig (stündlich)
        my $do_backup = 1;
        if ($state->{last_backup}) {
            my ($year, $month, $day, $hour, $minute, $second) = 
                $state->{last_backup} =~ /^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)/;
            if ($year) {
                my $last_backup_time = mktime($second, $minute, $hour, $day, $month - 1, $year - 1900);
                $do_backup = (time() - $last_backup_time) >= 3600; # 1 Stunde
            }
        }

        if ($do_backup) {
            $self->{logger}->info("Erstelle stündliches Backup...");
            my $timestamp = $self->create_backup();
            $state->{last_backup} = strftime('%Y-%m-%dT%H:%M:%S', localtime);

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

main() if !caller();
