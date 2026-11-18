#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a1bdc1a84141559fa054ae4b4fdbf6436d914a0c58983f8721d09fae9ee53ea4", "source_sha256": "8d48f51942bb1c171bbd41e0696beb0722cb4b94d6596233f54b32928b645086", "target_language": "lua"}
-- db_maintainer.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:scripts/db_maintainer.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
Database Maintainer Sub-Agent
Automated database maintenance with 30min checks, hourly backups (3 days retention),
band tree command execution for important/openclaw-tree.txt
]]

local os = require("os")
local io = require("io")
local table = require("table")
local string = require("string")
local lfs = require("lfs")
local posix = require("posix")

-- Hilfsfunktionen für Pfade
local function path_join(...)
    local parts = {...}
    return table.concat(parts, "/")
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function mkdir_p(path)
    -- Rekursives Erstellen von Verzeichnissen
    local dirs = {}
    for dir in string.gmatch(path, "[^/]+") do
        table.insert(dirs, dir)
    end
    
    local current_path = ""
    for i, dir in ipairs(dirs) do
        if i == 1 then
            current_path = dir
        else
            current_path = current_path .. "/" .. dir
        end
        
        local mode = lfs.attributes(current_path, "mode")
        if not mode then
            local success, err = lfs.mkdir(current_path)
            if not success then
                return false, err
            end
        elseif mode ~= "directory" then
            return false, "Path exists but is not a directory: " .. current_path
        end
    end
    
    return true
end

-- Umgebungsvariablen und Pfade
local OPENCLAW_WORKSPACE = os.getenv("OPENCLAW_WORKSPACE")
if not OPENCLAW_WORKSPACE then
    -- Bestimme das Verzeichnis des Skripts
    local script_path = debug.getinfo(1, "S").source:sub(2)
    local script_dir = script_path:match("(.*/)")
    if script_dir then
        OPENCLAW_WORKSPACE = script_dir .. "../"
    else
        OPENCLAW_WORKSPACE = "./"
    end
end

local WORKSPACE = OPENCLAW_WORKSPACE:gsub("/+$", "")
local DB_DIR = WORKSPACE
local BACKUP_DIR = path_join(WORKSPACE, "db", "backups")
local LOG_DIR = path_join(WORKSPACE, "logs", "db-maintainer")
local IMPORTANT_DIR = path_join(WORKSPACE, "important")

-- Verzeichnisse erstellen
mkdir_p(BACKUP_DIR)
mkdir_p(LOG_DIR)
mkdir_p(IMPORTANT_DIR)

-- Logger-Klasse
local Logger = {}
Logger.__index = Logger

function Logger:new()
    local obj = {
        log_file = path_join(LOG_DIR, os.date("%Y-%m-%d") .. ".log")
    }
    setmetatable(obj, Logger)
    return obj
end

function Logger:log(level, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = string.format("[%s] [%s] %s", timestamp, level, message)
    print(line)
    
    local file = io.open(self.log_file, "a")
    if file then
        file:write(line .. "\n")
        file:close()
    end
end

function Logger:info(msg) self:log("INFO", msg) end
function Logger:warn(msg) self:log("WARN", msg) end
function Logger:error(msg) self:log("ERROR", msg) end

-- Hilfsfunktionen für JSON
local function read_json_file(filepath)
    local file = io.open(filepath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local func, err = load("return " .. content)
        if func then
            local ok, result = pcall(func)
            if ok then
                return result
            end
        end
    end
    return nil
end

local function write_json_file(filepath, data)
    local file = io.open(filepath, "w")
    if file then
        -- Einfache JSON Serialisierung (für einfache Tabellen)
        local function serialize(tbl, indent)
            indent = indent or 0
            local spaces = string.rep(" ", indent)
            local result = "{\n"
            
            for k, v in pairs(tbl) do
                local key = type(k) == "string" and '"' .. k .. '"' or tostring(k)
                local value
                if type(v) == "table" then
                    value = serialize(v, indent + 2)
                elseif type(v) == "string" then
                    value = '"' .. v .. '"'
                else
                    value = tostring(v)
                end
                result = result .. spaces .. "  " .. key .. ": " .. value .. ",\n"
            end
            
            result = result .. spaces .. "}"
            return result
        end
        
        -- Konvertiere zu JSON-kompatibler Struktur
        local json_str = "{\n"
        for k, v in pairs(data) do
            local key = '"' .. k .. '"'
            local value
            if type(v) == "table" then
                value = serialize(v, 2)
            elseif type(v) == "string" then
                value = '"' .. v .. '"'
            else
                value = tostring(v)
            end
            json_str = json_str .. "  " .. key .. ": " .. value .. ",\n"
        end
        json_str = json_str .. "}"
        
        file:write(json_str)
        file:close()
        return true
    end
    return false
end

-- DatabaseMaintainer-Klasse
local DatabaseMaintainer = {}
DatabaseMaintainer.__index = DatabaseMaintainer

function DatabaseMaintainer:new()
    local obj = {
        logger = Logger:new(),
        state_file = path_join(DB_DIR, "maintainer_state.json"),
        retention_days = 3
    }
    setmetatable(obj, DatabaseMaintainer)
    return obj
end

function DatabaseMaintainer:load_state()
    local state = read_json_file(self.state_file)
    if not state then
        state = {
            last_check = nil,
            last_backup = nil,
            last_tree_update = nil,
            file_hashes = {}
        }
    end
    return state
end

function DatabaseMaintainer:save_state(state)
    write_json_file(self.state_file, state)
end

function DatabaseMaintainer:get_file_hash(filepath)
    local handle = io.popen("md5sum " .. filepath .. " 2>/dev/null", "r")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result ~= "" then
            return result:match("^([a-f0-9]+)")
        end
    end
    return nil
end

function DatabaseMaintainer:_python_tree_fallback(max_depth)
    max_depth = max_depth or 8
    local lines = {WORKSPACE}
    
    local function walk(dirpath, prefix, depth)
        if depth > max_depth then
            return
        end
        
        local entries = {}
        local attr = lfs.attributes(dirpath)
        if attr and attr.mode == "directory" then
            for file in lfs.dir(dirpath) do
                if file ~= "." and file ~= ".." then
                    table.insert(entries, file)
                end
            end
            table.sort(entries)
        end
        
        for i, entry in ipairs(entries) do
            local full_path = path_join(dirpath, entry)
            local attr = lfs.attributes(full_path)
            if attr then
                local connector = (i == #entries) and "└── " or "├── "
                table.insert(lines, prefix .. connector .. entry)
                
                if attr.mode == "directory" then
                    local extension = (i == #entries) and "    " or "│   "
                    walk(full_path, prefix .. extension, depth + 1)
                end
            end
        end
    end
    
    walk(WORKSPACE, "", 1)
    return table.concat(lines, "\n") .. "\n"
end

function DatabaseMaintainer:run_tree_command()
    local handle = io.popen("timeout 60 tree -a -L 8 " .. WORKSPACE .. " 2>&1", "r")
    if handle then
        local result = handle:read("*a")
        local success, _, code = handle:close()
        if success and code == 0 then
            self.logger:info("tree -a -L 8 erfolgreich ausgeführt")
            return result
        else
            self.logger:warn("tree command fehlgeschlagen – nutze Python-Fallback")
            return self:_python_tree_fallback()
        end
    else
        self.logger:warn("tree-Binary nicht installiert – nutze Python-Fallback")
        return self:_python_tree_fallback()
    end
end

function DatabaseMaintainer:update_tree_file(tree_output)
    if not tree_output then
        return false
    end
    
    local tree_file = path_join(IMPORTANT_DIR, "openclaw-tree.txt")
    local header = "# OpenClaw Workspace Tree\n" ..
                   "# Generiert: " .. os.date("%Y-%m-%dT%H:%M:%S") .. "\n" ..
                   "# Befehl: tree -a -L 8 " .. WORKSPACE .. "\n" ..
                   "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
    
    local file = io.open(tree_file, "w")
    if file then
        file:write(header)
        file:write(tree_output)
        file:close()
        self.logger:info("openclaw-tree.txt aktualisiert: " .. tree_file)
        return true
    else
        self.logger:error("Fehler beim Schreiben von openclaw-tree.txt")
        return false
    end
end

function DatabaseMaintainer:scan_documentations()
    local docs = {}
    
    local function scan_directory(dir)
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local filepath = path_join(dir, file)
                local attr = lfs.attributes(filepath)
                if attr then
                    if attr.mode == "directory" and file ~= "node_modules" and not string.find(filepath, "db/backups", 1, true) then
                        scan_directory(filepath)
                    elseif attr.mode == "file" and string.sub(file, -3) == ".md" and not string.find(filepath, "db/backups", 1, true) and file ~= "node_modules" then
                        local rel_path = filepath:gsub("^" .. WORKSPACE .. "/", "")
                        table.insert(docs, {
                            path = rel_path,
                            hash = self:get_file_hash(filepath),
                            mtime = attr.modification
                        })
                    end
                end
            end
        end
    end
    
    scan_directory(WORKSPACE)
    return docs
end

function DatabaseMaintainer:check_for_changes()
    local state = self:load_state()
    local current_docs = self:scan_documentations()
    
    local changes = {}
    local current_hashes = {}
    
    for _, doc in ipairs(current_docs) do
        local path = doc.path
        current_hashes[path] = doc.hash
        
        if not state.file_hashes[path] then
            table.insert(changes, "NEW: " .. path)
        elseif state.file_hashes[path] ~= doc.hash then
            table.insert(changes, "CHANGED: " .. path)
        end
    end
    
    -- Prüfe auf gelöschte Dateien
    for old_path, _ in pairs(state.file_hashes) do
        if not current_hashes[old_path] then
            table.insert(changes, "DELETED: " .. old_path)
        end
    end
    
    return changes, current_hashes
end

function DatabaseMaintainer:update_databases()
    local handle = io.popen("timeout 60 python3 " .. path_join(WORKSPACE, "scripts", "update_docs_db.py") .. " 2>&1", "r")
    if handle then
        local result = handle:read("*a")
        local success, _, code = handle:close()
        if success and code == 0 then
            self.logger:info("docs.db aktualisiert")
            return true
        else
            self.logger:error("DB-Update fehlgeschlagen: " .. (result or ""))
            return false
        end
    else
        self.logger:error("DB-Update Exception: Could not execute command")
        return false
    end
end

function DatabaseMaintainer:update_tree_db_v2()
    local handle = io.popen("timeout 120 python3 " .. path_join(WORKSPACE, "scripts", "tree_indexer_v2.py") .. " 2>&1", "r")
    if handle then
        local result = handle:read("*a")
        local success, _, code = handle:close()
        if success and code == 0 then
            self.logger:info("tree.db v2 aktualisiert")
            return true
        else
            self.logger:error("Tree-DB v2 fehlgeschlagen: " .. (result or ""))
            return false
        end
    else
        self.logger:error("Tree-DB v2 Exception: Could not execute command")
        return false
    end
end

function DatabaseMaintainer:create_backup()
    local timestamp = os.date("%Y-%m-%d_%H-%M")
    
    for _, db_name in ipairs({"docs.db", "tree.db"}) do
        local source = path_join(DB_DIR, db_name)
        if file_exists(source) then
            local backup_name = timestamp .. "_" .. db_name .. ".bak"
            local backup_path = path_join(BACKUP_DIR, backup_name)
            
            -- Kopiere Datei
            local src = io.open(source, "rb")
            local dst = io.open(backup_path, "wb")
            if src and dst then
                local content = src:read("*all")
                dst:write(content)
                src:close()
                dst:close()
                self.logger:info("Backup erstellt: " .. backup_name)
            end
        end
    end
    
    return timestamp
end

function DatabaseMaintainer:cleanup_old_backups()
    local cutoff = os.time() - (self.retention_days * 24 * 60 * 60)
    local deleted = 0
    
    for _, db_name in ipairs({"docs.db", "tree.db"}) do
        -- Finde alle Backup-Dateien
        local pattern = "*_" .. db_name .. ".bak"
        local files = {}
        
        -- Liste alle Dateien im Backup-Verzeichnis auf
        for file in lfs.dir(BACKUP_DIR) do
            if string.match(file, pattern) then
                local filepath = path_join(BACKUP_DIR, file)
                local attr = lfs.attributes(filepath)
                if attr and attr.mode == "file" then
                    table.insert(files, {name = file, path = filepath, modification = attr.modification})
                end
            end
        end
        
        -- Sortiere nach Modifikationszeit
        table.sort(files, function(a, b) return a.modification < b.modification end)
        
        -- Lösche alte Dateien
        for _, file_info in ipairs(files) do
            -- Extrahiere Datum aus Filename (Format: YYYY-MM-DD_HH-MM)
            local date_part = file_info.name:match("^(.-)_")
            if date_part then
                local year, month, day = date_part:match("(%d+)%-(%d+)%-(%d+)")
                if year and month and day then
                    local file_time = file_info.modification
                    if file_time < cutoff then
                        os.remove(file_info.path)
                        deleted = deleted + 1
                        self.logger:info("Altes Backup gelöscht: " .. file_info.name)
                    end
                end
            end
        end
    end
    
    if deleted == 0 then
        self.logger:info("Keine alten Backups zum Löschen")
    else
        self.logger:info(deleted .. " alte Backups gelöscht (< 3 Tage)")
    end
end

function DatabaseMaintainer:run_cycle()
    self.logger:info("=" .. string.rep("=", 58))
    self.logger:info("DB MAINTAINER CYCLE START")
    self.logger:info("=" .. string.rep("=", 58))
    
    local state = self:load_state()
    
    -- 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    self.logger:info("Führe tree -a -L 8 aus...")
    local tree_output = self:run_tree_command()
    if tree_output then
        self:update_tree_file(tree_output)
        state.last_tree_update = os.date("%Y-%m-%dT%H:%M:%S")
    end
    
    -- 2. tree.db aktualisieren (intern v2)
    self.logger:info("Aktualisiere tree.db v2...")
    self:update_tree_db_v2()
    
    -- 3. Änderungen prüfen
    self.logger:info("Prüfe auf Dokumentations-Änderungen...")
    local changes, current_hashes = self:check_for_changes()
    
    if #changes > 0 then
        self.logger:info(#changes .. " Änderungen gefunden:")
        for i, change in ipairs(changes) do
            if i <= 10 then
                self.logger:info("  - " .. change)
            end
        end
        if #changes > 10 then
            self.logger:info("  ... und " .. (#changes - 10) .. " weitere")
        end
        
        -- 4. docs.db aktualisieren
        self.logger:info("Aktualisiere docs.db...")
        if self:update_databases() then
            state.last_check = os.date("%Y-%m-%dT%H:%M:%S")
            state.file_hashes = current_hashes
        end
    else
        self.logger:info("Keine Dokumentations-Änderungen gefunden")
    end
    
    -- 5. Prüfe ob Backup fällig (stündlich)
    local last_backup = state.last_backup
    local do_backup = false
    
    if last_backup then
        -- Parse das Datum aus dem ISO-String
        local year, month, day, hour, min, sec = last_backup:match("(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
        if year and month and day and hour and min and sec then
            local last_backup_time = os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day), 
                                              hour=tonumber(hour), min=tonumber(min), sec=tonumber(sec)})
            local current_time = os.time()
            do_backup = (current_time - last_backup_time) >= 3600  -- 1 Stunde in Sekunden
        else
            do_backup = true
        end
    else
        do_backup = true
    end
    
    if do_backup then
        self.logger:info("Erstelle stündliches Backup...")
        local timestamp = self:create_backup()
        state.last_backup = os.date("%Y-%m-%dT%H:%M:%S")
        
        -- 6. Alte Backups aufräumen (3 Tage Retention)
        self.logger:info("Räume alte Backups auf (3 Tage Retention)...")
        self:cleanup_old_backups()
    else
        self.logger:info("Backup nicht nötig (letztes < 1h)")
    end
    
    self:save_state(state)
    
    self.logger:info("=" .. string.rep("=", 58))
    self.logger:info("DB MAINTAINER CYCLE END")
    self.logger:info("=" .. string.rep("=", 58))
end

-- Hauptfunktion
local function main()
    local maintainer = DatabaseMaintainer:new()
    
    local success, err = pcall(function()
        maintainer:run_cycle()
    end)
    
    if not success then
        maintainer.logger:error("CRITICAL ERROR: " .. tostring(err))
        os.exit(1)
    end
end

-- Starte das Programm wenn direkt aufgerufen
if arg and #arg == 0 then
    main()
end
