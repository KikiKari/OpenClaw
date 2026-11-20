#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "9fd9bed8cd900001d0e562fa8f16a5600af75028f324f606191e5eb7cbf5b040", "source_sha256": "bf11781342e249f3bb5e5746f94668968b3fed5b83b099b77d5a9bb8ec38b713", "target_language": "perl5"}
# filter-staged-files.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/pre-commit/filter-staged-files.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Basename;

=head1 NAME

filter-staged-files.pl - Filter staged files for linting or formatting

=head1 DESCRIPTION

Prints selected files as NUL-delimited tokens to stdout.

Usage:
  perl filter-staged-files.pl lint -- <files...>
  perl filter-staged-files.pl format -- <files...>

Keep this dependency-free: the pre-commit hook runs in many environments.

=cut

my $mode = $ARGV[0];
my @raw_args = @ARGV[1..$#ARGV];

# Remove leading "--" if present
my @files = (@raw_args && $raw_args[0] eq "--") ? @raw_args[1..$#raw_args] : @raw_args;

if ($mode ne "lint" && $mode ne "format") {
    print STDERR "usage: filter-staged-files.pl <lint|format> -- <files...>\n";
    exit 2;
}

my %lint_exts = map { $_ => 1 } (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs");
my %format_exts = map { $_ => 1 } (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".json", ".md", ".mdx");
my %format_ignored_paths = map { $_ => 1 } ("src/canvas-host/a2ui/a2ui.bundle.js");

sub should_select {
    my ($file_path) = @_;
    my ($name, $dirs, $ext) = fileparse($file_path, qr/\.[^.]*/);
    $ext = lc($ext);
    
    if ($mode eq "lint") {
        return exists $lint_exts{$ext};
    }
    
    if (exists $format_ignored_paths{$file_path}) {
        return 0;
    }
    
    return exists $format_exts{$ext};
}

foreach my $file (@files) {
    if (should_select($file)) {
        print $file . "\0";
    }
}
