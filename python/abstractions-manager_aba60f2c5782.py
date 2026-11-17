#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "2e02129355775237b6b3dc426abca1d81eecfe99fb757e6012bc98357333ab27", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "python"}
# abstractions-manager.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import subprocess
import sys
import os

def main():
    # Führe das externe Skript aus und leite alle Argumente weiter
    script_path = "/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh"
    
    try:
        # Übergib alle Kommandozeilenargumente an das Shell-Skript
        result = subprocess.run([script_path] + sys.argv[1:], 
                              check=True, 
                              stdout=subprocess.PIPE, 
                              stderr=subprocess.PIPE)
        
        # Gebe die Ausgabe des Skripts weiter
        sys.stdout.write(result.stdout.decode())
        sys.stderr.write(result.stderr.decode())
        
    except subprocess.CalledProcessError as e:
        # Behandle Fehler vom aufgerufenen Skript
        sys.stderr.write(e.stderr.decode() if e.stderr else "")
        sys.exit(e.returncode)
    except FileNotFoundError:
        sys.stderr.write(f"Fehler: Skript {script_path} nicht gefunden\n")
        sys.exit(127)

if __name__ == "__main__":
    main()
