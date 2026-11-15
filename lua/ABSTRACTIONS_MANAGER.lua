#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "411b1c785df811d4b6147f67d826ab3cccd3e2b78d7796295fc631220c18a73e", "source_sha256": "1a472288a0369d1ab50d7682ef1fd8fb0f3252b751dcc14dceeea89b1522ec52", "target_language": "lua"}
-- ABSTRACTIONS_MANAGER.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[Skill-Einstieg fuer den kanonischen Abstractions Manager.]]

local KANONISCHER_MANAGER = "/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py"

local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

if not file_exists(KANONISCHER_MANAGER) then
    error("Kanonischer Abstractions Manager fehlt: " .. KANONISCHER_MANAGER)
end

-- Führe die Python-Datei mit dem Python-Interpreter aus
os.execute("python3 " .. KANONISCHER_MANAGER)
