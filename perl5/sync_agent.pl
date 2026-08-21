#!/usr/bin/perl
# sync_agent.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/clawhub-git-sync-agent/scripts/sync_agent.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON qw(decode_json encode_json);
use File::Path qw(make_path);
use File::Spec;
use File::Find;
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);

# Konfiguration
my $CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
my $GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";
my $STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";
my $BACKUP_ROOT = "/home/openclaw/.openclaw/workspace/backups/sync_agent";

# Füge das Skriptverzeichnis zum Suchpfad hinzu
unshift @INC, '/home/openclaw/.openclaw/workspace/scripts';

# Lade externe Funktionen
require "sync_clawhub_git.pl";

sub load_state {
    my $state = {};
    if (-f $STATE_FILE) {
        open(my $fh, '<', $STATE_FILE) or die "Kann $STATE_FILE nicht öffnen: $!";
        local $/;
        my $json_text = <$fh>;
        close($fh);
        eval {
            $state = decode_json($json_text);
        };
        if ($@) {
            warn "Fehler beim Parsen des Zustands: $@";
            $state = {};
        }
    }
    $state->{sync_history} //= [];
    $state->{pending} //= [];
    return $state;
}

sub save_state {
    my ($state) = @_;
    
    # Erstelle Verzeichnisstruktur falls nötig
    my ($volume, $directories) = File::Spec->splitpath($STATE_FILE);
    my @dirs = File::Spec->splitdir($directories);
    pop @dirs; # Entferne leeres Element am Ende
    my $dir_path = File::Spec->catpath($volume, File::Spec->catdir(@dirs), '');
    make_path($dir_path) unless -d $dir_path;
    
    open(my $fh, '>', $STATE_FILE) or die "Kann $STATE_FILE nicht schreiben: $!";
    print $fh encode_json($state);
    close($fh);
}

sub get_all_skills {
    my (%skills);
    
    # Durchsuche ClawHub Verzeichnis
    if (-d $CLAWHUB_DIR) {
        opendir(my $dh, $CLAWHUB_DIR) or die "Kann $CLAWHUB_DIR nicht öffnen: $!";
        while (readdir $dh) {
            next if /^\.\.?$/;
            my $path = "$CLAWHUB_DIR/$_";
            if (-d $path && !/^[._]/ && -f "$path/SKILL.md") {
                $skills{$_} = 1;
            }
        }
        closedir $dh;
    }
    
    # Durchsuche Git Verzeichnis
    if (-d $GIT_DIR) {
        opendir(my $dh, $GIT_DIR) or die "Kann $GIT_DIR nicht öffnen: $!";
        while (readdir $dh) {
            next if /^\.\.?$/;
            my $path = "$GIT_DIR/$_";
            if (-d $path && !/^[._]/ && -f "$path/SKILL.md") {
                $skills{$_} = 1;
            }
        }
        closedir $dh;
    }
    
    return keys %skills;
}

sub init_git_repo {
    my ($skill_path, $skill_name) = @_;
    my $git_dir = "$skill_path/.git";
    
    unless (-d $git_dir) {
        chdir($skill_path) or die "Kann nicht in $skill_path wechseln: $!";
        system("git init >/dev/null 2>&1");
        system("git add . >/dev/null 2>&1");
        system("git commit -m 'Initial commit: $skill_name skill' >/dev/null 2>&1");
        &log("Git initialized for $skill_name");
    }
}

sub backup_skill_dir {
    my ($skill_path, $skill_name) = @_;
    
    return unless -d $skill_path;
    
    my $timestamp = strftime("%Y%m%d%H%M%S", localtime);
    my $backup_dir = "$BACKUP_ROOT/$timestamp";
    make_path($backup_dir) unless -d $backup_dir;
    
    my $archive_name = "${skill_name}_${timestamp}.tar.gz";
    my $archive_path = "$backup_dir/$archive_name";
    my $archive_base = $archive_path;
    $archive_base =~ s/\.tar\.gz$//;
    
    system("tar -czf '$archive_path' -C '$skill_path' . >/dev/null 2>&1");
    &log("Backup created for $skill_name at $archive_path");
}

sub get_hashes {
    my ($skill_dir) = @_;
    my %hashes;
    
    find(sub {
        return if -d $_ && /\.git/;
        return unless -f $_;
        
        my $relative_path = $File::Find::name;
        $relative_path =~ s/^\Q$skill_dir\E\/?//;
        return if $relative_path eq '' || $relative_path =~ /\.git/;
        
        open(my $fh, '<', $_) or return;
        binmode($fh);
        $hashes{$relative_path} = md5_hex(<$fh>);
        close($fh);
    }, $skill_dir);
    
    return %hashes;
}

sub compare_hashes {
    my ($hash1_ref, $hash2_ref) = @_;
    my %hash1 = %$hash1_ref;
    my %hash2 = %$hash2_ref;
    
    # Prüfe ob alle Keys übereinstimmen
    my @keys1 = sort keys %hash1;
    my @keys2 = sort keys %hash2;
    
    return 0 unless @keys1 == @keys2;
    
    for my $key (@keys1) {
        return 0 unless exists $hash2{$key};
        return 0 unless $hash1{$key} eq $hash2{$key};
    }
    
    return 1;
}

sub sync_skill_bidirectional {
    my ($skill_name, $dry_run) = @_;
    $dry_run //= 0;
    
    my $clawhub_path = "$CLAWHUB_DIR/$skill_name";
    my $git_path = "$GIT_DIR/$skill_name";
    
    # Fall 1: Nur in ClawHub → zu Git
    if (-d $clawhub_path && !-d $git_path) {
        &log("NEW in ClawHub: $skill_name → syncing to Git");
        unless ($dry_run) {
            backup_skill_dir($clawhub_path, "${skill_name}_clawhub");
        }
        if (&sync_to_git($skill_name, $dry_run)) {
            unless ($dry_run) {
                init_git_repo($git_path, $skill_name);
            }
            return "synced_to_git";
        }
    }
    
    # Fall 2: Nur in Git → zu ClawHub
    elsif (-d $git_path && !-d $clawhub_path) {
        &log("NEW in Git: $skill_name → syncing to ClawHub");
        unless ($dry_run) {
            backup_skill_dir($git_path, "${skill_name}_git");
        }
        if (&sync_to_clawhub($skill_name, $dry_run)) {
            return "synced_to_clawhub";
        }
    }
    
    # Fall 3: In beiden vorhanden → Vergleiche Timestamps
    elsif (-d $clawhub_path && -d $git_path) {
        # Validiere beide Skills
        unless (&validate_skill($clawhub_path)) {
            &log("Validation failed for ClawHub skill: $skill_name", "ERROR");
            return "error";
        }
        unless (&validate_skill($git_path)) {
            &log("Validation failed for Git skill: $skill_name", "ERROR");
            return "error";
        }
        
        # Berechne Hashes
        my %clawhub_hashes = get_hashes($clawhub_path);
        my %git_hashes = get_hashes($git_path);
        
        unless (compare_hashes(\%clawhub_hashes, \%git_hashes)) {
            &log("Content difference detected for: $skill_name");
            
            # Bestimme Richtung basierend auf Modifikationszeit
            my @clawhub_stat = stat($clawhub_path);
            my @git_stat = stat($git_path);
            my $direction = $clawhub_stat[9] >= $git_stat[9] ? "to-git" : "to-clawhub";
            
            &log("UPDATE: $skill_name → syncing $direction");
            unless ($dry_run) {
                backup_skill_dir($clawhub_path, "${skill_name}_clawhub");
                backup_skill_dir($git_path, "${skill_name}_git");
            }
            
            my $sync_func = $direction eq "to-git" ? \&sync_to_git : \&sync_to_clawhub;
            if ($sync_func->($skill_name, $dry_run)) {
                if (!$dry_run && $direction eq "to-git") {
                    chdir($git_path) or die "Kann nicht in $git_path wechseln: $!";
                    system("git add . >/dev/null 2>&1");
                    my $commit_time = strftime("%Y-%m-%d %H:%M", localtime);
                    system("git commit -m 'Sync from ClawHub content diff: $commit_time' >/dev/null 2>&1");
                }
                return $direction eq "to-git" ? "updated_git" : "updated_clawhub";
            } else {
                &log("Failed to sync $skill_name to Git after content diff", "ERROR");
                return "error";
            }
        } else {
            &log("Content is identical for: $skill_name");
            return "no_change";
        }
    }
    
    return "no_change";
}

sub main {
    # Parse Kommandozeilenargumente
    my $dry_run = 0;
    for my $arg (@ARGV) {
        if ($arg eq '--dry-run') {
            $dry_run = 1;
        }
    }
    
    &log("=== ClawHub ↔ Git Sync Agent gestartet ===");
    
    my $state = load_state();
    my @all_skills = get_all_skills();
    &log("Gefundene Skills: " . scalar(@all_skills));
    
    my %results = (
        synced_to_git => [],
        synced_to_clawhub => [],
        updated_git => [],
        updated_clawhub => [],
        no_change => [],
        errors => []
    );
    
    for my $skill (sort @all_skills) {
        eval {
            my $result = sync_skill_bidirectional($skill, $dry_run);
            push @{$results{$result}}, $skill;
        };
        if ($@) {
            &log("ERROR syncing $skill: $@", "ERROR");
            push @{$results{errors}}, $skill;
        }
    }
    
    # Zusammenfassung
    &log("\n=== SYNC ZUSAMMENFASSUNG ===");
    &log("Neu in Git: " . scalar(@{$results{synced_to_git}}) . " - [" . join(", ", @{$results{synced_to_git}}) . "]");
    &log("Neu in ClawHub: " . scalar(@{$results{synced_to_clawhub}}) . " - [" . join(", ", @{$results{synced_to_clawhub}}) . "]");
    &log("Git aktualisiert: " . scalar(@{$results{updated_git}}) . " - [" . join(", ", @{$results{updated_git}}) . "]");
    &log("ClawHub aktualisiert: " . scalar(@{$results{updated_clawhub}}) . " - [" . join(", ", @{$results{updated_clawhub}}) . "]");
    &log("Keine Änderung: " . scalar(@{$results{no_change}}));
    &log("Fehler: " . scalar(@{$results{errors}}) . " - [" . join(", ", @{$results{errors}}) . "]");
    
    # Speichere Zustand außer bei Dry-Run
    unless ($dry_run) {
        $state->{sync_history} //= [];
        push @{$state->{sync_history}}, {
            timestamp => strftime("%Y-%m-%dT%H:%M:%S", localtime),
            results => \%results
        };
        
        # Behalte nur letzte 100 Einträge
        splice(@{$state->{sync_history}}, 0, @{$state->{sync_history}} - 100) 
            if @{$state->{sync_history}} > 100;
            
        save_state($state);
    }
    
    &log("=== Sync Agent beendet ===\n");
}

main() unless caller;
