#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "1904d5cd8c5549c397419a62ae59f94b4f9ed0c275555153b94103cb1b85ef97", "source_sha256": "5081f9f0745ca8b2223c2de657aa97d48e58ccf61c24467e46c9d562803e34a6", "target_language": "lua"}
-- log_collector.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
-- auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
Log Collector Sub-Agent
Sammelt Logs von allen Nodes via SSH/VPN alle 3 Stunden
]]

local sqlite3 = require("lsqlite3")
local posix = require("posix")

-- Hilfsfunktionen fuer Pfade und Zeit
local function join_paths(...)
    local parts = {...}
    return table.concat(parts, "/")
end

local function current_date()
    return os.date("%Y-%m-%d")
end

local function current_datetime_iso()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function format_datetime(t)
    if type(t) == "number" then
        return os.date("!%Y-%m-%dT%H:%M:%SZ", t)
    end
    return tostring(t)
end

-- Konfiguration
local HOME = os.getenv("HOME") or "/tmp"
local WORKSPACE = join_paths(HOME, ".openclaw/workspace")
local DB_PATH = join_paths(WORKSPACE, "db", "logs.db")
local LOG_DIR = join_paths(WORKSPACE, "logs", "log-collector")

-- Sicherstellen dass LOG_DIR existiert
posix.mkdir(join_paths(HOME, ".openclaw"))
posix.mkdir(join_paths(HOME, ".openclaw", "workspace"))
posix.mkdir(join_paths(WORKSPACE, "db"))
posix.mkdir(join_paths(WORKSPACE, "logs"))
posix.mkdir(LOG_DIR)

-- Logger Klasse
local Logger = {}
Logger.__index = Logger

function Logger:new()
    local today = current_date()
    local log_file = join_paths(LOG_DIR, today .. ".log")
    
    local obj = {
        log_file = log_file
    }
    setmetatable(obj, Logger)
    return obj
end

function Logger:log(level, msg)
    local ts = current_datetime_iso()
    local line = string.format("[%s] [%s] %s", ts, level, msg)
    print(line)
    
    local file = io.open(self.log_file, "a")
    if file then
        file:write(line .. "\n")
        file:close()
    end
end

function Logger:info(msg) self:log('INFO', msg) end
function Logger:error(msg) self:log('ERROR', msg) end


-- LogCollector Klasse
local LogCollector = {}
LogCollector.__index = LogCollector

function LogCollector:new()
    local obj = {
        logger = Logger:new(),
        conn = nil
    }
    setmetatable(obj, LogCollector)
    return obj
end

function LogCollector:connect_db()
    self.conn = sqlite3.open(DB_PATH)
    -- Row factory aehnlich wie in Python
    self:_init_schema()
    return self.conn
end

function LogCollector:_init_schema()
    -- Pruefen ob Tabellen existieren
    local exists = false
    for row in self.conn:nrows("SELECT name FROM sqlite_master WHERE type='table' LIMIT 1") do
        exists = true
        break
    end
    
    if not exists then
        local schema_path = join_paths(WORKSPACE, "db", "logs.db.schema.sql")
        local file = io.open(schema_path, "r")
        if file then
            local schema_sql = file:read("*all")
            file:close()
            self.conn:exec(schema_sql)
        end
    end
end

function LogCollector:get_nodes()
    local nodes = {}
    for row in self.conn:nrows("SELECT * FROM nodes") do
        table.insert(nodes, row)
    end
    return nodes
end

function LogCollector:check_vpn(ip)
    local handle = io.popen(string.format("ping -c 1 -W 3 %s 2>/dev/null", ip))
    if handle then
        local result = handle:close()
        return result ~= nil
    end
    return false
end

function LogCollector:ssh_connect_and_collect(node)
    local node_id = node.node_id
    local vpn_ip = node.vpn_ip or node.tailscale_ip or node.wireguard_ip
    
    if not vpn_ip then
        self.logger:error(node_id .. ": Keine VPN-IP konfiguriert")
        return nil
    end
    
    -- 1. VPN-Check
    self.logger:info(node_id .. ": Pruefe VPN " .. vpn_ip .. "...")
    if not self:check_vpn(vpn_ip) then
        self.logger:error(node_id .. ": VPN nicht erreichbar")
        self:_log_ssh_connection(node_id, 'tailscale', false, 'VPN unreachable')
        return nil
    end
    
    -- 2. SSH-Verbindung
    self.logger:info(node_id .. ": Verbinde via SSH...")
    
    local log_commands = {
        "journalctl -n 500 --no-pager",
        "tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'",
        "tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'"
    }
    
    local logs_collected = {}
    local success = true
    
    for _, cmd in ipairs(log_commands) do
        local full_cmd = string.format("ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no openclaw@%s '%s'", vpn_ip, cmd)
        local handle = io.popen(full_cmd, "r")
        if handle then
            local output = handle:read("*all")
            local ok, _, code = handle:close()
            
            if ok and code == 0 then
                table.insert(logs_collected, {
                    command = cmd,
                    output = output,
                    timestamp = current_datetime_iso()
                })
            end
        else
            success = false
        end
    end
    
    if success then
        -- Erfolg loggen
        self:_log_ssh_connection(node_id, 'ssh', true, nil)
        
        -- In DB speichern
        self:_insert_logs(node_id, logs_collected)
        
        return #logs_collected
    else
        self.logger:error(node_id .. ": SSH Fehler bei Verbindung")
        self:_log_ssh_connection(node_id, 'ssh', false, 'SSH command failed')
        return nil
    end
end

function LogCollector:_log_ssh_connection(node_id, conn_type, success, error_msg)
    local stmt = self.conn:prepare([[
        INSERT INTO ssh_connections (node_id, connection_type, success, error_message)
        VALUES (?, ?, ?, ?)
    ]])
    if stmt then
        stmt:bind_values(node_id, conn_type, success and 1 or 0, error_msg)
        stmt:step()
        stmt:reset()
    end
end

function LogCollector:_insert_logs(node_id, logs)
    local retention = os.time() + (30 * 24 * 60 * 60) -- 30 Tage in Sekunden
    
    for _, log_entry in ipairs(logs) do
        local stmt = self.conn:prepare([[
            INSERT INTO logs (node_id, log_type, source, content, severity, 
                            collected_by, collection_method, retention_until)
            VALUES (?, 'system', ?, ?, 'info', ?, 'ssh', ?)
        ]])
        if stmt then
            -- Begrenzen der Laenge der Felder
            local source = string.sub(log_entry.command, 1, 50)
            local content = string.sub(log_entry.output, 1, 10000)
            
            stmt:bind_values(
                node_id,
                source,
                content,
                'node1',
                format_datetime(retention)
            )
            stmt:step()
            stmt:reset()
        end
    end
    
    self.conn:exec("COMMIT")
    self.logger:info(node_id .. ": " .. #logs .. " Log-Eintraege gespeichert")
end

function LogCollector:cleanup_retention()
    local stmt = self.conn:prepare([[
        DELETE FROM logs WHERE retention_until < datetime('now')
    ]])
    if stmt then
        stmt:step()
        local deleted = self.conn:changes()
        stmt:reset()
        self.logger:info("Retention-Cleanup: " .. deleted .. " alte Logs geloescht")
        return deleted
    end
    return 0
end

function LogCollector:run_collection_cycle()
    self.logger:info(string.rep("=", 60))
    self.logger:info("LOG COLLECTOR CYCLE START")
    self.logger:info(string.rep("=", 60))
    
    self:connect_db()
    
    -- 1. Nodes holen
    local nodes = self:get_nodes()
    self.logger:info("Gefunden: " .. #nodes .. " Nodes")
    
    -- 2. Collection-Run starten
    local stmt = self.conn:prepare([[
        INSERT INTO collection_runs (started_at, nodes_total)
        VALUES (datetime('now'), ?)
    ]])
    local run_id
    if stmt then
        stmt:bind_values(#nodes)
        stmt:step()
        run_id = self.conn:last_insert_rowid()
        stmt:reset()
    end
    
    -- 3. Fuer jeden Node sammeln
    local success_count = 0
    local failed_count = 0
    local total_logs = 0
    
    for _, node in ipairs(nodes) do
        if node.node_id == 'node1' then
            -- Lokale Logs (Gateway selbst)
            self.logger:info("node1: Lokale Collection (Gateway)")
            success_count = success_count + 1
        else
            -- Remote-Node abfragen
            local result = self:ssh_connect_and_collect(node)
            if result ~= nil then
                success_count = success_count + 1
                total_logs = total_logs + result
            else
                failed_count = failed_count + 1
            end
        end
    end
    
    -- 4. Run abschliessen
    local update_stmt = self.conn:prepare([[
        UPDATE collection_runs SET
            finished_at = datetime('now'),
            nodes_success = ?,
            nodes_failed = ?,
            logs_collected = ?
        WHERE run_id = ?
    ]])
    if update_stmt then
        update_stmt:bind_values(success_count, failed_count, total_logs, run_id)
        update_stmt:step()
        update_stmt:reset()
    end
    
    -- 5. Retention-Cleanup
    self.logger:info("Retention-Cleanup (30 Tage)...")
    self:cleanup_retention()
    
    self.logger:info(string.rep("=", 60))
    self.logger:info(string.format("SUMMARY: %d OK, %d Failed, %d Logs", success_count, failed_count, total_logs))
    self.logger:info(string.rep("=", 60))
end


-- Hauptfunktion
function main()
    print(string.rep("=", 60))
    print("LOG COLLECTOR")
    print(string.rep("=", 60))
    
    local collector = LogCollector:new()
    
    local status, err = pcall(function()
        collector:run_collection_cycle()
    end)
    
    if not status then
        print("CRITICAL ERROR: " .. tostring(err))
        os.exit(1)
    end
end


main()
