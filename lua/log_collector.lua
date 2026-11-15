#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "0be162b9f2a634af3c50cc777435cc62e54f3689547a1e821416a1f1ef1ba6ce", "source_sha256": "5081f9f0745ca8b2223c2de657aa97d48e58ccf61c24467e46c9d562803e34a6", "target_language": "lua"}
-- log_collector.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/log-collector/scripts/log_collector.py
-- auch in: OpenClaw@gateway2:skills/log-collector/scripts/log_collector.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[
Log Collector Sub-Agent
Sammelt Logs von allen Nodes via SSH/VPN alle 3 Stunden
]]

local sqlite3 = require("lsqlite3")
local posix = require("posix")

-- Hilfsfunktionen fuer Pfade und Zeit
local function join_paths(...)
    local args = {...}
    return table.concat(args, "/")
end

local function current_date()
    return os.date("%Y-%m-%d")
end

local function current_datetime_iso()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function datetime_now()
    return os.time()
end

local function datetime_from_string(str)
    local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
    local year, month, day, hour, min, sec = str:match(pattern)
    return os.time({year=year, month=month, day=day, hour=hour, min=min, sec=sec})
end

local function datetime_add_days(timestamp, days)
    return timestamp + (days * 24 * 60 * 60)
end

local HOME = os.getenv("HOME") or "/tmp"
local WORKSPACE = join_paths(HOME, ".openclaw/workspace")
local DB_PATH = join_paths(WORKSPACE, "db", "logs.db")
local LOG_DIR = join_paths(WORKSPACE, "logs", "log-collector")

-- Stelle sicher dass LOG_DIR existiert
posix.mkdir(LOG_DIR, true)

-- Logger Klasse
local Logger = {}
Logger.__index = Logger

function Logger:new()
    local obj = {
        log_file = join_paths(LOG_DIR, current_date() .. ".log")
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


-- LogCollector Hauptklasse
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
    
    -- Setze Row Factory Ersatz (manuelle Konvertierung)
    self:_init_schema()
    return self.conn
end

function LogCollector:_init_schema()
    -- Pruefe ob Tabellen existieren
    local stmt = self.conn:prepare("SELECT name FROM sqlite_master WHERE type='table'")
    local has_tables = false
    for row in stmt:nrows() do
        has_tables = true
        break
    end
    
    if not has_tables then
        local schema_path = join_paths(WORKSPACE, "db", "logs.db.schema.sql")
        local file = io.open(schema_path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            self.conn:exec(content)
        end
    end
end

function LogCollector:get_nodes()
    local nodes = {}
    local stmt = self.conn:prepare("SELECT * FROM nodes")
    for row in stmt:nrows() do
        table.insert(nodes, row)
    end
    return nodes
end

function LogCollector:check_vpn(ip)
    local command = {"ping", "-c", "1", "-W", "3", ip}
    local _, exit_code = self:_run_command(command, 10)
    return exit_code == 0
end

function LogCollector:_run_command(cmd_array, timeout)
    -- Fuehre Kommando als String aus
    local cmd_str = table.concat(cmd_array, " ")
    local handle = io.popen(cmd_str)
    if not handle then return "", 1 end
    
    local output = handle:read("*a")
    local success, _, exit_code = handle:close()
    
    if not success then
        exit_code = 1
    end
    
    return output, exit_code
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
    
    for _, cmd in ipairs(log_commands) do
        local full_cmd = {"ssh", "-o", "ConnectTimeout=10", "-o", "StrictHostKeyChecking=no",
                         "openclaw@" .. vpn_ip, cmd}
        
        -- Simuliere Timeout mit pcall und timer (vereinfacht)
        local output, exit_code = self:_run_command(full_cmd, 30)
        
        if exit_code == 0 then
            table.insert(logs_collected, {
                command = cmd,
                output = output,
                timestamp = current_datetime_iso()
            })
        end
    end
    
    -- Erfolg loggen
    self:_log_ssh_connection(node_id, 'ssh', true, nil)
    
    -- In DB speichern
    self:_insert_logs(node_id, logs_collected)
    
    return #logs_collected
end

function LogCollector:_log_ssh_connection(node_id, conn_type, success, error)
    local stmt = self.conn:prepare([[
        INSERT INTO ssh_connections (node_id, connection_type, success, error_message)
        VALUES (?, ?, ?, ?)
    ]])
    stmt:bind_values(node_id, conn_type, success and 1 or 0, error)
    stmt:step()
    stmt:reset()
    self.conn:exec("COMMIT")
end

function LogCollector:_insert_logs(node_id, logs)
    local stmt = self.conn:prepare([[
        INSERT INTO logs (node_id, log_type, source, content, severity, 
                        collected_by, collection_method, retention_until)
        VALUES (?, 'system', ?, ?, 'info', ?, 'ssh', ?)
    ]])
    
    local retention_timestamp = datetime_add_days(datetime_now(), 30)
    local retention_iso = os.date("!%Y-%m-%dT%H:%M:%SZ", retention_timestamp)
    
    for _, log_entry in ipairs(logs) do
        local source = string.sub(log_entry.command, 1, 50)
        local content = string.sub(log_entry.output, 1, 10000)  -- Limit 10KB
        stmt:bind_values(node_id, source, content, 'node1', retention_iso)
        stmt:step()
        stmt:reset()
    end
    
    self.conn:exec("COMMIT")
    self.logger:info(string.format("%s: %d Log-Einträge gespeichert", node_id, #logs))
end

function LogCollector:cleanup_retention()
    local stmt = self.conn:prepare([[
        DELETE FROM logs WHERE retention_until < datetime('now')
    ]])
    stmt:step()
    local deleted = self.conn:changes()
    stmt:reset()
    self.conn:exec("COMMIT")
    self.logger:info("Retention-Cleanup: " .. deleted .. " alte Logs gelöscht")
    return deleted
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
    local insert_stmt = self.conn:prepare([[
        INSERT INTO collection_runs (started_at, nodes_total)
        VALUES (CURRENT_TIMESTAMP, ?)
    ]])
    insert_stmt:bind_values(#nodes)
    insert_stmt:step()
    insert_stmt:reset()
    local run_id = self.conn:last_insert_rowid()
    self.conn:exec("COMMIT")
    
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
            finished_at = CURRENT_TIMESTAMP,
            nodes_success = ?,
            nodes_failed = ?,
            logs_collected = ?
        WHERE run_id = ?
    ]])
    update_stmt:bind_values(success_count, failed_count, total_logs, run_id)
    update_stmt:step()
    update_stmt:reset()
    self.conn:exec("COMMIT")
    
    -- 5. Retention-Cleanup
    self.logger:info("Retention-Cleanup (30 Tage)...")
    self:cleanup_retention()
    
    self.logger:info(string.rep("=", 60))
    self.logger:info(string.format("SUMMARY: %d OK, %d Failed, %d Logs", success_count, failed_count, total_logs))
    self.logger:info(string.rep("=", 60))
end


-- Hauptprogramm
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
        -- Stacktrace ist in Lua schwer zu emulieren ohne debug.traceback
        os.exit(1)
    end
end

main()
