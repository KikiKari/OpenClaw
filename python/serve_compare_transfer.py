#!/usr/bin/env python3
# serve_compare_transfer.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import http.server
import socketserver
from pathlib import Path

COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare"
TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
HOST_IP = "152.53.145.65"
PORT = "80"
SELF_PATH = os.path.realpath(__file__)

# Finde alle Dateien im Compare-Verzeichnis (max. Tiefe 1), ausschließlich Dateien
files = [
    f for f in Path(COMPARE_DIR).iterdir()
    if f.is_file() and f != Path(SELF_PATH)
]
files.sort()

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

# Wechsle ins Compare-Verzeichnis und starte HTTP-Server
os.chdir(COMPARE_DIR)

Handler = http.server.SimpleHTTPRequestHandler
with socketserver.TCPServer(("0.0.0.0", int(PORT)), Handler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer gestoppt.")
        sys.exit(0)
