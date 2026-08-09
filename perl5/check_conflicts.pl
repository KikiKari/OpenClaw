#!/usr/bin/perl
# check_conflicts.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Find;
use File::Spec;
use Digest::MD5 qw(md5_hex);
use Time::Piece;

# Konfiguration
my $CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
my $GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";

# Füge das Verzeichnis mit den Sync-Funktionen zum @INC-Pfad hinzu
use lib '/home/openclaw/.openclaw/workspace/scripts';

# Lade die Funktion get_file_hash aus sync_clawhub_git.pm
require sync_clawhub_git;
sync_clawhub_git->import(qw(get_file_hash));

sub check_conflicts {
    # Prüft auf Konflikte zwischen ClawHub und Git
    my @conflicts = ();
    
    # Alle Skills die in beiden Orten existieren
    my @common_skills = ();
    if (-d $CLAWHUB_DIR && -d $GIT_DIR) {
        my %clawhub_skills = map { $_ => 1 } grep { -d "$CLAWHUB_DIR/$_" } glob("$CLAWHUB_DIR/*");
        my %git_skills = map { $_ => 1 } grep { -d "$GIT_DIR/$_" } glob("$GIT_DIR/*");
        
        for my $skill (keys %clawhub_skills) {
            if (exists $git_skills{$skill}) {
                push @common_skills, $skill;
            }
        }
    }
    
    print "Prüfe " . scalar(@common_skills) . " Skills auf Konflikte...\n\n";
    
    for my $skill (sort @common_skills) {
        my $clawhub_path = "$CLAWHUB_DIR/$skill";
        my $git_path = "$GIT_DIR/$skill";
        
        # Alle Dateien vergleichen
        my @skill_conflicts = ();
        
        # ClawHub Dateien
        my %clawhub_files = ();
        find(sub {
            return if -d $_ || $_ eq '.git';
            my $rel_path = File::Spec->abs2rel($File::Find::name, $clawhub_path);
            $clawhub_files{$rel_path} = $File::Find::name;
        }, $clawhub_path);
        
        # Git Dateien
        my %git_files = ();
        find(sub {
            return if -d $_ || $_ eq '.git';
            my $rel_path = File::Spec->abs2rel($File::Find::name, $git_path);
            $git_files{$rel_path} = $File::Find::name;
        }, $git_path);
        
        # Vergleiche gemeinsame Dateien
        my %common_files = ();
        for my $file (keys %clawhub_files) {
            if (exists $git_files{$file}) {
                $common_files{$file} = 1;
            }
        }
        
        for my $rel_path (keys %common_files) {
            my $clawhub_file = $clawhub_files{$rel_path};
            my $git_file = $git_files{$rel_path};
            
            if (get_file_hash($clawhub_file) ne get_file_hash($git_file)) {
                my @clawhub_stat = stat($clawhub_file);
                my @git_stat = stat($git_file);
                
                my $clawhub_mtime = localtime($clawhub_stat[9]);
                my $git_mtime = localtime($git_stat[9]);
                
                my $newer = $clawhub_stat[9] > $git_stat[9] ? "clawhub" : "git";
                
                push @skill_conflicts, {
                    "file" => $rel_path,
                    "clawhub_modified" => $clawhub_mtime->strftime('%Y-%m-%d %H:%M:%S'),
                    "git_modified" => $git_mtime->strftime('%Y-%m-%d %H:%M:%S'),
                    "newer" => $newer
                };
            }
        }
        
        if (@skill_conflicts) {
            push @conflicts, {
                "skill" => $skill,
                "conflicts" => \@skill_conflicts
            };
        }
    }
    
    # Ausgabe
    if (@conflicts) {
        print "⚠️  KONFLIKTE GEFUNDEN:\n";
        print "=" x 80 . "\n";
        
        for my $conflict (@conflicts) {
            print "\n📦 Skill: " . $conflict->{"skill"} . "\n";
            print "-" x 40 . "\n";
            
            for my $file_conflict (@{$conflict->{"conflicts"}}) {
                print "  📄 " . $file_conflict->{"file"} . "\n";
                print "     ClawHub: " . $file_conflict->{"clawhub_modified"} . "\n";
                print "     Git:     " . $file_conflict->{"git_modified"} . "\n";
                print "     Neuer:   " . uc($file_conflict->{"newer"}) . "\n";
                print "\n";
            }
        }
        
        print "=" x 80 . "\n";
        print "Gesamt: " . scalar(@conflicts) . " Skills mit Konflikten\n";
        print "\nNutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen.\n";
    } else {
        print "✅ Keine Konflikte gefunden!\n";
        print "Alle gemeinsamen Skills sind synchron.\n";
    }
}

sub main {
    # Hauptfunktion
    check_conflicts();
}

main() if __FILE__ eq $0;
