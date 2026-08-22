#!/usr/bin/perl
# setup-xvfb-node3.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(setlocale LC_ALL);
use File::Path qw(remove_tree);

# Xvfb Setup fuer Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

print "=== Xvfb + Chromium Setup fuer Node 3 ===\n";
print "=== Entferne altes VNC-Setup ===\n";

# Altes VNC stoppen & entfernen (falls vorhanden)
system("sudo systemctl stop vncserver@* 2>/dev/null") == 0 or print "Keine vncserver Instanzen zum Stoppen gefunden\n";
system("sudo systemctl disable vncserver@* 2>/dev/null") == 0 or print "Keine vncserver Instanzen zum Deaktivieren gefunden\n";
system("sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null") == 0 or print "Keine VNC-Pakete zum Entfernen gefunden\n";

# Entferne VNC-Konfigurationsdateien
remove_tree($ENV{HOME} . "/.vnc");
system("sudo rm -rf /tmp/.X11-unix/X*");

print "=== Installiere Xvfb + Chromium ===\n";

# Update & Install
system("sudo apt-get update") == 0 or die "Fehler beim Aktualisieren der Paketliste\n";
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

my $package_list = join(" ", @packages);
system("sudo apt-get install -y $package_list") == 0 or die "Fehler beim Installieren der Pakete\n";

# Xvfb Systemd Service erstellen
open(my $fh, '>', '/etc/systemd/system/xvfb.service') or die "Konnte xvfb.service nicht erstellen: $!";
print $fh <<'EOF';
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
close($fh) or die "Konnte xvfb.service nicht schreiben: $!";

# Service aktivieren
system("sudo systemctl daemon-reload") == 0 or die "Fehler beim Neuladen der Systemd-Konfiguration\n";
system("sudo systemctl enable xvfb") == 0 or die "Fehler beim Aktivieren des xvfb Services\n";
system("sudo systemctl start xvfb") == 0 or die "Fehler beim Starten des xvfb Services\n";

print "=== Xvfb laeuft auf DISPLAY :99 ===\n";
print "Chromium Version:\n";
system("chromium --version") == 0 or print "Chromium nicht gefunden\n";

print "=== Setup abgeschlossen ===\n";
print "=== Altes VNC-Setup wurde entfernt ===\n";
