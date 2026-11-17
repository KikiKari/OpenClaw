#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "db2af7c7f19dc7780a2b57e5872765dec22414cc9f4888ba414bc66a7f23448e", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "perl5"}
# check_conflicts.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use Digest::MD5 qw(md5_hex);
use File::Spec;
use File::Basename;
use POSIX qw(strftime);

# Check Conflicts - Erkennt Sync-Konflikte

my $CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
my $GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";

# Füge das Verzeichnis zum Suchpfad hinzu
push @INC, '/home/openclaw/.openclaw/workspace/scripts';

# Lade die Funktion get_file_hash nach
sub get_file_hash {
    my ($file_path) = @_;
    open(my $fh, '<', $file_path) or return '';
    binmode($fh);
    my $hash = md5_hex(<$fh>);
    close($fh);
    return $hash;
}

sub check_conflicts {
    # Prüft auf Konflikte zwischen ClawHub und Git
    my @conflicts = ();
    
    # Alle Skills die in beiden Orten existieren
    my @common_skills = ();
    if (-d $CLAWHUB_DIR && -d $GIT_DIR) {
        opendir(my $clawhub_dh, $CLAWHUB_DIR) or die "Konnte $CLAWHUB_DIR nicht öffnen: $!";
        my %clawhub_skills = map { $_ => 1 } grep { -d "$CLAWHUB_DIR/$_" && $_ !~ /^\.\.?$/ } readdir($clawhub_dh);
        closedir($clawhub_dh);
        
        opendir(my $git_dh, $GIT_DIR) or die "Konnte $GIT_DIR nicht öffnen: $!";
        my %git_skills = map { $_ => 1 } grep { -d "$GIT_DIR/$_" && $_ !~ /^\.\.?$/ } readdir($git_dh);
        closedir($git_dh);
        
        for my $skill (keys %clawhub_skills) {
            push @common_skills, $skill if exists $git_skills{$skill};
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
            return if -d $_ || index($File::Find::dir, '/.git') != -1;
            my $rel_path = File::Spec->abs2rel($File::Find::name, $clawhub_path);
            $clawhub_files{$rel_path} = $File::Find::name;
        }, $clawhub_path);
        
        # Git Dateien
        my %git_files = ();
        find(sub {
            return if -d $_ || index($File::Find::dir, '/.git') != -1;
            my $rel_path = File::Spec->abs2rel($File::Find::name, $git_path);
            $git_files{$rel_path} = $File::Find::name;
        }, $git_path);
        
        # Vergleiche gemeinsame Dateien
        my %seen_in_clawhub = map { $_ => 1 } keys %clawhub_files;
        for my $rel_path (keys %git_files) {
            if (exists $seen_in_clawhub{$rel_path}) {
                my $clawhub_file = $clawhub_files{$rel_path};
                my $git_file = $git_files{$rel_path};
                
                if (get_file_hash($clawhub_file) ne get_file_hash($git_file)) {
                    my @clawhub_stat = stat($clawhub_file);
                    my @git_stat = stat($git_file);
                    
                    my $clawhub_mtime = strftime('%Y-%m-%d %H:%M:%S', localtime($clawhub_stat[9]));
                    my $git_mtime = strftime('%Y-%m-%d %H:%M:%S', localtime($git_stat[9]));
                    
                    my $newer = $clawhub_stat[9] > $git_stat[9] ? "clawhub" : "git";
                    
                    push @skill_conflicts, {
                        "file" => $rel_path,
                        "clawhub_modified" => $clawhub_mtime,
                        "git_modified" => $git_mtime,
                        "newer" => $newer
                    };
                }
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
