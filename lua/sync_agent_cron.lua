#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f689de3acb8de66f09ef42aacd44509dca908e2456eaf675fd61a88cf623aa79", "source_sha256": "6dcc2c07911eedad64d93e999a1605091bebc0ed6eadad479df838626620545d", "target_language": "lua"}
-- sync_agent_cron.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
-- auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
-- auch in: workspace@local:scripts/sync_agent_cron.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync
]]

package.path = package.path .. ";/home/openclaw/.openclaw/workspace/scripts/?.lua"

local sync_clawhub_git = require("sync_clawhub_git")
local log = sync_clawhub_git.log
local validate_skill = sync_clawhub_git.validate_skill
local sync_to_git = sync_clawhub_git.sync_to_git
local sync_to_clawhub = sync_clawhub_git.sync_to_clawhub

local CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
local GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"
local LOG_FILE = "/home/openclaw/.openclaw/workspace/logs/sync-agent.log"

-- Hilfsfunktionen
function file_mtime(path)
    local files = {}
    local function scan_directory(dir)
        local handle = io.popen('find "' .. dir .. '" -type f -not -path "*/.git/*" 2>/dev/null')
        for file in handle:lines() do
            table.insert(files, file)
        end
        handle:close()
    end
    scan_directory(path)

    if #files == 0 then return 0 end

    local max_mtime = 0
    for _, filepath in ipairs(files) do
        local attr = lfs.attributes(filepath, "modification")
        if attr and attr > max_mtime then
            max_mtime = attr
        end
    end
    return max_mtime
end

function write_to_log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local entry = string.format("[%s] [%s] %s", timestamp, level, message)
    print(entry)
    local f = io.open(LOG_FILE, "a")
    if f then
        f:write(entry .. "\n")
        f:close()
    end
end

-- Hauptlog-Funktion überschreiben
sync_clawhub_git.log = write_to_log

write_to_log(string.rep("=", 70))
write_to_log("CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF")
write_to_log("Zeitstempel: " .. os.date("%Y-%m-%dT%H:%M:%S"))
write_to_log(string.rep("=", 70))

-- Liste der Skills lesen
function get_directories(base_path)
    local dirs = {}
    local handle = io.popen('ls -1 "' .. base_path .. '" 2>/dev/null')
    for line in handle:lines() do
        if not line:match("^%.") then
            local full_path = base_path .. "/" .. line
            local attr = lfs.attributes(full_path, "mode")
            if attr == "directory" then
                dirs[line] = true
            end
        end
    end
    handle:close()
    return dirs
end

local clawhub_skills = get_directories(CLAWHUB_DIR)
local git_skills = get_directories(GIT_DIR)

-- DRY-RUN: Erkenne Änderungen
write_to_log("\n[DRY-RUN] Analysiere Änderungen...")

local changes_detected = {
    new_in_clawhub = {},
    new_in_git = {},
    clawhub_newer = {},
    git_newer = {},
    synced = {}
}

-- 1. Neue Skills
for skill, _ in pairs(clawhub_skills) do
    if not git_skills[skill] then
        table.insert(changes_detected.new_in_clawhub, skill)
    end
end

for skill, _ in pairs(git_skills) do
    if not clawhub_skills[skill] then
        table.insert(changes_detected.new_in_git, skill)
    end
end

table.sort(changes_detected.new_in_clawhub)
table.sort(changes_detected.new_in_git)

-- 2. Existierende prüfen
local in_both = {}
for skill, _ in pairs(clawhub_skills) do
    if git_skills[skill] then
        table.insert(in_both, skill)
    end
end
table.sort(in_both)

for _, skill in ipairs(in_both) do
    local c_mtime = file_mtime(CLAWHUB_DIR .. "/" .. skill)
    local g_mtime = file_mtime(GIT_DIR .. "/" .. skill)
    local diff = c_mtime - g_mtime

    if math.abs(diff) > 60 then
        if diff > 0 then
            table.insert(changes_detected.clawhub_newer, {skill, diff})
        else
            table.insert(changes_detected.git_newer, {skill, math.abs(diff)})
        end
    else
        table.insert(changes_detected.synced, skill)
    end
end

-- Report
local total_changes = #changes_detected.new_in_clawhub + #changes_detected.new_in_git +
                      #changes_detected.clawhub_newer + #changes_detected.git_newer

write_to_log("Neu in ClawHub: " .. #changes_detected.new_in_clawhub)
write_to_log("Neu in Git: " .. #changes_detected.new_in_git)
write_to_log("ClawHub neuer: " .. #changes_detected.clawhub_newer)
write_to_log("Git neuer: " .. #changes_detected.git_newer)
write_to_log("Synchron: " .. #changes_detected.synced)

if total_changes == 0 then
    write_to_log("\n✅ Keine Änderungen erkannt. Sync nicht nötig.")
    write_to_log(string.rep("=", 70))
    os.exit(0)
end

write_to_log("\n🔄 " .. total_changes .. " Änderungen erkannt - starte Synchronisation...")

-- ECHTE SYNCHRONISATION
local results = {
    synced_to_git = {},
    synced_to_clawhub = {},
    up_to_date = {},
    errors = {}
}

-- 1. NEU in ClawHub → zu Git
for _, skill in ipairs(changes_detected.new_in_clawhub) do
    local success, err = pcall(function()
        if validate_skill(CLAWHUB_DIR .. "/" .. skill) then
            write_to_log("→ Synchronisiere " .. skill .. " zu Git...")
            if sync_to_git(skill, false) then
                local git_path = GIT_DIR .. "/" .. skill
                os.execute('cd "' .. git_path .. '" && git init -q 2>/dev/null')
                os.execute('cd "' .. git_path .. '" && git add . -f 2>/dev/null')
                local commit_msg = 'git commit -m "Initial: ' .. skill .. '" -q 2>/dev/null'
                os.execute('cd "' .. git_path .. '" && ' .. commit_msg)
                table.insert(results.synced_to_git, skill)
                write_to_log("  ✓ " .. skill .. " synchronisiert")
            end
        else
            table.insert(results.errors, skill .. " (invalid)")
        end
    end)
    if not success then
        write_to_log("  ✗ ERROR: " .. skill .. " - " .. tostring(err), "ERROR")
        table.insert(results.errors, skill)
    end
end

-- 2. NEU in Git → zu ClawHub
for _, skill in ipairs(changes_detected.new_in_git) do
    local success, err = pcall(function()
        if validate_skill(GIT_DIR .. "/" .. skill) then
            write_to_log("→ Synchronisiere " .. skill .. " zu ClawHub...")
            if sync_to_clawhub(skill, false) then
                table.insert(results.synced_to_clawhub, skill)
                write_to_log("  ✓ " .. skill .. " synchronisiert")
            end
        else
            table.insert(results.errors, skill .. " (invalid)")
        end
    end)
    if not success then
        write_to_log("  ✗ ERROR: " .. skill .. " - " .. tostring(err), "ERROR")
        table.insert(results.errors, skill)
    end
end

-- 3. Updates
for _, item in ipairs(changes_detected.clawhub_newer) do
    local skill, diff = item[1], item[2]
    local success, err = pcall(function()
        write_to_log("→ Update " .. skill .. " (ClawHub +" .. string.format("%.0f", diff) .. "s neuer)...")
        if sync_to_git(skill, false) then
            local git_path = GIT_DIR .. "/" .. skill
            os.execute('cd "' .. git_path .. '" && git add . -f 2>/dev/null')
            local dt = os.date("%Y-%m-%d %H:%M")
            local commit_msg = 'git commit -m "Sync from ClawHub: ' .. dt .. '" -q 2>/dev/null'
            os.execute('cd "' .. git_path .. '" && ' .. commit_msg)
            table.insert(results.synced_to_git, skill)
            write_to_log("  ✓ " .. skill .. " aktualisiert")
        end
    end)
    if not success then
        write_to_log("  ✗ ERROR: " .. skill .. " - " .. tostring(err), "ERROR")
        table.insert(results.errors, skill)
    end
end

for _, item in ipairs(changes_detected.git_newer) do
    local skill, diff = item[1], item[2]
    local success, err = pcall(function()
        write_to_log("→ Update " .. skill .. " (Git +" .. string.format("%.0f", diff) .. "s neuer)...")
        if sync_to_clawhub(skill, false) then
            table.insert(results.synced_to_clawhub, skill)
            write_to_log("  ✓ " .. skill .. " aktualisiert")
        end
    end)
    if not success then
        write_to_log("  ✗ ERROR: " .. skill .. " - " .. tostring(err), "ERROR")
        table.insert(results.errors, skill)
    end
end

results.up_to_date = changes_detected.synced

-- ZUSAMMENFASSUNG
write_to_log("\n" .. string.rep("=", 70))
write_to_log("SYNCHRONISATION ABGESCHLOSSEN")
write_to_log(string.rep("=", 70))
write_to_log("Zu Git synchronisiert:     " .. #results.synced_to_git)
write_to_log("Zu ClawHub synchronisiert: " .. #results.synced_to_clawhub)
write_to_log("Bereits aktuell:           " .. #results.up_to_date)
write_to_log("Fehler:                    " .. #results.errors)
if #results.errors > 0 then
    local error_list = ""
    for i, err in ipairs(results.errors) do
        error_list = error_list .. err
        if i < #results.errors then error_list = error_list .. ", " end
    end
    write_to_log("  Fehlerhafte: " .. error_list)
end
write_to_log(string.rep("=", 70))

-- State speichern
local STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json"
os.execute("mkdir -p $(dirname " .. STATE_FILE .. ")")

local state = {
    last_run = os.date("%Y-%m-%dT%H:%M:%S"),
    results = results,
    changes_detected = {}
}

for k, v in pairs(changes_detected) do
    if type(v) == "table" then
        state.changes_detected[k] = #v
    else
        state.changes_detected[k] = v
    end
end

local f = io.open(STATE_FILE, "w")
if f then
    f:write(require("cjson").encode(state))
    f:close()
    write_to_log("State gespeichert: " .. STATE_FILE)
end
