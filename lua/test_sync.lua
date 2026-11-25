#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d791fe3b2571cac01e005890e94cac5b8923fb24fced2a6ae9c394d2b4159356", "source_sha256": "daf78be577ece366a1908ac16ff31d6e57298b1256bb88185a5bc1cf5294a804", "target_language": "lua"}
-- test_sync.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:scripts/test_sync.py
-- auch in: OpenClaw@gateway2:scripts/test_sync.py
-- auch in: workspace@local:scripts/test_sync.py
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[Test für Sync-Script]]

package.path = package.path .. ';/home/openclaw/.openclaw/workspace/scripts/?.lua'

local sync_clawhub_git = require("sync_clawhub_git")

-- Test: db-maintainer ClawHub → Git (DRY-RUN)
print("=== TEST: db-maintainer sync (DRY-RUN) ===")
local skill = "db-maintainer"
local result = sync_clawhub_git.sync_to_git(skill, true)
print("Result: " .. (result and "SUCCESS" or "FAILED"))
print("\n=== LOG-Inhalt ===")
local file = io.open("/home/openclaw/.openclaw/workspace/logs/sync.log", "r")
if file then
    print(file:read("*a"))
    file:close()
else
    print("Logfile konnte nicht geöffnet werden")
end
