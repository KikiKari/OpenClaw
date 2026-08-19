#!/usr/bin/env perl
# package_skill.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd 'abs_path';
use File::Path qw(make_path);
use File::Find;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

# Lade das Modul quick_validate.pm
require "./quick_validate.pm";

# Hilfsfunktion: Prüft, ob ein Pfad innerhalb eines anderen liegt
sub _is_within {
    my ($path, $root) = @_;
    my @path_parts = split('/', $path);
    my @root_parts = split('/', $root);

    # Entferne leere Elemente am Anfang
    shift @path_parts while @path_parts && $path_parts[0] eq '';
    shift @root_parts while @root_parts && $root_parts[0] eq '';

    # Vergleiche die Pfade
    for my $i (0 .. $#root_parts) {
        return 0 if $i > $#path_parts || $path_parts[$i] ne $root_parts[$i];
    }
    return 1;
}

# Paketiert einen Skill-Ordner in eine .skill-Datei
sub package_skill {
    my ($skill_path, $output_dir) = @_;

    # Normalisiere den Pfad
    $skill_path = abs_path($skill_path);

    # Prüfe, ob der Skill-Ordner existiert
    unless (-d $skill_path) {
        print "[ERROR] Skill folder not found or is not a directory: $skill_path\n";
        return undef;
    }

    # Prüfe, ob SKILL.md existiert
    my $skill_md = File::Spec->catfile($skill_path, "SKILL.md");
    unless (-f $skill_md) {
        print "[ERROR] SKILL.md not found in $skill_path\n";
        return undef;
    }

    # Validierung vor dem Packen
    print "Validating skill...\n";
    my ($valid, $message) = quick_validate::validate_skill($skill_path);
    unless ($valid) {
        print "[ERROR] Validation failed: $message\n";
        print "   Please fix the validation errors before packaging.\n";
        return undef;
    }
    print "[OK] $message\n\n";

    # Bestimme den Ausgabeort
    my $skill_name = basename($skill_path);
    my $output_path;
    if ($output_dir) {
        $output_path = abs_path($output_dir);
        make_path($output_path) unless -d $output_path;
    } else {
        $output_path = cwd();
    }

    my $skill_filename = File::Spec->catfile($output_path, "$skill_name.skill");

    my %EXCLUDED_DIRS = map { $_ => 1 } qw(.git .svn .hg __pycache__ node_modules);

    # Erstelle die .skill-Datei (ZIP-Format)
    eval {
        my $zip = Archive::Zip->new();

        # Sammle alle Dateien im Skill-Ordner
        my @files_to_add;
        find(
            sub {
                return if -l $_; # Symlinks überspringen
                my $rel_path = File::Spec->abs2rel($File::Find::name, $skill_path);
                my @parts = split('/', $rel_path);
                return if grep { $EXCLUDED_DIRS{$_} } @parts;

                if (-f $_) {
                    my $resolved_file = abs_path($_);
                    unless (_is_within($resolved_file, $skill_path)) {
                        die "[ERROR] File escapes skill root: $_\n";
                    }
                    if ($resolved_file eq abs_path($skill_filename)) {
                        print "[WARN] Skipping output archive: $_\n";
                        return;
                    }
                    push @files_to_add, [$File::Find::name, $rel_path];
                }
            },
            $skill_path
        );

        # Füge Dateien zum ZIP-Archiv hinzu
        for my $file_info (@files_to_add) {
            my ($full_path, $rel_path) = @$file_info;
            my $arcname = File::Spec->catfile($skill_name, $rel_path);
            $zip->addFile($full_path, $arcname);
            print "  Added: $arcname\n";
        }

        # Schreibe das ZIP-Archiv
        unless ($zip->writeToFileNamed($skill_filename) == AZ_OK) {
            die "[ERROR] Failed to write .skill file: $skill_filename\n";
        }

        print "\n[OK] Successfully packaged skill to: $skill_filename\n";
        return $skill_filename;
    };

    if ($@) {
        print $@;
        return undef;
    }

    return $skill_filename;
}

# Hauptprogramm
sub main {
    if (@ARGV < 1) {
        print "Usage: perl package_skill.pl <path/to/skill-folder> [output-directory]\n";
        print "\nExample:\n";
        print "  perl package_skill.pl skills/public/my-skill\n";
        print "  perl package_skill.pl skills/public/my-skill ./dist\n";
        exit 1;
    }

    my $skill_path = $ARGV[0];
    my $output_dir = $ARGV[1] // undef;

    print "Packaging skill: $skill_path\n";
    if ($output_dir) {
        print "   Output directory: $output_dir\n";
    }
    print "\n";

    my $result = package_skill($skill_path, $output_dir);

    exit($result ? 0 : 1);
}

main() if __FILE__ eq $0;
