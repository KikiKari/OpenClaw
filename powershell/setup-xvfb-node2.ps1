#!/usr/bin/env pwsh
# setup-xvfb-node2.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 2 (Netcup VPS)
# Erstellt: 2026-04-09

$ErrorActionPreference = "Stop"

Write-Host "=== Xvfb + Chromium Setup für Node 2 ==="

# Update & Install
Write-Host "Aktualisiere Paketliste und installiere benötigte Pakete..."
& sudo apt-get update
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& sudo apt-get install -y `
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

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

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

$xvfbServicePath = "/etc/systemd/system/xvfb.service"
Write-Host "Erstelle Xvfb Systemd Service unter $xvfbServicePath..."

# Schreibe den Service-Inhalt in die Datei
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $xvfbServiceContent
& sudo mv $tempFile $xvfbServicePath
if ($LASTEXITCODE -ne 0) { 
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    exit $LASTEXITCODE 
}

# Service aktivieren
Write-Host "Lade Systemd neu und aktiviere Xvfb Service..."
& sudo systemctl daemon-reload
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& sudo systemctl enable xvfb
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& sudo systemctl start xvfb
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== Xvfb läuft auf DISPLAY :99 ==="
Write-Host "Chromium Version:"

$chromiumVersion = & chromium-browser --version
if ($LASTEXITCODE -eq 0) {
    Write-Host $chromiumVersion
} else {
    Write-Host "Chromium nicht gefunden"
}

Write-Host "=== Setup abgeschlossen ==="
