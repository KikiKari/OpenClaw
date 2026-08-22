#!/usr/bin/perl
# setup-xvfb-node2.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use autodie;

# Xvfb Setup für Node 2 (Netcup VPS)
# Erstellt: 2026-04-09

print "=== Xvfb + Chromium Setup für Node 2 ===\n";

# Update & Install
system("sudo apt-get update");

my @packages = qw(
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
);

system("sudo apt-get install -y " . join(" ", @packages));

# Xvfb Systemd Service erstellen
open my $fh, ">", "/etc/systemd/system/xvfb.service";
print $fh <<'EOF';
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
EOF
close $fh;

# Service aktivieren
system("sudo systemctl daemon-reload");
system("sudo systemctl enable xvfb");
system("sudo systemctl start xvfb");

print "=== Xvfb läuft auf DISPLAY :99 ===\n";
print "Chromium Version:\n";
system("chromium-browser --version") == 0 or print "Chromium nicht gefunden\n";

print "=== Setup abgeschlossen ===\n";
