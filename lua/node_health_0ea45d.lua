#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "fb224aafcba2f1797c74b1d186ce987cc2c393482a2a55577e7c95860866d22d", "source_sha256": "0ea45de4496e55f73aa9b10188cc6a04921d74e1cadbe0ac04a948d0f2772243", "target_language": "lua"}
-- node_health.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[
Node Health Monitor - Multi-Node Gesundheitsüberwachung
]]

local socket = require("socket")
local json = require("cjson")
local lfs = require("lfs")

-- Konfiguration
local WORKSPACE = "/home/openclaw/.openclaw/workspace"
local HEALTH_DB = WORKSPACE .. "/db/health.db"
local LOG_FILE = WORKSPACE .. "/logs/node-health.log"

-- Node-Definitionen
local NODES = {
    node1 = {
        name = "Node 1",
        host = "localhost",
        user = "openclaw",
        critical = true
    },
    node2 = {
        name = "Node 2",
        host = "10.10.0.2",
        user = "root",
        ssh_key = "~/.ssh/id_rsa",
        ssh_opts = "-o ConnectTimeout=10 -o BatchMode=yes"
    },
    node3 = {
        name = "Node 3",
        host = "localhost",
        user = "root",
        port = 18794,
        ssh_opts = "-p 18794 -o ConnectTimeout=10 -o BatchMode=yes",
        disk_warning = 85
    },
    node5 = {
        name = "Redmi",
        host = "192.168.1.x",
        user = "openclaw",
        optional = true
    }
}

function log_message(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local entry = string.format("[%s] [%s] %s", timestamp, level, message)
    print(entry)
    
    -- Stelle sicher, dass das Log-Verzeichnis existiert
    local log_dir = string.match(LOG_FILE, "(.-)[^/]*$")
    local handle = io.popen("mkdir -p " .. log_dir)
    handle:close()
    
    local file = io.open(LOG_FILE, "a")
    if file then
        file:write(entry .. "\n")
        file:close()
    end
end

function check_ping(host, timeout)
    timeout = timeout or 10
    local cmd = string.format("ping -c 1 -W %d %s 2>/dev/null", timeout, host)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success, _, _ = handle:close()
    return success ~= nil
end

function check_ssh(node_config)
    local host = node_config.host
    local user = node_config.user or "root"
    local ssh_opts = node_config.ssh_opts or ""
    local port = node_config.port or ""
    
    local cmd_parts = {"ssh"}
    if ssh_opts ~= "" then
        for opt in string.gmatch(ssh_opts, "%S+") do
            table.insert(cmd_parts, opt)
        end
    end
    if port ~= "" then
        table.insert(cmd_parts, "-p")
        table.insert(cmd_parts, tostring(port))
    end
    table.insert(cmd_parts, "-o")
    table.insert(cmd_parts, "ConnectTimeout=10")
    table.insert(cmd_parts, "-o")
    table.insert(cmd_parts, "BatchMode=yes")
    table.insert(cmd_parts, string.format("%s@%s", user, host))
    table.insert(cmd_parts, "echo")
    table.insert(cmd_parts, "\"OK\"")
    
    local cmd = table.concat(cmd_parts, " ")
    local handle = io.popen(cmd .. " 2>/dev/null")
    local result = handle:read("*a")
    local success, _, _ = handle:close()
    return success ~= nil and string.find(result, "OK") ~= nil
end

function get_node_metrics(node_config)
    local host = node_config.host
    local user = node_config.user or "root"
    
    local metrics = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        available = false,
        cpu = nil,
        ram = nil,
        disk = nil,
        load = nil
    }
    
    -- SSH-Command für alle Metriken
    local cmd = string.format([[ssh -o ConnectTimeout=10 %s@%s '
        # CPU
        echo "CPU:$(top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%%" -f1)"
        
        # RAM
        echo "RAM:$(free | grep Mem | awk "{print (\$3/\$2) * 100.0}")"
        
        # Disk
        echo "DISK:$(df -h / | tail -1 | awk "{print \$5}" | tr -d "%%")"
        
        # Load
        echo "LOAD:$(uptime | awk -F"load average:" "{print \$2}" | awk "{print \$1}" | tr -d ",")"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
        fi
    ']], user, host)
    
    local handle, err = io.popen(cmd .. " 2>/dev/null")
    if not handle then
        log_message(string.format("Error executing SSH command for %s: %s", node_config.name, err), "ERROR")
        return metrics
    end
    
    local result, read_err = handle:read("*a")
    local success, _, exit_code = handle:close()
    
    if not success or exit_code ~= 0 then
        log_message(string.format("SSH command failed for %s", node_config.name), "WARN")
        return metrics
    end
    
    metrics.available = true
    
    for line in string.gmatch(result, "[^\r\n]+") do
        if string.find(line, ":") then
            local key, value = string.match(line, "([^:]+):(.*)")
            if key == "CPU" and value ~= "" then
                metrics.cpu = tonumber(value)
            elseif key == "RAM" and value ~= "" then
                metrics.ram = tonumber(value)
            elseif key == "DISK" and value ~= "" then
                metrics.disk = tonumber(value)
            elseif key == "LOAD" and value ~= "" then
                metrics.load = tonumber(value)
            elseif key == "GATEWAY" then
                metrics.gateway_status = value
            end
        end
    end
    
    return metrics
end

function check_alerts(node_id, node_config, metrics)
    local alerts = {}
    
    -- Verfügbarkeit
    if not metrics.available then
        if not node_config.optional then
            table.insert(alerts, {
                level = "CRITICAL",
                message = string.format("Node %s nicht erreichbar!", node_config.name)
            })
        end
    else
        -- CPU
        if metrics.cpu and metrics.cpu > 90 then
            table.insert(alerts, {
                level = "WARNING",
                message = string.format("Node %s: CPU bei %.1f%%", node_config.name, metrics.cpu)
            })
        end
        
        -- RAM
        if metrics.ram and metrics.ram > 90 then
            table.insert(alerts, {
                level = "WARNING", 
                message = string.format("Node %s: RAM bei %.1f%%", node_config.name, metrics.ram)
            })
        end
        
        -- Disk
        local disk_threshold = node_config.disk_warning or 85
        if metrics.disk and metrics.disk > disk_threshold then
            local level = "CRITICAL"
            if metrics.disk <= 95 then
                level = "WARNING"
            end
            table.insert(alerts, {
                level = level,
                message = string.format("Node %s: Disk bei %d%%", node_config.name, metrics.disk)
            })
        end
        
        -- Gateway
        if node_config.critical and metrics.gateway_status == "inactive" then
            table.insert(alerts, {
                level = "CRITICAL",
                message = string.format("Node %s: OpenClaw Gateway nicht aktiv!", node_config.name)
            })
        end
    end
    
    return alerts
end

function send_alert(alert)
    local cmd = string.format(
        "python3 %s/skills/channel-status-agent/scripts/channel_status.py --type alert --message \"%s: %s\"",
        WORKSPACE,
        alert.level,
        alert.message
    )
    
    local handle = io.popen(cmd .. " 2>/dev/null")
    local result = handle:read("*a")
    local success, _, _ = handle:close()
    
    if success then
        log_message(string.format("Alert sent: %s", alert.message))
    else
        log_message(string.format("Failed to send alert: %s", alert.message), "ERROR")
    end
end

function parse_args(arg)
    local args = {
        node = "all",
        check = "all",
        alert = false
    }
    
    for i = 1, #arg do
        if arg[i] == "--node" and arg[i+1] then
            args.node = arg[i+1]
            i = i + 1
        elseif arg[i] == "--check" and arg[i+1] then
            args.check = arg[i+1]
            i = i + 1
        elseif arg[i] == "--alert" then
            args.alert = true
        end
    end
    
    return args
end

function main(args)
    args = parse_args(args)
    
    -- Nodes bestimmen
    local nodes_to_check = {}
    if args.node == "all" then
        for id, config in pairs(NODES) do
            nodes_to_check[id] = config
        end
    else
        if NODES[args.node] then
            nodes_to_check[args.node] = NODES[args.node]
        else
            log_message(string.format("Unknown node: %s", args.node), "ERROR")
            os.exit(1)
        end
    end
    
    -- Health-Checks durchführen
    local all_alerts = {}
    
    for node_id, node_config in pairs(nodes_to_check) do
        log_message(string.format("Checking %s (%s)", node_config.name, node_id))
        
        -- Ping
        if args.check == "ping" or args.check == "all" then
            if node_config.host ~= "localhost" then
                local ping_ok = check_ping(node_config.host)
                log_message(string.format("  Ping: %s", ping_ok and "OK" or "FAILED"))
            end
        end
        
        -- SSH
        if args.check == "ssh" or args.check == "all" then
            local ssh_ok = check_ssh(node_config)
            log_message(string.format("  SSH: %s", ssh_ok and "OK" or "FAILED"))
        end
        
        -- Metriken
        if args.check == "metrics" or args.check == "all" then
            local metrics = get_node_metrics(node_config)
            
            if metrics.available then
                log_message(string.format("  CPU: %s", metrics.cpu and string.format("%.1f%%", metrics.cpu) or "N/A"))
                log_message(string.format("  RAM: %s", metrics.ram and string.format("%.1f%%", metrics.ram) or "N/A"))
                log_message(string.format("  Disk: %s", metrics.disk and string.format("%d%%", metrics.disk) or "N/A"))
                log_message(string.format("  Load: %s", metrics.load and tostring(metrics.load) or "N/A"))
            else
                log_message("  Metrics: UNAVAILABLE")
            end
            
            -- Alerts prüfen
            local alerts = check_alerts(node_id, node_config, metrics)
            for _, alert in ipairs(alerts) do
                table.insert(all_alerts, alert)
            end
        end
    end
    
    -- Alerts senden
    if args.alert and #all_alerts > 0 then
        log_message(string.format("\nSending %d alerts...", #all_alerts))
        for _, alert in ipairs(all_alerts) do
            send_alert(alert)
        end
    elseif #all_alerts > 0 then
        log_message(string.format("\n%d alerts found (use --alert to send)", #all_alerts))
    else
        log_message("\nAll nodes healthy!")
    end
end

-- Hauptfunktion aufrufen
main(arg)
