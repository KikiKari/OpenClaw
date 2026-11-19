#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "7da6270e0da50e8a7817105c4c7487de5885698d2157d16d1709e3442148a3be", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "python"}
# serve_compare_transfer.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
from pathlib import Path
from http.server import HTTPServer, SimpleHTTPRequestHandler
import socket

# Konfiguration
COMPARE_DIR = Path("/home/openclaw/.openclaw/workspace/vscode/compare")
TRANSFER_DIR = Path("/home/openclaw/.openclaw/workspace/vscode/compare/transfer")
HOST_IP = "152.53.145.65"
PORT = 80
SELF_PATH = Path(__file__).resolve()

# Finde alle Dateien im Compare-Verzeichnis (ausser diesem Skript)
files = []
try:
    for item in COMPARE_DIR.iterdir():
        if item.is_file() and item != SELF_PATH:
            files.append(item)
    files.sort()
except FileNotFoundError:
    print(f"Verzeichnis {COMPARE_DIR} nicht gefunden.")
    sys.exit(1)

if not files:
    print(f"Keine Dateien in {COMPARE_DIR} gefunden.")
    sys.exit(1)

print()
print(f"Bereitgestellte Dateien aus {COMPARE_DIR}:")
for src in files:
    print(f"- {src.name}")

print()
print("Copy/Paste auf anderem Gateway (Download nach {}):".format(TRANSFER_DIR))
for src in files:
    file = src.name
    print(f"curl -fL --retry 3 --connect-timeout 10 -o {TRANSFER_DIR}/{file} http://{HOST_IP}:{PORT}/{file}")

print()
print(f"Server auf Port {PORT} aktiv. Beenden mit STRG+C.")
print()

# Starte HTTP-Server
os.chdir(str(COMPARE_DIR))

class CustomHTTPRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

try:
    httpd = HTTPServer(('0.0.0.0', PORT), CustomHTTPRequestHandler)
    httpd.serve_forever()
except PermissionError:
    print(f"Fehler: Keine Berechtigung, Port {PORT} zu binden. Möglicherweise wird Root benötigt.")
    sys.exit(1)
except OSError as e:
    if e.errno == 98:  # Address already in use
        print(f"Fehler: Port {PORT} wird bereits verwendet.")
    else:
        print(f"Fehler beim Starten des Servers: {e}")
    sys.exit(1)
