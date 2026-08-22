#!/usr/bin/perl
# sync_clawhub_git.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:scripts/sync_clawhub_git.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use File::Find;
use Digest::SHA;
use Getopt::Long;
use File::Spec;
use Cwd qw(abs_path);
use File::Basename;

# Konfiguration
my $CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
my $GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";
my $BACKUP_DIR = "/home/openclaw/.openclaw/workspace/backups/sync";
my $LOG_FILE = "/home/openclaw/.openclaw/workspace/logs/sync-agent.log";

# Erstelle Verzeichnisse
make_path($GIT_DIR, { verbose => 0 });
make_path($BACKUP_DIR, { verbose => 0 });
make_path(dirname($LOG_FILE), { verbose => 0 });

# Logging
sub log_message {
    my ($message, $level) = @_;
    $level //= "INFO";
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $timestamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    my $entry = "[$timestamp] [$level] $message\n";
    print $entry;
    open(my $fh, '>>', $LOG_FILE) or die "Could not open log file '$LOG_FILE': $!";
    print $fh $entry;
    close($fh);
}

# Validierung
sub validate_skill {
    my ($skill_dir) = @_;
    my $skill_md = "$skill_dir/SKILL.md";
    if (!-e $skill_md) {
        log_message("Validation failed: " . basename($skill_dir) . " missing SKILL.md", "ERROR");
        return 0;
    }
    return 1;
}

# Backup
sub create_backup {
    my ($source, $skill_name) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $timestamp = sprintf("%04d%02d%02d_%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    my $backup_path = "$BACKUP_DIR/${skill_name}_${timestamp}";

    # Backup verzeichnis löschen falls es existiert
    if (-e $backup_path) {
        eval {
            remove_tree($backup_path);
            log_message("Removed existing backup: $backup_path");
        };
        if ($@) {
            log_message("Failed to remove existing backup $backup_path: $@", "ERROR");
            return 0;
        }
    }

    eval {
        copytree($source, $backup_path);
        log_message("Backup created: $backup_path");
        return 1;
    };
    if ($@) {
        log_message("Backup failed: $@", "ERROR");
        return 0;
    }
    return 0;
}

# Hilfsfunktion zum Kopieren von Verzeichnissen
sub copytree {
    my ($src, $dst) = @_;
    opendir(my $dh, $src) or die "Cannot open directory '$src': $!";
    my @files = readdir($dh);
    closedir($dh);

    make_path($dst) unless -d $dst;

    for my $file (@files) {
        next if ($file eq '.' || $file eq '..');
        next if ($file eq '.git'); # Ignoriere .git Verzeichnis
        my $src_file = "$src/$file";
        my $dst_file = "$dst/$file";
        if (-d $src_file) {
            copytree($src_file, $dst_file);
        } else {
            copy($src_file, $dst_file) or die "Copy failed: $src_file -> $dst_file : $!";
        }
    }
}

# Hash-Vergleich
sub get_file_hash {
    my ($file_path) = @_;
    open(my $fh, '<', $file_path) or die "Cannot open file '$file_path': $!";
    binmode($fh);
    my $sha = Digest::SHA->new("SHA256");
    $sha->addfile($fh);
    close($fh);
    return $sha->hexdigest();
}

# Sync Richtung ClawHub → Git
sub sync_to_git {
    my ($skill_name, $dry_run) = @_;
    $dry_run //= 1;
    my $source = "$CLAWHUB_DIR/$skill_name";
    my $target = "$GIT_DIR/$skill_name";

    return 0 unless validate_skill($source);

    # Backup vor Änderungen (nur wenn target existiert)
    if (!$dry_run && -e $target) {
        return 0 unless create_backup($target, $skill_name);
    }

    # Änderungen erkennen
    my @changes = ();
    find(sub {
        return if ($_ eq '.git');
        return unless -f $_;
        my $rel_file = substr($File::Find::name, length($source) + 1);
        return unless defined $rel_file && length($rel_file) > 0;
        my $tgt_file = "$target/$rel_file";
        if (!-e $tgt_file) {
            push @changes, "ADD $rel_file";
        } elsif (get_file_hash($_) ne get_file_hash($tgt_file)) {
            push @changes, "UPDATE $rel_file";
        }
    }, $source);

    # Dry-Run Report
    if ($dry_run) {
        log_message("DRY-RUN: $skill_name - " . scalar(@changes) . " changes");
        for my $change (@changes) {
            log_message("  $change");
        }
        return 1;
    }

    # Echte Synchronisation
    log_message("SYNC: $skill_name - Applying " . scalar(@changes) . " changes");
    if (-e $target) {
        remove_tree($target);
    }
    copytree($source, $target);
    log_message("SYNC: $skill_name - Complete");
    return 1;
}

# Sync Richtung Git → ClawHub
sub sync_to_clawhub {
    my ($skill_name, $dry_run) = @_;
    $dry_run //= 1;
    my $source = "$GIT_DIR/$skill_name";
    my $target = "$CLAWHUB_DIR/$skill_name";

    return 0 unless validate_skill($source);

    # Backup vor Änderungen (nur wenn target existiert)
    if (!$dry_run && -e $target) {
        return 0 unless create_backup($target, $skill_name);
    }

    # Änderungen erkennen
    my @changes = ();
    find(sub {
        return if ($_ eq '.git');
        return unless -f $_;
        my $rel_file = substr($File::Find::name, length($source) + 1);
        return unless defined $rel_file && length($rel_file) > 0;
        my $tgt_file = "$target/$rel_file";
        if (!-e $tgt_file) {
            push @changes, "ADD $rel_file";
        } elsif (get_file_hash($_) ne get_file_hash($tgt_file)) {
            push @changes, "UPDATE $rel_file";
        }
    }, $source);

    # Dry-Run Report
    if ($dry_run) {
        log_message("DRY-RUN: $skill_name - " . scalar(@changes) . " changes");
        for my $change (@changes) {
            log_message("  $change");
        }
        return 1;
    }

    # Echte Synchronisation
    log_message("SYNC: $skill_name - Applying " . scalar(@changes) . " changes");
    if (-e $target) {
        remove_tree($target);
    }
    copytree($source, $target);
    log_message("SYNC: $skill_name - Complete");
    return 1;
}

# Hauptfunktion
sub main {
    my $skill;
    my $direction;
    my $dry_run = 0;
    my $force = 0;

    GetOptions(
        "skill=s"     => \$skill,
        "direction=s" => \$direction,
        "dry-run"     => \$dry_run,
        "force"       => \$force,
    ) or die "Falsche Optionen\n";

    die "Option --skill ist erforderlich\n" unless defined $skill;
    die "Option --direction ist erforderlich\n" unless defined $direction;
    die "Ungültige Richtung: $direction\n" unless ($direction eq 'to-git' || $direction eq 'to-clawhub');

    log_message("Starting sync: $skill ($direction)");

    my $success;
    if ($direction eq 'to-git') {
        $success = sync_to_git($skill, $dry_run);
    } else {
        $success = sync_to_clawhub($skill, $dry_run);
    }

    if (!$success) {
        log_message("Sync failed", "ERROR");
        exit(1);
    }

    log_message("Sync completed");
}

main() if __FILE__ eq $0;
