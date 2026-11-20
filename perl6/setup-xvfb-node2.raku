#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "7d390cd1c2a56d391b3b25f681014df413d178cc61f40ec2e11105a5a10a2109", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "perl6"}
# setup-xvfb-node2.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 2 (Netcup VPS)
# Erstellt: 2026-04-09

use v6;

sub MAIN() {
    say "=== Xvfb + Chromium Setup für Node 2 ===";

    # Update & Install
    run-qx("sudo", "apt-get", "update");
    run-qx("sudo", "apt-get", "install", "-y",
        "xvfb",
        "chromium-browser",
        "chromium-chromedriver",
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
        "xdg-utils");

    # Xvfb Systemd Service erstellen
    my $service-content = q:to/EOF/;
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

    my $service-file = "/etc/systemd/system/xvfb.service";
    write-file($service-file, $service-content);
    
    # Setze die richtigen Berechtigungen
    run-qx("sudo", "chmod", "644", $service-file);

    # Service aktivieren
    run-qx("sudo", "systemctl", "daemon-reload");
    run-qx("sudo", "systemctl", "enable", "xvfb");
    run-qx("sudo", "systemctl", "start", "xvfb");

    say "=== Xvfb läuft auf DISPLAY :99 ===";
    
    # Chromium Version anzeigen
    say "Chromium Version:";
    try {
        my $proc = run("chromium-browser", "--version", :out);
        if $proc.status == 0 {
            say $proc.out.slurp.chomp;
        } else {
            say "Chromium nicht gefunden";
        }
    }

    say "=== Setup abgeschlossen ===";
}

# Hilfsfunktion zum Ausführen von Kommandos mit Fehlerbehandlung
sub run-qx(*@args) {
    my $proc = run(|@args, :err);
    if $proc.status != 0 {
        die "Fehler beim Ausführen: @args[]";
    }
}

# Hilfsfunktion zum Schreiben einer Datei mit sudo
sub write-file($filename, $content) {
    # Verwende ein temporäres File und verschiebe es dann mit sudo
    my $tmpfile = "/tmp/" ~ $*PID ~ ".tmp";
    spurt($tmpfile, $content);
    
    run-qx("sudo", "mv", $tmpfile, $filename);
}
