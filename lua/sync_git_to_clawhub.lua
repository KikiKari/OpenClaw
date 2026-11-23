#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "5b52a50ee767540801ce1f2c8634228649c0f3714c30780d3634850792736046", "source_sha256": "6e59b459db4fb36ac761c1c0efd5b719de1cb0a62c0e628aa8274f5ef6a1056c", "target_language": "lua"}
-- sync_git_to_clawhub.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:scripts/sync_git_to_clawhub.py
-- auch in: workspace@local:scripts/sync_git_to_clawhub.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[Sync die aktiven Skill-Repositories zu ClawHub.]]

package.path = package.path .. ";/home/openclaw/.openclaw/workspace/scripts/?.lua"

local sync_clawhub_git = require("sync_clawhub_git")
local log = sync_clawhub_git.log

-- Nur aktive Skill-Repositories synchronisieren.
local git_repos = {
    "sub-agents-utils",
    "multi-nodes-utils",
}

-- Check if in git/
local git_path = "/home/openclaw/.openclaw/workspace/git"
for _, repo in ipairs(git_repos) do
    local handle = io.popen("test -d " .. git_path .. "/" .. repo .. " && echo true || echo false")
    local result = handle:read("*a")
    handle:close()
    
    if string.find(result, "true") then
        log("Syncing " .. repo .. " from Git to ClawHub...")
        sync_clawhub_git.sync_to_clawhub(repo, false)
        log("✅ " .. repo .. " synced to ClawHub")
    end
end
