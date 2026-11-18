#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "7fa03f8d11203856e28f64e84d7c778ee3345556653bf4f6b676b3af7654e143", "source_sha256": "1a472288a0369d1ab50d7682ef1fd8fb0f3252b751dcc14dceeea89b1522ec52", "target_language": "lua"}
-- ABSTRACTIONS_MANAGER.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

--[[Skill-Einstieg fuer den kanonischen Abstractions Manager.]]

local KANONISCHER_MANAGER = "/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py"

-- Funktion zum Pruefen, ob eine Datei existiert
local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

-- Funktion zum Ausfuehren einer Python-Datei
local function run_python_file(filepath)
    local success, _, exit_code = os.execute("python3 " .. filepath)
    if not success then
        os.exit(exit_code or 1)
    end
end

if not file_exists(KANONISCHER_MANAGER) then
    print("Kanonischer Abstractions Manager fehlt: " .. KANONISCHER_MANAGER)
    os.exit(1)
end

run_python_file(KANONISCHER_MANAGER)
