#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "b114fc2afa7613f7d00031a09e402b7fd0f97c07c2a89741379b74a3345dca14", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "perl6"}
# abstractions-manager.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

use MONKEY-SEE-NO-EVAL;

sub MAIN(*@args) {
    # Führe das externe Skript mit denselben Argumenten aus
    my @command = '/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh', |@args;
    run(@command) or die "Konnte {@command[0]} nicht ausführen";
}
