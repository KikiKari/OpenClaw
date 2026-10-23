#!/bin/bash
# tiktok-common.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-common.js
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# In Bash gibt es kein direktes Equivalent zu Node.js module.exports.
# Da diese Datei lediglich ein require() auf ein anderes Skript ausführt,
# stellen wir sicher, dass das andere Skript (../../tiktok-live/scripts/tiktok-common)
# ebenfalls nach Bash portiert wurde und hier aufgerufen wird.

# Prüfen ob das Ziel-Skript existiert
if [[ ! -f "../../tiktok-live/scripts/tiktok-common" ]]; then
    echo "Fehler: Das benötigte Skript '../../tiktok-live/scripts/tiktok-common' wurde nicht gefunden." >&2
    exit 1
fi

# Das externe Skript ausführen und dessen Ausgabe weiterleiten
source "../../tiktok-live/scripts/tiktok-common" "$@"
