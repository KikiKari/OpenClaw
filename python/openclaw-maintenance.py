#!/usr/bin/env python3
# openclaw-maintenance.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import subprocess
import sys

def run_command(command):
    """Führt einen Shell-Befehl aus und gibt den Exit-Code zurück."""
    try:
        result = subprocess.run(command, check=True, shell=True, capture_output=True, text=True)
        print(result.stdout, end='')
        if result.stderr:
            print(result.stderr, file=sys.stderr, end='')
        return result.returncode
    except subprocess.CalledProcessError as e:
        print(f"Fehler beim Ausführen von: {command}", file=sys.stderr)
        print(e.stderr, file=sys.stderr)
        return e.returncode

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
        run_command(f"openclaw memory promote --apply --agent \"{agent}\"")

    # === 7. Secrets ===
    run_command("openclaw secrets reload")

if __name__ == "__main__":
    main()
