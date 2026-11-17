#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "4a859f71b5af2cb43edb3b970ae737640e15d52170bb9f1611923b9c39aeecda", "source_sha256": "0a55a33f11db266892b50c887fd8d01783f387e3072c8c5b9ed86ca6788a8c52", "target_language": "perl6"}
# gen_tree.py — portiert nach perl6
# Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
# (used because the `tree` binary is unavailable in this sandbox).

use v6;

my $ROOT = "/workspace";
my $OUT = "/workspace/important/openclaw-tree.txt";
my $MAX_DEPTH = 6;

sub collect($path, $prefix = "", $depth = 1) {
    my @lines;
    my @entries;
    try {
        @entries = dir($path).map({ .basename }).sort;
        CATCH {
            return @lines;
        }
    }
    my $total = @entries.elems;
    for @entries.kv -> $i, $name {
        my $is-last = ($i == $total - 1);
        my $connector = $is-last ?? "└── " !! "├── ";
        @lines.push($prefix ~ $connector ~ $name);
        my $full = $path ~ "/" ~ $name;
        if $depth < $MAX_DEPTH && $full.IO.d && ! $full.IO.l {
            my $next-prefix = $prefix ~ ($is-last ?? "    " !! "│   ");
            @lines.push(|collect($full, $next-prefix, $depth + 1));
        }
    }
    return @lines;
}

my @body = collect($ROOT);
my $now = DateTime.now;
my $header = join("\n",
    "# OpenClaw Workspace Tree",
    "# Generiert: " ~ $now.yyyy-mm-dd ~ "T" ~ $now.hh-mm-ss ~ "." ~ sprintf("%06d", $now.nanosecond div 1000) ~ $now.offset-string,
    "# Befehl: tree -a -L 6 " ~ $ROOT ~ " (emuliert via gen_tree.py)",
    "# Diese Datei wird automatisch von db-maintainer aktualisiert",
    ""
) ~ "\n";
my $content = $header ~ ".\n" ~ @body.join("\n") ~ "\n";

spurt($OUT, $content, :enc<utf8>);

say "written $OUT: " ~ (@body.elems + 1) ~ " lines, " ~ $content.encode('utf8').elems ~ " bytes";
