#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "bf7a0444e9925904def69dd6f3887c59fe4d22493c567d8fb9a808a633b774ea", "source_sha256": "8621f6f7e524474de82b3d877ee62bbcbd9fa3b247b69c437b063b71fa995f5a", "target_language": "lua"}
-- ops-hub-heartbeat.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
-- auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

local fs = require('fs') or require('lfs')
local path = require('path') or {}

-- Hilfsfunktion für Pfadverarbeitung, falls path nicht verfügbar
local function join_paths(...)
    local parts = {...}
    return table.concat(parts, package.config:sub(1,1))
end

-- Aktualisiere den Statusbericht mit aktueller Zeit
local script_dir = arg[0]:match("(.*)[/\\]")
local statusPath = join_paths(script_dir, "..", "docs", "ops-hub", "status.md")

function updateHeartbeat()
    local content
    local file = io.open(statusPath, "r")
    if file then
        content = file:read("*all")
        file:close()
    else
        print("❌ Konnte status.md nicht lesen: " .. (statusPath .. " nicht gefunden"))
        return
    end

    -- Aktuelle Zeit in deutscher Lokalisierung mit Zeitzone Europe/Berlin
    local now = os.date("%d.%m.%Y, %H:%M:%S")  -- Einfache Formatierung als Ersatz
    
    -- Ersetze den Heartbeat-Zeitstempel
    local updated = content:gsub("(Letzter Heartbeat:) [^\n]*", "%1 " .. now)

    -- Schreibe aktualisierten Inhalt zurück
    local outFile = io.open(statusPath, "w")
    if outFile then
        outFile:write(updated)
        outFile:close()
        print("✅ Heartbeat aktualisiert: " .. now)
    else
        print("❌ Konnte status.md nicht schreiben: " .. statusPath)
    end
end

updateHeartbeat()
