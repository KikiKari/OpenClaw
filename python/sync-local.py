#!/usr/bin/env python3
# sync-local.ps1 — portiert nach python
# Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

"""
.SYNOPSIS
  Hält den lokalen Dev-Stack (docker-compose.dev.yml) inkrementell mit GitHub synchron.

.DESCRIPTION
  Pollt origin/<Branch> und zieht neue Commits per Fast-Forward. Danach entscheidet
  der Diff, was nötig ist:
    - nur Quellcode geändert            -> nichts tun, Hot-Reload übernimmt
    - package.json / package-lock.json  -> Frontend-Container neu starten
                                           (Entrypoint installiert Dependencies nur
                                           bei geändertem Lockfile-Hash nach)
    - backend/Dockerfile, requirements* -> Backend-Image gezielt neu bauen
    - docker-compose.dev.yml            -> Dev-Stack neu erzeugen
  Es wird nie „blind" der ganze Branch neu gebaut.

.EXAMPLE
  python scripts/sync-local.py                # Dauerbetrieb, 20-s-Intervall
  python scripts/sync-local.py --once        # genau ein Sync-Durchlauf
  python scripts/sync-local.py --branch main # anderen Branch verfolgen
"""

import argparse
import subprocess
import time
import sys
import os
from pathlib import Path


def log(msg):
    """Gibt eine Zeitstempel-Nachricht auf stdout aus."""
    print(f"[{time.strftime('%H:%M:%S')}] {msg}")


def run_command(cmd, check=True, capture_output=False, cwd=None):
    """Führt einen Shell-Befehl aus und gibt das Ergebnis zurück."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=check,
            capture_output=capture_output,
            text=True,
            cwd=cwd
        )
        return result
    except subprocess.CalledProcessError as e:
        if check:
            raise
        return e


def invoke_compose(compose_args, compose_file):
    """Führt docker compose mit den gegebenen Argumenten aus."""
    cmd = f"docker compose -f {compose_file} {' '.join(compose_args)}"
    result = run_command(cmd, check=False)
    if result.returncode != 0:
        log(f"WARNUNG: docker compose {' '.join(compose_args)} fehlgeschlagen (Exit {result.returncode})")
    return result


def main():
    parser = argparse.ArgumentParser(description="Hält den lokalen Dev-Stack mit GitHub synchron.")
    parser.add_argument("--branch", default="claude/onboarding-persistent-sandbox-vjfmcx", help="Zu verfolgender Branch")
    parser.add_argument("--interval-seconds", type=int, default=20, help="Poll-Intervall in Sekunden")
    parser.add_argument("--compose-file", default="docker-compose.dev.yml", help="Zu nutzende Compose-Datei")
    parser.add_argument("--once", action="store_true", help="Nur einen Sync-Durchlauf ausführen")

    args = parser.parse_args()

    # Repo-Root bestimmen (übergeordnetes Verzeichnis des Skript-Verzeichnisses)
    repo_root = Path(__file__).parent.parent.resolve()
    os.chdir(repo_root)

    # Sicherstellen, dass der Ziel-Branch ausgecheckt ist
    result = run_command("git rev-parse --abbrev-ref HEAD", capture_output=True)
    current = result.stdout.strip()
    
    if current != args.branch:
        log(f"Wechsle von '{current}' auf '{args.branch}' …")
        run_command(f"git fetch origin {args.branch}")
        
        # Versuche switch, falls fehlgeschlagen -> create und track
        result = run_command(f"git switch {args.branch}", check=False)
        if result.returncode != 0:
            result = run_command(f"git switch -c {args.branch} --track origin/{args.branch}", check=False)
            if result.returncode != 0:
                raise RuntimeError(f"Branch '{args.branch}' konnte nicht ausgecheckt werden.")

    log(f"Sync aktiv: origin/{args.branch} -> {repo_root} (Intervall {args.interval_seconds}s, Compose: {args.compose_file})")

    while True:
        # Fetch im Hintergrund
        result = run_command(f"git fetch origin {args.branch} --quiet", check=False)
        if result.returncode != 0:
            log(f"Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in {args.interval_seconds}s")
        else:
            # Lokalen und Remote-HEAD bestimmen
            local_result = run_command("git rev-parse HEAD", capture_output=True)
            remote_result = run_command(f"git rev-parse origin/{args.branch}", capture_output=True)
            
            local = local_result.stdout.strip()
            remote = remote_result.stdout.strip()

            if local != remote:
                # Prüfen, ob lokaler Stand Vorfahre des Remotes ist
                result = run_command(f"git merge-base --is-ancestor {local} {remote}", check=False)
                
                if result.returncode != 0:
                    log("ACHTUNG: Lokaler Stand ist von origin/{} abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen.".format(args.branch))
                else:
                    # Geänderte Dateien ermitteln
                    diff_result = run_command(f"git diff --name-only {local}..{remote}", capture_output=True)
                    changed_files = diff_result.stdout.strip().split('\n') if diff_result.stdout.strip() else []
                    
                    # Merge durchführen
                    run_command(f"git merge --ff-only {remote} --quiet")
                    log(f"Aktualisiert {local[:7]} -> {remote[:7]} ({len(changed_files)} Datei(en))")

                    # Änderungen klassifizieren
                    frontend_deps = [f for f in changed_files if f in ("package.json", "package-lock.json")]
                    backend_image = [f for f in changed_files if f.startswith("backend/") and 
                                    (f == "backend/Dockerfile" or f.startswith("backend/requirements") and f.endswith(".txt"))]
                    compose_changed = [f for f in changed_files if f == args.compose_file]

                    # Aktionen basierend auf Änderungen ausführen
                    if compose_changed:
                        log("Compose-Datei geändert — erzeuge Dev-Stack neu …")
                        invoke_compose(["up", "-d"], args.compose_file)
                    
                    if backend_image:
                        log("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …")
                        invoke_compose(["up", "-d", "--build", "backend"], args.compose_file)
                    
                    if frontend_deps:
                        log("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …")
                        invoke_compose(["restart", "frontend"], args.compose_file)
                    
                    if not (compose_changed or backend_image or frontend_deps):
                        log("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.")

        if args.once:
            break
            
        time.sleep(args.interval_seconds)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nBeendet.")
        sys.exit(0)
    except Exception as e:
        print(f"Fehler: {e}", file=sys.stderr)
        sys.exit(1)
