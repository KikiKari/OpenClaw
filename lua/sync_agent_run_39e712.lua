#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "99f5366ab6eea00861ac91729f50cc507002d9c2e5372cd8ccfdefe23c59997b", "source_sha256": "39e712425a2c8c6fe6bad486ac97ef9c9d7f8a52e1abc18d11018d93ddc9d170", "target_language": "lua"}
-- sync_agent_run.py — portiert nach lua
-- Quelle: python, workspace@local:scripts/sync_agent_run.py
-- auch in: workspace@local:scripts/sync_agent.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
Permanenter ClawHub ↔ Git Sync Agent
Multi-Node fähig, stündliche Ausführung
]]

local json = require("cjson")
local posix = require("posix")

-- Konfiguration
local CLAWHUB_DIR = "/workspace/skills"
local GIT_DIR = "/workspace/git/skills"
local STATE_FILE = "/workspace/db/sync_state.json"
local BACKUP_ROOT = "/workspace/backups/sync_agent"

-- Globale Variablen für Importe
local sync_functions = dofile("/workspace/scripts/sync_clawhub_git.lua")
local sync_to_git = sync_functions.sync_to_git
local sync_to_clawhub = sync_functions.sync_to_clawhub
local log = sync_functions.log
local validate_skill = sync_functions.validate_skill
local get_file_hash = sync_functions.get_file_hash

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
    local cmd = "mkdir -p " .. path
    local success = os.execute(cmd)
    return success == 0 or success == true
end

local function load_state()
    --[[
    Lädt den Sync-State
    ]]
    if file_exists(STATE_FILE) then
        local file = io.open(STATE_FILE, "r")
        if file then
            local content = file:read("*a")
            file:close()
            local state = json.decode(content)
            return state or {sync_history = {}, pending = {}}
        end
    end
    return {sync_history = {}, pending = {}}
end

local function save_state(state)
    --[[
    Speichert den Sync-State
    ]]
    local parent_dir = string.match(STATE_FILE, "(.+)/[^/]*")
    mkdir_p(parent_dir)
    
    local file = io.open(STATE_FILE, "w")
    if file then
        file:write(json.encode(state))
        file:close()
    end
end

local function list_dirs(path)
    local dirs = {}
    local handle = io.popen("ls -1 " .. path)
    if handle then
        for line in handle:lines() do
            if not string.match(line, "^%.") and not string.match(line, "^_") then
                local full_path = path .. "/" .. line
                if dir_exists(full_path) then
                    table.insert(dirs, line)
                end
            end
        end
        handle:close()
    end
    return dirs
end

local function get_all_skills()
    --[[
    Findet nur valide Skill-Verzeichnisse in beiden Verzeichnissen.
    ]]
    local clawhub_skills = {}
    local git_skills = {}
    
    -- Hole Skills aus ClawHub
    for _, skill in ipairs(list_dirs(CLAWHUB_DIR)) do
        local skill_path = CLAWHUB_DIR .. "/" .. skill
        local skill_md = skill_path .. "/SKILL.md"
        if file_exists(skill_md) then
            clawhub_skills[skill] = true
        end
    end
    
    -- Hole Skills aus Git
    for _, skill in ipairs(list_dirs(GIT_DIR)) do
        local skill_path = GIT_DIR .. "/" .. skill
        local skill_md = skill_path .. "/SKILL.md"
        if file_exists(skill_md) then
            git_skills[skill] = true
        end
    end
    
    -- Vereinige beide Sets
    local all_skills = {}
    for skill, _ in pairs(clawhub_skills) do
        all_skills[skill] = true
    end
    for skill, _ in pairs(git_skills) do
        all_skills[skill] = true
    end
    
    -- Konvertiere zu Liste
    local skill_list = {}
    for skill, _ in pairs(all_skills) do
        table.insert(skill_list, skill)
    end
    
    table.sort(skill_list)
    return skill_list
end

local function init_git_repo(skill_path, skill_name)
    --[[
    Initialisiert Git-Repo wenn nötig
    ]]
    local git_dir = skill_path .. "/.git"
    if not dir_exists(git_dir) then
        local old_cwd = posix.getcwd()
        posix.chdir(skill_path)
        os.execute("git init >/dev/null 2>&1")
        os.execute("git add . >/dev/null 2>&1")
        os.execute(string.format('git commit -m "Initial commit: %s skill" >/dev/null 2>&1', skill_name))
        posix.chdir(old_cwd)
        log(string.format("Git initialized for %s", skill_name))
    end
end

local function backup_skill_dir(skill_path, skill_name)
    --[[
    Creates a timestamped tar.gz backup of a skill directory.
    ]]
    if not dir_exists(skill_path) then
        return
    end
    
    local timestamp = os.date("%Y%m%d%H%M%S")
    local backup_dir = BACKUP_ROOT .. "/" .. timestamp
    mkdir_p(backup_dir)
    
    local archive_name = string.format("%s_%s.tar.gz", skill_name, timestamp)
    local archive_path = backup_dir .. "/" .. archive_name
    
    local cmd = string.format(
        "cd %s && tar -czf %s . 2>/dev/null",
        skill_path,
        archive_path
    )
    os.execute(cmd)
    
    log(string.format("Backup created for %s at %s", skill_name, archive_path))
end

local function get_file_mod_time(path)
    local stat = posix.stat(path)
    return stat and stat.mtime or 0
end

local function get_hashes(skill_dir)
    --[[
    Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner.
    ]]
    local hashes = {}
    
    local function walk_directory(current_path, base_path)
        local handle = io.popen("ls -A " .. current_path)
        if not handle then return end
        
        for entry in handle:lines() do
            if entry ~= "." and entry ~= ".." then
                local full_path = current_path .. "/" .. entry
                local stat = posix.stat(full_path)
                
                if stat then
                    if stat.type == "directory" and not string.find(full_path, "%.git") then
                        walk_directory(full_path, base_path)
                    elseif stat.type == "regular" and not string.find(full_path, "%.git") then
                        local relative_path = string.gsub(full_path, "^" .. base_path .. "/", "")
                        hashes[relative_path] = get_file_hash(full_path)
                    end
                end
            end
        end
        handle:close()
    end
    
    walk_directory(skill_dir, skill_dir)
    return hashes
end

local function compare_hashes(hash1, hash2)
    -- Prüfe ob beide Tabellen die gleiche Anzahl an Einträgen haben
    local count1, count2 = 0, 0
    for _, _ in pairs(hash1) do count1 = count1 + 1 end
    for _, _ in pairs(hash2) do count2 = count2 + 1 end
    
    if count1 ~= count2 then
        return false
    end
    
    -- Prüfe jeden Hash-Wert
    for key, value in pairs(hash1) do
        if hash2[key] ~= value then
            return false
        end
    end
    
    return true
end

local function sync_skill_bidirectional(skill_name, dry_run)
    --[[
    Bidirektionale Synchronisation eines Skills
    ]]
    local clawhub_path = CLAWHUB_DIR .. "/" .. skill_name
    local git_path = GIT_DIR .. "/" .. skill_name
    dry_run = dry_run or false
    
    -- Fall 1: Nur in ClawHub → zu Git
    if dir_exists(clawhub_path) and not dir_exists(git_path) then
        log(string.format("NEW in ClawHub: %s → syncing to Git", skill_name))
        if not dry_run then
            backup_skill_dir(clawhub_path, skill_name .. "_clawhub")
        end
        if sync_to_git(skill_name, dry_run) then
            if not dry_run then
                init_git_repo(git_path, skill_name)
            end
            return "synced_to_git"
        end
    
    -- Fall 2: Nur in Git → zu ClawHub
    elseif dir_exists(git_path) and not dir_exists(clawhub_path) then
        log(string.format("NEW in Git: %s → syncing to ClawHub", skill_name))
        if not dry_run then
            backup_skill_dir(git_path, skill_name .. "_git")
        end
        if sync_to_clawhub(skill_name, dry_run) then
            return "synced_to_clawhub"
        end
    
    -- Fall 3: In beiden vorhanden → Vergleiche Timestamps
    elseif dir_exists(clawhub_path) and dir_exists(git_path) then
        -- MODIFIZIERTE LOGIK: Robusterer Datei-Hash-Vergleich
        
        -- Stelle sicher, dass beide als gültige Skills validiert werden
        if not validate_skill(clawhub_path) then
            log(string.format("Validation failed for ClawHub skill: %s", skill_name), "ERROR")
            return "error"
        end
        if not validate_skill(git_path) then
            log(string.format("Validation failed for Git skill: %s", skill_name), "ERROR")
            return "error"
        end
        
        -- Berechne Hashes für clawhub und git
        local clawhub_hashes = get_hashes(clawhub_path)
        local git_hashes = get_hashes(git_path)
        
        if not compare_hashes(clawhub_hashes, git_hashes) then
            log(string.format("Content difference detected for: %s", skill_name))
            
            -- Einfache (aber oft ausreichende) Logik: Wenn clawhub neuer ist, lade hoch.
            -- Eine detailliertere Strategie (z.B. welche Version von Git übernehmen)
            -- könnte hier implementiert werden, falls nötig.
            -- Für jetzt: Wenn sie sich unterscheiden, priorisieren wir ClawHub > Git
            -- und aktualisieren Git.
            
            local direction = "to-git"
            if get_file_mod_time(clawhub_path) < get_file_mod_time(git_path) then
                direction = "to-clawhub"
            end
            
            log(string.format("UPDATE: %s → syncing %s", skill_name, direction))
            if not dry_run then
                backup_skill_dir(clawhub_path, skill_name .. "_clawhub")
                backup_skill_dir(git_path, skill_name .. "_git")
            end
            
            local sync_func = sync_to_git
            if direction == "to-clawhub" then
                sync_func = sync_to_clawhub
            end
            
            if sync_func(skill_name, dry_run) then
                if not dry_run and direction == "to-git" then
                    local old_cwd = posix.getcwd()
                    posix.chdir(git_path)
                    os.execute("git add . >/dev/null 2>&1")
                    local commit_msg = string.format(
                        'git commit -m "Sync from ClawHub content diff: %s" >/dev/null 2>&1',
                        os.date("%Y-%m-%d %H:%M")
                    )
                    os.execute(commit_msg)
                    posix.chdir(old_cwd)
                end
                return direction == "to-git" and "updated_git" or "updated_clawhub"
            else
                log(string.format("Failed to sync %s to Git after content diff", skill_name), "ERROR")
                return "error"
            end
        else
            log(string.format("Content is identical for: %s", skill_name))
            return "no_change"
        end
    end
    
    return "no_change"
end

local function main(arg)
    --[[
    Hauptfunktion des Sync-Agents
    ]]
    local dry_run = false
    for _, v in ipairs(arg) do
        if v == "--dry-run" then
            dry_run = true
        end
    end
    
    log("=== ClawHub ↔ Git Sync Agent gestartet ===")
    
    local state = load_state()
    local all_skills = get_all_skills()
    log(string.format("Gefundene Skills: %d", #all_skills))
    
    local results = {
        synced_to_git = {},
        synced_to_clawhub = {},
        updated_git = {},
        updated_clawhub = {},
        no_change = {},
        errors = {}
    }
    
    for _, skill in ipairs(all_skills) do
        local success, result = pcall(sync_skill_bidirectional, skill, dry_run)
        if success then
            table.insert(results[result], skill)
        else
            log(string.format("ERROR syncing %s: %s", skill, result), "ERROR")
            table.insert(results.errors, skill)
        end
    end
    
    -- Zusammenfassung
    log("\n=== SYNC ZUSAMMENFASSUNG ===")
    log(string.format("Neu in Git: %d - %s", #results.synced_to_git, table.concat(results.synced_to_git, ", ")))
    log(string.format("Neu in ClawHub: %d - %s", #results.synced_to_clawhub, table.concat(results.synced_to_clawhub, ", ")))
    log(string.format("Git aktualisiert: %d - %s", #results.updated_git, table.concat(results.updated_git, ", ")))
    log(string.format("ClawHub aktualisiert: %d - %s", #results.updated_clawhub, table.concat(results.updated_clawhub, ", ")))
    log(string.format("Keine Änderung: %d", #results.no_change))
    log(string.format("Fehler: %d - %s", #results.errors, table.concat(results.errors, ", ")))
    
    -- Ein Dry-Run bleibt vollständig nicht-mutierend (abgesehen vom Audit-Log).
    if not dry_run then
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
    end
    
    log("=== Sync Agent beendet ===\n")
end

-- Starte das Programm
main(arg)
