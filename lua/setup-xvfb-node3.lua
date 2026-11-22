#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "8aca930d1c5523dd2b1cfd7072d673369e0094029ff9944b291a0d9894ca879a", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "lua"}
-- setup-xvfb-node3.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
-- auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

-- Xvfb Setup für Node 3 (xNetX VPS)
-- Erstellt: 2026-04-09
-- Hinweis: Altes VNC-Setup wird entfernt

local function execute_command(command)
    local handle = io.popen(command .. " 2>/dev/null")
    local result = handle:read("*a")
    local success, _, code = handle:close()
    return success, code, result
end

print("=== Xvfb + Chromium Setup für Node 3 ===")
print("=== Entferne altes VNC-Setup ===")

-- Altes VNC stoppen & entfernen (falls vorhanden)
execute_command("sudo systemctl stop vncserver@*")
execute_command("sudo systemctl disable vncserver@*")
execute_command("sudo apt-get remove -y tightvncserver tigervnc-standalone-server")
os.execute("sudo rm -rf ~/.vnc /tmp/.X11-unix/X* 2>/dev/null")

print("=== Installiere Xvfb + Chromium ===")

-- Update & Install
os.execute("sudo apt-get update")
os.execute([[sudo apt-get install -y \
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
    xdg-utils]])

-- Xvfb Systemd Service erstellen
local service_content = [[
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
]]

local file = io.open("/etc/systemd/system/xvfb.service", "w")
if file then
    file:write(service_content)
    file:close()
else
    print("Fehler beim Schreiben der Service-Datei")
    os.exit(1)
end

-- Service aktivieren
os.execute("sudo systemctl daemon-reload")
os.execute("sudo systemctl enable xvfb")
os.execute("sudo systemctl start xvfb")

print("=== Xvfb läuft auf DISPLAY :99 ===")
print("Chromium Version:")

local _, _, chromium_version = execute_command("chromium --version")
if chromium_version and chromium_version ~= "" then
    print(chromium_version)
else
    print("Chromium nicht gefunden")
end

print("=== Setup abgeschlossen ===")
print("=== Altes VNC-Setup wurde entfernt ===")
