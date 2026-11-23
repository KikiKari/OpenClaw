#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "f99c9ab3642195c90a13e1f2a32236e12ec99440202ef9b988a872bce6e9290d", "source_sha256": "1bde9ce66616d24f21a9092c84abb4b447779e6077ec9035f2df678b92bb76f4", "target_language": "perl5"}
# sync_clawhub_git_local.py — portiert nach perl5
# Quelle: python, workspace@local:scripts/sync_clawhub_git_local.py
# auch in: workspace@local:scripts/sync_clawhub_git.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use File::Find;
use Digest::SHA qw(sha256_hex);
use Getopt::Long;
use File::Spec;
use Cwd qw(abs_path);
use POSIX qw(strftime);

# Konfiguration
my $script_path = abs_path($0);
my @path_parts = split('/', $script_path);
pop(@path_parts); # Entferne den Skriptnamen
my $workspace_dir = join('/', @path_parts[0..$#path_parts-1]);
my $clawhub_dir = "$workspace_dir/skills";
my $git_dir = "$workspace_dir/git/skills";
my $backup_dir = "$workspace_dir/backups/sync";
my $log_file = "$workspace_dir/logs/sync-agent.log";

# Erstelle Verzeichnisse
make_path($git_dir, { verbose => 0 }) or die "Konnte $git_dir nicht erstellen: $!";
make_path($backup_dir, { verbose => 0 }) or die "Konnte $backup_dir nicht erstellen: $!";
make_path((split '/', $log_file)[0..2], { verbose => 0 }) or die "Konnte ".join('/', (split '/', $log_file)[0..2])." nicht erstellen: $!";

# Logging
sub log_message {
    my ($message, $level) = @_;
    $level //= "INFO";
    my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime);
    my $entry = "[$timestamp] [$level] $message\n";
    print $entry;
    open(my $fh, '>>', $log_file) or die "Konnte $log_file nicht öffnen: $!";
    print $fh $entry;
    close($fh);
}

# Validierung
sub validate_skill {
    my ($skill_dir) = @_;
    if (!-f "$skill_dir/SKILL.md") {
        log_message("Validation failed: " . (split '/', $skill_dir)[-1] . " missing SKILL.md", "ERROR");
        return 0;
    }
    return 1;
}

# Backup
sub create_backup {
    my ($source, $skill_name) = @_;
    my $timestamp = strftime('%Y%m%d_%H%M%S', localtime);
    my $backup_path = "$backup_dir/${skill_name}_$timestamp";

    # Backup verzeichnis löschen falls es existiert
    if (-d $backup_path) {
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
        make_path($backup_path, { verbose => 0 });
        copy_recursive($source, $backup_path);
        log_message("Backup created: $backup_path");
    };
    if ($@) {
        log_message("Backup failed: $@", "ERROR");
        return 0;
    }
    return 1;
}

# Rekursives Kopieren
sub copy_recursive {
    my ($src, $dst) = @_;
    opendir(my $dh, $src) or die "Konnte $src nicht öffnen: $!";
    my @files = readdir($dh);
    closedir($dh);

    for my $file (@files) {
        next if ($file eq '.' || $file eq '..' || $file eq '.git');
        my $src_path = "$src/$file";
        my $dst_path = "$dst/$file";

        if (-d $src_path) {
            make_path($dst_path, { verbose => 0 });
            copy_recursive($src_path, $dst_path);
        } else {
            copy($src_path, $dst_path) or die "Konnte $src_path nicht nach $dst_path kopieren: $!";
        }
    }
}

# Hash-Vergleich
sub get_file_hash {
    my ($file_path) = @_;
    open(my $fh, '<', $file_path) or die "Konnte $file_path nicht öffnen: $!";
    binmode($fh);
    my $digest = sha256_hex(do { local $/; <$fh> });
    close($fh);
    return $digest;
}

# Sync Richtung ClawHub → Git
sub sync_to_git {
    my ($skill_name, $dry_run) = @_;
    $dry_run //= 1;
    my $source = "$clawhub_dir/$skill_name";
    my $target = "$git_dir/$skill_name";

    if (!validate_skill($source)) {
        return 0;
    }

    # Backup vor Änderungen (nur wenn target existiert)
    if (!$dry_run && -d $target) {
        create_backup($target, $skill_name);
    }

    # Änderungen erkennen
    my @changes;
    find(sub {
        return if ($_ eq '.git');
        my $rel_path = $File::Find::name;
        $rel_path =~ s/^.*\/$skill_name\///;
        return if ($rel_path eq '');

        my $src_file = "$source/$rel_path";
        my $tgt_file = "$target/$rel_path";

        if (!-f $tgt_file) {
            push @changes, "ADD $rel_path";
        } elsif (get_file_hash($src_file) ne get_file_hash($tgt_file)) {
            push @changes, "UPDATE $rel_path";
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
    if (-d $target) {
        remove_tree($target);
    }
    make_path($target, { verbose => 0 });
    copy_recursive($source, $target);
    log_message("SYNC: $skill_name - Complete");
    return 1;
}

# Sync Richtung Git → ClawHub
sub sync_to_clawhub {
    my ($skill_name, $dry_run) = @_;
    $dry_run //= 1;
    my $source = "$git_dir/$skill_name";
    my $target = "$clawhub_dir/$skill_name";

    if (!validate_skill($source)) {
        return 0;
    }

    # Backup vor Änderungen (nur wenn target existiert)
    if (!$dry_run && -d $target) {
        create_backup($target, $skill_name);
    }

    # Änderungen erkennen
    my @changes;
    find(sub {
        return if ($_ eq '.git');
        my $rel_path = $File::Find::name;
        $rel_path =~ s/^.*\/$skill_name\///;
        return if ($rel_path eq '');

        my $src_file = "$source/$rel_path";
        my $tgt_file = "$target/$rel_path";

        if (!-f $tgt_file) {
            push @changes, "ADD $rel_path";
        } elsif (get_file_hash($src_file) ne get_file_hash($tgt_file)) {
            push @changes, "UPDATE $rel_path";
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
    if (-d $target) {
        remove_tree($target);
    }
    make_path($target, { verbose => 0 });
    copy_recursive($source, $target);
    log_message("SYNC: $skill_name - Complete");
    return 1;
}

# Hauptfunktion
sub main {
    my ($skill, $direction, $dry_run, $force);
    GetOptions(
        "skill=s"     => \$skill,
        "direction=s" => \$direction,
        "dry-run"     => \$dry_run,
        "force"       => \$force
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
        exit 1;
    }

    log_message("Sync completed");
}

main() if !caller;
