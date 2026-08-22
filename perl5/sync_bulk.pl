#!/usr/bin/perl
# sync_bulk.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin";
use File::Find;
use File::stat;
use Time::HiRes qw(stat);

# Bulk Sync - Synchronisiert alle Skills

# Import sync functions
use lib '/home/openclaw/.openclaw/workspace/scripts';
require 'sync_clawhub_git.pl';

my $CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
my $GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";

sub sync_all_skills {
    my ($dry_run) = @_;
    
    # Alle Skills finden
    my %all_skills;
    if (-d $CLAWHUB_DIR) {
        opendir(my $dh, $CLAWHUB_DIR) or die "Cannot open directory $CLAWHUB_DIR: $!";
        while (readdir($dh)) {
            next if /^\./;
            next unless -d "$CLAWHUB_DIR/$_";
            $all_skills{$_} = 1;
        }
        closedir($dh);
    }
    if (-d $GIT_DIR) {
        opendir(my $dh, $GIT_DIR) or die "Cannot open directory $GIT_DIR: $!";
        while (readdir($dh)) {
            next if /^\./;
            next unless -d "$GIT_DIR/$_";
            $all_skills{$_} = 1;
        }
        closedir($dh);
    }
    
    log_msg("Bulk Sync: " . scalar(keys %all_skills) . " Skills gefunden");
    
    my %results = (
        "synced" => [],
        "skipped" => [],
        "failed" => []
    );
    
    for my $skill (sort keys %all_skills) {
        my $clawhub_path = "$CLAWHUB_DIR/$skill";
        my $git_path = "$GIT_DIR/$skill";
        
        eval {
            # Nur in ClawHub → zu Git
            if (-d $clawhub_path && !-d $git_path) {
                if (validate_skill($clawhub_path)) {
                    log_msg("Syncing $skill to Git...");
                    if (sync_to_git($skill, $dry_run)) {
                        push @{$results{"synced"}}, "$skill → Git";
                    } else {
                        push @{$results{"failed"}}, $skill;
                    }
                } else {
                    push @{$results{"skipped"}}, "$skill (validation failed)";
                }
            
            # Nur in Git → zu ClawHub
            } elsif (-d $git_path && !-d $clawhub_path) {
                if (validate_skill($git_path)) {
                    log_msg("Syncing $skill to ClawHub...");
                    if (sync_to_clawhub($skill, $dry_run)) {
                        push @{$results{"synced"}}, "$skill → ClawHub";
                    } else {
                        push @{$results{"failed"}}, $skill;
                    }
                } else {
                    push @{$results{"skipped"}}, "$skill (validation failed)";
                }
            
            # In beiden - prüfe ob Update nötig
            } elsif (-d $clawhub_path && -d $git_path) {
                # Vereinfachte Prüfung
                my $clawhub_mtime = get_max_mtime($clawhub_path);
                my $git_mtime = get_max_mtime($git_path, 1); # exclude .git
                
                if (abs($clawhub_mtime - $git_mtime) > 60) {
                    if ($clawhub_mtime > $git_mtime) {
                        log_msg("Updating $skill in Git...");
                        if (sync_to_git($skill, $dry_run)) {
                            push @{$results{"synced"}}, "$skill → Git (update)";
                        } else {
                            push @{$results{"failed"}}, $skill;
                        }
                    } else {
                        log_msg("Updating $skill in ClawHub...");
                        if (sync_to_clawhub($skill, $dry_run)) {
                            push @{$results{"synced"}}, "$skill → ClawHub (update)";
                        } else {
                            push @{$results{"failed"}}, $skill;
                        }
                    }
                } else {
                    push @{$results{"skipped"}}, "$skill (already synced)";
                }
            }
        };
        if ($@) {
            log_msg("Error processing $skill: $@", "ERROR");
            push @{$results{"failed"}}, $skill;
        }
    }
    
    # Zusammenfassung
    print "\n" . "=" x 60 . "\n";
    print "Bulk Sync " . ($dry_run ? "DRY-RUN" : "EXECUTED") . " - Zusammenfassung\n";
    print "=" x 60 . "\n";
    print "✅ Synchronisiert: " . scalar(@{$results{'synced'}}) . "\n";
    for my $item (@{$results{"synced"}}) {
        print "   - $item\n";
    }
    print "\n⏭️  Übersprungen: " . scalar(@{$results{'skipped'}}) . "\n";
    if (scalar(@{$results{'skipped'}}) <= 10) {
        for my $item (@{$results{"skipped"}}) {
            print "   - $item\n";
        }
    } else {
        print "   - " . scalar(@{$results{'skipped'}}) . " Skills (bereits synchron oder Validierung fehlgeschlagen)\n";
    }
    print "\n❌ Fehlgeschlagen: " . scalar(@{$results{'failed'}}) . "\n";
    for my $item (@{$results{"failed"}}) {
        print "   - $item\n";
    }
    print "=" x 60 . "\n";
}

sub get_max_mtime {
    my ($path, $exclude_git) = @_;
    my $max_time = 0;
    
    find(sub {
        return if -d $_;  # Skip directories
        return if $exclude_git && m|/\.git/|;  # Exclude .git if requested
        my @stat = stat($_);
        $max_time = $stat[9] if $stat[9] > $max_time;
    }, $path);
    
    return $max_time;
}

sub main {
    # Emulate argument parsing
    my $dry_run = 0;
    my $execute = 0;
    
    for my $arg (@ARGV) {
        if ($arg eq '--dry-run') {
            $dry_run = 1;
        } elsif ($arg eq '--execute') {
            $execute = 1;
        }
    }
    
    if (!$dry_run && !$execute) {
        print "Bitte --dry-run oder --execute angeben\n";
        exit 1;
    }
    
    sync_all_skills($dry_run);
}

main() unless caller;
