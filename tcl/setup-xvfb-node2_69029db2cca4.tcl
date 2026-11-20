#!/usr/bin/tclsh
# abstraction-provenance: {"artifact_sha256": "af11a1c89aa75d72c5b0fb59fc0a28299b46cc0df9a847eee8b6125b3f2085bf", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "tcl"}
# setup-xvfb-node2.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 2 (Netcup VPS)
# Erstellt: 2026-04-09

proc puts_stderr {msg} {
    puts stderr $msg
}

proc run_command {cmd} {
    if {[catch {exec {*}$cmd} result]} {
        puts_stderr "Fehler beim Ausführen: $cmd"
        puts_stderr "Ausgabe: $result"
        exit 1
    }
    return $result
}

proc run_command_bg {cmd} {
    if {[catch {exec {*}$cmd &} result]} {
        puts_stderr "Fehler beim Ausführen: $cmd"
        puts_stderr "Ausgabe: $result"
        exit 1
    }
    return $result
}

puts "=== Xvfb + Chromium Setup für Node 2 ==="

# Update & Install
run_command {sudo apt-get update}
run_command {sudo apt-get install -y xvfb chromium-browser chromium-chromedriver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils}

# Xvfb Systemd Service erstellen
set service_content {[Unit]
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

set fd [open "/etc/systemd/system/xvfb.service" w]
puts $fd $service_content
close $fd

# Service aktivieren
run_command {sudo systemctl daemon-reload}
run_command {sudo systemctl enable xvfb}
run_command {sudo systemctl start xvfb}

puts "=== Xvfb läuft auf DISPLAY :99 ==="
puts "Chromium Version:"

if {[catch {exec chromium-browser --version} version_result]} {
    puts "Chromium nicht gefunden"
} else {
    puts $version_result
}

puts "=== Setup abgeschlossen ==="
