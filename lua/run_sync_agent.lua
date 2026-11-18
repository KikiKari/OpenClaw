#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "952315cf131298031905167f4195bf3cd937703f1687f2db70cc20eac0ec1167", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "lua"}
-- run_sync_agent.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

--[[Sandbox-Wrapper für sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace.]]
package.path = "/workspace/scripts/?.lua;/workspace/scripts/?/init.lua;" ..
               "/workspace/skills/clawhub-git-sync-agent/scripts/?.lua;" ..
               "/workspace/skills/clawhub-git-sync-agent/scripts/?/init.lua;" .. package.path

local sync_agent = require("sync_agent")

local function Path(...)
    local parts = {...}
    return table.concat(parts, "/")
end

sync_agent.CLAWHUB_DIR = Path("/workspace", "skills")
sync_agent.GIT_DIR = Path("/workspace", "git", "skills")
sync_agent.STATE_FILE = Path("/workspace", "db", "sync_state.json")

sync_agent.main()
