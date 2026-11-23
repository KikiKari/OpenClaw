#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "3bea97b5e777d2c0031c6156e7a35b7a1c4c0b1ff8666b5abff29bac9ec47bdc", "source_sha256": "8780fd3b730020944ddee0cfabb1d6dde324ba0be8de46b91510150d0b3f4e96", "target_language": "lua"}
-- sync_git_to_clawhub.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:scripts/sync_git_to_clawhub.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[Sync die 4 Git-Repos zu ClawHub]]

package.path = package.path .. ';/home/openclaw/.openclaw/workspace/scripts/?.lua'

local sync_clawhub_git = require("sync_clawhub_git")
local log = sync_clawhub_git.log

-- Die 4 Git-Repos die zu ClawHub müssen
local git_repos = {
    "abstractions-utils",
    "sub-agents-utils", 
    "multi-nodes-utils",
    "Abstraktionen"
}

-- Check if in git/
local git_path = "/home/openclaw/.openclaw/workspace/git"
for _, repo in ipairs(git_repos) do
    if os.rename(git_path .. "/" .. repo, git_path .. "/" .. repo) then
        log("Syncing " .. repo .. " from Git to ClawHub...")
        -- Rename für sync function
        if repo == "Abstraktionen" then
            goto continue  -- Skip - ist kein Skill
        end
        sync_clawhub_git.sync_to_clawhub(repo, false)
        log("✅ " .. repo .. " synced to ClawHub")
        ::continue::
    end
end
