#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "4f7ca7a07fe21184be7e5e8bde2ebe853e5632464fbf380706f2f39f71170b6b", "source_sha256": "b0b2d14634c78d492d814989a9bf887ffef50ac058176565e0d55191bb8ac787", "target_language": "python"}
# serve_compare_transfer.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import argparse
from pathlib import Path
from http.server import HTTPServer, SimpleHTTPRequestHandler
import socket

# Konfiguration
COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare"
TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
HOST_IP = "89.58.15.220"
PORT = 80
SELF_PATH = Path(__file__).resolve()

def get_files(compare_dir, self_path):
    """Finde alle Dateien im Vergleichsverzeichnis, außer dem Skript selbst."""
    files = []
    for item in Path(compare_dir).iterdir():
        if item.is_file() and item != self_path:
            files.append(item)
    
    # Sortiere die Dateien alphabetisch
    files.sort()
    return files

def print_file_list(files):
    """Zeige die bereitgestellten Dateien an."""
    print()
    print(f"Bereitgestellte Dateien aus {COMPARE_DIR}:")
    for src in files:
        print(f"- {src.name}")

def print_curl_commands(files):
    """Zeige die curl-Befehle für den Download an."""
    print()
    print(f"Copy/Paste auf anderem Gateway (Download nach {TRANSFER_DIR}):")
    for src in files:
        file_name = src.name
        print(f"curl -fL --retry 3 --connect-timeout 10 -o {TRANSFER_DIR}/{file_name} http://{HOST_IP}:{PORT}/{file_name}")

def start_server(port, directory):
    """Starte den HTTP-Server."""
    print()
    print(f"Server auf Port {port} aktiv. Beenden mit STRG+C.")
    print()
    
    os.chdir(directory)
    
    # Starte den HTTP-Server
    server_address = ('0.0.0.0', port)
    httpd = HTTPServer(server_address, SimpleHTTPRequestHandler)
    httpd.serve_forever()

def main():
    # Argumentparser für den Port (optional)
    parser = argparse.ArgumentParser(description='Serve and transfer compare files')
    parser.add_argument('--port', type=int, default=PORT, help='Port für den Server')
    args = parser.parse_args()

    # Hole die Dateien
    files = get_files(COMPARE_DIR, SELF_PATH)
    
    # Prüfe, ob Dateien vorhanden sind
    if not files:
        print(f"Keine Dateien in {COMPARE_DIR} gefunden.")
        sys.exit(1)
    
    # Zeige die Dateiliste an
    print_file_list(files)
    
    # Zeige die curl-Befehle an
    print_curl_commands(files)
    
    # Starte den Server
    try:
        start_server(args.port, COMPARE_DIR)
    except KeyboardInterrupt:
        print("\nServer beendet.")
        sys.exit(0)

if __name__ == "__main__":
    main()
