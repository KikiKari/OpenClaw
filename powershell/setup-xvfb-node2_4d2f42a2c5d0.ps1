#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "561b25353bfbffb23aa1d80a1fecfc1a95e7d10837318b8857d7134af1e98e69", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "powershell"}
# setup-xvfb-node2.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 2 (Netcup VPS)
# Erstellt: 2026-04-09

Write-Output "=== Xvfb + Chromium Setup für Node 2 ==="

# Update & Install
sudo apt-get update
sudo apt-get install -y `
    xvfb `
    chromium-browser `
    chromium-chromedriver `
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
User=openclaw
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
    chromium-browser --version
} catch {
    Write-Output "Chromium nicht gefunden"
}

Write-Output "=== Setup abgeschlossen ==="
