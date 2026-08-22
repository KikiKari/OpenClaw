#!/usr/bin/env pwsh
# setup-xvfb-node3.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

Write-Output "=== Xvfb + Chromium Setup für Node 3 ==="
Write-Output "=== Entferne altes VNC-Setup ==="

# Altes VNC stoppen & entfernen (falls vorhanden)
Get-Service "vncserver@*" -ErrorAction SilentlyContinue | Stop-Service -ErrorAction SilentlyContinue
Get-Service "vncserver@*" -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled -ErrorAction SilentlyContinue

# Entferne VNC-Pakete (Beispielhaft, da Paketnamen variieren koennten)
$packagesToRemove = @("tightvncserver", "tigervnc-standalone-server")
foreach ($package in $packagesToRemove) {
    if (Get-Command "apt-get" -ErrorAction SilentlyContinue) {
        sudo apt-get remove -y $package 2>$null
    }
}

# Entferne VNC-Konfigurationsdateien
if (Test-Path "$env:HOME/.vnc") {
    Remove-Item -Recurse -Force "$env:HOME/.vnc" -ErrorAction SilentlyContinue
}
Get-ChildItem "/tmp/.X11-unix/X*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

Write-Output "=== Installiere Xvfb + Chromium ==="

# Update & Install
if (Get-Command "apt-get" -ErrorAction SilentlyContinue) {
    sudo apt-get update
    $packagesToInstall = @(
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
    )
    sudo apt-get install -y $packagesToInstall
}

# Xvfb Systemd Service erstellen
$xvfbServiceContent = @"
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
"@

$xvfbServicePath = "/etc/systemd/system/xvfb.service"
$xvfbServiceContent | Out-File -FilePath $xvfbServicePath -Encoding utf8

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable xvfb
sudo systemctl start xvfb

Write-Output "=== Xvfb läuft auf DISPLAY :99 ==="
Write-Output "Chromium Version:"
if (Get-Command "chromium" -ErrorAction SilentlyContinue) {
    chromium --version
} else {
    Write-Output "Chromium nicht gefunden"
}

Write-Output "=== Setup abgeschlossen ==="
Write-Output "=== Altes VNC-Setup wurde entfernt ==="
