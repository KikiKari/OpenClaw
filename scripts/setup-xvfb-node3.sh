#!/bin/bash
# Xvfb Setup für Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

set -e

echo "=== Xvfb + Chromium Setup für Node 3 ==="
echo "=== Entferne altes VNC-Setup ==="

# Altes VNC stoppen & entfernen (falls vorhanden)
sudo systemctl stop vncserver@* 2>/dev/null || true
sudo systemctl disable vncserver@* 2>/dev/null || true
sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null || true
sudo rm -rf ~/.vnc /tmp/.X11-unix/X*

echo "=== Installiere Xvfb + Chromium ==="

# Update & Install
sudo apt-get update
sudo apt-get install -y \
    xvfb \
    chromium \
    chromium-driver \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxss1 \
    xdg-utils

# Xvfb Systemd Service erstellen
sudo tee /etc/systemd/system/xvfb.service << 'EOF'
[Unit]
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
EOF

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable xvfb
sudo systemctl start xvfb

echo "=== Xvfb läuft auf DISPLAY :99 ==="
echo "Chromium Version:"
chromium --version || echo "Chromium nicht gefunden"

echo "=== Setup abgeschlossen ==="
echo "=== Altes VNC-Setup wurde entfernt ==="
