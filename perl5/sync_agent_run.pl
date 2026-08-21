#!/usr/bin/perl
# sync_agent_run.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_run.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_run.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Find;
use File::stat;
use Time::HiRes qw(stat);
use JSON;
use POSIX qw(strftime);

# Add the script directory to @INC
use lib '/home/openclaw/.openclaw/workspace/scripts';

# Assuming these functions are available in Perl modules or need to be implemented
# For now we'll assume they're defined elsewhere or will be stubbed
require 'sync_clawhub_git.pl';  # This would contain sync_to_git, sync_to_clawhub, log, validate_skill

my $CLAWHUB_DIR = '/home/openclaw/.openclaw/workspace/skills';
my $GIT_DIR = '/home/openclaw/.openclaw/workspace/git/skills';

sub file_mtime {
    my ($path) = @_;
    my $max_mtime = 0;
    
    find(sub {
        return if ($_ eq '.git');
        my $full_path = $File::Find::name;
        if (-f $full_path) {
            my @stat = stat($full_path);
            if (@stat && $stat[9] > $max_mtime) {
                $max_mtime = $stat[9];
            }
        }
    }, $path);
    
    return $max_mtime;
}

&log("=" x 70);
&log("CLAWHUB \x{2194} GIT SYNC AGENT - PRODUKTIONS-LAUF");
&log("Zeitstempel: " . strftime("%Y-%m-%dT%H:%M:%S", localtime));
&log("=" x 70);

opendir(my $clawhub_dh, $CLAWHUB_DIR) or die "Cannot opendir $CLAWHUB_DIR: $!";
my @clawhub_dirs = grep { !/^\./ && -d "$CLAWHUB_DIR/$_" } readdir($clawhub_dh);
closedir($clawhub_dh);
my %clawhub_skills = map { $_ => 1 } @clawhub_dirs;

opendir(my $git_dh, $GIT_DIR) or die "Cannot opendir $GIT_DIR: $!";
my @git_dirs = grep { !/^\./ && -d "$GIT_DIR/$_" } readdir($git_dh);
closedir($git_dh);
my %git_skills = map { $_ => 1 } @git_dirs;

my %results = (
    synced_to_git => [],
    synced_to_clawhub => [],
    up_to_date => [],
    errors => []
);

# PHASE 1: NEU in ClawHub → zu Git syncen
&log("\n[PHASE 1] ClawHub \x{2192} Git Synchronisation");
&log("-" x 40);

my @new_in_clawhub = sort grep { !$git_skills{$_} } keys %clawhub_skills;
foreach my $skill (@new_in_clawhub) {
    eval {
        if (&validate_skill("$CLAWHUB_DIR/$skill")) {
            &log("→ Synchronisiere $skill zu Git...");
            if (&sync_to_git($skill, 0)) {  # dry_run = false
                my $git_path = "$GIT_DIR/$skill";
                chdir($git_path) or die "Cannot chdir to $git_path: $!";
                system('git init -q 2>/dev/null');
                system('git add . -f 2>/dev/null');
                my $dt = strftime("%Y-%m-%d %H:%M", localtime);
                system("git commit -m \"Initial: $skill\" -q 2>/dev/null");
                push @{$results{synced_to_git}}, $skill;
                &log("  ✓ $skill synchronisiert & Git initialisiert");
            } else {
                push @{$results{errors}}, "$skill (sync failed)";
            }
        } else {
            push @{$results{errors}}, "$skill (invalid)";
        }
    };
    if ($@) {
        &log("  ✗ ERROR: $skill - $@", "ERROR");
        push @{$results{errors}}, "$skill (exception)";
    }
}

# PHASE 2: Prüfe existierende Skills auf Änderungen
&log("\n[PHASE 2] Prüfe existierende Skills auf Änderungen");
&log("-" x 40);

my @in_both = sort grep { $git_skills{$_} } keys %clawhub_skills;
foreach my $skill (@in_both) {
    eval {
        my $c_mtime = file_mtime("$CLAWHUB_DIR/$skill");
        my $g_mtime = file_mtime("$GIT_DIR/$skill");
        my $diff = $c_mtime - $g_mtime;

        if (abs($diff) > 60) {
            if ($diff > 0) {
                &log("→ $skill: ClawHub neuer (+".int($diff)."s) → sync zu Git");
                if (&sync_to_git($skill, 0)) {
                    my $git_path = "$GIT_DIR/$skill";
                    chdir($git_path) or die "Cannot chdir to $git_path: $!";
                    system('git add . -f 2>/dev/null');
                    my $dt = strftime("%Y-%m-%d %H:%M", localtime);
                    system("git commit -m \"Sync from ClawHub: $dt\" -q 2>/dev/null");
                    push @{$results{synced_to_git}}, $skill;
                } else {
                    push @{$results{errors}}, "$skill (update failed)";
                }
            } else {
                &log("→ $skill: Git neuer (+".int(abs($diff))."s) → sync zu ClawHub");
                if (&sync_to_clawhub($skill, 0)) {
                    push @{$results{synced_to_clawhub}}, $skill;
                } else {
                    push @{$results{errors}}, "$skill (update failed)";
                }
            }
        } else {
            push @{$results{up_to_date}}, $skill;
        }
    };
    if ($@) {
        &log("  ✗ ERROR: $skill - $@", "ERROR");
        push @{$results{errors}}, "$skill (exception)";
    }
}

# ZUSAMMENFASSUNG
&log("\n" . "=" x 70);
&log("SYNCHRONISATION ABGESCHLOSSEN");
&log("=" x 70);
&log(sprintf("Zu Git synchronisiert:     %d", scalar(@{$results{synced_to_git}})));
if (@{$results{synced_to_git}}) {
    &log("  ". join(", ", @{$results{synced_to_git}}));
}
&log(sprintf("Zu ClawHub synchronisiert: %d", scalar(@{$results{synced_to_clawhub}})));
if (@{$results{synced_to_clawhub}}) {
    &log("  ". join(", ", @{$results{synced_to_clawhub}}));
}
&log(sprintf("Bereits aktuell:           %d", scalar(@{$results{up_to_date}})));
&log(sprintf("Fehler:                    %d", scalar(@{$results{errors}})));
if (@{$results{errors}}) {
    &log("  ". join(", ", @{$results{errors}}));
}
&log("=" x 70);

# Speichere State
my $STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";
my $state_dir = "/home/openclaw/.openclaw/workspace/db";
mkdir($state_dir, 0755) unless -d $state_dir;

my $timestamp = strftime("%Y-%m-%dT%H:%M:%S", localtime);
my $state_data = {
    last_run => $timestamp,
    results => \%results
};

open(my $fh, '>', $STATE_FILE) or die "Cannot write to $STATE_FILE: $!";
print $fh to_json($state_data, { pretty => 1 });
close($fh);
&log("State gespeichert: $STATE_FILE");
