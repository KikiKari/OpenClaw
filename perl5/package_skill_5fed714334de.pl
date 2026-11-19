#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "9e84946feb5cfc1ce36a650e4ab701f1000a0385462b02cebc16d7058e32d73e", "source_sha256": "f290101073ee6a167f46edadda164d2c88affc03c554135fe101a4e422c44c22", "target_language": "perl5"}
# package_skill.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Spec;
use File::Path qw(make_path);
use Cwd qw(abs_path getcwd);
use File::Basename;

# Documentation
=head1 SYNOPSIS

Skill Packager - Creates a distributable .skill file of a skill folder

Usage:
    perl utils/package_skill.pl <path/to/skill-folder> [output-directory]

Example:
    perl utils/package_skill.pl skills/public/my-skill
    perl utils/package_skill.pl skills/public/my-skill ./dist

=cut

# Quick validation function (stub - replace with actual implementation)
sub validate_skill {
    my ($skill_path) = @_;
    
    # Check if required files exist
    my $skill_md = File::Spec->catfile($skill_path, 'SKILL.md');
    unless (-f $skill_md) {
        return (0, "SKILL.md not found");
    }
    
    return (1, "Validation passed");
}

# Helper function to check if path is within root
sub _is_within {
    my ($path, $root) = @_;
    
    my @path_parts = split('/', $path);
    my @root_parts = split('/', $root);
    
    # Remove empty parts from beginning if any
    shift @path_parts while (@path_parts && $path_parts[0] eq '');
    shift @root_parts while (@root_parts && $root_parts[0] eq '');
    
    # Check if path starts with root
    for my $i (0 .. $#root_parts) {
        return 0 if $i > $#path_parts;
        return 0 if $path_parts[$i] ne $root_parts[$i];
    }
    
    return 1;
}

# Main packaging function
sub package_skill {
    my ($skill_path, $output_dir) = @_;
    
    $skill_path = abs_path($skill_path);
    
    # Validate skill folder exists
    unless (-d $skill_path) {
        print "[ERROR] Skill folder not found or not a directory: $skill_path\n";
        return undef;
    }
    
    # Validate SKILL.md exists
    my $skill_md = File::Spec->catfile($skill_path, 'SKILL.md');
    unless (-f $skill_md) {
        print "[ERROR] SKILL.md not found in $skill_path\n";
        return undef;
    }
    
    # Run validation before packaging
    print "Validating skill...\n";
    my ($valid, $message) = validate_skill($skill_path);
    unless ($valid) {
        print "[ERROR] Validation failed: $message\n";
        print "   Please fix the validation errors before packaging.\n";
        return undef;
    }
    print "[OK] $message\n\n";
    
    # Determine output location
    my $skill_name = basename($skill_path);
    my $output_path;
    if ($output_dir) {
        $output_path = abs_path($output_dir);
        make_path($output_path) unless -d $output_path;
    } else {
        $output_path = getcwd();
    }
    
    my $skill_filename = File::Spec->catfile($output_path, "$skill_name.skill");
    
    my %EXCLUDED_DIRS = map { $_ => 1 } qw(.git .svn .hg __pycache__ node_modules);
    
    # Collect files to include
    my @files_to_include;
    
    find(
        sub {
            # Skip directories that are excluded
            my @parts = split('/', $File::Find::dir);
            foreach my $part (@parts) {
                return if exists $EXCLUDED_DIRS{$part};
            }
            
            # Skip if this is an excluded directory
            return if exists $EXCLUDED_DIRS{$_};
            
            # Skip symlinks
            if (-l $_) {
                print "[WARN] Skipping symlink: $File::Find::name\n";
                return;
            }
            
            # Only process files
            return unless -f $_;
            
            push @files_to_include, $File::Find::name;
        },
        $skill_path
    );
    
    # Create the .skill file (simple format - you may want to implement proper ZIP compression)
    eval {
        open(my $fh, '>', $skill_filename) or die "Cannot create file: $!";
        
        # Write header
        print $fh "SKILL_PACKAGE:$skill_name\n";
        
        foreach my $file_path (@files_to_include) {
            # Security: never follow or package symlinks.
            if (-l $file_path) {
                print "[WARN] Skipping symlink: $file_path\n";
                next;
            }
            
            my $rel_path = File::Spec->abs2rel($file_path, $skill_path);
            my @rel_parts = split('/', $rel_path);
            my $skip = 0;
            foreach my $part (@rel_parts) {
                if (exists $EXCLUDED_DIRS{$part}) {
                    $skip = 1;
                    last;
                }
            }
            next if $skip;
            
            my $resolved_file = abs_path($file_path);
            unless (_is_within($resolved_file, $skill_path)) {
                print "[ERROR] File escapes skill root: $file_path\n";
                die "File escape detected";
            }
            
            # If output lives under skill_path, avoid writing archive into itself.
            if (abs_path($resolved_file) eq abs_path($skill_filename)) {
                print "[WARN] Skipping output archive: $file_path\n";
                next;
            }
            
            # Calculate the relative path within the zip.
            my $arcname = File::Spec->catfile($skill_name, $rel_path);
            print "  Added: $arcname\n";
            
            # Add file content to archive (simplified approach)
            open(my $infh, '<', $file_path) or die "Cannot read file $file_path: $!";
            print $fh "FILE:$arcname\n";
            while (my $line = <$infh>) {
                print $fh $line;
            }
            print $fh "END_FILE\n";
            close($infh);
        }
        
        close($fh);
        print "\n[OK] Successfully packaged skill to: $skill_filename\n";
        return $skill_filename;
    };
    
    if ($@) {
        print "[ERROR] Error creating .skill file: $@\n";
        return undef;
    }
}

# Main function
sub main {
    if (@ARGV < 1) {
        print "Usage: perl utils/package_skill.pl <path/to/skill-folder> [output-directory]\n";
        print "\nExample:\n";
        print "  perl utils/package_skill.pl skills/public/my-skill\n";
        print "  perl utils/package_skill.pl skills/public/my-skill ./dist\n";
        exit(1);
    }
    
    my $skill_path = $ARGV[0];
    my $output_dir = $ARGV[1] if @ARGV > 1;
    
    print "Packaging skill: $skill_path\n";
    if ($output_dir) {
        print "   Output directory: $output_dir\n";
    }
    print "\n";
    
    my $result = package_skill($skill_path, $output_dir);
    
    if ($result) {
        exit(0);
    } else {
        exit(1);
    }
}

main() if __FILE__ eq $0;
