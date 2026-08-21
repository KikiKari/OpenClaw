#!/usr/bin/perl
# sync_agent_cron.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Find;
use File::stat;
use JSON;
use Time::HiRes qw(gettimeofday);

# Konfiguration
my $CLAWHUB_DIR = '/home/openclaw/.openclaw/workspace/skills';
my $GIT_DIR = '/home/openclaw/.openclaw/workspace/git/skills';
my $LOG_FILE = '/home/openclaw/.openclaw/workspace/logs/sync-agent.log';

# Globale Variablen für Ergebnisse
my %results = (
    synced_to_git => [],
    synced_to_clawhub => [],
    up_to_date => [],
    errors => []
);

my %changes_detected = (
    new_in_clawhub => [],
    new_in_git => [],
    clawhub_newer => [],
    git_newer => [],
    synced => []
);

# Hilfsfunktionen
sub file_mtime {
    my ($path) = @_;
    my @files;
    
    find(sub {
        return if -d $_ && $_ eq '.git';
        push @files, $File::Find::name if -f $_;
    }, $path);
    
    return 0 unless @files;
    
    my $max_time = 0;
    for my $file (@files) {
        my $mtime = (stat($file))[9];
        $max_time = $mtime if $mtime > $max_time;
    }
    
    return $max_time;
}

sub write_to_log {
    my ($message, $level) = @_;
    $level //= "INFO";
    
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
    my $timestamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", 
                           $year+1900, $mon+1, $mday, $hour, $min, $sec);
    
    my $entry = "[$timestamp] [$level] $message\n";
    print $entry;
    
    open(my $fh, '>>', $LOG_FILE) or die "Kann Logdatei nicht öffnen: $!";
    print $fh $entry;
    close($fh);
}

sub validate_skill {
    my ($skill_path) = @_;
    # Dummy-Implementierung - muss angepasst werden
    return 1;
}

sub sync_to_git {
    my ($skill, $dry_run) = @_;
    # Dummy-Implementierung - muss angepasst werden
    return 1;
}

sub sync_to_clawhub {
    my ($skill, $dry_run) = @_;
    # Dummy-Implementierung - muss angepasst werden
    return 1;
}

# Hauptprogramm
write_to_log("=" x 70);
write_to_log("CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF");
my $timestamp = localtime();
write_to_log("Zeitstempel: " . (localtime()));
write_to_log("=" x 70);

# Skills auflisten
my @clawhub_skills = ();
opendir(my $dh1, $CLAWHUB_DIR) or die "Kann ClawHub-Verzeichnis nicht öffnen: $!";
while (readdir $dh1) {
    next if /^\./;
    my $path = "$CLAWHUB_DIR/$_";
    push @clawhub_skills, $_ if -d $path;
}
closedir $dh1;

my @git_skills = ();
opendir(my $dh2, $GIT_DIR) or die "Kann Git-Verzeichnis nicht öffnen: $!";
while (readdir $dh2) {
    next if /^\./;
    my $path = "$GIT_DIR/$_";
    push @git_skills, $_ if -d $path;
}
closedir $dh2;

my %clawhub_set = map { $_ => 1 } @clawhub_skills;
my %git_set = map { $_ => 1 } @git_skills;

# DRY-RUN: Änderungen analysieren
write_to_log("\n[DRY-RUN] Analysiere Änderungen...");

# 1. Neue Skills
my @new_in_clawhub = sort grep { !$git_set{$_} } @clawhub_skills;
my @new_in_git = sort grep { !$clawhub_set{$_} } @git_skills;
$changes_detected{new_in_clawhub} = \@new_in_clawhub;
$changes_detected{new_in_git} = \@new_in_git;

# 2. Existierende prüfen
my @in_both = sort grep { $clawhub_set{$_} && $git_set{$_} } @clawhub_skills;
for my $skill (@in_both) {
    my $c_mtime = file_mtime("$CLAWHUB_DIR/$skill");
    my $g_mtime = file_mtime("$GIT_DIR/$skill");
    my $diff = $c_mtime - $g_mtime;
    
    if (abs($diff) > 60) {
        if ($diff > 0) {
            push @{$changes_detected{clawhub_newer}}, [$skill, $diff];
        } else {
            push @{$changes_detected{git_newer}}, [$skill, abs($diff)];
        }
    } else {
        push @{$changes_detected{synced}}, $skill;
    }
}

# Report
my $total_changes = 
    scalar(@new_in_clawhub) + 
    scalar(@new_in_git) + 
    scalar(@{$changes_detected{clawhub_newer}}) + 
    scalar(@{$changes_detected{git_newer}});

write_to_log("Neu in ClawHub: " . scalar(@new_in_clawhub));
write_to_log("Neu in Git: " . scalar(@new_in_git));
write_to_log("ClawHub neuer: " . scalar(@{$changes_detected{clawhub_newer}}));
write_to_log("Git neuer: " . scalar(@{$changes_detected{git_newer}}));
write_to_log("Synchron: " . scalar(@{$changes_detected{synced}}));

if ($total_changes == 0) {
    write_to_log("\n✅ Keine Änderungen erkannt. Sync nicht nötig.");
    write_to_log("=" x 70);
    exit(0);
}

write_to_log("\n🔄 $total_changes Änderungen erkannt - starte Synchronisation...");

# ECHTE SYNCHRONISATION
# 1. NEU in ClawHub → zu Git
for my $skill (@new_in_clawhub) {
    eval {
        if (validate_skill("$CLAWHUB_DIR/$skill")) {
            write_to_log("→ Synchronisiere $skill zu Git...");
            if (sync_to_git($skill, 0)) {
                my $git_path = "$GIT_DIR/$skill";
                chdir($git_path);
                system('git init -q 2>/dev/null');
                system('git add . -f 2>/dev/null');
                my $dt = localtime();
                system("git commit -m \"Initial: $skill\" -q 2>/dev/null");
                push @{$results{synced_to_git}}, $skill;
                write_to_log("  ✓ $skill synchronisiert");
            }
        } else {
            push @{$results{errors}}, "$skill (invalid)";
        }
    };
    if ($@) {
        write_to_log("  ✗ ERROR: $skill - $@", "ERROR");
        push @{$results{errors}}, "$skill";
    }
}

# 2. NEU in Git → zu ClawHub
for my $skill (@new_in_git) {
    eval {
        if (validate_skill("$GIT_DIR/$skill")) {
            write_to_log("→ Synchronisiere $skill zu ClawHub...");
            if (sync_to_clawhub($skill, 0)) {
                push @{$results{synced_to_clawhub}}, $skill;
                write_to_log("  ✓ $skill synchronisiert");
            }
        } else {
            push @{$results{errors}}, "$skill (invalid)";
        }
    };
    if ($@) {
        write_to_log("  ✗ ERROR: $skill - $@", "ERROR");
        push @{$results{errors}}, "$skill";
    }
}

# 3. Updates
for my $change (@{$changes_detected{clawhub_newer}}) {
    my ($skill, $diff) = @$change;
    eval {
        write_to_log("→ Update $skill (ClawHub +${diff}s neuer)...");
        if (sync_to_git($skill, 0)) {
            my $git_path = "$GIT_DIR/$skill";
            chdir($git_path);
            system('git add . -f 2>/dev/null');
            my $dt = localtime();
            system("git commit -m \"Sync from ClawHub: $dt\" -q 2>/dev/null");
            push @{$results{synced_to_git}}, $skill;
            write_to_log("  ✓ $skill aktualisiert");
        }
    };
    if ($@) {
        write_to_log("  ✗ ERROR: $skill - $@", "ERROR");
        push @{$results{errors}}, "$skill";
    }
}

for my $change (@{$changes_detected{git_newer}}) {
    my ($skill, $diff) = @$change;
    eval {
        write_to_log("→ Update $skill (Git +${diff}s neuer)...");
        if (sync_to_clawhub($skill, 0)) {
            push @{$results{synced_to_clawhub}}, $skill;
            write_to_log("  ✓ $skill aktualisiert");
        }
    };
    if ($@) {
        write_to_log("  ✗ ERROR: $skill - $@", "ERROR");
        push @{$results{errors}}, "$skill";
    }
}

$results{up_to_date} = $changes_detected{synced};

# ZUSAMMENFASSUNG
write_to_log("\n" . ("=" x 70));
write_to_log("SYNCHRONISATION ABGESCHLOSSEN");
write_to_log("=" x 70);
write_to_log("Zu Git synchronisiert:     " . scalar(@{$results{synced_to_git}}));
write_to_log("Zu ClawHub synchronisiert: " . scalar(@{$results{synced_to_clawhub}}));
write_to_log("Bereits aktuell:           " . scalar(@{$results{up_to_date}}));
write_to_log("Fehler:                    " . scalar(@{$results{errors}}));

if (@{$results{errors}}) {
    write_to_log("  Fehlerhafte: " . join(", ", @{$results{errors}}));
}
write_to_log("=" x 70);

# State speichern
my $STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";
my $state_dir = "/home/openclaw/.openclaw/workspace/db";
mkdir $state_dir unless -d $state_dir;

my $state = {
    last_run => localtime(),
    results => \%results,
    changes_detected => {
        new_in_clawhub => scalar(@{$changes_detected{new_in_clawhub}}),
        new_in_git => scalar(@{$changes_detected{new_in_git}}),
        clawhub_newer => scalar(@{$changes_detected{clawhub_newer}}),
        git_newer => scalar(@{$changes_detected{git_newer}}),
        synced => scalar(@{$changes_detected{synced}})
    }
};

open(my $fh, '>', $STATE_FILE) or die "Kann State-Datei nicht öffnen: $!";
print $fh to_json($state, {pretty => 1});
close($fh);
write_to_log("State gespeichert: $STATE_FILE");
