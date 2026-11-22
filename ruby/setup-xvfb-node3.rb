#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "313e3fbc2cc8df8fb6955e05ca7b85f15d9b6b2a673b707528aafc17d51baa04", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "ruby"}
# setup-xvfb-node3.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 3 (xNetX VPS)
# Erstellt: 2026-04-09
# Hinweis: Altes VNC-Setup wird entfernt

puts "=== Xvfb + Chromium Setup für Node 3 ==="
puts "=== Entferne altes VNC-Setup ==="

# Altes VNC stoppen & entfernen (falls vorhanden)
system("sudo systemctl stop vncserver@* 2>/dev/null", out: File::NULL, err: File::NULL) rescue nil
system("sudo systemctl disable vncserver@* 2>/dev/null", out: File::NULL, err: File::NULL) rescue nil
system("sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null", out: File::NULL, err: File::NULL) rescue nil
system("sudo rm -rf ~/.vnc /tmp/.X11-unix/X*", out: File::NULL, err: File::NULL) rescue nil

puts "=== Installiere Xvfb + Chromium ==="

# Update & Install
system("sudo apt-get update")
system("sudo apt-get install -y xvfb chromium chromium-driver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils")

# Xvfb Systemd Service erstellen
xvfb_service_content = <<~EOF
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

File.open("/etc/systemd/system/xvfb.service", "w") do |file|
  file.write(xvfb_service_content)
end

# Service aktivieren
system("sudo systemctl daemon-reload")
system("sudo systemctl enable xvfb")
system("sudo systemctl start xvfb")

puts "=== Xvfb läuft auf DISPLAY :99 ==="
puts "Chromium Version:"
result = system("chromium --version")
puts "Chromium nicht gefunden" unless result

puts "=== Setup abgeschlossen ==="
puts "=== Altes VNC-Setup wurde entfernt ==="
