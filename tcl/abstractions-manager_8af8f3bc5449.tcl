#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "60ca673b008cb4494c026c9de43e353281977d827f626e7d34d701248754999f", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "tcl"}
# abstractions-manager.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Execute the abstractions manager cron script with all arguments
exec /home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh {*}$argv
