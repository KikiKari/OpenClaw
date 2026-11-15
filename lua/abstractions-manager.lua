#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "957ebe3f20cd502495007a4ed14772fa7caf0c90e4cc4c075d62d58fa90ae5f1", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "lua"}
-- abstractions-manager.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

-- Führe das externe Skript mit denselben Argumenten aus
os.execute("/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh " .. table.concat(arg, " "))
