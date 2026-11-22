#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "738bb0054d5c06f97d57e53396aab9b4f371f1eb67a4a835e0de836899cc7b5e", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "powershell"}
# setup-xvfb-node3.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

Write-Output "=== Xvfb + Chromium Setup für Node 3 ==="
Write-Output "=== Entferne altes VNC-Setup ==="

# Altes VNC stoppen & entfernen (falls vorhanden)
try {
    sudo systemctl stop vncserver@* 2>$null
} catch {
    # Ignoriere Fehler
}
try {
    sudo systemctl disable vncserver@* 2>$null
} catch {
    # Ignoriere Fehler
}
try {
    sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>$null
} catch {
    # Ignoriere Fehler
}
try {
    sudo rm -rf ~/.vnc /tmp/.X11-unix/X*
} catch {
    # Ignoriere Fehler
}

Write-Output "=== Installiere Xvfb + Chromium ==="

# Update & Install
sudo apt-get update
sudo apt-get install -y `
    xvfb `
    chromium `
    chromium-driver `
    fonts-liberation `
    libappindicator3-1 `
    libasound2 `
    libatk-bridge2.0-0 `
    libatk1.0-0 `
    libcups2 `
    libgtk-3-0 `
    libnspr4 `
    libnss3 `
    libxss1 `
    xdg-utils

# Xvfb Systemd Service erstellen
$xvfbServiceContent = @'
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
'@

$xvfbServiceContent | sudo tee /etc/systemd/system/xvfb.service > $null

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable xvfb
sudo systemctl start xvfb

Write-Output "=== Xvfb läuft auf DISPLAY :99 ==="
Write-Output "Chromium Version:"
try {
    chromium --version
} catch {
    Write-Output "Chromium nicht gefunden"
}

Write-Output "=== Setup abgeschlossen ==="
Write-Output "=== Altes VNC-Setup wurde entfernt ==="
