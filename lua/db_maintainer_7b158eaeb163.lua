#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "98351e70026cf0a95fdd2f7f77b175b4358afa8fc28a79524e5a9e6b87f59929", "source_sha256": "3ee904e4ee842489bd9bef8522f5a93fc06583e6cb1c3c5243afae19a4e2ed5f", "target_language": "lua"}
-- db_maintainer.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/db_maintainer.py
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

--[[
Database Maintainer Sub-Agent
Automated database maintenance with 30min checks, hourly backups (3 days retention),
band tree command execution for important/openclaw-tree.txt
]]

local sqlite3 = require("lsqlite3")
local json = require("cjson")
local posix = require("posix")

-- Hilfsfunktionen für Dateioperationen
local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function read_file(path)
    local f = io.open(path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        return content
    end
    return nil
end

local function write_file(path, content)
    local f = io.open(path, "w")
    if f then
        f:write(content)
        f:close()
        return true
    end
    return false
end

local function mkdir_p(path)
    -- Rekursives Erstellen von Verzeichnissen
    local dirs = {}
    local current = ""
    
    for dir in string.gmatch(path, "[^/]+") do
        current = current .. "/" .. dir
        table.insert(dirs, current)
    end
    
    for _, dir in ipairs(dirs) do
        posix.mkdir(dir, 511) -- 0777 in Oktal
    end
end

local function glob(pattern, base_dir)
    local results = {}
    local handle = io.popen("find " .. base_dir .. " -name '" .. pattern .. "'")
    if handle then
        for line in handle:lines() do
            table.insert(results, line)
        end
        handle:close()
    end
    return results
end

local function stat(path)
    local attrs = posix.stat(path)
    return attrs or {}
end

local function copy(src, dst)
    local src_f = io.open(src, "rb")
    if not src_f then return false end
    
    local dst_f = io.open(dst, "wb")
    if not dst_f then 
        src_f:close()
        return false 
    end
    
    local data = src_f:read("*all")
    dst_f:write(data)
    
    src_f:close()
    dst_f:close()
    return true
end

local function unlink(path)
    return os.remove(path)
end

local function strftime(format, time)
    return os.date(format, time)
end

local function strptime(date_str, format)
    -- Vereinfachte Implementierung für spezielle Formate
    if format == "%Y-%m-%d_%H-%M" then
        local year, month, day, hour, min = string.match(date_str, "(%d+)-(%d+)-(%d+)_(%d+)-(%d+)")
        if year and month and day and hour and min then
            return os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day), 
                           hour=tonumber(hour), min=tonumber(min), sec=0})
        end
    end
    return nil
end

local HOME = os.getenv("HOME") or "/tmp"
local WORKSPACE = HOME .. "/.openclaw/workspace"
local DB_DIR = WORKSPACE .. "/db"
local BACKUP_DIR = DB_DIR .. "/backups"
local LOG_DIR = HOME .. "/.openclaw/logs/db-maintainer"
local IMPORTANT_DIR = HOME .. "/.openclaw/important"

-- Verzeichnisse erstellen
mkdir_p(BACKUP_DIR)
mkdir_p(LOG_DIR)

-- Logger-Klasse
local Logger = {}
Logger.__index = Logger

function Logger:new()
    local obj = {
        log_file = LOG_DIR .. "/" .. strftime("%Y-%m-%d", os.time()) .. ".log"
    }
    setmetatable(obj, Logger)
    return obj
end

function Logger:log(level, message)
    local timestamp = strftime("%Y-%m-%d %H:%M:%S", os.time())
    local line = "[" .. timestamp .. "] [" .. level .. "] " .. message
    print(line)
    
    local f = io.open(self.log_file, "a")
    if f then
        f:write(line .. "\n")
        f:close()
    end
end

function Logger:info(msg) self:log("INFO", msg) end
function Logger:warn(msg) self:log("WARN", msg) end
function Logger:error(msg) self:log("ERROR", msg) end

-- DatabaseMaintainer-Klasse
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
        local content = read_file(self.state_file)
        if content then
            local ok, state = pcall(json.decode, content)
            if ok then
                return state
            end
        end
    end
    return {last_check = nil, last_backup = nil, last_tree_update = nil, file_hashes = {}}
end

function DatabaseMaintainer:save_state(state)
    local content = json.encode(state)
    write_file(self.state_file, content)
end

function DatabaseMaintainer:get_file_hash(filepath)
    local f = io.open(filepath, "rb")
    if not f then return nil end
    
    local md5 = require("openssl").digest.new("md5")
    while true do
        local block = f:read(8192)
        if not block then break end
        md5:update(block)
    end
    f:close()
    
    return md5:final(true) -- hex string
end

function DatabaseMaintainer:run_tree_command()
    local handle = io.popen("tree -a -L 8 " .. WORKSPACE .. " 2>/dev/null")
    if handle then
        local result = handle:read("*all")
        local success, _, code = handle:close()
        
        if success and code == 0 then
            self.logger:info("tree -a -L 8 erfolgreich ausgeführt")
            return result
        else
            self.logger:error("tree command fehlgeschlagen")
            return nil
        end
    else
        self.logger:error("tree command konnte nicht gestartet werden")
        return nil
    end
end

function DatabaseMaintainer:update_tree_file(tree_output)
    if not tree_output then
        return false
    end
    
    local tree_file = IMPORTANT_DIR .. "/openclaw-tree.txt"
    
    local header = "# OpenClaw Workspace Tree\n" ..
                   "# Generiert: " .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. "\n" ..
                   "# Befehl: tree -a -L 8 " .. WORKSPACE .. "\n" ..
                   "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
    
    if write_file(tree_file, header .. tree_output) then
        self.logger:info("openclaw-tree.txt aktualisiert: " .. tree_file)
        return true
    else
        self.logger:error("Fehler beim Schreiben von openclaw-tree.txt")
        return false
    end
end

function DatabaseMaintainer:scan_documentations()
    local docs = {}
    
    local function add_md_files(dir)
        local files = glob("*.md", dir)
        for _, file in ipairs(files) do
            local attrs = stat(file)
            if attrs and attrs.type == "regular" then
                local rel_path = string.gsub(file, "^" .. WORKSPACE .. "/", "")
                if not string.find(rel_path, "db/backups") and not string.find(rel_path, "node_modules") then
                    table.insert(docs, {
                        path = rel_path,
                        hash = self:get_file_hash(file),
                        mtime = attrs.mtime
                    })
                end
            end
        end
    end
    
    add_md_files(WORKSPACE)
    
    -- Rekursiv durch Unterverzeichnisse suchen
    local function scan_recursive(dir)
        local handle = io.popen("find " .. dir .. " -type d")
        if handle then
            for line in handle:lines() do
                if line ~= dir then
                    add_md_files(line)
                    scan_recursive(line)
                end
            end
            handle:close()
        end
    end
    
    scan_recursive(WORKSPACE)
    
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
    local handle = io.popen("cd " .. WORKSPACE .. " && python3 scripts/update_docs_db.py 2>&1")
    if handle then
        local output = handle:read("*all")
        local success, _, code = handle:close()
        
        if success and code == 0 then
            self.logger:info("docs.db aktualisiert")
            return true
        else
            self.logger:error("DB-Update fehlgeschlagen: " .. output)
            return false
        end
    else
        self.logger:error("DB-Update konnte nicht gestartet werden")
        return false
    end
end

function DatabaseMaintainer:update_tree_db_v2()
    local handle = io.popen("cd " .. WORKSPACE .. " && python3 scripts/tree_indexer_v2.py 2>&1")
    if handle then
        local output = handle:read("*all")
        local success, _, code = handle:close()
        
        if success and code == 0 then
            self.logger:info("tree.db v2 aktualisiert")
            return true
        else
            self.logger:error("Tree-DB v2 fehlgeschlagen: " .. output)
            return false
        end
    else
        self.logger:error("Tree-DB v2 konnte nicht gestartet werden")
        return false
    end
end

function DatabaseMaintainer:create_backup()
    local timestamp = strftime("%Y-%m-%d_%H-%M", os.time())
    
    for _, db_name in ipairs({"docs.db", "tree.db"}) do
        local source = DB_DIR .. "/" .. db_name
        if file_exists(source) then
            local backup_name = timestamp .. "_" .. db_name .. ".bak"
            local backup_path = BACKUP_DIR .. "/" .. backup_name
            if copy(source, backup_path) then
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
        local handle = io.popen("ls " .. BACKUP_DIR .. "/*_" .. db_name .. ".bak 2>/dev/null")
        if handle then
            for line in handle:lines() do
                local filename = string.match(line, "([^/]+)$")
                local parts = {}
                for part in string.gmatch(filename, "[^_]+") do
                    table.insert(parts, part)
                end
                
                if #parts >= 2 then
                    local date_part = parts[1]
                    local time_part = string.gsub(parts[2], "%.bak$", "")
                    local backup_time = strptime(date_part .. "_" .. time_part, "%Y-%m-%d_%H-%M")
                    
                    if backup_time and backup_time < cutoff then
                        if unlink(line) then
                            deleted = deleted + 1
                            self.logger:info("Altes Backup gelöscht: " .. filename)
                        end
                    end
                else
                    self.logger:warn("Konnte Backup-Datum nicht parsen: " .. filename)
                end
            end
            handle:close()
        end
    end
    
    if deleted == 0 then
        self.logger:info("Keine alten Backups zum Löschen")
    else
        self.logger:info(deleted .. " alte Backups gelöscht (< 3 Tage)")
    end
end

function DatabaseMaintainer:run_cycle()
    self.logger:info(string.rep("=", 60))
    self.logger:info("DB MAINTAINER CYCLE START")
    self.logger:info(string.rep("=", 60))
    
    local state = self:load_state()
    
    -- 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
    self.logger:info("Führe tree -a -L 8 aus...")
    local tree_output = self:run_tree_command()
    if tree_output then
        self:update_tree_file(tree_output)
        state.last_tree_update = os.date("!%Y-%m-%dT%H:%M:%SZ")
    end
    
    -- 2. tree.db aktualisieren (intern v2)
    self.logger:info("Aktualisiere tree.db v2...")
    self:update_tree_db_v2()
    
    -- 3. Änderungen prüfen
    self.logger:info("Prüfe auf Dokumentations-Änderungen...")
    local changes, current_hashes = self:check_for_changes()
    
    if #changes > 0 then
        self.logger:info(#changes .. " Änderungen gefunden:")
        for i = 1, math.min(10, #changes) do
            self.logger:info("  - " .. changes[i])
        end
        if #changes > 10 then
            self.logger:info("  ... und " .. (#changes - 10) .. " weitere")
        end
        
        -- 4. docs.db aktualisieren
        self.logger:info("Aktualisiere docs.db...")
        if self:update_databases() then
            state.last_check = os.date("!%Y-%m-%dT%H:%M:%SZ")
            state.file_hashes = current_hashes
        end
    else
        self.logger:info("Keine Dokumentations-Änderungen gefunden")
    end
    
    -- 5. Prüfe ob Backup fällig (stündlich)
    local last_backup = state.last_backup
    
    local do_backup
    if last_backup then
        local last_backup_time = os.time() - os.time(os.date("!*t", os.time())) + 
                                 os.time(os.date("*t", os.time())) - 
                                 (os.time() - os.time(os.date("!*t", os.time())))
        do_backup = os.time() - last_backup_time >= 3600
    else
        do_backup = true
    end
    
    if do_backup then
        self.logger:info("Erstelle stündliches Backup...")
        local timestamp = self:create_backup()
        state.last_backup = os.date("!%Y-%m-%dT%H:%M:%SZ")
        
        -- 6. Alte Backups aufräumen (3 Tage Retention)
        self.logger:info("Räume alte Backups auf (3 Tage Retention)...")
        self:cleanup_old_backups()
    else
        self.logger:info("Backup nicht nötig (letztes < 1h)")
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
