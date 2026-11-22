#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "77382f3737c80b66502d7b19d0f2c74306781aa0985fb6e1570bc8f27d158ac0", "source_sha256": "b0b2d14634c78d492d814989a9bf887ffef50ac058176565e0d55191bb8ac787", "target_language": "perl6"}
# serve_compare_transfer.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use v6;

my $COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
my $TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
my $HOST_IP = "89.58.15.220";
my $PORT = "80";
my $SELF_PATH = $*PROGRAM.absolute;

# Finde alle Dateien im Vergleichsverzeichnis, außer diesem Skript selbst
my @files = run(<find $COMPARE_DIR -maxdepth 1 -type f>, :out).out.lines.grep({ $_ ne $SELF_PATH }).sort;

if @files.elems == 0 {
    say "Keine Dateien in $COMPARE_DIR gefunden.";
    exit 1;
}

say "";
say "Bereitgestellte Dateien aus $COMPARE_DIR:";
for @files -> $src {
    say "- " ~ $src.IO.basename;
}

say "";
say "Copy/Paste auf anderem Gateway (Download nach $TRANSFER_DIR):";
for @files -> $src {
    my $file = $src.IO.basename;
    say "curl -fL --retry 3 --connect-timeout 10 -o $TRANSFER_DIR/$file http://$HOST_IP:$PORT/$file";
}

say "";
say "Server auf Port $PORT aktiv. Beenden mit STRG+C.";
say "";

# Wechsle ins Vergleichsverzeichnis und starte den HTTP-Server
chdir($COMPARE_DIR);
run("python3", "-m", "http.server", $PORT, "--bind", "0.0.0.0");
