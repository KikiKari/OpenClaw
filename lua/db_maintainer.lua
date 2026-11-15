#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "6c556d165890fe2828b00b1344efec1b75e53a3aa1c0b3a45381b6e7945a7f62", "source_sha256": "3ee904e4ee842489bd9bef8522f5a93fc06583e6cb1c3c5243afae19a4e2ed5f", "target_language": "lua"}
-- db_maintainer.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[
Database Maintainer Sub-Agent
Automated database maintenance with 30min checks, hourly backups (3 days retention),
band tree command execution for important/openclaw-tree.txt
]]

local sqlite3 = require("lsqlite3")
local posix = require("posix")

-- Hilfsfunktionen für Dateioperationen
local function mkdir_p(path)
    local success, err = posix.mkdir(path, "p")
    if not success and err ~= "EEXIST" then
        return nil, err
    end
    return true
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function read_file(path)
    local f, err = io.open(path, "r")
    if not f then return nil, err end
    local content = f:read("*all")
    f:close()
    return content
end

local function write_file(path, content)
    local f, err = io.open(path, "w")
    if not f then return nil, err end
    f:write(content)
    f:close()
    return true
end

local function copy_file(src, dst)
    local src_f, err = io.open(src, "rb")
    if not src_f then return nil, err end
    
    local dst_f, err = io.open(dst, "wb")
    if not dst_f then 
        src_f:close()
        return nil, err 
    end
    
    local data = src_f:read("*all")
    dst_f:write(data)
    
    src_f:close()
    dst_f:close()
    return true
end

-- Glob-Funktion für Lua
local function glob(pattern)
    local files = {}
    local handle = io.popen("find " .. pattern .. " -type f 2>/dev/null")
    if handle then
        for file in handle:lines() do
            table.insert(files, file)
        end
        handle:close()
    end
    return files
end

-- MD5-Funktion (vereinfacht)
local function md5(str)
    -- In echter Implementierung würde man eine echte MD5-Bibliothek verwenden
    -- Hier verwenden wir eine einfache Hash-Funktion zur Demonstration
    local hash = 0
    for i = 1, #str do
        hash = bit32.band(hash + string.byte(str, i), 0xFFFFFFFF)
    end
    return string.format("%08x", hash)
end

local function file_md5(filepath)
    local f, err = io.open(filepath, "rb")
    if not f then return nil, err end
    local content = f:read("*all")
    f:close()
    return md5(content)
end

local WORKSPACE = "/home/openclaw/.openclaw/workspace"
local DB_DIR = WORKSPACE .. "/db"
local BACKUP_DIR = DB_DIR .. "/backups"
local LOG_DIR = WORKSPACE .. "/logs/db-maintainer"
local IMPORTANT_DIR = WORKSPACE .. "/important"

-- Verzeichnisse erstellen
mkdir_p(BACKUP_DIR)
mkdir_p(LOG_DIR)

local Logger = {}
Logger.__index = Logger

function Logger:new()
    local obj = {
        log_file = LOG_DIR .. "/" .. os.date('%Y-%m-%d') .. ".log"
    }
    setmetatable(obj, Logger)
    return obj
end

function Logger:log(level, message)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local line = string.format("[%s] [%s] %s", timestamp, level, message)
    print(line)
    
    local f, err = io.open(self.log_file, 'a')
    if f then
        f:write(line .. '\n')
        f:close()
    end
end

function Logger:info(msg) self:log('INFO', msg) end
function Logger:warn(msg) self:log('WARN', msg) end
function Logger:error(msg) self:log('ERROR', msg) end

local DatabaseMaintainer = {}
DatabaseMaintainer.__index = DatabaseMaintainer

function DatabaseMaintainer:new()
    local obj = {
        logger = Logger:new(),
        state_file = DB_DIR .. "/maintainer_state.json",
        retention_days = 3
    }
    setmetatable(obj, DatabaseMaintainer)
    return obj
end

function DatabaseMaintainer:load_state()
    if file_exists(self.state_file) then
        local content, err = read_file(self.state_file)
        if content then
            local state = {}
            -- Einfacher JSON-Parser für dieses spezielle Format
            content = string.gsub(content, "%s+", "")
            content = string.gsub(content, "\"([^\"]+)\"", function(s) return s end)
            content = string.gsub(content, "{(.*)}", function(s)
                for k, v in string.gmatch(s, "([^:]+):([^,}]*)") do
                    state[k] = v
                end
                return ""
            end)
            return state
        end
    end
    return {last_check = nil, last_backup = nil, last_tree_update = nil, file_hashes = {}}
end

function DatabaseMaintainer:save_state(state)
    local content = "{\n"
    for k, v in pairs(state) do
        if type(v) == "table" then
            content = content .. "  \"" .. k .. "\": {\n"
            for hk, hv in pairs(v) do
                content = content .. "    \"" .. hk .. "\": \"" .. tostring(hv) .. "\",\n"
            end
            content = content .. "  },\n"
        else
            content = content .. "  \"" .. k .. "\": \"" .. tostring(v) .. "\",\n"
        end
    end
    content = content .. "}\n"
    
    local success, err = write_file(self.state_file, content)
    if not success then
        self.logger:error("Failed to save state: " .. err)
    end
end

function DatabaseMaintainer:get_file_hash(filepath)
    local hash, err = file_md5(filepath)
    if not hash then
        self.logger:warn("Could not calculate hash for " .. filepath .. ": " .. tostring(err))
        return nil
    end
    return hash
end

function DatabaseMaintainer:run_tree_command()
    local cmd = "tree -a -L 8 " .. WORKSPACE
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then
        self.logger:error("Failed to execute tree command")
        return nil
    end
    
    local result = handle:read("*all")
    local success, _, code = handle:close()
    
    if success and code == 0 then
        self.logger:info("tree -a -L 8 executed successfully")
        return result
    else
        self.logger:error("tree command failed")
        return nil
    end
end

function DatabaseMaintainer:update_tree_file(tree_output)
    if not tree_output then
        return false
    end
    
    local tree_file = IMPORTANT_DIR .. "/openclaw-tree.txt"
    local header = "# OpenClaw Workspace Tree\n" ..
                   "# Generated: " .. os.date('%Y-%m-%dT%H:%M:%S') .. "\n" ..
                   "# Command: tree -a -L 8 " .. WORKSPACE .. "\n" ..
                   "# This file is automatically updated by db-maintainer\n\n"
    
    local success, err = write_file(tree_file, header .. tree_output)
    if success then
        self.logger:info("openclaw-tree.txt updated: " .. tree_file)
        return true
    else
        self.logger:error("Failed to write openclaw-tree.txt: " .. err)
        return false
    end
end

function DatabaseMaintainer:scan_documentations()
    local docs = {}
    
    -- Suche nach .md Dateien
    local patterns = {WORKSPACE .. "/*.md", WORKSPACE .. "/**/*.md"}
    for _, pattern in ipairs(patterns) do
        local files = glob(pattern)
        for _, filepath in ipairs(files) do
            -- Prüfe ob Datei gültig ist
            if not string.find(filepath, "db/backups") and not string.find(filepath, "node_modules") then
                local stat = posix.stat(filepath)
                if stat and stat.type == "regular" then
                    local rel_path = string.gsub(filepath, WORKSPACE .. "/", "")
                    table.insert(docs, {
                        path = rel_path,
                        hash = self:get_file_hash(filepath),
                        mtime = stat.mtime
                    })
                end
            end
        end
    end
    
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
        
        if not state.file_hashes or not state.file_hashes[path] then
            table.insert(changes, "NEW: " .. path)
        elseif state.file_hashes[path] ~= doc.hash then
            table.insert(changes, "CHANGED: " .. path)
        end
    end
    
    -- Prüfe auf gelöschte Dateien
    if state.file_hashes then
        for old_path, _ in pairs(state.file_hashes) do
            if not current_hashes[old_path] then
                table.insert(changes, "DELETED: " .. old_path)
            end
        end
    end
    
    return changes, current_hashes
end

function DatabaseMaintainer:update_databases()
    local cmd = "python3 " .. WORKSPACE .. "/scripts/update_docs_db.py"
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then
        self.logger:error("Failed to execute DB update script")
        return false
    end
    
    local result = handle:read("*all")
    local success, _, code = handle:close()
    
    if success and code == 0 then
        self.logger:info("docs.db updated")
        return true
    else
        self.logger:error("DB update failed")
        return false
    end
end

function DatabaseMaintainer:update_tree_db_v2()
    local cmd = "python3 " .. WORKSPACE .. "/scripts/tree_indexer_v2.py"
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then
        self.logger:error("Failed to execute tree indexer script")
        return false
    end
    
    local result = handle:read("*all")
    local success, _, code = handle:close()
    
    if success and code == 0 then
        self.logger:info("tree.db v2 updated")
        return true
    else
        self.logger:error("Tree-DB v2 failed")
        return false
    end
end

function DatabaseMaintainer:create_backup()
    local timestamp = os.date('%Y-%m-%d_%H-%M')
    
    for _, db_name in ipairs({"docs.db", "tree.db"}) do
        local source = DB_DIR .. "/" .. db_name
        if file_exists(source) then
            local backup_name = timestamp .. "_" .. db_name .. ".bak"
            local backup_path = BACKUP_DIR .. "/" .. backup_name
            local success, err = copy_file(source, backup_path)
            if success then
                self.logger:info("Backup created: " .. backup_name)
            else
                self.logger:error("Failed to create backup: " .. err)
            end
        end
    end
    
    return timestamp
end

function DatabaseMaintainer:cleanup_old_backups()
    local cutoff = os.time() - (self.retention_days * 24 * 60 * 60)
    local deleted = 0
    
    for _, db_name in ipairs({"docs.db", "tree.db"}) do
        local pattern = BACKUP_DIR .. "/*_" .. db_name .. ".bak"
        local files = glob(pattern)
        
        for _, backup in ipairs(files) do
            -- Extrahiere Datum aus Filename
            local filename = string.match(backup, "([^/]+)$")
            local date_part, time_part = string.match(filename, "([^_]+)_([^_]+)")
            if date_part and time_part then
                local year, month, day = string.match(date_part, "(%d+)%-(%d+)%-(%d+)")
                local hour, min = string.match(time_part, "(%d+)%-(%d+)")
                
                if year and month and day and hour and min then
                    local backup_time = os.time({year=tonumber(year), month=tonumber(month), 
                                                day=tonumber(day), hour=tonumber(hour), 
                                                min=tonumber(min)})
                    
                    if backup_time < cutoff then
                        local success, err = os.remove(backup)
                        if success then
                            deleted = deleted + 1
                            self.logger:info("Deleted old backup: " .. filename)
                        else
                            self.logger:warn("Failed to delete backup: " .. tostring(err))
                        end
                    end
                end
            end
        end
    end
    
    if deleted == 0 then
        self.logger:info("No old backups to delete")
    else
        self.logger:info(deleted .. " old backups deleted (< 3 days)")
    end
end

function DatabaseMaintainer:run_cycle()
    self.logger:info(string.rep("=", 60))
    self.logger:info("DB MAINTAINER CYCLE START")
    self.logger:info(string.rep("=", 60))
    
    local state = self:load_state()
    
    -- 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    self.logger:info("Executing tree -a -L 8...")
    local tree_output = self:run_tree_command()
    if tree_output then
        self:update_tree_file(tree_output)
        state.last_tree_update = os.date('%Y-%m-%dT%H:%M:%S')
    end
    
    -- 2. tree.db aktualisieren (intern v2)
    self.logger:info("Updating tree.db v2...")
    self:update_tree_db_v2()
    
    -- 3. Änderungen prüfen
    self.logger:info("Checking for documentation changes...")
    local changes, current_hashes = self:check_for_changes()
    
    if #changes > 0 then
        self.logger:info(#changes .. " changes found:")
        for i = 1, math.min(10, #changes) do
            self.logger:info("  - " .. changes[i])
        end
        if #changes > 10 then
            self.logger:info("  ... and " .. (#changes-10) .. " more")
        end
        
        -- 4. docs.db aktualisieren
        self.logger:info("Updating docs.db...")
        if self:update_databases() then
            state.last_check = os.date('%Y-%m-%dT%H:%M:%S')
            state.file_hashes = current_hashes
        end
    else
        self.logger:info("No documentation changes found")
    end
    
    -- 5. Prüfe ob Backup fällig (stündlich)
    local do_backup = true
    if state.last_backup then
        local last_backup_time = os.time(state.last_backup)
        do_backup = os.difftime(os.time(), last_backup_time) >= 3600  -- 1 Stunde
    end
    
    if do_backup then
        self.logger:info("Creating hourly backup...")
        local timestamp = self:create_backup()
        state.last_backup = os.date('%Y-%m-%dT%H:%M:%S')
        
        -- 6. Alte Backups aufräumen (3 Tage Retention)
        self.logger:info("Cleaning up old backups (3 days retention)...")
        self:cleanup_old_backups()
    else
        self.logger:info("Backup not needed (last < 1h)")
    end
    
    self:save_state(state)
    
    self.logger:info(string.rep("=", 60))
    self.logger:info("DB MAINTAINER CYCLE END")
    self.logger:info(string.rep("=", 60))
end

function main()
    local maintainer = DatabaseMaintainer:new()
    
    local success, err = pcall(function()
        maintainer:run_cycle()
    end)
    
    if not success then
        maintainer.logger:error("CRITICAL ERROR: " .. tostring(err))
        os.exit(1)
    end
end

main()
