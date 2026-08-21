#!/usr/bin/env python3
# sync-local.sh — portiert nach python
# Quelle: shell, Onboarding@main:scripts/sync-local.sh
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

# Python-Äquivalent zu sync-local.ps1 — inkrementeller Git-Sync für den Dev-Stack.
# Nutzung: scripts/sync-local.py [--branch <name>] [--interval <s>] [--once]

import subprocess
import sys
import os
import time
import argparse
from pathlib import Path
from datetime import datetime

def log(message):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {message}")

def compose(compose_file, *args):
    try:
        subprocess.run(["docker", "compose", "-f", compose_file] + list(args), check=True)
    except subprocess.CalledProcessError:
        log("WARNUNG: docker compose {} fehlgeschlagen".format(" ".join(args)))

def run_command(command, cwd=None, capture_output=False):
    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=cwd,
            capture_output=capture_output,
            text=True,
            check=True
        )
        return result.stdout.strip() if capture_output else None
    except subprocess.CalledProcessError as e:
        if capture_output:
            return None
        raise e

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--branch", default="claude/onboarding-persistent-sandbox-vjfmcx")
    parser.add_argument("--interval", type=int, default=20)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--compose-file", default="docker-compose.dev.yml")

    args = parser.parse_args()

    # Wechsel ins Wurzelverzeichnis des Repositories
    script_dir = Path(__file__).parent.parent.resolve()
    os.chdir(script_dir)

    # Aktuellen Branch prüfen und ggf. wechseln
    current_branch = run_command("git rev-parse --abbrev-ref HEAD", capture_output=True)
    if current_branch != args.branch:
        log(f"Wechsle von '{current_branch}' auf '{args.branch}' …")
        run_command(f"git fetch origin {args.branch}")
        try:
            run_command(f"git switch {args.branch}")
        except subprocess.CalledProcessError:
            run_command(f"git switch -c {args.branch} --track origin/{args.branch}")

    log(f"Sync aktiv: origin/{args.branch} -> {os.getcwd()} (Intervall {args.interval}s, Compose: {args.compose_file})")

    while True:
        try:
            run_command(f"git fetch origin {args.branch} --quiet")
        except subprocess.CalledProcessError:
            log(f"Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in {args.interval}s")
            if args.once:
                break
            time.sleep(args.interval)
            continue

        local_rev = run_command("git rev-parse HEAD", capture_output=True)
        remote_rev = run_command(f"git rev-parse origin/{args.branch}", capture_output=True)

        if local_rev != remote_rev:
            # Prüfen ob lokaler Stand Vorfahre des Remote-Stands ist
            is_ancestor_result = subprocess.run(
                ["git", "merge-base", "--is-ancestor", local_rev, remote_rev],
                cwd=os.getcwd()
            )

            if is_ancestor_result.returncode != 0:
                log("ACHTUNG: Lokaler Stand von origin/{} abgewichen — kein automatischer Merge, bitte manuell auflösen.".format(args.branch))
            else:
                # Geänderte Dateien ermitteln
                changed_files_raw = run_command(f"git diff --name-only {local_rev}..{remote_rev}", capture_output=True)
                changed_files = changed_files_raw.splitlines() if changed_files_raw else []

                run_command(f"git merge --ff-only {remote_rev} --quiet")
                log("Aktualisiert {:.7} -> {:.7} ({} Datei(en))".format(local_rev, remote_rev, len(changed_files)))

                needs_action = False

                # Prüfung auf Änderungen in der Compose-Datei
                if args.compose_file in changed_files:
                    log("Compose-Datei geändert — erzeuge Dev-Stack neu …")
                    compose(args.compose_file, "up", "-d")
                    needs_action = True

                # Prüfung auf Änderungen im Backend
                backend_files = [f for f in changed_files if f.startswith("backend/") and ("Dockerfile" in f or "requirements" in f)]
                if backend_files:
                    log("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …")
                    compose(args.compose_file, "up", "-d", "--build", "backend")
                    needs_action = True

                # Prüfung auf Änderungen im Frontend
                frontend_files = [f for f in changed_files if f in ("package.json", "package-lock.json")]
                if frontend_files:
                    log("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …")
                    compose(args.compose_file, "restart", "frontend")
                    needs_action = True

                if not needs_action:
                    log("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.")

        if args.once:
            break
        time.sleep(args.interval)

if __name__ == "__main__":
    main()
