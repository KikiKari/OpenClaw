#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "94378b38d6af9470e214a85a0a1b8a66ef287de0e00dba91383d16b7bc803d26", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "perl6"}
# serve_compare_transfer.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

my $COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
my $TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
my $HOST_IP = "152.53.145.65";
my $PORT = "80";
my $SELF_PATH = $*PROGRAM.absolute;

# Finde alle Dateien im Compare-Verzeichnis, außer diesem Skript selbst
my @files = $COMPARE_DIR.IO.dir.grep(*.f).grep({ .absolute ne $SELF_PATH }).sort;

if @files.elems == 0 {
    say "Keine Dateien in $COMPARE_DIR gefunden.";
    exit 1;
}

say "";
say "Bereitgestellte Dateien aus $COMPARE_DIR:";
for @files -> $src {
    say "- {$src.basename}";
}

say "";
say "Copy/Paste auf anderem Gateway (Download nach $TRANSFER_DIR):";
for @files -> $src {
    my $file = $src.basename;
    say "curl -fL --retry 3 --connect-timeout 10 -o $TRANSFER_DIR/$file http://$HOST_IP:$PORT/$file";
}

say "";
say "Server auf Port $PORT aktiv. Beenden mit STRG+C.";
say "";

# Wechsle ins Compare-Verzeichnis und starte den HTTP-Server
chdir($COMPARE_DIR);
run("python3", "-m", "http.server", $PORT, "--bind", "0.0.0.0");
