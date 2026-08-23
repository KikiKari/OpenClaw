#!/usr/bin/perl
# sync_status.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_status.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_status.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON;
use File::Find;
use File::Spec;
use Time::Piece;

# Sync Status - Zeigt Status aller Skills

my $CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
my $GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";
my $STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";

# Füge das Script-Verzeichnis zum Suchpfad hinzu
unshift @INC, '/home/openclaw/.openclaw/workspace/scripts';

# Lade die Funktion get_file_hash aus sync_clawhub_git.pl
require "sync_clawhub_git.pl";

sub get_max_mtime {
    my ($path, $exclude_git) = @_;
    my $max_mtime = 0;
    
    find(sub {
        return if -d $_ && $_ eq '.git' && $exclude_git;
        return unless -f $_;
        my $mtime = (stat($_))[9] // 0;
        $max_mtime = $mtime if $mtime > $max_mtime;
    }, $path);
    
    return $max_mtime;
}

sub check_skill_status {
    my ($skill_name) = @_;
    
    my $clawhub_path = File::Spec->catdir($CLAWHUB_DIR, $skill_name);
    my $git_path = File::Spec->catdir($GIT_DIR, $skill_name);
    
    my %status = (
        name => $skill_name,
        in_clawhub => -d $clawhub_path,
        in_git => -d $git_path,
        has_git_repo => (-d $git_path && -d File::Spec->catdir($git_path, ".git")),
        status => "unknown",
        last_modified => {}
    );
    
    # Status bestimmen
    if ($status{in_clawhub} && !$status{in_git}) {
        $status{status} = "only_clawhub";
    } elsif ($status{in_git} && !$status{in_clawhub}) {
        $status{status} = "only_git";
    } elsif ($status{in_clawhub} && $status{in_git}) {
        # Timestamps vergleichen
        eval {
            my $clawhub_mtime = get_max_mtime($clawhub_path, 0);
            my $git_mtime = get_max_mtime($git_path, 1);
            
            my $clawhub_time_str = localtime($clawhub_mtime)->strftime('%Y-%m-%d %H:%M:%S');
            my $git_time_str = localtime($git_mtime)->strftime('%Y-%m-%d %H:%M:%S');
            
            $status{last_modified}->{clawhub} = $clawhub_time_str;
            $status{last_modified}->{git} = $git_time_str;
            
            if (abs($clawhub_mtime - $git_mtime) < 60) {
                $status{status} = "synced";
            } elsif ($clawhub_mtime > $git_mtime) {
                $status{status} = "clawhub_newer";
            } else {
                $status{status} = "git_newer";
            }
        };
        if ($@) {
            $status{status} = "error";
        }
    }
    
    return \%status;
}

sub main {
    print "=" x 80 . "\n";
    print "ClawHub ↔ Git Sync Status\n";
    print "=" x 80 . "\n";
    my $now = localtime->strftime('%Y-%m-%d %H:%M:%S');
    print "Zeitpunkt: $now\n\n";
    
    # Alle Skills finden
    my %all_skills;
    
    if (-d $CLAWHUB_DIR) {
        opendir(my $dh, $CLAWHUB_DIR) or die "Kann $CLAWHUB_DIR nicht öffnen: $!";
        while (readdir $dh) {
            next if /^\./;
            my $path = File::Spec->catdir($CLAWHUB_DIR, $_);
            $all_skills{$_} = 1 if -d $path;
        }
        closedir $dh;
    }
    
    if (-d $GIT_DIR) {
        opendir(my $dh, $GIT_DIR) or die "Kann $GIT_DIR nicht öffnen: $!";
        while (readdir $dh) {
            next if /^\./;
            my $path = File::Spec->catdir($GIT_DIR, $_);
            $all_skills{$_} = 1 if -d $path;
        }
        closedir $dh;
    }
    
    # Status-Kategorien
    my %categories = (
        synced => [],
        clawhub_newer => [],
        git_newer => [],
        only_clawhub => [],
        only_git => [],
        error => []
    );
    
    # Status für jeden Skill prüfen
    for my $skill (sort keys %all_skills) {
        my $status = check_skill_status($skill);
        push @{$categories{$status->{status}}}, $status;
    }
    
    # Ausgabe
    my $total_skills = scalar(keys %all_skills);
    print "📊 Gesamt: $total_skills Skills\n\n";
    
    # Synchronisiert
    if (@{$categories{synced}}) {
        printf "✅ Synchronisiert (%d)\n", scalar(@{$categories{synced}});
        for my $s (@{$categories{synced}}) {
            print "   - $s->{name}\n";
        }
        print "\n";
    }
    
    # ClawHub neuer
    if (@{$categories{clawhub_newer}}) {
        printf "🔄 ClawHub neuer (%d)\n", scalar(@{$categories{clawhub_newer}});
        for my $s (@{$categories{clawhub_newer}}) {
            print "   - $s->{name} (ClawHub: $s->{last_modified}->{clawhub})\n";
        }
        print "\n";
    }
    
    # Git neuer
    if (@{$categories{git_newer}}) {
        printf "🔄 Git neuer (%d)\n", scalar(@{$categories{git_newer}});
        for my $s (@{$categories{git_newer}}) {
            print "   - $s->{name} (Git: $s->{last_modified}->{git})\n";
        }
        print "\n";
    }
    
    # Nur in ClawHub
    if (@{$categories{only_clawhub}}) {
        printf "📦 Nur in ClawHub (%d)\n", scalar(@{$categories{only_clawhub}});
        for my $s (@{$categories{only_clawhub}}) {
            print "   - $s->{name}\n";
        }
        print "\n";
    }
    
    # Nur in Git
    if (@{$categories{only_git}}) {
        printf "📁 Nur in Git (%d)\n", scalar(@{$categories{only_git}});
        for my $s (@{$categories{only_git}}) {
            print "   - $s->{name}\n";
        }
        print "\n";
    }
    
    # Fehler
    if (@{$categories{error}}) {
        printf "❌ Fehler (%d)\n", scalar(@{$categories{error}});
        for my $s (@{$categories{error}}) {
            print "   - $s->{name}\n";
        }
        print "\n";
    }
    
    # State-File Info
    if (-f $STATE_FILE) {
        open(my $fh, '<', $STATE_FILE) or die "Kann $STATE_FILE nicht öffnen: $!";
        my $json_text = do { local $/; <$fh> };
        close $fh;
        
        my $state = decode_json($json_text);
        my $last_sync = $state->{last_sync} || {};
        my @last_runs = sort keys %$last_sync;
        
        if (@last_runs) {
            my $last_run = $last_runs[-1];
            print "📅 Letzter automatischer Sync: $last_run\n";
        }
    }
    
    print "=" x 80 . "\n";
}

main() if __FILE__ eq $0;
