#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "9cd2c699be89364262ffb06181a688fef453acf1842efde8536bc3e62b352393", "source_sha256": "04518825207cd6ef771c2d840daf0a025f3144f4e384f1d13b46e016570f59df", "target_language": "lua"}
-- fix_gateway_node_path.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
-- auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

-- Backup der originalen Service-Datei
local date = os.date("%Y%m%d_%H%M%S")
local backup_cmd = string.format("cp /etc/systemd/system/openclaw-gateway.service /etc/systemd/system/openclaw-gateway.service.backup-%s", date)
os.execute(backup_cmd)

-- Korrektur des Node.js Pfads in der Service-Datei
-- Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
local service_file = "/etc/systemd/system/openclaw-gateway.service"
local temp_file = "/tmp/openclaw-gateway.service.tmp"

-- Lese die Datei und ersetze den Pfad
local file = io.open(service_file, "r")
if not file then
    print("Fehler: Kann Service-Datei nicht lesen")
    return 1
end
local content = file:read("*a")
file:close()

-- Ersetze den alten Node-Pfad mit dem neuen
content = content:gsub("/home/openclaw/.nvm/versions/node/v22.22.2/bin/node", "/usr/bin/node")

-- Schreibe den aktualisierten Inhalt in eine temporäre Datei
local temp = io.open(temp_file, "w")
if not temp then
    print("Fehler: Kann temporäre Datei nicht erstellen")
    return 1
end
temp:write(content)
temp:close()

-- Verschiebe die temporäre Datei an den richtigen Ort (benötigt möglicherweise Root-Rechte)
os.execute(string.format("mv %s %s", temp_file, service_file))

-- Service neu laden und neu starten
os.execute("systemctl daemon-reload")
os.execute("systemctl restart openclaw-gateway")

-- Status prüfen
os.execute("systemctl status openclaw-gateway --no-pager")
