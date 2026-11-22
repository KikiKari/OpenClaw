#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "ebe0d67da8551160e702534c7ea8b5a07f33224a6431e7e38e83e0c66961f86e", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "perl6"}
# setup-xvfb-node3.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

use MONKEY-SEE-NO-EVAL;

sub run-or-die($command, $description) {
    say "Führe aus: $description";
    my $proc = run($command.split(/\s+/), :out, :err);
    if $proc.exitcode != 0 {
        note "Fehler bei: $description";
        exit 1;
    }
}

sub run-ignore-error($command, $description) {
    say "Führe aus (ignoriere Fehler): $description";
    run($command.split(/\s+/), :out, :err);
}

say "=== Xvfb + Chromium Setup für Node 3 ===";
say "=== Entferne altes VNC-Setup ===";

# Altes VNC stoppen & entfernen (falls vorhanden)
run-ignore-error("sudo systemctl stop vncserver@*", "Stoppe vncserver");
run-ignore-error("sudo systemctl disable vncserver@*", "Deaktiviere vncserver");
run-ignore-error("sudo apt-get remove -y tightvncserver tigervnc-standalone-server", "Entferne alte VNC-Pakete");

# Entferne VNC-Konfigurationsdateien
run-ignore-error("sudo rm -rf ~/.vnc /tmp/.X11-unix/X*", "Lösche alte VNC-Dateien");

say "=== Installiere Xvfb + Chromium ===";

# Update & Install
run-or-die("sudo apt-get update", "Aktualisiere Paketliste");

my @packages = <
    xvfb
    chromium
    chromium-driver
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
>;

run-or-die("sudo apt-get install -y {@packages.join(' ')}", "Installiere benötigte Pakete");

# Xvfb Systemd Service erstellen
my $service-content = q:to/EOF/;
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

spurt('/tmp/xvfb.service', $service-content);
run-or-die("sudo mv /tmp/xvfb.service /etc/systemd/system/xvfb.service", "Erstelle Xvfb systemd service");
run-or-die("sudo chown root:root /etc/systemd/system/xvfb.service", "Setze Besitzer für Service-Datei");
run-or-die("sudo chmod 644 /etc/systemd/system/xvfb.service", "Setze Rechte für Service-Datei");

# Service aktivieren
run-or-die("sudo systemctl daemon-reload", "Lade systemd neu");
run-or-die("sudo systemctl enable xvfb", "Aktiviere Xvfb service");
run-or-die("sudo systemctl start xvfb", "Starte Xvfb service");

say "=== Xvfb läuft auf DISPLAY :99 ===";

# Prüfe Chromium-Version
my $chromium-version = run(<chromium --version>, :out);
if $chromium-version.exitcode == 0 {
    say $chromium-version.out.slurp-rest.chomp;
} else {
    say "Chromium nicht gefunden";
}

say "=== Setup abgeschlossen ===";
say "=== Altes VNC-Setup wurde entfernt ===";
