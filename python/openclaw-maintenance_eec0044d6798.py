#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "d9a650c592b90e54b340d45c99f94b50e2f961f181d93e380f5754acb61eaed0", "source_sha256": "2a9ca592fdc915cfb281aa77dde9f07ffd3de83ce5abb8d87c77d46668d75dd6", "target_language": "python"}
# openclaw-maintenance.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

import subprocess
import sys

def run_command(command):
    """Führt einen Shell-Befehl aus und gibt das Ergebnis zurück."""
    try:
        result = subprocess.run(command, shell=True, check=True, text=True, capture_output=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Fehler beim Ausführen von: {command}\n{e.stderr}")
        sys.exit(1)

def main():
    # === 1. Service-/Config-Drift ===
    run_command("openclaw doctor")

    # === 2. Plugin-Stage (aktive Varianten, NICHT plugins doctor) ===
    run_command("openclaw plugins registry --refresh")
    run_command("openclaw plugins update --all")

    # === 3. Tasks ===
    run_command("openclaw tasks maintenance --apply")

    # === 4. Sessions – alle Agents auf einmal ===
    run_command("openclaw sessions cleanup --enforce --all-agents")

    # === 5. Memory – status/index decken alle Agents ab ===
    run_command("openclaw memory status --deep --fix")
    run_command("openclaw memory index --force")

    # === 6. Memory promote – MUSS pro Agent ===
    agents = ["main", "knecht", "docs", "ops-hub", "cron"]
    for agent in agents:
        run_command(f'openclaw memory promote --apply --agent "{agent}"')

    # === 7. Secrets ===
    run_command("openclaw secrets reload")

if __name__ == "__main__":
    main()
