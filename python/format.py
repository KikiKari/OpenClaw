#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "6c4504ce02f08d4969deb0fdb5865204914ea59f0e66c4f8edb0c3f1416ebbd0", "source_sha256": "ed82b1410f121f3b1436d54099143d7010035ba702c64f21d2669fce9dd3f2ae", "target_language": "python"}
# format.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/Swabble/scripts/format.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import subprocess
import sys
import os

# Setze die Optionen für das Skript
# set -euo pipefail wird durch try-except und check=True simuliert

# Bestimme das Root-Verzeichnis
# ROOT="$(cd "$(dirname "$0")/.." && pwd)"
script_dir = os.path.dirname(os.path.abspath(__file__))
root_dir = os.path.abspath(os.path.join(script_dir, ".."))

# Konfigurationsdatei festlegen
# CONFIG="${ROOT}/.swiftformat"
config_file = os.path.join(root_dir, ".swiftformat")

# Zielverzeichnis festlegen
# "$ROOT/Sources"
sources_dir = os.path.join(root_dir, "Sources")

try:
    # swiftformat --config "$CONFIG" "$ROOT/Sources"
    result = subprocess.run(
        ["swiftformat", "--config", config_file, sources_dir],
        check=True,
        capture_output=True,
        text=True
    )
    print(result.stdout)
except subprocess.CalledProcessError as e:
    print(f"Fehler beim Ausführen von swiftformat: {e}", file=sys.stderr)
    print(f"stderr: {e.stderr}", file=sys.stderr)
    sys.exit(e.returncode)
except FileNotFoundError:
    print("swiftformat wurde nicht gefunden. Bitte stelle sicher, dass es installiert ist.", file=sys.stderr)
    sys.exit(1)
