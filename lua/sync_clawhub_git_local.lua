#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d044d6ff4cb68ec10a1c38cb9b02e31f8bc74752af5887a5e4883b1351e922c5", "source_sha256": "1bde9ce66616d24f21a9092c84abb4b447779e6077ec9035f2df678b92bb76f4", "target_language": "lua"}
-- sync_clawhub_git_local.py — portiert nach lua
-- Quelle: python, workspace@local:scripts/sync_clawhub_git_local.py
-- auch in: workspace@local:scripts/sync_clawhub_git.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
Bidirektionale ClawHub ↔ Git Synchronisation
]]

local fs = require("lfs")
local socket = require("socket") -- für Zeitstempel

-- Hilfsfunktionen für Dateisystemoperationen
local function mkdir_p(path)
    local sep = package.config:sub(1,1)
    local dirs = {}
    for dir in path:gmatch("[^"..sep.."]+") do
        table.insert(dirs, dir)
    end
    local current = ""
    if path:sub(1,1) == sep then
        current = sep
    end
    for i, dir in ipairs(dirs) do
        current = current .. dir .. sep
        local mode = lfs.attributes(current, "mode")
        if not mode then
            local ok, err = lfs.mkdir(current)
            if not ok then
                error("Konnte Verzeichnis nicht erstellen: " .. current .. " Fehler: " .. err)
            end
        elseif mode ~= "directory" then
            error("Pfad ist keine Datei: " .. current)
        end
    end
end

-- Pfad-Hilfsfunktionen
local function split_path(path)
    local parts = {}
    for part in string.gmatch(path, "[^/]+") do
        table.insert(parts, part)
    end
    return parts
end

local function join_paths(...)
    local t = {...}
    local result = ""
    for i, v in ipairs(t) do
        if type(v) == "table" then
            result = result .. table.concat(v, "/")
        else
            result = result .. tostring(v)
        end
        if i < #t then
            result = result .. "/"
        end
    end
    return result
end

local function path_exists(path)
    local attr = lfs.attributes(path)
    return attr and true or false
end

local function is_directory(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == "directory"
end

local function is_file(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == "file"
end

-- Konfiguration
local script_path = arg[0] or "."
local script_dir = script_path:match("(.-)[^\\/]*$")
script_dir = script_dir:sub(1, -2) -- Entferne abschließenden Schrägstrich
local WORKSPACE_DIR = script_dir .. "../"
local CLAWHUB_DIR = WORKSPACE_DIR .. "skills"
local GIT_DIR = WORKSPACE_DIR .. "git/skills"
local BACKUP_DIR = WORKSPACE_DIR .. "backups/sync"
local LOG_FILE = WORKSPACE_DIR .. "logs/sync-agent.log"

-- Erstelle Verzeichnisse
mkdir_p(GIT_DIR)
mkdir_p(BACKUP_DIR)
mkdir_p(WORKSPACE_DIR .. "logs")

-- Logging
local function log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local entry = "[" .. timestamp .. "] [" .. level .. "] " .. message
    print(entry)
    local f = io.open(LOG_FILE, "a")
    if f then
        f:write(entry .. "\n")
        f:close()
    end
end

-- SHA256 Hash-Berechnung (vereinfachte Version)
local function get_file_hash(file_path)
    local f = io.open(file_path, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    
    -- Vereinfachte Hash-Funktion (nicht echter SHA256, aber zur Demonstration)
    local sum = 0
    for i = 1, #content do
        sum = (sum + string.byte(content, i)) % 0xFFFFFFFF
    end
    return string.format("%08x", sum)
end

-- Rekursive Kopierfunktion mit Ausschluss von .git
local function copy_tree(src, dst, overwrite)
    if not path_exists(src) then
        log("Quellverzeichnis existiert nicht: " .. src, "ERROR")
        return false
    end
    
    if not is_directory(src) then
        log("Quelle ist kein Verzeichnis: " .. src, "ERROR")
        return false
    end
    
    if not path_exists(dst) then
        local ok, err = lfs.mkdir(dst)
        if not ok then
            log("Konnte Zielverzeichnis nicht erstellen: " .. dst .. " Fehler: " .. err, "ERROR")
            return false
        end
    elseif not overwrite then
        log("Zielverzeichnis existiert bereits: " .. dst, "ERROR")
        return false
    end
    
    for file in lfs.dir(src) do
        if file ~= "." and file ~= ".." and file ~= ".git" then
            local src_path = src .. "/" .. file
            local dst_path = dst .. "/" .. file
            
            local attr = lfs.attributes(src_path)
            if attr then
                if attr.mode == "directory" then
                    copy_tree(src_path, dst_path, overwrite)
                elseif attr.mode == "file" then
                    -- Datei kopieren
                    local src_f = io.open(src_path, "rb")
                    if src_f then
                        local dst_f = io.open(dst_path, "wb")
                        if dst_f then
                            local data = src_f:read("*all")
                            dst_f:write(data)
                            src_f:close()
                            dst_f:close()
                        else
                            src_f:close()
                            log("Konnte Zieldatei nicht öffnen: " .. dst_path, "ERROR")
                            return false
                        end
                    else
                        log("Konnte Quelldatei nicht öffnen: " .. src_path, "ERROR")
                        return false
                    end
                end
            end
        end
    end
    return true
end

-- Backup-Funktion
local function create_backup(source, skill_name)
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_path = BACKUP_DIR .. "/" .. skill_name .. "_" .. timestamp
    
    -- Backup-Verzeichnis löschen falls es existiert
    if path_exists(backup_path) then
        -- In Lua gibt es keine einfache rekursive Löschfunktion, daher überspringen wir das Löschen
        log("Backup-Pfad existiert bereits (Löschung nicht implementiert): " .. backup_path, "WARNING")
    end
    
    -- Kopiere Baum
    local success = copy_tree(source, backup_path, false)
    if success then
        log("Backup erstellt: " .. backup_path)
        return true
    else
        log("Backup fehlgeschlagen", "ERROR")
        return false
    end
end

-- Validierung
local function validate_skill(skill_dir)
    local skill_md = skill_dir .. "/SKILL.md"
    if not path_exists(skill_md) then
        log("Validation failed: " .. skill_dir .. " missing SKILL.md", "ERROR")
        return false
    end
    return true
end

-- Sync Richtung ClawHub → Git
local function sync_to_git(skill_name, dry_run)
    local source = CLAWHUB_DIR .. "/" .. skill_name
    local target = GIT_DIR .. "/" .. skill_name
    
    if not validate_skill(source) then
        return false
    end
    
    -- Backup vor Änderungen (nur wenn target existiert)
    if not dry_run and path_exists(target) then
        create_backup(target, skill_name)
    end
    
    -- Änderungen erkennen
    local changes = {}
    
    -- Durchsuche rekursiv das Quellverzeichnis
    local function scan_directory(base, relative)
        relative = relative or ""
        for file in lfs.dir(base .. "/" .. relative) do
            if file ~= "." and file ~= ".." and file ~= ".git" then
                local full_path = base .. "/" .. relative .. "/" .. file
                local rel_file_path = relative .. "/" .. file
                if relative == "" then
                    rel_file_path = file
                end
                
                local attr = lfs.attributes(full_path)
                if attr then
                    if attr.mode == "directory" then
                        scan_directory(base, relative .. "/" .. file)
                    elseif attr.mode == "file" then
                        local src_file = source .. "/" .. rel_file_path
                        local tgt_file = target .. "/" .. rel_file_path
                        
                        -- Vergleich
                        if not path_exists(tgt_file) then
                            table.insert(changes, "ADD " .. rel_file_path)
                        else
                            local src_hash = get_file_hash(src_file)
                            local tgt_hash = get_file_hash(tgt_file)
                            if src_hash ~= tgt_hash then
                                table.insert(changes, "UPDATE " .. rel_file_path)
                            end
                        end
                    end
                end
            end
        end
    end
    
    scan_directory(source)
    
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
    if path_exists(target) then
        -- Ziel existiert, überschreiben
        -- Da Lua-LFS keine direkte Option für dirs_exist_ok hat, müssen wir manuell vorgehen
        -- Hier vereinfachen wir es und kopieren einfach alles neu
        copy_tree(source, target, true)
    else
        -- Ziel existiert nicht, normales Kopieren
        copy_tree(source, target, false)
    end
    log("SYNC: " .. skill_name .. " - Complete")
    return true
end

-- Sync Richtung Git → ClawHub
local function sync_to_clawhub(skill_name, dry_run)
    local source = GIT_DIR .. "/" .. skill_name
    local target = CLAWHUB_DIR .. "/" .. skill_name
    
    if not validate_skill(source) then
        return false
    end
    
    -- Backup vor Änderungen (nur wenn target existiert)
    if not dry_run and path_exists(target) then
        create_backup(target, skill_name)
    end
    
    -- Änderungen erkennen
    local changes = {}
    
    -- Durchsuche rekursiv das Quellverzeichnis
    local function scan_directory(base, relative)
        relative = relative or ""
        for file in lfs.dir(base .. "/" .. relative) do
            if file ~= "." and file ~= ".." and file ~= ".git" then
                local full_path = base .. "/" .. relative .. "/" .. file
                local rel_file_path = relative .. "/" .. file
                if relative == "" then
                    rel_file_path = file
                end
                
                local attr = lfs.attributes(full_path)
                if attr then
                    if attr.mode == "directory" then
                        scan_directory(base, relative .. "/" .. file)
                    elseif attr.mode == "file" then
                        local src_file = source .. "/" .. rel_file_path
                        local tgt_file = target .. "/" .. rel_file_path
                        
                        -- Vergleich
                        if not path_exists(tgt_file) then
                            table.insert(changes, "ADD " .. rel_file_path)
                        else
                            local src_hash = get_file_hash(src_file)
                            local tgt_hash = get_file_hash(tgt_file)
                            if src_hash ~= tgt_hash then
                                table.insert(changes, "UPDATE " .. rel_file_path)
                            end
                        end
                    end
                end
            end
        end
    end
    
    scan_directory(source)
    
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
    if path_exists(target) then
        -- Ziel existiert, überschreiben
        copy_tree(source, target, true)
    else
        -- Ziel existiert nicht, normales Kopieren
        copy_tree(source, target, false)
    end
    log("SYNC: " .. skill_name .. " - Complete")
    return true
end

-- Argument Parsing (manuell)
local function parse_args(args)
    local parsed = {
        skill = nil,
        direction = nil,
        dry_run = false,
        force = false
    }
    
    for i = 1, #args do
        local arg = args[i]
        if arg == "--skill" and args[i+1] then
            parsed.skill = args[i+1]
            i = i + 1
        elseif arg == "--direction" and args[i+1] then
            parsed.direction = args[i+1]
            i = i + 1
        elseif arg == "--dry-run" then
            parsed.dry_run = true
        elseif arg == "--force" then
            parsed.force = true
        end
    end
    
    return parsed
end

-- Hauptfunktion
local function main()
    local args = parse_args(arg)
    
    if not args.skill or not args.direction then
        print("Benutzung: lua sync_clawhub_git_local.lua --skill <skill> --direction [to-git|to-clawhub] [--dry-run] [--force]")
        os.exit(1)
    end
    
    if args.direction ~= "to-git" and args.direction ~= "to-clawhub" then
        print("Richtung muss entweder 'to-git' oder 'to-clawhub' sein")
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
