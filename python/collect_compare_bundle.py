#!/usr/bin/env python3
# collect_compare_bundle.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import shutil
from datetime import datetime
import getpass

def run_command(command, check=True, capture_output=True):
    """Führt einen Shell-Befehl aus und gibt das Ergebnis zurück."""
    try:
        result = subprocess.run(command, shell=True, check=check, 
                              capture_output=capture_output, text=True)
        return result.stdout.strip() if capture_output else None
    except subprocess.CalledProcessError as e:
        if capture_output:
            print(f"Fehler beim Ausführen von '{command}': {e.stderr}", file=sys.stderr)
        else:
            print(f"Fehler beim Ausführen von '{command}'", file=sys.stderr)
        sys.exit(1)

def check_tree_installed():
    """Prüft, ob 'tree' installiert ist."""
    if shutil.which("tree") is None:
        print("Fehler: 'tree' ist nicht installiert.")
        sys.exit(1)

def append_file_verbatim(md_file, label, path, lang="text"):
    """Fügt eine Datei wörtlich zur Markdown-Datei hinzu."""
    with open(md_file, "a", encoding="utf-8") as f:
        f.write(f"\n## {label}\n\n")
        f.write(f"Pfad: `{path}`\n\n")
        f.write(f"```{lang}\n")
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8", errors="replace") as file_content:
                f.write(file_content.read())
        else:
            f.write(f"[FEHLT] {path}\n")
        f.write("\n```\n")

def append_env_verbatim(md_file):
    """Fügt alle Umgebungsvariablen zur Markdown-Datei hinzu."""
    with open(md_file, "a", encoding="utf-8") as f:
        f.write("\n## Umgebungsvariablen (env)\n\n")
        f.write("```text\n")
        for key, value in sorted(os.environ.items()):
            f.write(f"{key}={value}\n")
        f.write("```\n")

def append_dir_files_verbatim(md_file, section, directory):
    """Fügt alle Dateien eines Verzeichnisses rekursiv zur Markdown-Datei hinzu."""
    with open(md_file, "a", encoding="utf-8") as f:
        f.write(f"\n## {section}\n\n")
        if not os.path.isdir(directory):
            f.write(f"[FEHLT] {directory}\n")
            return
        f.write(f"Basisverzeichnis: `{directory}`\n")

    # Finde alle Dateien rekursiv und sortiere sie
    all_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            all_files.append(os.path.join(root, file))
    all_files.sort()

    for file_path in all_files:
        with open(md_file, "a", encoding="utf-8") as f:
            f.write(f"\n### Datei: `{file_path}`\n\n")
            f.write("```text\n")
            try:
                with open(file_path, "r", encoding="utf-8", errors="replace") as content_file:
                    f.write(content_file.read())
            except Exception as e:
                f.write(f"[FEHLER BEIM LESEN] {e}\n")
            f.write("\n```\n")

def main():
    # Konfiguration
    ROOT = "/home/openclaw/.openclaw"
    OUT_DIR = os.path.join(ROOT, "workspace", "vscode", "compare")
    TRANSFER_DIR = os.path.join(OUT_DIR, "transfer")
    MD_FILE = os.path.join(OUT_DIR, "local-gateway-config.md")
    TREE_FILE = os.path.join(OUT_DIR, "tree.txt")
    BACKUP_FILE = "/home/openclaw/openclaw-backup.tar.gz"
    
    NOW_LOCAL = datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')
    NOW_UTC = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    
    try:
        HOST = subprocess.check_output(["hostname", "-f"], stderr=subprocess.DEVNULL).decode().strip()
    except subprocess.CalledProcessError:
        HOST = subprocess.check_output(["hostname"], text=True).strip()

    OPENCLAW_JSON = os.path.join(ROOT, "openclaw.json")
    EXEC_APPROVALS_JSON = os.path.join(ROOT, "exec-approvals.json")
    GATEWAY_SYSTEMD_ENV = os.path.join(ROOT, "gateway.systemd.env")
    DOT_ENV = os.path.join(ROOT, ".env")
    CONFIG_DIR = os.path.join(ROOT, ".config")
    AGENTS_DIR = os.path.join(ROOT, "agents")

    # Erstelle Verzeichnisse
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(TRANSFER_DIR, exist_ok=True)

    # Prüfe Abhängigkeiten
    check_tree_installed()

    # Erstelle Markdown-Kopf
    with open(MD_FILE, "w", encoding="utf-8") as f:
        f.write(f"""# Lokaler Gateway-Konfigurationsstand

Generiert: {NOW_LOCAL}
UTC: {NOW_UTC}
Host: {HOST}

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.
""")

    # Füge Dateien hinzu
    append_file_verbatim(MD_FILE, "openclaw.json", OPENCLAW_JSON, "json")
    append_file_verbatim(MD_FILE, "exec-approvals.json", EXEC_APPROVALS_JSON, "json")
    append_file_verbatim(MD_FILE, "gateway.systemd.env", GATEWAY_SYSTEMD_ENV, "dotenv")
    append_file_verbatim(MD_FILE, ".env", DOT_ENV, "dotenv")
    append_env_verbatim(MD_FILE)
    append_dir_files_verbatim(MD_FILE, ".config (alle Dateien rekursiv)", CONFIG_DIR)
    append_dir_files_verbatim(MD_FILE, "agents (alle Dateien rekursiv)", AGENTS_DIR)

    # Erstelle Baumansicht
    with open(TREE_FILE, "w", encoding="utf-8") as tree_file:
        subprocess.run(["tree", "-a", "-L", "6", ROOT], stdout=tree_file, check=True)

    # Erstelle Backup
    run_command(f"openclaw backup create --output {BACKUP_FILE} --verify")
    shutil.copy2(BACKUP_FILE, OUT_DIR)

    # Ausgabe
    print("OK")
    print("Erzeugt:")
    print(f"- {MD_FILE}")
    print(f"- {TREE_FILE}")
    print(f"- {BACKUP_FILE}")
    print(f"- {TRANSFER_DIR} (leer)")

if __name__ == "__main__":
    main()
