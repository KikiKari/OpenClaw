#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e6a8fcc6e9e1da81ca654e49ddf4e5053242034afc66d6b9c4c7615a4c5a3f68", "source_sha256": "2a279f44187e822afbb6a0af5593a2890c8e99b41f885f5d063355b6ea20b921", "target_language": "lua"}
-- sync_clawhub_git.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:scripts/sync_clawhub_git.py
-- auch in: Projects@clawhub:clawhub/Skills/sync_clawhub_git.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
Bidirektionale ClawHub ↔ Git Synchronisation
]]

local fs = require("lfs")
local posix = require("posix")

-- Hilfsfunktionen für Pfade
local function path_join(...)
    local parts = {...}
    local result = ""
    for i, part in ipairs(parts) do
        if part ~= "" then
            if i > 1 and string.sub(result, -1) ~= "/" and part:sub(1,1) ~= "/" then
                result = result .. "/"
            end
            result = result .. part
        end
    end
    return result
end

local function path_split(path)
    local parts = {}
    for part in string.gmatch(path, "[^/]+") do
        table.insert(parts, part)
    end
    return parts
end

local function path_exists(path)
    local attr = fs.attributes(path)
    return attr ~= nil
end

local function is_directory(path)
    local attr = fs.attributes(path)
    return attr and attr.mode == "directory"
end

local function is_file(path)
    local attr = fs.attributes(path)
    return attr and attr.mode == "file"
end

local function dirname(path)
    local dir = path:match("(.+)/[^/]*$")
    return dir or "."
end

local function basename(path)
    return path:match("([^/]+)$")
end

-- Konfiguration
local SCRIPT_PATH = arg[0] or "./sync_clawhub_git.lua"
local WORKSPACE_ROOT = fs.currentdir() -- In Lua können wir das Verzeichnis nicht so einfach bestimmen
local CLAWHUB_DIR = path_join(WORKSPACE_ROOT, "skills")
local GIT_DIR = path_join(WORKSPACE_ROOT, "git", "skills")
local BACKUP_DIR = path_join(WORKSPACE_ROOT, "backups", "sync")
local LOG_FILE = path_join(WORKSPACE_ROOT, "logs", "sync-agent.log")
local IGNORED_NAMES = {[".git"] = true, [".clawhub"] = true, ["node_modules"] = true, ["__pycache__"] = true, [".pytest_cache"] = true}
local RESERVED_SKILL_NAMES = {["github-clones"] = true, ["skills"] = true, ["backups"] = true, [".restore"] = true, ["git"] = true, ["Abstraktionen"] = true}
local PRESERVED_TARGET_NAMES = {[".git"] = true, [".clawhub"] = true, ["node_modules"] = true, ["__pycache__"] = true, [".pytest_cache"] = true}

-- Erstelle Verzeichnisse
local function mkdir_p(path)
    local parts = path_split(path)
    local current = ""
    for _, part in ipairs(parts) do
        current = path_join(current, part)
        local attr = fs.attributes(current)
        if not attr then
            posix.mkdir(current)
        elseif attr.mode ~= "directory" then
            error("Path exists but is not a directory: " .. current)
        end
    end
end

mkdir_p(GIT_DIR)
mkdir_p(BACKUP_DIR)
mkdir_p(dirname(LOG_FILE))

-- Logging
local function log(message, level)
    level = level or "INFO"
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local entry = string.format("[%s] [%s] %s", timestamp, level, message)
    print(entry)
    local f = io.open(LOG_FILE, "a")
    if f then
        f:write(entry .. "\n")
        f:close()
    end
end

-- Validierung
local function validate_skill(skill_dir)
    -- Prüft Skill-Struktur - SKILL.md required, scripts/ optional
    local skill_name = basename(skill_dir)
    if RESERVED_SKILL_NAMES[skill_name] then
        log("Validation failed: " .. skill_name .. " is reserved and must not be synced as a skill", "ERROR")
        return false
    end
    if not path_exists(path_join(skill_dir, "SKILL.md")) then
        log("Validation failed: " .. skill_name .. " missing SKILL.md", "ERROR")
        return false
    end
    return true
end

local function _is_ignored_path(path_parts)
    for _, part in ipairs(path_parts) do
        if IGNORED_NAMES[part] or (string.len(part) >= 11 and part:sub(-4) == ".pyc") then
            return true
        end
    end
    return false
end

local function _is_generated_duplicate_path(root, rel_path_parts)
    -- Detect generated duplicate folders such as <skill>/<skill> or scripts/scripts.
    if #rel_path_parts == 0 then
        return false
    end
    local root_name = basename(root)
    if rel_path_parts[1] == root_name then
        return true
    end
    for i = 2, #rel_path_parts do
        if rel_path_parts[i] == rel_path_parts[i-1] then
            return true
        end
    end
    return false
end

local function iter_sync_files(root)
    local files = {}
    
    local function walk(current_root, base_path)
        local full_path = path_join(root, current_root)
        local attr = fs.attributes(full_path)
        if not attr or attr.mode ~= "directory" then
            return
        end
        
        local rel_parts = path_split(current_root)
        if _is_ignored_path(rel_parts) then
            return
        end
        
        for file in fs.dir(full_path) do
            if file ~= "." and file ~= ".." then
                local file_path = path_join(full_path, file)
                local rel_file_path = path_join(current_root, file)
                local rel_parts_file = path_split(rel_file_path)
                
                if not (_is_ignored_path({file}) or (string.len(file) >= 4 and file:sub(-4) == ".pyc")) then
                    local attr_file = fs.attributes(file_path)
                    if attr_file then
                        if attr_file.mode == "directory" then
                            if not _is_generated_duplicate_path(root, path_split(rel_file_path)) then
                                walk(rel_file_path, base_path)
                            end
                        elseif attr_file.mode == "file" then
                            if not _is_ignored_path(rel_parts_file) and 
                               not _is_generated_duplicate_path(root, rel_parts_file) then
                                if file == "SKILL.md" and rel_file_path ~= "SKILL.md" then
                                    -- skip
                                else
                                    table.insert(files, {file_path, rel_file_path})
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    walk("", "")
    return files
end

local function reset_sync_target(target)
    -- Remove stale synced content before copying, preserving local-only metadata.
    mkdir_p(target)
    
    for file in fs.dir(target) do
        if file ~= "." and file ~= ".." then
            if not PRESERVED_TARGET_NAMES[file] then
                local child = path_join(target, file)
                local attr = fs.attributes(child)
                if attr then
                    if attr.mode == "directory" and not attr.permissions:match("l") then
                        posix.rmdir(child)
                    else
                        os.remove(child)
                    end
                end
            end
        end
    end
end

local function copy_sync_files(source, target)
    reset_sync_target(target)
    local files = iter_sync_files(source)
    for _, file_info in ipairs(files) do
        local src_file = file_info[1]
        local rel_path = file_info[2]
        local dest_file = path_join(target, rel_path)
        local dest_dir = dirname(dest_file)
        mkdir_p(dest_dir)
        
        -- Kopieren der Datei
        local src_f = io.open(src_file, "rb")
        if src_f then
            local dest_f = io.open(dest_file, "wb")
            if dest_f then
                local data = src_f:read("*all")
                dest_f:write(data)
                dest_f:close()
            end
            src_f:close()
        end
    end
end

-- Backup
local function create_backup(source, skill_name)
    -- Erstellt Backup eines Skills
    local timestamp = os.date('%Y%m%d_%H%M%S')
    local backup_path = path_join(BACKUP_DIR, skill_name .. "_" .. timestamp)
    
    -- Backup verzeichnis löschen falls es existiert
    if path_exists(backup_path) then
        local success, err = os.execute("rm -rf '" .. backup_path .. "'")
        if success then
            log("Removed existing backup: " .. backup_path)
        else
            log("Failed to remove existing backup " .. backup_path .. ": " .. tostring(err), "ERROR")
            return false
        end
    end
    
    local success, err = os.execute("cp -r '" .. source .. "' '" .. backup_path .. "'")
    if success then
        log("Backup created: " .. backup_path)
        return true
    else
        log("Backup failed: " .. tostring(err), "ERROR")
        return false
    end
end

-- Hash-Vergleich
local function get_file_hash(file_path)
    -- SHA256-Hash einer Datei
    -- Ensure the path points to a regular file.
    if not is_file(file_path) then
        return ""
    end
    
    local f = io.open(file_path, "rb")
    if not f then
        log("Failed to open " .. file_path, "ERROR")
        return ""
    end
    
    local sha2 = require("sha2")
    local hasher = sha2.sha256()
    
    while true do
        local chunk = f:read(4096)
        if not chunk then break end
        hasher:update(chunk)
    end
    
    f:close()
    return hasher:finish()
end

-- Sync Richtung ClawHub → Git
local function sync_to_git(skill_name, dry_run)
    -- Synchronisiert ClawHub Skill zu Git
    local source = path_join(CLAWHUB_DIR, skill_name)
    local target = path_join(GIT_DIR, skill_name)
    
    if not validate_skill(source) then
        return false
    end
    
    -- Backup vor Änderungen (nur wenn target existiert)
    if not dry_run and path_exists(target) then
        create_backup(target, skill_name)
    end
    
    -- Änderungen erkennen
    local changes = {}
    local files = iter_sync_files(source)
    for _, file_info in ipairs(files) do
        local src_file = file_info[1]
        local rel_path = file_info[2]
        local tgt_file = path_join(target, rel_path)
        if not path_exists(tgt_file) then
            table.insert(changes, "ADD " .. rel_path)
        elseif get_file_hash(src_file) ~= get_file_hash(tgt_file) then
            table.insert(changes, "UPDATE " .. rel_path)
        end
    end
    
    -- Dry-Run Report
    if dry_run then
        log("DRY-RUN: " .. skill_name .. " - " .. #changes .. " changes")
        for _, change in ipairs(changes) do
            log("  " .. change)
        end
        return true
    end
    
    -- Echte Synchronisation
    log("SYNC: " .. skill_name .. " - Applying " .. #changes .. " changes")
    copy_sync_files(source, target)
    log("SYNC: " .. skill_name .. " - Complete")
    return true
end

-- Sync Richtung Git → ClawHub
local function sync_to_clawhub(skill_name, dry_run)
    -- Synchronisiert Git Skill zu ClawHub
    local source = path_join(GIT_DIR, skill_name)
    local target = path_join(CLAWHUB_DIR, skill_name)
    
    if not validate_skill(source) then
        return false
    end
    
    -- Backup vor Änderungen (nur wenn target existiert)
    if not dry_run and path_exists(target) then
        create_backup(target, skill_name)
    end

    -- Änderungen erkennen (gleiche Logik wie oben)
    local changes = {}
    local files = iter_sync_files(source)
    for _, file_info in ipairs(files) do
        local src_file = file_info[1]
        local rel_path = file_info[2]
        local tgt_file = path_join(target, rel_path)
        if not path_exists(tgt_file) then
            table.insert(changes, "ADD " .. rel_path)
        elseif get_file_hash(src_file) ~= get_file_hash(tgt_file) then
            table.insert(changes, "UPDATE " .. rel_path)
        end
    end

    -- Dry-Run Report
    if dry_run then
        log("DRY-RUN: " .. skill_name .. " - " .. #changes .. " changes")
        for _, change in ipairs(changes) do
            log("  " .. change)
        end
        return true
    end

    -- Echte Synchronisation
    log("SYNC: " .. skill_name .. " - Applying " .. #changes .. " changes")
    copy_sync_files(source, target)
    log("SYNC: " .. skill_name .. " - Complete")
    return true
end

-- Hauptfunktion
local function main()
    local args = {
        skill = nil,
        direction = nil,
        dry_run = false,
        force = false
    }
    
    -- Simple argument parsing
    for i = 1, #arg do
        if arg[i] == "--skill" and arg[i+1] then
            args.skill = arg[i+1]
            i = i + 1
        elseif arg[i] == "--direction" and arg[i+1] then
            args.direction = arg[i+1]
            i = i + 1
        elseif arg[i] == "--dry-run" then
            args.dry_run = true
        elseif arg[i] == "--force" then
            args.force = true
        end
    end
    
    if not args.skill or not args.direction then
        print("Usage: sync_clawhub_git.lua --skill SKILL_NAME --direction [to-git|to-clawhub] [--dry-run] [--force]")
        os.exit(1)
    end
    
    log("Starting sync: " .. args.skill .. " (" .. args.direction .. ")")
    
    local success
    if args.direction == "to-git" then
        success = sync_to_git(args.skill, args.dry_run)
    else
        success = sync_to_clawhub(args.skill, args.dry_run)
    end
    
    if not success then
        log("Sync failed", "ERROR")
        os.exit(1)
    end
    
    log("Sync completed")
end

main()
