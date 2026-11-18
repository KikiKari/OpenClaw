#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "bb8837376524459da26ff432aaab666e9faeb8997bae2de8dddc69c5bb27d87f", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "perl6"}
# abstractions-manager.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use v6;

sub MAIN(|) {
    run("/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh", @*ARGS);
}
