#!/usr/bin/env python3
# serve_compare_transfer.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
from pathlib import Path
from http.server import HTTPServer, SimpleHTTPRequestHandler
import socket

# Konfiguration
COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare"
TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
HOST_IP = "89.58.15.220"
PORT = 80
SELF_PATH = os.path.realpath(__file__)

def get_files():
    """Finde alle Dateien im COMPARE_DIR außer diesem Skript"""
    compare_path = Path(COMPARE_DIR)
    files = []
    
    if compare_path.exists() and compare_path.is_dir():
        for item in compare_path.iterdir():
            if item.is_file() and str(item) != SELF_PATH:
                files.append(item)
    
    # Sortiere alphabetisch
    files.sort()
    return files

def main():
    files = get_files()
    
    if not files:
        print(f"Keine Dateien in {COMPARE_DIR} gefunden.")
        sys.exit(1)
    
    print()
    print(f"Bereitgestellte Dateien aus {COMPARE_DIR}:")
    for src in files:
        print(f"- {src.name}")
    
    print()
    print(f"Copy/Paste auf anderem Gateway (Download nach {TRANSFER_DIR}):")
    for src in files:
        file_name = src.name
        print(f"curl -fL --retry 3 --connect-timeout 10 -o {TRANSFER_DIR}/{file_name} http://{HOST_IP}:{PORT}/{file_name}")
    
    print()
    print(f"Server auf Port {PORT} aktiv. Beenden mit STRG+C.")
    print()
    
    # Wechsle ins Verzeichnis und starte HTTP-Server
    os.chdir(COMPARE_DIR)
    
    # Starte HTTP-Server auf allen Interfaces
    httpd = HTTPServer(('0.0.0.0', PORT), SimpleHTTPRequestHandler)
    httpd.serve_forever()

if __name__ == "__main__":
    main()
