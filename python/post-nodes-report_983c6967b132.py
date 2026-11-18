#!/usr/bin/env python3.12
# abstraction-provenance: {"artifact_sha256": "00977cb8d551a71bfbfdb8cd07244f68506e8fcc38e1d4f9c14206eb4c93a58f", "source_sha256": "04afaeaf031d1de3a9c71606dba8c1d6ea78b3b575d8ecf94af9256d4dc3886d", "target_language": "python"}
# post-nodes-report.js — portiert nach python
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

import os
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# Pfade
DASHBOARD_PATH = Path(__file__).parent.parent / "dashboards" / "nodes-overview.md"
REPORT_LOG = Path(__file__).parent.parent / "logs" / "nodes-report.log"

# Farbcodes
class C:
    green = '\033[32m'
    yellow = '\033[33m'
    red = '\033[31m'
    reset = '\033[0m'

def post_report():
    try:
        with open(DASHBOARD_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as err:
        print(f"{C.red}❌ Fehler beim Lesen der Dashboard-Datei:{C.reset} {err}")
        return

    # Nachricht über OpenClaw message senden
    escaped_content = content.replace('\n', '\\n')
    message_cmd = ["openclaw", "message", "send", "--target=main", "--message", escaped_content]

    try:
        subprocess.run(message_cmd, check=True, capture_output=True, text=True)
        print(f"{C.green}✅ Report erfolgreich im 'main'-Channel gepostet.{C.reset}")
        with open(REPORT_LOG, 'a', encoding='utf-8') as log_file:
            log_file.write(f"[{datetime.now().isoformat()}] Report posted.\n")
    except subprocess.CalledProcessError as err:
        error_output = err.stderr if err.stderr else str(err)
        print(f"{C.red}❌ Fehler beim Senden der Nachricht:{C.reset} {error_output}")
        with open(REPORT_LOG, 'a', encoding='utf-8') as log_file:
            log_file.write(f"[{datetime.now().isoformat()}] Failed to post: {err}\n")

# Hauptausführung
if __name__ == "__main__":
    print(f"{C.yellow}📤 Sende Nodes-Übersicht in 'main'...{C.reset}")
    post_report()
