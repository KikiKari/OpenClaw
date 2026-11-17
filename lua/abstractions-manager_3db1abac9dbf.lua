#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "c57b4bdd28bc8e86b4ffb3d751eb99d152e9659929b5f6f8d7db636324965946", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "lua"}
-- abstractions-manager.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

-- Führe das externe Skript mit denselben Argumenten aus
local script = "/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh"
local args = {...}

-- Baue den Befehl zusammen
local cmd = script
for i, arg in ipairs(args) do
    cmd = cmd .. " " .. arg
end

-- Führe den Befehl aus
os.execute(cmd)
