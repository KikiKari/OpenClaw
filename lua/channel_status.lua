#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a073b79041b40c48663bc1b963bede3efe035ba8f086ca8c12038c7c5528c7f6", "source_sha256": "705cb2cc5900c507db1038d107f06e2f8452a95c37d0611cd27dfe2ed61dd498", "target_language": "lua"}
-- channel_status.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/channel-status-agent/scripts/channel_status.py
-- auch in: OpenClaw@gateway2:skills/channel-status-agent/scripts/channel_status.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[
Channel Status Agent - Automatische Status-Updates
]]

local WORKSPACE = "/home/openclaw/.openclaw/workspace"
local LOGS_DB = WORKSPACE .. "/db/logs.db"
local CONFIG_FILE = WORKSPACE .. "/config/channel-status.json"
local LOG_FILE = WORKSPACE .. "/logs/channel-status.log"

-- Hilfsfunktion für Logging
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

-- Führt einen Shell-Befehl aus und gibt stdout, stderr und exit_code zurück
function run_command(command)
    local handle = io.popen(command .. " 2>&1", "r")
    local output = handle:read("*a")
    local success, _, exit_code = handle:close()
    return output, "", exit_code or (success and 0 or 1)
end

-- Sammelt System-Status
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
    local crontab_out, _, crontab_exit = run_command("crontab -l")
    if crontab_exit == 0 then
        local cron_lines = 0
        for line in crontab_out:gmatch("[^\r\n]+") do
            if not line:match("^%s*#") and line:match("%S") then
                cron_lines = cron_lines + 1
            end
        end
        status.agents.active_crons = cron_lines
    else
        status.agents.active_crons = "unknown"
    end
    
    -- System-Metriken
    local df_out, _, _ = run_command("df -h /")
    for line in df_out:gmatch("[^\r\n]+") do
        if line:find("/") and line:find("%%") then
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
    
    local free_out, _, _ = run_command("free -h")
    for line in free_out:gmatch("[^\r\n]+") do
        if line:find("Mem:") then
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
    
    return status
end

-- Formatiert täglichen Status
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
    
    -- Sortiere Nodes nach Schlüssel für konsistente Reihenfolge
    local sorted_nodes = {}
    for k, v in pairs(nodes) do
        table.insert(sorted_nodes, {key = k, value = v})
    end
    table.sort(sorted_nodes, function(a, b) return a.key < b.key end)
    
    for _, pair in ipairs(sorted_nodes) do
        local info = pair.value
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

-- Formatiert wöchentlichen Status
function format_weekly_status(_)
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

-- Sendet Nachricht an Channel
function send_to_channel(message, channel_type, channel_id)
    channel_type = channel_type or "telegram"
    channel_id = channel_id or "-1002381931352"
    
    if channel_type ~= "telegram" then
        log_message("Channel type " .. channel_type .. " not implemented", "WARN")
        return false
    end
    
    -- Escape single quotes in message for shell safety
    local escaped_msg = message:gsub("'", "'\"'\"'")
    local cmd = string.format("openclaw message send --target '%s' --message '%s'", channel_id, escaped_msg)
    
    local _, _, exit_code = run_command(cmd)
    if exit_code == 0 then
        log_message("Message sent to " .. channel_type .. " " .. channel_id)
        return true
    else
        log_message("Failed to send message via command: " .. cmd, "ERROR")
        return false
    end
end

-- Hauptfunktion
function main(args)
    log_message("Starting " .. args.type .. " status update")
    
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
    else
        print("Ungültiger Typ: " .. args.type)
        return
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

-- Simple Argument Parser
function parse_args(arg)
    local options = {
        type = nil,
        message = nil,
        channel = "-1002381931352",
        dry_run = false
    }
    
    for i = 1, #arg do
        if arg[i] == "--type" and arg[i+1] then
            options.type = arg[i+1]
            i = i + 1
        elseif arg[i] == "--message" and arg[i+1] then
            options.message = arg[i+1]
            i = i + 1
        elseif arg[i] == "--channel" and arg[i+1] then
            options.channel = arg[i+1]
            i = i + 1
        elseif arg[i] == "--dry-run" then
            options.dry_run = true
        end
    end
    
    if not options.type then
        print("Fehler: --type ist erforderlich")
        print("Verwendung: lua channel_status.lua --type [daily|weekly|alert]")
        os.exit(1)
    end
    
    return options
end

-- Sicherstellen, dass das Log-Verzeichnis existiert
local log_dir = LOG_FILE:match("(.+)/[^/]*$")
os.execute("mkdir -p '" .. log_dir .. "'")

-- Starten
local args = parse_args(arg)
main(args)
