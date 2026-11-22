#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "902686d6c49307ae81d7d33badbb9f82029bc95a40fcdd75ff5aa900994fef92", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "python"}
# setup-xvfb-node3.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

import subprocess
import os
import sys

def run_command(command, ignore_errors=False):
    """Führt einen Shell-Befehl sicher aus"""
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        if ignore_errors:
            return None
        print(f"Fehler beim Ausführen von: {command}", file=sys.stderr)
        print(e.stderr, file=sys.stderr)
        sys.exit(1)

def main():
    print("=== Xvfb + Chromium Setup für Node 3 ===")
    print("=== Entferne altes VNC-Setup ===")

    # Altes VNC stoppen & entfernen (falls vorhanden)
    run_command("sudo systemctl stop vncserver@* 2>/dev/null || true", ignore_errors=True)
    run_command("sudo systemctl disable vncserver@* 2>/dev/null || true", ignore_errors=True)
    run_command("sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null || true", ignore_errors=True)
    run_command("sudo rm -rf ~/.vnc /tmp/.X11-unix/X* 2>/dev/null || true", ignore_errors=True)

    print("=== Installiere Xvfb + Chromium ===")

    # Update & Install
    run_command("sudo apt-get update")
    
    packages = [
        "xvfb",
        "chromium",
        "chromium-driver",
        "fonts-liberation",
        "libappindicator3-1",
        "libasound2",
        "libatk-bridge2.0-0",
        "libatk1.0-0",
        "libcups2",
        "libgtk-3-0",
        "libnspr4",
        "libnss3",
        "libxss1",
        "xdg-utils"
    ]
    
    run_command(f"sudo apt-get install -y {' '.join(packages)}")

    # Xvfb Systemd Service erstellen
    service_content = """[Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
"""

    with open("/tmp/xvfb.service", "w") as f:
        f.write(service_content)
    
    run_command("sudo mv /tmp/xvfb.service /etc/systemd/system/xvfb.service")
    run_command("sudo chmod 644 /etc/systemd/system/xvfb.service")

    # Service aktivieren
    run_command("sudo systemctl daemon-reload")
    run_command("sudo systemctl enable xvfb")
    run_command("sudo systemctl start xvfb")

    print("=== Xvfb läuft auf DISPLAY :99 ===")
    print("Chromium Version:")
    
    try:
        version = run_command("chromium --version")
        print(version.strip())
    except:
        print("Chromium nicht gefunden")

    print("=== Setup abgeschlossen ===")
    print("=== Altes VNC-Setup wurde entfernt ===")

if __name__ == "__main__":
    main()
