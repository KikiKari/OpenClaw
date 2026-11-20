#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "1f91b75e739f643739ba95301c98994b4c198d095c4c56431dad5052876d87a7", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "ruby"}
# setup-xvfb-node2.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
# auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

# Xvfb Setup für Node 2 (Netcup VPS)
# Erstellt: 2026-04-09

puts "=== Xvfb + Chromium Setup für Node 2 ==="

# Update & Install
system("sudo apt-get update")
system("sudo apt-get install -y xvfb chromium-browser chromium-chromedriver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils")

# Xvfb Systemd Service erstellen
xvfb_service_content = <<~EOF
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

File.write("/tmp/xvfb.service", xvfb_service_content)
system("sudo mv /tmp/xvfb.service /etc/systemd/system/xvfb.service")

# Service aktivieren
system("sudo systemctl daemon-reload")
system("sudo systemctl enable xvfb")
system("sudo systemctl start xvfb")

puts "=== Xvfb läuft auf DISPLAY :99 ==="
puts "Chromium Version:"
result = system("chromium-browser --version")
puts "Chromium nicht gefunden" unless result

puts "=== Setup abgeschlossen ==="
