#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "9e22d0f7a1f5f17d8b4c5b6d8c4084205ef1a8c8c501fa34c644f3fbef773dcd", "source_sha256": "04518825207cd6ef771c2d840daf0a025f3144f4e384f1d13b46e016570f59df", "target_language": "lua"}
-- fix_gateway_node_path.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
-- auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

local os = require("os")
local io = require("io")

-- Backup der originalen Service-Datei
local timestamp = os.date("%Y%m%d_%H%M%S")
local backup_cmd = string.format("cp /etc/systemd/system/openclaw-gateway.service /etc/systemd/system/openclaw-gateway.service.backup-%s", timestamp)
os.execute(backup_cmd)

-- Korrektur des Node.js Pfads in der Service-Datei
-- Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
local service_file = "/etc/systemd/system/openclaw-gateway.service"
local temp_file = "/tmp/openclaw-gateway.service.tmp"

-- Datei einlesen und den Pfad ersetzen
local file = io.open(service_file, "r")
if not file then
    print("Fehler: Kann Servicedatei nicht lesen")
    return 1
end

local content = file:read("*all")
file:close()

-- Pfad ersetzen
local new_content = string.gsub(content, "/home/openclaw/.nvm/versions/node/v22.22.2/bin/node", "/usr/bin/node")

-- Temporäre Datei schreiben
local temp = io.open(temp_file, "w")
if not temp then
    print("Fehler: Kann temporäre Datei nicht erstellen")
    return 1
end

temp:write(new_content)
temp:close()

-- Datei zurückkopieren (benötigt möglicherweise root-Rechte)
local move_cmd = string.format("mv %s %s", temp_file, service_file)
os.execute(move_cmd)

-- Service neu laden und neu starten
os.execute("systemctl daemon-reload")
os.execute("systemctl restart openclaw-gateway")

-- Status prüfen
os.execute("systemctl status openclaw-gateway --no-pager")
