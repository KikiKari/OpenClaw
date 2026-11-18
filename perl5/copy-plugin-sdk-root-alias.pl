#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "61719462e4a01bf56e9e551551dcb73f3024e58493699aebe691960cb169f13c", "source_sha256": "5fc2c92995e4c87536b6317eba7c9959c9babc16a20ce4476804921089ee2e34", "target_language": "perl5"}
# copy-plugin-sdk-root-alias.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/copy-plugin-sdk-root-alias.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd qw(abs_path);
use utf8;

# Helper function to read file content
sub read_file {
    my ($file_path) = @_;
    open my $fh, '<:encoding(UTF-8)', $file_path or die "Could not open '$file_path': $!";
    local $/; # Enable 'slurp' mode
    my $content = <$fh>;
    close $fh;
    return $content;
}

# Helper function to write file if changed
sub write_text_file_if_changed {
    my ($target, $content) = @_;
    
    my $current_content = '';
    if (-f $target) {
        $current_content = read_file($target);
    }
    
    if ($current_content ne $content) {
        # Ensure directory exists
        my ($volume, $directories) = File::Spec->splitpath($target);
        my @dirs = File::Spec->splitdir($directories);
        pop @dirs if $dirs[-1] eq ''; # Remove trailing empty element if present
        
        my $dir_path = $volume;
        foreach my $dir (@dirs) {
            $dir_path = File::Spec->catdir($dir_path, $dir);
            unless (-d $dir_path) {
                mkdir $dir_path or die "Failed to create directory '$dir_path': $!";
            }
        }
        
        open my $fh, '>:encoding(UTF-8)', $target or die "Could not open '$target' for writing: $!";
        print $fh $content;
        close $fh;
        print "Updated $target\n";
    }
}

sub copy_plugin_sdk_root_alias {
    my (%params) = @_;
    
    # Get current working directory
    my $cwd = $params{cwd} // abs_path('.');
    
    # Resolve source and target paths
    my $source = File::Spec->catfile($cwd, 'src', 'plugin-sdk', 'root-alias.cjs');
    my $target = File::Spec->catfile($cwd, 'dist', 'plugin-sdk', 'root-alias.cjs');
    
    # Read source content
    my $content = read_file($source);
    
    # Write to target if changed
    write_text_file_if_changed($target, $content);
}

# Execute main function when script is run directly
if (!caller()) {
    copy_plugin_sdk_root_alias();
}

1; # Return true value for module inclusion
