#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "1afe6cf92e989f533d7a8d7187f87d431fd928dd385e9a8c4df6ac9331c6194f", "source_sha256": "8d48f51942bb1c171bbd41e0696beb0722cb4b94d6596233f54b32928b645086", "target_language": "perl5"}
# db_maintainer.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON::PP;
use File::Path qw(make_path);
use File::Copy;
use File::Find;
use Digest::MD5;
use POSIX qw(strftime);
use Cwd qw(abs_path);
use File::Spec;
use File::Basename;

# Bestimme WORKSPACE basierend auf Umgebungsvariable oder dem Verzeichnis dieser Datei
my $script_dir = dirname(abs_path($0));
my $workspace_env = $ENV{'OPENCLAW_WORKSPACE'};
my $WORKSPACE = $workspace_env ? abs_path($workspace_env) : dirname($script_dir);

# Definiere Pfade
my $DB_DIR = $WORKSPACE;
my $BACKUP_DIR = File::Spec->catdir($WORKSPACE, 'db', 'backups');
my $LOG_DIR = File::Spec->catdir($WORKSPACE, 'logs', 'db-maintainer');
my $IMPORTANT_DIR = File::Spec->catdir($WORKSPACE, 'important');

# Stelle sicher, dass die Verzeichnisse existieren
make_path($BACKUP_DIR, { verbose => 0 });
make_path($LOG_DIR, { verbose => 0 });
make_path($IMPORTANT_DIR, { verbose => 0 });

package Logger {
    sub new {
        my ($class) = @_;
        my $self = {};
        bless $self, $class;
        $self->{log_file} = File::Spec->catfile($LOG_DIR, strftime('%Y-%m-%d', localtime()) . '.log');
        return $self;
    }

    sub log {
        my ($self, $level, $message) = @_;
        my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime());
        my $line = "[$timestamp] [$level] $message\n";
        print $line;
        open(my $fh, '>>', $self->{log_file}) or die "Could not open log file: $!";
        print $fh $line;
        close($fh);
    }

    sub info { shift->log('INFO', @_); }
    sub warn { shift->log('WARN', @_); }
    sub error { shift->log('ERROR', @_); }
}

package DatabaseMaintainer {
    sub new {
        my ($class) = @_;
        my $self = {};
        bless $self, $class;
        $self->{logger} = Logger->new();
        $self->{state_file} = File::Spec->catfile($DB_DIR, 'maintainer_state.json');
        $self->{retention_days} = 3; # 3 Tage Backup-Aufbewahrung
        return $self;
    }

    sub load_state {
        my ($self) = @_;
        if (-f $self->{state_file}) {
            open(my $fh, '<', $self->{state_file}) or die "Could not read state file: $!";
            local $/;
            my $json_text = <$fh>;
            close($fh);
            my $data = decode_json($json_text);
            return $data;
        }
        return {
            'last_check' => undef,
            'last_backup' => undef,
            'last_tree_update' => undef,
            'file_hashes' => {}
        };
    }

    sub save_state {
        my ($self, $state) = @_;
        open(my $fh, '>', $self->{state_file}) or die "Could not write state file: $!";
        print $fh encode_json($state);
        close($fh);
    }

    sub get_file_hash {
        my ($self, $filepath) = @_;
        eval {
            open(my $fh, '<', $filepath) or die "Cannot open file: $!";
            binmode($fh);
            my $digest = Digest::MD5->new;
            $digest->addfile($fh);
            close($fh);
            return $digest->hexdigest;
        };
        if ($@) {
            return undef;
        }
    }

    sub _python_tree_fallback {
        my ($self, $max_depth) = @_;
        $max_depth //= 8;
        my @lines = ($WORKSPACE);
        my $root_obj = bless { path => $WORKSPACE, is_dir => 1 }, 'FileEntry';

        sub walk {
            my ($dirpath, $prefix, $depth) = @_;
            return if $depth > $max_depth;
            my @entries;
            if (opendir(my $dh, $dirpath)) {
                while (my $entry = readdir($dh)) {
                    next if $entry eq '.' || $entry eq '..';
                    my $full_path = File::Spec->catfile($dirpath, $entry);
                    my $is_dir = -d $full_path && !(-l $full_path);
                    push @entries, bless { name => $entry, path => $full_path, is_dir => $is_dir }, 'FileEntry';
                }
                closedir($dh);
            } else {
                return;
            }
            @entries = sort { !$a->{is_dir} <=> !$b->{is_dir} || $a->{name} cmp $b->{name} } @entries;
            for my $i (0 .. $#entries) {
                my $entry = $entries[$i];
                my $connector = ($i == $#entries) ? '└── ' : '├── ';
                push @lines, $prefix . $connector . $entry->{name};
                if ($entry->{is_dir}) {
                    my $extension = ($i == $#entries) ? '    ' : '│   ';
                    walk($entry->{path}, $prefix . $extension, $depth + 1);
                }
            }
        }

        walk($WORKSPACE, '', 1);
        return join("\n", @lines) . "\n";
    }

    sub run_tree_command {
        my ($self) = @_;
        eval {
            local $SIG{ALRM} = sub { die "timeout\n"; };
            alarm(60);
            my $cmd = "tree -a -L 8 '$WORKSPACE'";
            my $output = `$cmd`;
            my $exit_code = $? >> 8;
            alarm(0);
            if ($exit_code == 0) {
                $self->{logger}->info("tree -a -L 8 erfolgreich ausgeführt");
                return $output;
            } else {
                my $stderr = $!;
                chomp($stderr);
                $self->{logger}->warn("tree command fehlgeschlagen: $stderr – nutze Perl-Fallback");
                return $self->_python_tree_fallback();
            }
        };
        if ($@) {
            if ($@ eq "timeout\n") {
                $self->{logger}->error("tree command timeout");
                return undef;
            } elsif ($@ =~ /tree.*?not found/) {
                $self->{logger}->warn("tree-Binary nicht installiert – nutze Perl-Fallback");
                return $self->_python_tree_fallback();
            } else {
                $self->{logger}->error("tree command Exception: $@");
                return undef;
            }
        }
    }

    sub update_tree_file {
        my ($self, $tree_output) = @_;
        return 0 unless defined $tree_output;
        my $tree_file = File::Spec->catfile($IMPORTANT_DIR, 'openclaw-tree.txt');
        my $header = "# OpenClaw Workspace Tree\n";
        $header .= "# Generiert: " . strftime('%Y-%m-%dT%H:%M:%S', localtime()) . "\n";
        $header .= "# Befehl: tree -a -L 8 $WORKSPACE\n";
        $header .= "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n";

        eval {
            open(my $fh, '>', $tree_file) or die "Cannot write to tree file: $!";
            print $fh $header;
            print $fh $tree_output;
            close($fh);
            $self->{logger}->info("openclaw-tree.txt aktualisiert: $tree_file");
            return 1;
        };
        if ($@) {
            $self->{logger}->error("Fehler beim Schreiben von openclaw-tree.txt: $@");
            return 0;
        }
    }

    sub scan_documentations {
        my ($self) = @_;
        my @docs;
        find(sub {
            return unless /\.md$/;
            my $rel_path = File::Spec->abs2rel($File::Find::name, $WORKSPACE);
            return if index($rel_path, 'db/backups') != -1 || index($rel_path, 'node_modules') != -1;
            my $stat = stat($_);
            if ($stat) {
                push @docs, {
                    path => $rel_path,
                    hash => $self->get_file_hash($File::Find::name),
                    mtime => $stat->mtime
                };
            }
        }, $WORKSPACE);
        return \@docs;
    }

    sub check_for_changes {
        my ($self) = @_;
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

        # Prüfe auf gelöschte Dateien
        for my $old_path (keys %{$state->{file_hashes}}) {
            if (!exists $current_hashes{$old_path}) {
                push @changes, "DELETED: $old_path";
            }
        }

        return (\@changes, \%current_hashes);
    }

    sub update_databases {
        my ($self) = @_;
        eval {
            local $SIG{ALRM} = sub { die "timeout\n"; };
            alarm(60);
            my $script = File::Spec->catfile($WORKSPACE, 'scripts', 'update_docs_db.py');
            system("python3", $script);
            my $exit_code = $? >> 8;
            alarm(0);
            if ($exit_code == 0) {
                $self->{logger}->info("docs.db aktualisiert");
                return 1;
            } else {
                $self->{logger}->error("DB-Update fehlgeschlagen");
                return 0;
            }
        };
        if ($@) {
            $self->{logger}->error("DB-Update Exception: $@");
            return 0;
        }
    }

    sub update_tree_db_v2 {
        my ($self) = @_;
        eval {
            local $SIG{ALRM} = sub { die "timeout\n"; };
            alarm(120);
            my $script = File::Spec->catfile($WORKSPACE, 'scripts', 'tree_indexer_v2.py');
            system("python3", $script);
            my $exit_code = $? >> 8;
            alarm(0);
            if ($exit_code == 0) {
                $self->{logger}->info("tree.db v2 aktualisiert");
                return 1;
            } else {
                $self->{logger}->error("Tree-DB v2 fehlgeschlagen");
                return 0;
            }
        };
        if ($@) {
            $self->{logger}->error("Tree-DB v2 Exception: $@");
            return 0;
        }
    }

    sub create_backup {
        my ($self) = @_;
        my $timestamp = strftime('%Y-%m-%d_%H-%M', localtime());

        for my $db_name ('docs.db', 'tree.db') {
            my $source = File::Spec->catfile($DB_DIR, $db_name);
            if (-f $source) {
                my $backup_name = "${timestamp}_${db_name}.bak";
                my $backup_path = File::Spec->catfile($BACKUP_DIR, $backup_name);
                copy($source, $backup_path) or warn "Failed to copy $source to $backup_path: $!";
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
            opendir(my $dh, $BACKUP_DIR) or die "Cannot open backup directory: $!";
            my @backups = grep { /\.bak$/ && index($_, "_${db_name}.bak") != -1 } readdir($dh);
            closedir($dh);

            for my $backup (@backups) {
                eval {
                    my ($date_part, $time_part) = split('_', substr($backup, 0, length($backup) - 4));
                    my $backup_time_str = "${date_part}_${time_part}";
                    my ($year, $month, $day, $hour, $minute) = 
                        ($backup_time_str =~ /^(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})$/);
                    die "Invalid format" unless defined $year;
                    my $backup_time = timelocal(0, $minute, $hour, $day, $month - 1, $year);
                    if ($backup_time < $cutoff) {
                        unlink(File::Spec->catfile($BACKUP_DIR, $backup)) or warn "Failed to delete $backup: $!";
                        $deleted++;
                        $self->{logger}->info("Altes Backup gelöscht: $backup");
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
        my ($self) = @_;
        $self->{logger}->info("=" x 60);
        $self->{logger}->info("DB MAINTAINER CYCLE START");
        $self->{logger}->info("=" x 60);

        my $state = $self->load_state();

        # 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
        $self->{logger}->info("Führe tree -a -L 8 aus...");
        my $tree_output = $self->run_tree_command();
        if (defined $tree_output) {
            $self->update_tree_file($tree_output);
            $state->{last_tree_update} = strftime('%Y-%m-%dT%H:%M:%S', localtime());
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
                $state->{last_check} = strftime('%Y-%m-%dT%H:%M:%S', localtime());
                $state->{file_hashes} = $current_hashes_ref;
            }
        } else {
            $self->{logger}->info("Keine Dokumentations-Änderungen gefunden");
        }

        # 5. Prüfe ob Backup fällig (stündlich)
        my $last_backup = $state->{last_backup};
        my $do_backup = 1;
        if (defined $last_backup) {
            my ($year, $month, $day, $hour, $min, $sec) = 
                ($last_backup =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/);
            if (defined $year) {
                my $last_backup_time = timelocal($sec, $min, $hour, $day, $month - 1, $year);
                $do_backup = (time() - $last_backup_time) >= (60 * 60); # 1 hour
            }
        }

        if ($do_backup) {
            $self->{logger}->info("Erstelle stündliches Backup...");
            my $timestamp = $self->create_backup();
            $state->{last_backup} = strftime('%Y-%m-%dT%H:%M:%S', localtime());

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

# Hilfsklasse für FileEntry im Fallback
package FileEntry;
1;
