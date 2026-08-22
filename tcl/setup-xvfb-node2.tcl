#!/usr/bin/tclsh
# setup-xvfb-node2.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 2 (Netcup VPS)
# Erstellt: 2026-04-09

puts "=== Xvfb + Chromium Setup für Node 2 ==="

# Update & Install
if {[catch {exec sudo apt-get update} result]} {
    puts stderr "Fehler beim Update: $result"
    exit 1
}

set packages {
    xvfb
    chromium-browser
    chromium-chromedriver
    fonts-liberation
    libappindicator3-1
    libasound2
    libatk-bridge2.0-0
    libatk1.0-0
    libcups2
    libgtk-3-0
    libnspr4
    libnss3
    libxss1
    xdg-utils
}

if {[catch {exec sudo apt-get install -y {*}$packages} result]} {
    puts stderr "Fehler bei der Installation: $result"
    exit 1
}

# Xvfb Systemd Service erstellen
set serviceContent {
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
}

set fh [open "/etc/systemd/system/xvfb.service" w]
puts $fh $serviceContent
close $fh

# Service aktivieren
if {[catch {exec sudo systemctl daemon-reload} result]} {
    puts stderr "Fehler beim Neuladen der Systemd-Daemon: $result"
    exit 1
}

if {[catch {exec sudo systemctl enable xvfb} result]} {
    puts stderr "Fehler beim Aktivieren des Xvfb-Services: $result"
    exit 1
}

if {[catch {exec sudo systemctl start xvfb} result]} {
    puts stderr "Fehler beim Starten des Xvfb-Services: $result"
    exit 1
}

puts "=== Xvfb läuft auf DISPLAY :99 ==="
puts "Chromium Version:"

if {[catch {exec chromium-browser --version} version_result]} {
    puts "Chromium nicht gefunden"
} else {
    puts $version_result
}

puts "=== Setup abgeschlossen ==="
