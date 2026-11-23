#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "434bbb55dbb07382e974b7f4d20998fb96465e744ea5cb74b03f00aaa67a6132", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "perl6"}
# setup-xvfb-node3.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# auch in: workspace@local:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

use MONKEY-SEE-NO-EVAL;

sub run-or-die($command, $silent = False) {
    my $proc = run $command.split(/\s+/), :out, :err;
    unless $proc.exitcode == 0 {
        note "Fehler beim Ausführen von: $command" unless $silent;
        exit 1;
    }
    return $proc.out.slurp-rest.chomp;
}

sub MAIN() {
    say "=== Xvfb + Chromium Setup für Node 3 ===";
    say "=== Entferne altes VNC-Setup ===";

    # Altes VNC stoppen & entfernen (falls vorhanden)
    try {
        run-or-die("sudo systemctl stop vncserver@*", True);
        run-or-die("sudo systemctl disable vncserver@*", True);
        run-or-die("sudo apt-get remove -y tightvncserver tigervnc-standalone-server", True);
        run-or-die("sudo rm -rf ~/.vnc /tmp/.X11-unix/X*", True);
    }

    say "=== Installiere Xvfb + Chromium ===";

    # Update & Install
    run-or-die("sudo apt-get update");
    run-or-die(q:to/INSTALL/);
        sudo apt-get install -y \
            xvfb \
            chromium \
            chromium-driver \
            fonts-liberation \
            libappindicator3-1 \
            libasound2 \
            libatk-bridge2.0-0 \
            libatk1.0-0 \
            libcups2 \
            libgtk-3-0 \
            libnspr4 \
            libnss3 \
            libxss1 \
            xdg-utils
        INSTALL

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

    spurt("/tmp/xvfb.service", $service-content);
    run-or-die("sudo mv /tmp/xvfb.service /etc/systemd/system/xvfb.service");

    # Service aktivieren
    run-or-die("sudo systemctl daemon-reload");
    run-or-die("sudo systemctl enable xvfb");
    run-or-die("sudo systemctl start xvfb");

    say "=== Xvfb läuft auf DISPLAY :99 ===";
    say "Chromium Version:";
    
    try {
        my $version = run-or-die("chromium --version");
        say $version;
        CATCH {
            say "Chromium nicht gefunden";
        }
    }

    say "=== Setup abgeschlossen ===";
    say "=== Altes VNC-Setup wurde entfernt ===";
}
