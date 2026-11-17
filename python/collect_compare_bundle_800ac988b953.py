#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "e9e37de8832530847da5ffc157e9cbab9136c5e74ef05ef69f6a5937dec89fda", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "python"}
# collect_compare_bundle.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

ROOT = "/home/openclaw/.openclaw"
OUT_DIR = Path(ROOT) / "workspace" / "vscode" / "compare"
TRANSFER_DIR = OUT_DIR / "transfer"
MD_FILE = OUT_DIR / "local-gateway-config.md"
TREE_FILE = OUT_DIR / "tree.txt"
BACKUP_FILE = Path("/home/openclaw/openclaw-backup.tar.gz")

NOW_LOCAL = datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')
NOW_UTC = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')

try:
    HOST = subprocess.check_output(['hostname', '-f'], stderr=subprocess.STDOUT, text=True).strip()
except subprocess.CalledProcessError:
    HOST = subprocess.check_output(['hostname'], text=True).strip()

OPENCLAW_JSON = Path(ROOT) / "openclaw.json"
EXEC_APPROVALS_JSON = Path(ROOT) / "exec-approvals.json"
GATEWAY_SYSTEMD_ENV = Path(ROOT) / "gateway.systemd.env"
DOT_ENV = Path(ROOT) / ".env"
CONFIG_DIR = Path(ROOT) / ".config"
AGENTS_DIR = Path(ROOT) / "agents"

OUT_DIR.mkdir(parents=True, exist_ok=True)
TRANSFER_DIR.mkdir(parents=True, exist_ok=True)

def check_tree_installed():
    """Prüft ob das 'tree' Kommando verfügbar ist"""
    if not shutil.which('tree'):
        print("Fehler: 'tree' ist nicht installiert.")
        sys.exit(1)

def append_file_verbatim(label, path, lang="text"):
    """Fügt eine Datei wörtlich zum Markdown-Dokument hinzu"""
    with open(MD_FILE, "a") as md:
        md.write(f"\n## {label}\n\n")
        md.write(f"Pfad: `{path}`\n\n")
        md.write(f"```{lang}\n")
        if path.exists():
            with open(path, "r") as f:
                content = f.read()
                md.write(content)
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
        if not directory.exists():
            md.write(f"[FEHLT] {directory}\n")
            return
        md.write(f"Basisverzeichnis: `{directory}`\n")

        files = sorted(directory.rglob("*"))
        for file_path in files:
            if file_path.is_file():
                md.write(f"\n### Datei: `{file_path}`\n\n")
                md.write("```text\n")
                try:
                    with open(file_path, "r") as f:
                        md.write(f.read())
                except Exception as e:
                    md.write(f"[FEHLER BEIM LESEN] {e}\n")
                md.write("\n```\n")

# Hauptausgabe generieren
with open(MD_FILE, "w") as md:
    md.write(f"""# Lokaler Gateway-Konfigurationsstand

Generiert: {NOW_LOCAL}
UTC: {NOW_UTC}
Host: {HOST}

Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten.
""")

append_file_verbatim("openclaw.json", OPENCLAW_JSON, "json")
append_file_verbatim("exec-approvals.json", EXEC_APPROVALS_JSON, "json")
append_file_verbatim("gateway.systemd.env", GATEWAY_SYSTEMD_ENV, "dotenv")
append_file_verbatim(".env", DOT_ENV, "dotenv")
append_env_verbatim()
append_dir_files_verbatim(".config (alle Dateien rekursiv)", CONFIG_DIR)
append_dir_files_verbatim("agents (alle Dateien rekursiv)", AGENTS_DIR)

check_tree_installed()
with open(TREE_FILE, "w") as tree_out:
    subprocess.run(["tree", "-a", "-L", "6", ROOT], stdout=tree_out, check=True)

subprocess.run(["openclaw", "backup", "create", "--output", str(BACKUP_FILE), "--verify"], check=True)
shutil.copy(BACKUP_FILE, OUT_DIR)

print("OK")
print("Erzeugt:")
print(f"- {MD_FILE}")
print(f"- {TREE_FILE}")
print(f"- {BACKUP_FILE}")
print(f"- {TRANSFER_DIR} (leer)")
