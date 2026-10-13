#!/usr/bin/perl
# tree_fallback.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:db-maintainer/scripts/tree_fallback.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(strftime);
use File::Find;
use File::Spec;
use File::Path qw(make_path);

# Fallback tree generator for when the `tree` binary is unavailable.
#
# Produces output similar to `tree -a -L <depth>` and writes it to
# important/openclaw-tree.txt with a timestamp header.

my $WORKSPACE = "/workspace";
my $DEPTH = 6;
my %SKIP = map { $_ => 1 } (".git", "node_modules", "__pycache__", "venv", ".cache", ".npm", ".local");
my $OUT = "$WORKSPACE/important/openclaw-tree.txt";

sub walk {
    my ($path, $prefix, $depth) = @_;
    my @lines = ();
    $prefix //= "";
    $depth //= 0;

    if ($depth >= $DEPTH) {
        return @lines;
    }

    opendir(my $dh, $path) or return @lines;
    my @entries = readdir($dh);
    closedir($dh);

    # Filter out . and .., and skipped entries
    @entries = grep { !/^\.\.?$/ && !$SKIP{$_} } @entries;

    # Sort: directories first, then by name
    @entries = sort {
        my $a_is_dir = -d "$path/$a";
        my $b_is_dir = -d "$path/$b";
        # directories first
        ($b_is_dir <=> $a_is_dir) || $a cmp $b
    } @entries;

    for my $i (0..$#entries) {
        my $entry = $entries[$i];
        my $full_entry = "$path/$entry";
        my $last = ($i == $#entries);
        my $connector = $last ? "└── " : "├── ";
        my $suffix = (-d $full_entry) ? "/" : "";
        push @lines, "${prefix}${connector}${entry}${suffix}";
        if (-d $full_entry && !(-l $full_entry)) {
            my $extension = $last ? "    " : "│   ";
            push @lines, walk($full_entry, $prefix . $extension, $depth + 1);
        }
    }
    return @lines;
}

sub main {
    my @lines = ($WORKSPACE);
    push @lines, walk($WORKSPACE);
    my $body = join("\n", @lines) . "\n";
    my $timestamp = strftime("%Y-%m-%dT%H:%M:%S", localtime);
    my $header = 
        "# OpenClaw Workspace Tree\n" .
        "# Generiert: ${timestamp}\n" .
        "# Fallback (tree binary nicht verfuegbar), Tiefe ${DEPTH}\n" .
        "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n";

    # Create parent directory
    my ($volume, $directories, $file) = File::Spec->splitpath($OUT);
    my @dirs = File::Spec->splitdir($directories);
    pop @dirs if $dirs[-1] eq ''; # Remove trailing empty element if present
    my $parent_dir = File::Spec->catpath($volume, File::Spec->catdir(@dirs), '');
    make_path($parent_dir, { verbose => 0 }) or die "Could not create path $parent_dir: $!" unless -d $parent_dir;

    open(my $fh, '>', $OUT) or die "Could not open file '$OUT' $!";
    print $fh $header . $body;
    close $fh;

    print "openclaw-tree.txt aktualisiert (Fallback): $OUT (" . scalar(@lines) . " Eintraege)\n";
}

main() if __FILE__ eq $0;
