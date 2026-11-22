#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "fb3a9cd8858a50f8fbd67e202ca65951e55b43a449b15e66d06c46ece5afcffb", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "perl5"}
# setup-xvfb-node3.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Temp qw(tempfile);

print "=== Xvfb + Chromium Setup für Node 3 ===\n";
print "=== Entferne altes VNC-Setup ===\n";

# Altes VNC stoppen & entfernen (falls vorhanden)
system("sudo systemctl stop vncserver\@* 2>/dev/null") == 0 or print "Warning: Failed to stop vncserver\n";
system("sudo systemctl disable vncserver\@* 2>/dev/null") == 0 or print "Warning: Failed to disable vncserver\n";
system("sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null") == 0 or print "Warning: Failed to remove VNC packages\n";
system("sudo rm -rf ~/.vnc /tmp/.X11-unix/X* 2>/dev/null") == 0 or print "Warning: Failed to remove VNC files\n";

print "=== Installiere Xvfb + Chromium ===\n";

# Update & Install
system("sudo apt-get update") == 0 or die "Failed to update package list\n";
my @packages = (
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
);
system("sudo apt-get install -y " . join(" ", @packages)) == 0 or die "Failed to install packages\n";

# Xvfb Systemd Service erstellen
my $service_content = <<'EOF';
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

open(my $fh, '>', '/etc/systemd/system/xvfb.service') or die "Could not open file '/etc/systemd/system/xvfb.service' $!";
print $fh $service_content;
close $fh;

# Service aktivieren
system("sudo systemctl daemon-reload") == 0 or die "Failed to reload systemd daemon\n";
system("sudo systemctl enable xvfb") == 0 or die "Failed to enable xvfb service\n";
system("sudo systemctl start xvfb") == 0 or die "Failed to start xvfb service\n";

print "=== Xvfb läuft auf DISPLAY :99 ===\n";
print "Chromium Version:\n";
system("chromium --version") == 0 or print "Chromium nicht gefunden\n";

print "=== Setup abgeschlossen ===\n";
print "=== Altes VNC-Setup wurde entfernt ===\n";
