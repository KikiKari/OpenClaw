#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "70682df551828200fbaeea04379ef46d18ec5deab868c4a5e50bde407895a0c6", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "lua"}
-- setup-xvfb-node2.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
-- auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
-- Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

-- Xvfb Setup für Node 2 (Netcup VPS)
-- Erstellt: 2026-04-09

local function run_command(command)
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return result
end

local function write_file(filename, content)
    local file = io.open(filename, "w")
    file:write(content)
    file:close()
end

print("=== Xvfb + Chromium Setup für Node 2 ===")

-- Update & Install
run_command("sudo apt-get update")
run_command("sudo apt-get install -y xvfb chromium-browser chromium-chromedriver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils")

-- Xvfb Systemd Service erstellen
local service_content = [[
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
]]

write_file("/tmp/xvfb.service", service_content)
run_command("sudo mv /tmp/xvfb.service /etc/systemd/system/xvfb.service")

-- Service aktivieren
run_command("sudo systemctl daemon-reload")
run_command("sudo systemctl enable xvfb")
run_command("sudo systemctl start xvfb")

print("=== Xvfb läuft auf DISPLAY :99 ===")
print("Chromium Version:")

local chromever = run_command("chromium-browser --version")
if chromever ~= "" then
    print(chromever)
else
    print("Chromium nicht gefunden")
end

print("=== Setup abgeschlossen ===")
