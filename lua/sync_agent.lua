#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f2ad9e8145068aef3e8a171126ba3d7289cd4bc684f8f13025cefaabe73c99de", "source_sha256": "b470dd345a01d0a6c2fec8e2dd8ccd0a3b59e67f44ce1aa0e6f4d9c34420b355", "target_language": "lua"}
-- sync_agent.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
-- Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

--[[
Permanenter ClawHub ↔ Git Sync Agent
Multi-Node fähig, stündliche Ausführung
]]

local json = require("cjson")
local posix = require("posix")

-- Konfiguration
local CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
local GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"
local STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json"

-- Globale Variablen für reservierte Namen (müssen aus sync_clawhub_git.lua geladen werden)
local RESERVED_SKILL_NAMES = {}

-- Lade externe Funktionen
local sync_module = dofile("/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.lua")
local sync_to_git = sync_module.sync_to_git
local sync_to_clawhub = sync_module.sync_to_clawhub
local log = sync_module.log
local validate_skill = sync_module.validate_skill
local get_file_hash = sync_module.get_file_hash
local iter_sync_files = sync_module.iter_sync_files

-- Hilfsfunktionen
local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function dir_exists(path)
    local stat = posix.stat(path, "type")
    return stat == "directory"
end

local function mkdir_p(path)
    local parts = {}
    for part in string.gmatch(path, "[^/]+") do
        table.insert(parts, part)
    end
    local current = "/"
    for i, part in ipairs(parts) do
        current = current .. part .. "/"
        if not dir_exists(current) then
            posix.mkdir(current)
        end
    end
end

local function load_state()
    --[[
    Lädt den Sync-State
    ]]
    if file_exists(STATE_FILE) then
        local f = io.open(STATE_FILE, "r")
        if f then
            local content = f:read("*a")
            f:close()
            return json.decode(content)
        end
    end
    return {sync_history = {}, pending = {}}
end

local function save_state(state)
    --[[
    Speichert den Sync-State
    ]]
    -- Stelle sicher, dass das Elternverzeichnis existiert
    local parent_dir = string.match(STATE_FILE, "(.+)/[^/]*$")
    if parent_dir and not dir_exists(parent_dir) then
        mkdir_p(parent_dir)
    end
    local f = io.open(STATE_FILE, "w")
    if f then
        f:write(json.encode(state))
        f:close()
    end
end

local function list_dirs(path)
    local dirs = {}
    local pipe = io.popen("ls -1 " .. path)
    if pipe then
        for line in pipe:lines() do
            if not string.match(line, "^%.") then
                local full_path = path .. "/" .. line
                local stat = posix.stat(full_path, "type")
                if stat == "directory" and not RESERVED_SKILL_NAMES[line] and file_exists(full_path .. "/SKILL.md") then
                    table.insert(dirs, line)
                end
            end
        end
        pipe:close()
    end
    return dirs
end

local function get_all_skills()
    --[[
    Findet alle Skills in beiden Verzeichnissen
    ]]
    local clawhub_skills = {}
    for _, skill in ipairs(list_dirs(CLAWHUB_DIR)) do
        clawhub_skills[skill] = true
    end
    
    local git_skills = {}
    for _, skill in ipairs(list_dirs(GIT_DIR)) do
        git_skills[skill] = true
    end
    
    local all_skills = {}
    for skill, _ in pairs(clawhub_skills) do
        all_skills[skill] = true
    end
    for skill, _ in pairs(git_skills) do
        all_skills[skill] = true
    end
    
    local result = {}
    for skill, _ in pairs(all_skills) do
        table.insert(result, skill)
    end
    table.sort(result)
    return result
end

local function run_command(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

local function init_git_repo(skill_path, skill_name)
    --[[
    Initialisiert Git-Repo wenn nötig
    ]]
    local git_dir = skill_path .. "/.git"
    if not dir_exists(git_dir) then
        posix.chdir(skill_path)
        run_command("git init")
        run_command("git add .")
        run_command("git commit -m 'Initial commit: " .. skill_name .. " skill'")
        log("Git initialized for " .. skill_name)
    end
end

local function get_hashes(skill_dir)
    --[[
    Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner.
    ]]
    local hashes = {}
    for file_path, rel_path in iter_sync_files(skill_dir) do
        hashes[rel_path] = get_file_hash(file_path)
    end
    return hashes
end

local function preview_changes(source_dir, target_dir)
    --[[
    Berechnet Sync-Änderungen in einer Richtung, ohne zu schreiben.
    ]]
    local changes = {}
    for src_file, rel_path in iter_sync_files(source_dir) do
        local tgt_file = target_dir .. "/" .. rel_path
        if not file_exists(tgt_file) then
            table.insert(changes, "ADD " .. rel_path)
        elseif get_file_hash(src_file) ~= get_file_hash(tgt_file) then
            table.insert(changes, "UPDATE " .. rel_path)
        end
    end
    return changes
end

local function newest_mtime(skill_dir)
    --[[
    Ermittelt die neueste mtime über alle relevanten Dateien.
    ]]
    local mtimes = {}
    for file_path, _ in iter_sync_files(skill_dir) do
        local stat = posix.stat(file_path, "mtime")
        if stat then
            table.insert(mtimes, stat)
        end
    end
    if #mtimes > 0 then
        table.sort(mtimes)
        return mtimes[#mtimes]
    end
    return 0.0
end

local function sync_skill_bidirectional(skill_name)
    --[[
    Bidirektionale Synchronisation eines Skills
    ]]
    local clawhub_path = CLAWHUB_DIR .. "/" .. skill_name
    local git_path = GIT_DIR .. "/" .. skill_name
    
    -- Fall 1: Nur in ClawHub → zu Git
    if dir_exists(clawhub_path) and not dir_exists(git_path) then
        log("NEW in ClawHub: " .. skill_name .. " → syncing to Git")
        if sync_to_git(skill_name, false) then
            init_git_repo(git_path, skill_name)
            return "synced_to_git"
        end
    
    -- Fall 2: Nur in Git → zu ClawHub
    elseif dir_exists(git_path) and not dir_exists(clawhub_path) then
        log("NEW in Git: " .. skill_name .. " → syncing to ClawHub")
        if sync_to_clawhub(skill_name, false) then
            return "synced_to_clawhub"
        end
    
    -- Fall 3: In beiden vorhanden
    elseif dir_exists(clawhub_path) and dir_exists(git_path) then
        if not validate_skill(clawhub_path) then
            log("Validation failed for ClawHub skill: " .. skill_name, "ERROR")
            return "error"
        end
        if not validate_skill(git_path) then
            log("Validation failed for Git skill: " .. skill_name, "ERROR")
            return "error"
        end

        local clawhub_changes = preview_changes(clawhub_path, git_path)
        local git_changes = preview_changes(git_path, clawhub_path)

        if #clawhub_changes == 0 and #git_changes == 0 then
            log("Content is identical for: " .. skill_name)
            return "no_change"
        end

        if #clawhub_changes > 0 and #git_changes == 0 then
            log("Content difference detected for: " .. skill_name)
            log("UPDATE: " .. skill_name .. " ClawHub content is newer or different → syncing to Git")
            if sync_to_git(skill_name, false) then
                posix.chdir(git_path)
                run_command("git add .")
                local timestamp = os.date("%Y-%m-%d %H:%M")
                run_command("git commit -m 'Sync from ClawHub content diff: " .. timestamp .. "'")
                return "updated_git"
            end
            log("Failed to sync " .. skill_name .. " to Git after content diff", "ERROR")
            return "error"
        end

        if #git_changes > 0 and #clawhub_changes == 0 then
            log("Content difference detected for: " .. skill_name)
            log("UPDATE: " .. skill_name .. " Git content is newer or different → syncing to ClawHub")
            if sync_to_clawhub(skill_name, false) then
                return "updated_clawhub"
            end
            log("Failed to sync " .. skill_name .. " to ClawHub after content diff", "ERROR")
            return "error"
        end

        log("Content difference detected for: " .. skill_name)
        if newest_mtime(clawhub_path) >= newest_mtime(git_path) then
            log("UPDATE: " .. skill_name .. " ClawHub content is newer or different → syncing to Git")
            if sync_to_git(skill_name, false) then
                posix.chdir(git_path)
                run_command("git add .")
                local timestamp = os.date("%Y-%m-%d %H:%M")
                run_command("git commit -m 'Sync from ClawHub content diff: " .. timestamp .. "'")
                return "updated_git"
            end
        else
            log("UPDATE: " .. skill_name .. " Git content is newer or different → syncing to ClawHub")
            if sync_to_clawhub(skill_name, false) then
                return "updated_clawhub"
            end
        end

        log("Failed to resolve content diff for " .. skill_name, "ERROR")
        return "error"
    end
    
    return "no_change"
end

local function main()
    --[[
    Hauptfunktion des Sync-Agents mit Dry-Run Phase
    ]]
    log("=== ClawHub ↔ Git Sync Agent gestartet ===")
    
    -- Load previous state
    local state = load_state()
    local all_skills = get_all_skills()
    log("Gefundene Skills: " .. #all_skills)
    
    -- Dry-Run Phase: only report changes, no actual modifications
    log("--- Dry-Run Phase Start ---")
    for _, skill in ipairs(all_skills) do
        -- Perform dry-run sync in both directions to capture potential changes
        sync_to_git(skill, true)
        sync_to_clawhub(skill, true)
    end
    log("--- Dry-Run Phase End ---")
    
    local results = {
        synced_to_git = {},
        synced_to_clawhub = {},
        updated_git = {},
        updated_clawhub = {},
        no_change = {},
        errors = {}
    }
    
    -- Actual Sync Phase
    for _, skill in ipairs(all_skills) do
        local status, result = pcall(sync_skill_bidirectional, skill)
        if status then
            table.insert(results[result], skill)
        else
            log("ERROR syncing " .. skill .. ": " .. tostring(result), "ERROR")
            table.insert(results.errors, skill)
        end
    end
    
    -- Zusammenfassung
    log("\n=== SYNC ZUSAMMENFASSUNG ===")
    log("Neu in Git: " .. #results.synced_to_git .. " - " .. table.concat(results.synced_to_git, ", "))
    log("Neu in ClawHub: " .. #results.synced_to_clawhub .. " - " .. table.concat(results.synced_to_clawhub, ", "))
    log("Git aktualisiert: " .. #results.updated_git .. " - " .. table.concat(results.updated_git, ", "))
    log("ClawHub aktualisiert: " .. #results.updated_clawhub .. " - " .. table.concat(results.updated_clawhub, ", "))
    log("Keine Änderung: " .. #results.no_change)
    log("Fehler: " .. #results.errors .. " - " .. table.concat(results.errors, ", "))
    
    -- State speichern
    if not state.sync_history then
        state.sync_history = {}
    end
    table.insert(state.sync_history, {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        results = results
    })
    -- Nur letzte 100 Einträge behalten
    while #state.sync_history > 100 do
        table.remove(state.sync_history, 1)
    end
    save_state(state)
    
    log("=== Sync Agent beendet ===\n")
end

main()
