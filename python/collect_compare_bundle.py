#!/usr/bin/env python3
# collect_compare_bundle.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import shutil
from datetime import datetime
import socket

ROOT = "/home/openclaw/.openclaw"
OUT_DIR = os.path.join(ROOT, "workspace", "vscode", "compare")
TRANSFER_DIR = os.path.join(OUT_DIR, "transfer")
MD_FILE = os.path.join(OUT_DIR, "local-gateway-config.md")
TREE_FILE = os.path.join(OUT_DIR, "tree.txt")
BACKUP_FILE = "/home/openclaw/openclaw-backup.tar.gz"
NOW_LOCAL = datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')
NOW_UTC = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
try:
    HOST = socket.getfqdn()
except:
    HOST = socket.gethostname()

OPENCLAW_JSON = os.path.join(ROOT, "openclaw.json")
EXEC_APPROVALS_JSON = os.path.join(ROOT, "exec-approvals.json")
GATEWAY_SYSTEMD_ENV = os.path.join(ROOT, "gateway.systemd.env")
DOT_ENV = os.path.join(ROOT, ".env")
CONFIG_DIR = os.path.join(ROOT, ".config")
AGENTS_DIR = os.path.join(ROOT, "agents")

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(TRANSFER_DIR, exist_ok=True)

def check_tree_installed():
    """Prüft ob 'tree' installiert ist"""
    if not shutil.which("tree"):
        print("Fehler: 'tree' ist nicht installiert.")
        exit(1)

def append_file_verbatim(label, path, lang="text"):
    """Fügt eine Datei wörtlich zum Markdown-Dokument hinzu"""
    with open(MD_FILE, "a") as md:
        md.write(f"\n## {label}\n\n")
        md.write(f"Pfad: `{path}`\n\n")
        md.write(f"```{lang}\n")
        if os.path.isfile(path):
            with open(path, "r") as f:
                md.write(f.read())
        else:
            md.write(f"[FEHLT] {path}\n")
        md.write("\n```\n")

def append_env_verbatim():
    """Fügt alle Umgebungsvariablen zum Markdown-Dokument hinzu"""
    with open(MD_FILE, "a") as md:
        md.write("\n## Umgebungsvariablen (env)\n\n")
        md.write("```text\n")
        for key, value in sorted(os.environ.items()):
            md.write(f"{key}={value}\n")
        md.write("```\n")

def append_dir_files_verbatim(section, directory):
    """Fügt alle Dateien eines Verzeichnisses rekursiv zum Markdown-Dokument hinzu"""
    with open(MD_FILE, "a") as md:
        md.write(f"\n## {section}\n\n")
        if not os.path.isdir(directory):
            md.write(f"[FEHLT] {directory}\n")
            return
        md.write(f"Basisverzeichnis: `{directory}`\n")
        
        # Sammle alle Dateien rekursiv
        files = []
        for root, _, filenames in os.walk(directory):
            for filename in filenames:
                files.append(os.path.join(root, filename))
        files.sort()
        
        for file_path in files:
            md.write(f"\n### Datei: `{file_path}`\n\n")
            md.write("```text\n")
            try:
                with open(file_path, "r") as f:
                    content = f.read()
                    md.write(content)
            except Exception as e:
                md.write(f"[FEHLER beim Lesen: {str(e)}]\n")
            md.write("\n```\n")

def main():
    check_tree_installed()
    
    # Initialisiere die Markdown-Datei
    with open(MD_FILE, "w") as md:
        md.write(f"""# Lokaler Gateway-Konfigurationsstand

Generiert: {NOW_LOCAL}
UTC: {NOW_UTC}
Host: {HOST}

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.\n""")
    
    append_file_verbatim("openclaw.json", OPENCLAW_JSON, "json")
    append_file_verbatim("exec-approvals.json", EXEC_APPROVALS_JSON, "json")
    append_file_verbatim("gateway.systemd.env", GATEWAY_SYSTEMD_ENV, "dotenv")
    append_file_verbatim(".env", DOT_ENV, "dotenv")
    append_env_verbatim()
    append_dir_files_verbatim(".config (alle Dateien rekursiv)", CONFIG_DIR)
    append_dir_files_verbatim("agents (alle Dateien rekursiv)", AGENTS_DIR)
    
    # Erzeuge Baumansicht
    with open(TREE_FILE, "w") as tree_file:
        subprocess.run(["tree", "-a", "-L", "6", ROOT], stdout=tree_file, check=True)
    
    # Erstelle Backup
    subprocess.run(["openclaw", "backup", "create", "--output", BACKUP_FILE, "--verify"], check=True)
    shutil.copy2(BACKUP_FILE, OUT_DIR)
    
    print("OK")
    print("Erzeugt:")
    print(f"- {MD_FILE}")
    print(f"- {TREE_FILE}")
    print(f"- {BACKUP_FILE}")
    print(f"- {TRANSFER_DIR} (leer)")

if __name__ == "__main__":
    main()
