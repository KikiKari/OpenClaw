#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "8d31481f2e0b0f0ee055d13a215ae25df44a9c97842b1446e5159dc38d74b36c", "source_sha256": "705cb2cc5900c507db1038d107f06e2f8452a95c37d0611cd27dfe2ed61dd498", "target_language": "lua"}
-- channel_status.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/channel-status-agent/scripts/channel_status.py
-- auch in: OpenClaw@gateway2:skills/channel-status-agent/scripts/channel_status.py
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

--[[
Channel Status Agent - Automatische Status-Updates
--]]

local json = require("cjson")
local posix = require("posix")

-- Konfiguration
local WORKSPACE = "/home/openclaw/.openclaw/workspace"
local LOGS_DB = WORKSPACE .. "/db/logs.db"
local CONFIG_FILE = WORKSPACE .. "/config/channel-status.json"
local LOG_FILE = WORKSPACE .. "/logs/channel-status.log"

function log_message(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local entry = string.format("[%s] [%s] %s", timestamp, level, message)
    print(entry)
    
    local file = io.open(LOG_FILE, "a")
    if file then
        file:write(entry .. "\n")
        file:close()
    end
end

function get_system_status()
    local status = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        nodes = {},
        agents = {},
        system = {}
    }
    
    -- Node-Status (vereinfacht)
    local nodes = {
        node1 = {name = "Gateway", status = "online"},
        node2 = {name = "Worker", status = "online"},
        node3 = {name = "Relay", status = "offline", reason = "disk full"},
        node5 = {name = "Redmi", status = "intermittent"},
        node7 = {name = "Docker", status = "planned"}
    }
    status.nodes = nodes
    
    -- Agent-Status aus Cron
    local success, result = pcall(function()
        local handle = io.popen("crontab -l 2>/dev/null")
        if handle then
            local output = handle:read("*a")
            handle:close()
            local count = 0
            for line in output:gmatch("[^\r\n]+") do
                if not line:match("^%s*#") and line:match("%S") then
                    count = count + 1
                end
            end
            return count
        end
        return "unknown"
    end)
    
    status.agents.active_crons = success and result or "unknown"
    
    -- System-Metriken
    local function safe_popen(cmd)
        local success, result = pcall(function()
            local handle = io.popen(cmd)
            if handle then
                local output = handle:read("*a")
                handle:close()
                return output
            end
        end)
        return success and result or nil
    end
    
    -- Disk usage
    local df_output = safe_popen("df -h /")
    if df_output then
        for line in df_output:gmatch("[^\r\n]+") do
            if line:match("/") and line:match("%%") then
                local parts = {}
                for part in line:gmatch("%S+") do
                    table.insert(parts, part)
                end
                if #parts >= 5 then
                    status.system.disk_used = parts[5]
                    break
                end
            end
        end
    end
    
    -- RAM usage
    local free_output = safe_popen("free -h")
    if free_output then
        for line in free_output:gmatch("[^\r\n]+") do
            if line:match("Mem:") then
                local parts = {}
                for part in line:gmatch("%S+") do
                    table.insert(parts, part)
                end
                if #parts >= 3 then
                    status.system.ram_total = parts[2]
                    status.system.ram_used = parts[3]
                end
                break
            end
        end
    end
    
    return status
end

function format_daily_status(status)
    local nodes = status.nodes
    local online_count = 0
    for _, info in pairs(nodes) do
        if info.status == "online" then
            online_count = online_count + 1
        end
    end
    
    local message = string.format([[📊 **Täglicher Status-Report**
🗓️ %s

**🖥️ Nodes (%d/5 online):**
]], os.date("%Y-%m-%d %H:%M"), online_count)
    
    -- Sort nodes by key for consistent ordering
    local sorted_nodes = {}
    for k in pairs(nodes) do
        table.insert(sorted_nodes, k)
    end
    table.sort(sorted_nodes)
    
    for _, node_id in ipairs(sorted_nodes) do
        local info = nodes[node_id]
        local emoji = "🟢"
        if info.status == "offline" then
            emoji = "🔴"
        elseif info.status ~= "online" then
            emoji = "🟡"
        end
        message = message .. emoji .. " " .. info.name .. ": " .. info.status
        if info.reason then
            message = message .. " (" .. info.reason .. ")"
        end
        message = message .. "\n"
    end
    
    message = message .. "\n**🤖 Agents:**\n"
    message = message .. "Aktive Cron-Jobs: " .. tostring(status.agents.active_crons) .. "\n"
    
    if status.system.disk_used then
        message = message .. "\n**💾 System:**\n"
        message = message .. "Disk: " .. status.system.disk_used .. " belegt\n"
        message = message .. "RAM: " .. status.system.ram_used .. " / " .. status.system.ram_total .. "\n"
    end
    
    return message
end

function format_weekly_status(status)
    local message = string.format([[📈 **Wöchentlicher Report**
📅 Woche %s - %s

**Zusammenfassung:**
- 5 aktive Sub-Agents
- 11 Skills synchronisiert
- 3 neue Features implementiert

**Top-Ereignisse:**
1. ClawHub-Git Sync implementiert ✅
2. Node 3 Disk voll (95%) ⚠️
3. Channel-Status-Agent aktiviert 🆕

**Geplante Wartungen:**
- Node 3: Disk-Cleanup erforderlich
- Node 7: Docker-Setup ausstehend
]], os.date("%V"), os.date("%Y"))
    
    return message
end

function send_to_channel(message, channel_type, channel_id)
    channel_type = channel_type or "telegram"
    channel_id = channel_id or "-1002381931352"
    
    if channel_type == "telegram" then
        -- Nutze OpenClaw message tool
        local cmd = string.format("openclaw message send --target %s --message '%s'", 
                                channel_id, message:gsub("'", "'\"'\"'"))
        
        local success, _, exit_code = posix.spawn(cmd)
        if success and exit_code == 0 then
            log_message(string.format("Message sent to %s %s", channel_type, channel_id))
            return true
        else
            log_message(string.format("Failed to send: exit code %d", exit_code), "ERROR")
            return false
        end
    else
        log_message(string.format("Channel type %s not implemented", channel_type), "WARN")
        return false
    end
end

function main()
    -- Simple argument parsing
    local args = {
        type = nil,
        message = nil,
        channel = "-1002381931352",
        dry_run = false
    }
    
    for i = 1, #arg do
        if arg[i] == "--type" and arg[i+1] then
            args.type = arg[i+1]
            i = i + 1
        elseif arg[i] == "--message" and arg[i+1] then
            args.message = arg[i+1]
            i = i + 1
        elseif arg[i] == "--channel" and arg[i+1] then
            args.channel = arg[i+1]
            i = i + 1
        elseif arg[i] == "--dry-run" then
            args.dry_run = true
        end
    end
    
    if not args.type then
        print("Error: --type is required")
        print("Usage: channel_status.lua --type <daily|weekly|alert> [--message <msg>] [--channel <id>] [--dry-run]")
        os.exit(1)
    end
    
    log_message(string.format("Starting %s status update", args.type))
    
    -- Status sammeln
    local status = get_system_status()
    
    -- Message formatieren
    local message
    if args.type == "daily" then
        message = format_daily_status(status)
    elseif args.type == "weekly" then
        message = format_weekly_status(status)
    elseif args.type == "alert" then
        message = "🚨 **ALERT**\n" .. (args.message or "Manual alert")
    end
    
    -- Senden oder Dry-Run
    if args.dry_run then
        print("\n--- DRY RUN ---")
        print(message)
        print("--- END ---")
    else
        send_to_channel(message, "telegram", args.channel)
    end
    
    log_message("Status update completed")
end

-- Create log directory if it doesn't exist
local log_dir = WORKSPACE .. "/logs"
posix.mkdir(log_dir, "p")

-- Run main function
main()
