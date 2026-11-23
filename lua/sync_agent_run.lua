#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "0f8141c9dde314638a6ee28248d1af926e07bf2429f3f509e7da7f7003ded439", "source_sha256": "7012bf54a442a99950a2c73407058fd2f7330b956a58bc3b2698e87ee308dec9", "target_language": "lua"}
-- sync_agent_run.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:scripts/sync_agent_run.py
-- auch in: OpenClaw@gateway2:scripts/sync_agent_run.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
ClawHub ↔ Git Sync Agent - Produktionslauf
--]]
package.path = package.path .. ";/home/openclaw/.openclaw/workspace/scripts/?.lua"

local sync_lib = require("sync_clawhub_git")
local sync_to_git = sync_lib.sync_to_git
local sync_to_clawhub = sync_lib.sync_to_clawhub
local log = sync_lib.log
local validate_skill = sync_lib.validate_skill

local posix = require("posix")
local json = require("cjson")
local lfs = require("lfs")

local CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
local GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"

local function file_mtime(path)
    local max_mtime = 0
    local function scan_dir(dir)
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local full_path = dir .. "/" .. file
                local attr = lfs.attributes(full_path)
                if attr then
                    if attr.mode == "directory" and not string.find(full_path, "%.git") then
                        scan_dir(full_path)
                    elseif attr.mode == "file" and not string.find(full_path, "%.git") then
                        if attr.modification > max_mtime then
                            max_mtime = attr.modification
                        end
                    end
                end
            end
        end
    end
    scan_dir(path)
    return max_mtime
end

log(string.rep("=", 70))
log("CLAWHUB ↔ GIT SYNC AGENT - PRODUKTIONS-LAUF")
log("Zeitstempel: " .. os.date("%Y-%m-%dT%H:%M:%S"))
log(string.rep("=", 70))

local function get_dirs(base_path)
    local dirs = {}
    for dir in lfs.dir(base_path) do
        if dir ~= "." and dir ~= ".." and not string.sub(dir, 1, 1) == "." then
            local attr = lfs.attributes(base_path .. "/" .. dir)
            if attr and attr.mode == "directory" then
                dirs[dir] = true
            end
        end
    end
    return dirs
end

local clawhub_skills = get_dirs(CLAWHUB_DIR)
local git_skills = get_dirs(GIT_DIR)

local results = {
    synced_to_git = {},
    synced_to_clawhub = {},
    up_to_date = {},
    errors = {}
}

-- 1. NEU in ClawHub → zu Git syncen
log("")
log("[PHASE 1] ClawHub → Git Synchronisation")
log(string.rep("-", 40))

local new_in_clawhub = {}
for skill, _ in pairs(clawhub_skills) do
    if not git_skills[skill] then
        table.insert(new_in_clawhub, skill)
    end
end
table.sort(new_in_clawhub)

for _, skill in ipairs(new_in_clawhub) do
    local success, err = pcall(function()
        if validate_skill(CLAWHUB_DIR .. "/" .. skill) then
            log("→ Synchronisiere " .. skill .. " zu Git...")
            if sync_to_git(skill, false) then
                -- Git init
                local git_path = GIT_DIR .. "/" .. skill
                posix.chdir(git_path)
                os.execute("git init -q 2>/dev/null")
                os.execute("git add . -f 2>/dev/null")
                local dt = os.date("%Y-%m-%d %H:%M")
                os.execute(string.format('git commit -m "Initial: %s" -q 2>/dev/null', skill))
                table.insert(results.synced_to_git, skill)
                log("  ✓ " .. skill .. " synchronisiert & Git initialisiert")
            else
                table.insert(results.errors, skill .. " (sync failed)")
            end
        else
            table.insert(results.errors, skill .. " (invalid)")
        end
    end)
    if not success then
        log("  ✗ ERROR: " .. skill .. " - " .. tostring(err), "ERROR")
        table.insert(results.errors, skill .. " (exception)")
    end
end

-- 2. In beiden - prüfe Änderungen
log("")
log("[PHASE 2] Prüfe existierende Skills auf Änderungen")
log(string.rep("-", 40))

local in_both = {}
for skill, _ in pairs(clawhub_skills) do
    if git_skills[skill] then
        table.insert(in_both, skill)
    end
end
table.sort(in_both)

for _, skill in ipairs(in_both) do
    local success, err = pcall(function()
        local c_mtime = file_mtime(CLAWHUB_DIR .. "/" .. skill)
        local g_mtime = file_mtime(GIT_DIR .. "/" .. skill)
        local diff = c_mtime - g_mtime

        if math.abs(diff) > 60 then
            if diff > 0 then
                log(string.format("→ %s: ClawHub neuer (+%ds) → sync zu Git", skill, diff))
                if sync_to_git(skill, false) then
                    local git_path = GIT_DIR .. "/" .. skill
                    posix.chdir(git_path)
                    os.execute("git add . -f 2>/dev/null")
                    local dt = os.date("%Y-%m-%d %H:%M")
                    os.execute(string.format('git commit -m "Sync from ClawHub: %s" -q 2>/dev/null', dt))
                    table.insert(results.synced_to_git, skill)
                else
                    table.insert(results.errors, skill .. " (update failed)")
                end
            else
                log(string.format("→ %s: Git neuer (+%ds) → sync zu ClawHub", skill, math.abs(diff)))
                if sync_to_clawhub(skill, false) then
                    table.insert(results.synced_to_clawhub, skill)
                else
                    table.insert(results.errors, skill .. " (update failed)")
                end
            end
        else
            table.insert(results.up_to_date, skill)
        end
    end)
    if not success then
        log("  ✗ ERROR: " .. skill .. " - " .. tostring(err), "ERROR")
        table.insert(results.errors, skill .. " (exception)")
    end
end

-- ZUSAMMENFASSUNG
log("")
log(string.rep("=", 70))
log("SYNCHRONISATION ABGESCHLOSSEN")
log(string.rep("=", 70))
log("Zu Git synchronisiert:     " .. #results.synced_to_git)
if #results.synced_to_git > 0 then
    log("  " .. table.concat(results.synced_to_git, ", "))
end
log("Zu ClawHub synchronisiert: " .. #results.synced_to_clawhub)
if #results.synced_to_clawhub > 0 then
    log("  " .. table.concat(results.synced_to_clawhub, ", "))
end
log("Bereits aktuell:           " .. #results.up_to_date)
log("Fehler:                    " .. #results.errors)
if #results.errors > 0 then
    log("  " .. table.concat(results.errors, ", "))
end
log(string.rep("=", 70))

-- Speichere State
local STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json"
posix.mkdir("/home/openclaw/.openclaw/workspace/db")

local state = {
    last_run = os.date("%Y-%m-%dT%H:%M:%S"),
    results = results
}

local file = io.open(STATE_FILE, "w")
if file then
    file:write(json.encode(state))
    file:close()
    log("State gespeichert: " .. STATE_FILE)
end
