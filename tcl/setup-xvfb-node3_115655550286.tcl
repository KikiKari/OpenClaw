#!/usr/bin/tclsh
# abstraction-provenance: {"artifact_sha256": "6051f3facb14572393da0e6b32ce8d24922d0827a720dad9bb49ee7a110076c4", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "tcl"}
# setup-xvfb-node3.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

proc execute_command {cmd} {
    if {[catch {exec /bin/sh -c $cmd} result]} {
        puts stderr "Fehler beim Ausführen von: $cmd"
        puts stderr "Ausgabe: $result"
        return 0
    } else {
        puts $result
        return 1
    }
}

proc main {} {
    puts "=== Xvfb + Chromium Setup für Node 3 ==="
    puts "=== Entferne altes VNC-Setup ==="

    # Altes VNC stoppen & entfernen (falls vorhanden)
    execute_command "sudo systemctl stop vncserver@* 2>/dev/null || true"
    execute_command "sudo systemctl disable vncserver@* 2>/dev/null || true"
    execute_command "sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null || true"
    execute_command "sudo rm -rf ~/.vnc /tmp/.X11-unix/X* 2>/dev/null || true"

    puts "=== Installiere Xvfb + Chromium ==="

    # Update & Install
    execute_command "sudo apt-get update"
    
    set packages {
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
    }
    
    set cmd "sudo apt-get install -y"
    foreach pkg $packages {
        append cmd " $pkg"
    }
    
    execute_command $cmd

    # Xvfb Systemd Service erstellen
    set service_content {
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
    }

    set fd [open "/etc/systemd/system/xvfb.service" w]
    puts $fd $service_content
    close $fd

    # Service aktivieren
    execute_command "sudo systemctl daemon-reload"
    execute_command "sudo systemctl enable xvfb"
    execute_command "sudo systemctl start xvfb"

    puts "=== Xvfb läuft auf DISPLAY :99 ==="
    puts "Chromium Version:"
    
    if {![execute_command "chromium --version"]} {
        puts "Chromium nicht gefunden"
    }

    puts "=== Setup abgeschlossen ==="
    puts "=== Altes VNC-Setup wurde entfernt ==="
}

main
