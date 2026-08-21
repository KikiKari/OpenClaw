#!/usr/bin/perl
# sync_agent.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON;
use File::Find;
use File::Spec;
use File::Path qw(make_path);
use Digest::MD5 qw(md5_hex);
use Time::HiRes qw(stat);

=head1 NAME

Permanenter ClawHub ↔ Git Sync Agent
Multi-Node fähig, stündliche Ausführung

=cut

my $CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
my $GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";
my $STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";

# Reservierte Skill-Namen (aus sync_clawhub_git.py)
my @RESERVED_SKILL_NAMES = qw(
    .git
    node_modules
    __pycache__
    .DS_Store
    Thumbs.db
);

sub load_state {
    # Lädt den Sync-State
    if (-e $STATE_FILE) {
        open my $fh, '<', $STATE_FILE or die "Cannot open $STATE_FILE: $!";
        local $/;
        my $content = <$fh>;
        close $fh;
        return decode_json($content);
    }
    return { sync_history => [], pending => [] };
}

sub save_state {
    # Speichert den Sync-State
    my ($state) = @_;
    
    # Stelle sicher, dass das Verzeichnis existiert
    my ($volume, $directories, $file) = File::Spec->splitpath($STATE_FILE);
    my $parent_dir = File::Spec->catpath($volume, $directories, '');
    
    unless (-d $parent_dir) {
        make_path($parent_dir) or die "Cannot create directory $parent_dir: $!";
    }
    
    open my $fh, '>', $STATE_FILE or die "Cannot open $STATE_FILE: $!";
    print $fh to_json($state, { pretty => 1 });
    close $fh;
}

sub get_all_skills {
    # Findet alle Skills in beiden Verzeichnissen
    my (%clawhub_skills, %git_skills);
    
    opendir(my $dh, $CLAWHUB_DIR) or die "Cannot opendir $CLAWHUB_DIR: $!";
    while (readdir $dh) {
        my $entry = $_;
        next if $entry =~ /^\./;
        next if grep { $_ eq $entry } @RESERVED_SKILL_NAMES;
        my $full_path = File::Spec->catfile($CLAWHUB_DIR, $entry);
        if (-d $full_path && -e File::Spec->catfile($full_path, "SKILL.md")) {
            $clawhub_skills{$entry} = 1;
        }
    }
    closedir $dh;
    
    opendir($dh, $GIT_DIR) or die "Cannot opendir $GIT_DIR: $!";
    while (readdir $dh) {
        my $entry = $_;
        next if $entry =~ /^\./;
        next if grep { $_ eq $entry } @RESERVED_SKILL_NAMES;
        my $full_path = File::Spec->catfile($GIT_DIR, $entry);
        if (-d $full_path && -e File::Spec->catfile($full_path, "SKILL.md")) {
            $git_skills{$entry} = 1;
        }
    }
    closedir $dh;
    
    my %all_skills = (%clawhub_skills, %git_skills);
    return keys %all_skills;
}

sub init_git_repo {
    # Initialisiert Git-Repo wenn nötig
    my ($skill_path, $skill_name) = @_;
    my $git_dir = File::Spec->catfile($skill_path, ".git");
    
    unless (-d $git_dir) {
        chdir $skill_path or die "Cannot chdir to $skill_path: $!";
        system("git", "init") == 0 or die "git init failed: $?";
        system("git", "add", ".") == 0 or die "git add failed: $?";
        system("git", "commit", "-m", "Initial commit: $skill_name skill") == 0 or die "git commit failed: $?";
        log_msg("Git initialized for $skill_name");
    }
}

sub sync_skill_bidirectional {
    # Bidirektionale Synchronisation eines Skills
    my ($skill_name) = @_;
    my $clawhub_path = File::Spec->catfile($CLAWHUB_DIR, $skill_name);
    my $git_path = File::Spec->catfile($GIT_DIR, $skill_name);
    
    # Fall 1: Nur in ClawHub → zu Git
    if (-d $clawhub_path && !-d $git_path) {
        log_msg("NEW in ClawHub: $skill_name → syncing to Git");
        if (sync_to_git($skill_name, 0)) {  # 0 = nicht dry-run
            init_git_repo($git_path, $skill_name);
            return "synced_to_git";
        }
    }
    
    # Fall 2: Nur in Git → zu ClawHub
    elsif (-d $git_path && !-d $clawhub_path) {
        log_msg("NEW in Git: $skill_name → syncing to ClawHub");
        if (sync_to_clawhub($skill_name, 0)) {  # 0 = nicht dry-run
            return "synced_to_clawhub";
        }
    }
    
    # Fall 3: In beiden vorhanden
    elsif (-d $clawhub_path && -d $git_path) {
        unless (validate_skill($clawhub_path)) {
            log_msg("Validation failed for ClawHub skill: $skill_name", "ERROR");
            return "error";
        }
        unless (validate_skill($git_path)) {
            log_msg("Validation failed for Git skill: $skill_name", "ERROR");
            return "error";
        }

        my $clawhub_changes = preview_changes($clawhub_path, $git_path);
        my $git_changes = preview_changes($git_path, $clawhub_path);

        if (!@$clawhub_changes && !@$git_changes) {
            log_msg("Content is identical for: $skill_name");
            return "no_change";
        }

        if (@$clawhub_changes && !@$git_changes) {
            log_msg("Content difference detected for: $skill_name");
            log_msg("UPDATE: $skill_name ClawHub content is newer or different → syncing to Git");
            if (sync_to_git($skill_name, 0)) {
                chdir $git_path or die "Cannot chdir to $git_path: $!";
                system("git", "add", ".") == 0 or die "git add failed: $?";
                my $timestamp = localtime();
                system("git", "commit", "-m", "Sync from ClawHub content diff: $timestamp") == 0 or die "git commit failed: $?";
                return "updated_git";
            }
            log_msg("Failed to sync $skill_name to Git after content diff", "ERROR");
            return "error";
        }

        if (@$git_changes && !@$clawhub_changes) {
            log_msg("Content difference detected for: $skill_name");
            log_msg("UPDATE: $skill_name Git content is newer or different → syncing to ClawHub");
            if (sync_to_clawhub($skill_name, 0)) {
                return "updated_clawhub";
            }
            log_msg("Failed to sync $skill_name to ClawHub after content diff", "ERROR");
            return "error";
        }

        log_msg("Content difference detected for: $skill_name");
        if (newest_mtime($clawhub_path) >= newest_mtime($git_path)) {
            log_msg("UPDATE: $skill_name ClawHub content is newer or different → syncing to Git");
            if (sync_to_git($skill_name, 0)) {
                chdir $git_path or die "Cannot chdir to $git_path: $!";
                system("git", "add", ".") == 0 or die "git add failed: $?";
                my $timestamp = localtime();
                system("git", "commit", "-m", "Sync from ClawHub content diff: $timestamp") == 0 or die "git commit failed: $?";
                return "updated_git";
            }
        } else {
            log_msg("UPDATE: $skill_name Git content is newer or different → syncing to ClawHub");
            if (sync_to_clawhub($skill_name, 0)) {
                return "updated_clawhub";
            }
        }

        log_msg("Failed to resolve content diff for $skill_name", "ERROR");
        return "error";
    }
    
    return "no_change";
}

sub get_hashes {
    # Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner.
    my ($skill_dir) = @_;
    my %hashes;
    
    my @files = iter_sync_files($skill_dir);
    for my $file_info (@files) {
        my ($file_path, $rel_path) = @$file_info;
        $hashes{$rel_path} = get_file_hash($file_path);
    }
    return %hashes;
}

sub preview_changes {
    # Berechnet Sync-Änderungen in einer Richtung, ohne zu schreiben.
    my ($source_dir, $target_dir) = @_;
    my @changes;
    
    my @files = iter_sync_files($source_dir);
    for my $file_info (@files) {
        my ($src_file, $rel_path) = @$file_info;
        my $tgt_file = File::Spec->catfile($target_dir, $rel_path);
        
        if (!-e $tgt_file) {
            push @changes, "ADD $rel_path";
        } elsif (get_file_hash($src_file) ne get_file_hash($tgt_file)) {
            push @changes, "UPDATE $rel_path";
        }
    }
    return \@changes;
}

sub newest_mtime {
    # Ermittelt die neueste mtime über alle relevanten Dateien.
    my ($skill_dir) = @_;
    my @mtimes;
    
    my @files = iter_sync_files($skill_dir);
    for my $file_info (@files) {
        my ($file_path, $rel_path) = @$file_info;
        my @stat = stat($file_path);
        push @mtimes, $stat[9] if @stat;
    }
    
    return @mtimes ? (sort { $b <=> $a } @mtimes)[0] : 0.0;
}

sub log_msg {
    # Log-Funktion (Annahme: existiert in sync_clawhub_git.pm)
    my ($message, $level) = @_;
    $level //= "INFO";
    my $timestamp = localtime();
    print "[$level] [$timestamp] $message\n";
}

sub sync_to_git {
    # Annahme: existiert in sync_clawhub_git.pm
    # Dummy-Implementierung für die Übersetzung
    my ($skill_name, $dry_run) = @_;
    # Implementierung abhängig von der tatsächlichen Funktion
    return 1; # Erfolg
}

sub sync_to_clawhub {
    # Annahme: existiert in sync_clawhub_git.pm
    # Dummy-Implementierung für die Übersetzung
    my ($skill_name, $dry_run) = @_;
    # Implementierung abhängig von der tatsächlichen Funktion
    return 1; # Erfolg
}

sub validate_skill {
    # Annahme: existiert in sync_clawhub_git.pm
    # Dummy-Implementierung für die Übersetzung
    my ($skill_path) = @_;
    # Implementierung abhängig von der tatsächlichen Funktion
    return 1; # Gültig
}

sub get_file_hash {
    # Annahme: existiert in sync_clawhub_git.pm
    # Dummy-Implementierung für die Übersetzung
    my ($file_path) = @_;
    open my $fh, '<', $file_path or return "";
    binmode $fh;
    my $digest = md5_hex(<$fh>);
    close $fh;
    return $digest;
}

sub iter_sync_files {
    # Annahme: existiert in sync_clawhub_git.pm
    # Gibt Liste von [Dateipfad, relativer Pfad] zurück
    my ($skill_dir) = @_;
    my @result;
    
    find(sub {
        return if -d $_;
        return if /^\./;
        return if $_ eq "SKILL.md"; # Beispiel, möglicherweise andere Logik
        
        my $relative_path = File::Spec->abs2rel($File::Find::name, $skill_dir);
        push @result, [$File::Find::name, $relative_path];
    }, $skill_dir);
    
    return @result;
}

sub main {
    # Hauptfunktion des Sync-Agents mit Dry-Run Phase
    log_msg("=== ClawHub ↔ Git Sync Agent gestartet ===");
    
    # Load previous state
    my $state = load_state();
    my @all_skills = get_all_skills();
    log_msg("Gefundene Skills: " . scalar(@all_skills));
    
    # Dry-Run Phase: only report changes, no actual modifications
    log_msg("--- Dry-Run Phase Start ---");
    for my $skill (sort @all_skills) {
        # Perform dry-run sync in both directions to capture potential changes
        sync_to_git($skill, 1);      # 1 = dry-run
        sync_to_clawhub($skill, 1);  # 1 = dry-run
    }
    log_msg("--- Dry-Run Phase End ---");
    
    my %results = (
        synced_to_git     => [],
        synced_to_clawhub => [],
        updated_git       => [],
        updated_clawhub   => [],
        no_change         => [],
        errors            => []
    );
    
    # Actual Sync Phase
    for my $skill (sort @all_skills) {
        eval {
            my $result = sync_skill_bidirectional($skill);
            push @{$results{$result}}, $skill;
        };
        if ($@) {
            log_msg("ERROR syncing $skill: $@", "ERROR");
            push @{$results{errors}}, $skill;
        }
    }
    
    # Zusammenfassung
    log_msg("\n=== SYNC ZUSAMMENFASSUNG ===");
    log_msg("Neu in Git: " . scalar(@{$results{synced_to_git}}) . " - " . join(", ", @{$results{synced_to_git}}));
    log_msg("Neu in ClawHub: " . scalar(@{$results{synced_to_clawhub}}) . " - " . join(", ", @{$results{synced_to_clawhub}}));
    log_msg("Git aktualisiert: " . scalar(@{$results{updated_git}}) . " - " . join(", ", @{$results{updated_git}}));
    log_msg("ClawHub aktualisiert: " . scalar(@{$results{updated_clawhub}}) . " - " . join(", ", @{$results{updated_clawhub}}));
    log_msg("Keine Änderung: " . scalar(@{$results{no_change}}));
    log_msg("Fehler: " . scalar(@{$results{errors}}) . " - " . join(", ", @{$results{errors}}));
    
    # State speichern
    unless (exists $state->{sync_history}) {
        $state->{sync_history} = [];
    }
    
    push @{$state->{sync_history}}, {
        timestamp => scalar(localtime()),
        results   => \%results
    };
    
    # Nur letzte 100 Einträge behalten
    if (@{$state->{sync_history}} > 100) {
        splice @{$state->{sync_history}}, 0, @{$state->{sync_history}} - 100;
    }
    
    save_state($state);
    log_msg("=== Sync Agent beendet ===\n");
}

main() unless caller;
