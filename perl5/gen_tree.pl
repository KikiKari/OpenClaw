#!/usr/bin/perl
# gen_tree.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use File::Find;
use File::Spec;
use POSIX qw(strftime);

# Konstanten
my $ROOT = "/workspace";
my $OUT = "/workspace/important/openclaw-tree.txt";
my $MAX_DEPTH = 6;

# Sammelt das Verzeichnisbaum als Liste von Zeilen
sub collect {
    my ($path, $prefix, $depth) = @_;
    $prefix //= "";
    $depth //= 1;
    my @lines = ();

    # Versuche, die Einträge im Verzeichnis zu lesen
    opendir(my $dh, $path) or return @lines;
    my @entries = sort readdir($dh);
    closedir($dh);

    # Filtere "." und ".."
    @entries = grep { $_ ne '.' && $_ ne '..' } @entries;
    my $total = scalar @entries;

    for my $i (0 .. $#entries) {
        my $name = $entries[$i];
        my $is_last = ($i == $total - 1);
        my $connector = $is_last ? "└── " : "├── ";
        push @lines, $prefix . $connector . $name;
        my $full = File::Spec->catfile($path, $name);
        if ($depth < $MAX_DEPTH && -d $full && !-l $full) {
            my $next_prefix = $prefix . ($is_last ? "    " : "│   ");
            push @lines, collect($full, $next_prefix, $depth + 1);
        }
    }

    return @lines;
}

# Baum generieren
my @body = collect($ROOT);

# Header erstellen
my $timestamp = strftime("%Y-%m-%dT%H:%M:%S", localtime);
my $header = 
    "# OpenClaw Workspace Tree\n" .
    "# Generiert: $timestamp\n" .
    "# Befehl: tree -a -L 6 $ROOT (emuliert via gen_tree.py)\n" .
    "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n";

my $content = $header . ".\n" . join("\n", @body) . "\n";

# In Datei schreiben
open(my $fh, ">:encoding(UTF-8)", $OUT) or die "Kann $OUT nicht öffnen: $!";
print $fh $content;
close($fh);

my $line_count = scalar(@body) + 1;
my $byte_count = length($content);
print "written $OUT: $line_count lines, $byte_count bytes\n";
