#!/usr/bin/env perl
# sync_clawhub_git.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:scripts/sync_clawhub_git.py
# auch in: Projects@clawhub:clawhub/Skills/sync_clawhub_git.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use File::Find;
use Digest::SHA qw(sha256_hex);
use Getopt::Long;
use Pod::Usage;
use Time::Piece;

# Konfiguration
# Resolve paths relative to this repository so the helper works both in the
# hosted workspace and in environments without a /workspace mount.
my $script_path = __FILE__;
$script_path =~ s|\\|/|g;  # Normalize path separators on Windows
my @path_parts = split '/', $script_path;
splice @path_parts, -2;  # Remove script name and parent dir
my $WORKSPACE_ROOT = join('/', @path_parts);
$WORKSPACE_ROOT =~ s|/$||;  # Remove trailing slash if present

my $CLAWHUB_DIR = "$WORKSPACE_ROOT/skills";
my $GIT_DIR = "$WORKSPACE_ROOT/git/skills";
my $BACKUP_DIR = "$WORKSPACE_ROOT/backups/sync";
my $LOG_FILE = "$WORKSPACE_ROOT/logs/sync-agent.log";

my %IGNORED_NAMES = map { $_ => 1 } qw(.git .clawhub node_modules __pycache__ .pytest_cache);
my %RESERVED_SKILL_NAMES = map { $_ => 1 } qw(github-clones skills backups .restore git Abstraktionen);
my %PRESERVED_TARGET_NAMES = %IGNORED_NAMES;

# Erstelle Verzeichnisse
make_path($GIT_DIR, { verbose => 0 });
make_path($BACKUP_DIR, { verbose => 0 });
make_path((split '/', $LOG_FILE)[0..$#_-1], { verbose => 0 });

# Logging
sub log_message {
    my ($message, $level) = @_;
    $level //= "INFO";
    my $timestamp = localtime->strftime('%Y-%m-%d %H:%M:%S');
    my $entry = "[$timestamp] [$level] $message\n";
    print $entry;
    open(my $fh, '>>', $LOG_FILE) or warn "Could not open log file: $!";
    print $fh $entry;
    close $fh;
}

# Validierung
sub validate_skill {
    my ($skill_dir) = @_;
    my $skill_name = (split '/', $skill_dir)[-1];
    
    if (exists $RESERVED_SKILL_NAMES{$skill_name}) {
        log_message("Validation failed: $skill_name is reserved and must not be synced as a skill", "ERROR");
        return 0;
    }
    
    if (!-f "$skill_dir/SKILL.md") {
        log_message("Validation failed: $skill_name missing SKILL.md", "ERROR");
        return 0;
    }
    
    return 1;
}

sub is_ignored_path {
    my ($path) = @_;
    my @parts = split '/', $path;
    
    for my $part (@parts) {
        return 1 if exists $IGNORED_NAMES{$part};
        return 1 if $part =~ /\.pyc$/;
    }
    
    return 0;
}

sub is_generated_duplicate_path {
    my ($root, $rel_path) = @_;
    my @parts = split '/', $rel_path;
    
    return 0 unless @parts;
    
    my $root_name = (split '/', $root)[-1];
    return 1 if $parts[0] eq $root_name;
    
    for my $i (1..$#parts) {
        return 1 if $parts[$i] eq $parts[$i-1];
    }
    
    return 0;
}

sub iter_sync_files {
    my ($root) = @_;
    my @files;
    
    find(sub {
        my $current_root = $File::Find::dir;
        my $file = $_;
        
        # Skip ignored directories
        return if -d $file && exists $IGNORED_NAMES{$file};
        return if $file =~ /^__pycache__/;
        
        # Build relative path
        my $full_path = "$current_root/$file";
        $full_path =~ s|^$root/?||;
        $full_path =~ s|^/+||;
        
        # Skip if ignored path
        return if is_ignored_path($full_path);
        
        # Skip if generated duplicate
        return if is_generated_duplicate_path($root, $full_path);
        
        # Special handling for SKILL.md
        if ($file eq 'SKILL.md' && $full_path ne 'SKILL.md') {
            return;
        }
        
        # Only include regular files
        if (-f "$File::Find::dir/$file") {
            push @files, {
                full_path => "$File::Find::dir/$file",
                rel_path => $full_path
            };
        }
    }, $root);
    
    return @files;
}

sub reset_sync_target {
    my ($target) = @_;
    make_path($target, { verbose => 0 });
    
    opendir(my $dh, $target) or return;
    my @children = readdir($dh);
    closedir $dh;
    
    for my $child (@children) {
        next if $child eq '.' || $child eq '..';
        next if exists $PRESERVED_TARGET_NAMES{$child};
        
        my $full_path = "$target/$child";
        if (-d $full_path && !-l $full_path) {
            remove_tree($full_path);
        } elsif (-f $full_path || -l $full_path) {
            unlink $full_path;
        }
    }
}

sub copy_sync_files {
    my ($source, $target) = @_;
    reset_sync_target($target);
    
    my @files = iter_sync_files($source);
    for my $file_info (@files) {
        my $src_file = $file_info->{full_path};
        my $rel_path = $file_info->{rel_path};
        my $dest_file = "$target/$rel_path";
        
        # Create parent directory
        my $parent_dir = $dest_file;
        $parent_dir =~ s|/[^/]+$||;
        make_path($parent_dir, { verbose => 0 });
        
        # Copy file
        copy($src_file, $dest_file) or warn "Failed to copy $src_file to $dest_file: $!";
    }
}

# Backup
sub create_backup {
    my ($source, $skill_name) = @_;
    my $timestamp = localtime->strftime('%Y%m%d_%H%M%S');
    my $backup_path = "$BACKUP_DIR/${skill_name}_$timestamp";
    
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
        make_path($backup_path, { verbose => 0 });
        copy_recursive($source, $backup_path);
        log_message("Backup created: $backup_path");
        return 1;
    };
    if ($@) {
        log_message("Backup failed: $@", "ERROR");
        return 0;
    }
}

sub copy_recursive {
    my ($source, $target) = @_;
    
    opendir(my $dh, $source) or die "Cannot open directory $source: $!";
    my @items = readdir($dh);
    closedir $dh;
    
    for my $item (@items) {
        next if $item eq '.' || $item eq '..';
        next if exists $IGNORED_NAMES{$item};
        next if $item =~ /\.pyc$/;
        
        my $src_path = "$source/$item";
        my $tgt_path = "$target/$item";
        
        if (-d $src_path) {
            make_path($tgt_path, { verbose => 0 });
            copy_recursive($src_path, $tgt_path);
        } else {
            copy($src_path, $tgt_path) or die "Cannot copy $src_path to $tgt_path: $!";
        }
    }
}

# Hash-Vergleich
sub get_file_hash {
    my ($file_path) = @_;
    
    # Ensure the path points to a regular file.
    return "" unless -f $file_path;
    
    eval {
        open(my $fh, '<', $file_path) or die "Cannot open $file_path: $!";
        binmode $fh;
        my $hash = sha256_hex(do { local $/; <$fh> });
        close $fh;
        return $hash;
    };
    if ($@) {
        log_message("Failed to hash $file_path: $@", "ERROR");
        return "";
    }
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
        create_backup($target, $skill_name);
    }
    
    # Änderungen erkennen
    my @changes;
    my @files = iter_sync_files($source);
    for my $file_info (@files) {
        my $src_file = $file_info->{full_path};
        my $rel_path = $file_info->{rel_path};
        my $tgt_file = "$target/$rel_path";
        
        if (!-e $tgt_file) {
            push @changes, "ADD $rel_path";
        } elsif (get_file_hash($src_file) ne get_file_hash($tgt_file)) {
            push @changes, "UPDATE $rel_path";
        }
    }
    
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
    copy_sync_files($source, $target);
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
        create_backup($target, $skill_name);
    }
    
    # Änderungen erkennen (gleiche Logik wie oben)
    my @changes;
    my @files = iter_sync_files($source);
    for my $file_info (@files) {
        my $src_file = $file_info->{full_path};
        my $rel_path = $file_info->{rel_path};
        my $tgt_file = "$target/$rel_path";
        
        if (!-e $tgt_file) {
            push @changes, "ADD $rel_path";
        } elsif (get_file_hash($src_file) ne get_file_hash($tgt_file)) {
            push @changes, "UPDATE $rel_path";
        }
    }
    
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
    copy_sync_files($source, $target);
    log_message("SYNC: $skill_name - Complete");
    return 1;
}

# Hauptfunktion
sub main {
    my $skill;
    my $direction;
    my $dry_run = 0;
    my $force = 0;
    my $help = 0;
    
    GetOptions(
        'skill=s' => \$skill,
        'direction=s' => \$direction,
        'dry-run' => \$dry_run,
        'force' => \$force,
        'help|?' => \$help
    ) or pod2usage(2);
    
    pod2usage(1) if $help;
    pod2usage(2) unless $skill && $direction;
    pod2usage(2) unless $direction eq 'to-git' || $direction eq 'to-clawhub';
    
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

main() unless caller;

__END__

=head1 NAME

sync_clawhub_git.pl - Bidirektionaler Sync ClawHub ↔ Git

=head1 SYNOPSIS

sync_clawhub_git.pl [options]

 Options:
   --skill         Skill name
   --direction     Direction: to-git or to-clawhub
   --dry-run       Nur Änderungen anzeigen
   --force         Ohne Backup
   --help          Zeige diese Hilfe

=head1 OPTIONS

=over 4

=item B<--skill>

Name des Skills, der synchronisiert werden soll.

=item B<--direction>

Richtung der Synchronisation: entweder 'to-git' oder 'to-clawhub'.

=item B<--dry-run>

Wenn angegeben, werden nur die Änderungen angezeigt, ohne tatsächlich zu synchronisieren.

=item B<--force>

Wenn angegeben, wird kein Backup erstellt.

=back

=head1 DESCRIPTION

Dieses Skript führt eine bidirektionale Synchronisation zwischen ClawHub und Git durch.

=cut
