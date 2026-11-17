#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "0d0ba4cc78b4cbb6238b3a08c052bd07f7abce72a144f70b0d2d953db27101b7", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "lua"}
-- node_health.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
Node Health Monitor - Multi-Node Gesundheitsüberwachung
]]

local WORKSPACE = "/home/openclaw/.openclaw/workspace"
local HEALTH_DB = WORKSPACE .. "/db/health.db"
local LOG_FILE = WORKSPACE .. "/logs/node-health.log"

-- Node-Definitionen
local NODES = {
    node1 = {
        name = "Gateway",
        host = "localhost",
        user = "openclaw",
        critical = true
    },
    node2 = {
        name = "Worker", 
        host = "100.92.155.34",
        user = "root",
        ssh_key = "~/.ssh/id_rsa"
    },
    node3 = {
        name = "Relay",
        host = "185.242.xxx.xxx",
        user = "root",
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
    
    local log_dir = string.match(LOG_FILE, "(.-)/[^/]*$")
    os.execute(string.format("mkdir -p %q", log_dir))
    
    local f = io.open(LOG_FILE, "a")
    if f then
        f:write(entry .. "\n")
        f:close()
    end
end

function check_ping(host, timeout)
    timeout = timeout or 5
    local cmd = string.format("ping -c 1 -W %d %q >/dev/null 2>&1", timeout, host)
    local success = os.execute(cmd)
    return success == 0
end

function check_ssh(node_config)
    local host = node_config.host
    local user = node_config.user or "root"
    local cmd = string.format("ssh -o ConnectTimeout=10 -o BatchMode=yes %q@%q 'echo \"OK\"' 2>/dev/null", user, host)
    
    local handle = io.popen(cmd)
    if handle then
        local result = handle:read("*a")
        handle:close()
        return string.find(result, "OK") ~= nil
    end
    return false
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
    local cmd = string.format([[
ssh -o ConnectTimeout=10 %q@%q '
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
' 2>/dev/null]], user, host)
    
    local handle = io.popen(cmd)
    if handle then
        local output = handle:read("*a")
        local success, _, exit_code = handle:close()
        
        if success and exit_code == 0 then
            metrics.available = true
            
            for line in string.gmatch(output, "[^\n]+") do
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
            local level = metrics.disk > 95 and "CRITICAL" or "WARNING"
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
    local cmd = string.format("python3 %q --type alert --message '%s: %s' 2>/dev/null", 
                             WORKSPACE .. "/skills/channel-status-agent/scripts/channel_status.py",
                             alert.level, alert.message)
    local success = os.execute(cmd)
    if success == 0 then
        log_message(string.format("Alert sent: %s", alert.message))
    else
        log_message(string.format("Failed to send alert: %s", alert.message), "ERROR")
    end
end

function main()
    -- Simple argument parsing
    local args = {}
    for i = 1, #arg do
        if arg[i] == "--node" and arg[i+1] then
            args.node = arg[i+1]
        elseif arg[i] == "--check" and arg[i+1] then
            args.check = arg[i+1]
        elseif arg[i] == "--alert" then
            args.alert = true
        end
    end
    
    args.node = args.node or "all"
    args.check = args.check or "all"
    
    -- Nodes bestimmen
    local nodes_to_check = {}
    if args.node == "all" then
        for id, config in pairs(NODES) do
            table.insert(nodes_to_check, {id = id, config = config})
        end
    else
        if NODES[args.node] then
            table.insert(nodes_to_check, {id = args.node, config = NODES[args.node]})
        else
            log_message(string.format("Unknown node: %s", args.node), "ERROR")
            os.exit(1)
        end
    end
    
    -- Health-Checks durchführen
    local all_alerts = {}
    
    for _, node_data in ipairs(nodes_to_check) do
        local node_id = node_data.id
        local node_config = node_data.config
        
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

main()
