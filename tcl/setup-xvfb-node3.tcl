#!/usr/bin/tclsh
# setup-xvfb-node3.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

# Funktion zur Ausführung von Shell-Befehlen mit Fehlerbehandlung
proc exec_safe {cmd} {
    if {[catch {exec /bin/sh -c $cmd} result]} {
        puts stderr "Fehler bei Befehl: $cmd"
        puts stderr "Ausgabe: $result"
        return 0
    } else {
        puts $result
        return 1
    }
}

puts "=== Xvfb + Chromium Setup für Node 3 ==="
puts "=== Entferne altes VNC-Setup ==="

# Altes VNC stoppen & entfernen (falls vorhanden)
exec_safe "sudo systemctl stop vncserver@* 2>/dev/null || true"
exec_safe "sudo systemctl disable vncserver@* 2>/dev/null || true"
exec_safe "sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null || true"
exec_safe "sudo rm -rf ~/.vnc /tmp/.X11-unix/X* 2>/dev/null || true"

puts "=== Installiere Xvfb + Chromium ==="

# Update & Install
exec_safe "sudo apt-get update"
exec_safe "sudo apt-get install -y xvfb chromium chromium-driver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils"

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

# Schreibe Service-Datei
if {[catch {open "/etc/systemd/system/xvfb.service" w} fd]} {
    puts stderr "Konnte Service-Datei nicht erstellen"
} else {
    puts -nonewline $fd $service_content
    close $fd
    
    # Service aktivieren
    exec_safe "sudo systemctl daemon-reload"
    exec_safe "sudo systemctl enable xvfb"
    exec_safe "sudo systemctl start xvfb"
}

puts "=== Xvfb läuft auf DISPLAY :99 ==="
puts "Chromium Version:"
if {![exec_safe "chromium --version"]} {
    puts "Chromium nicht gefunden"
}

puts "=== Setup abgeschlossen ==="
puts "=== Altes VNC-Setup wurde entfernt ==="
