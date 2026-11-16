#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f7f059c5b820c993be9889f5bc3db6b1eda6bbc369ac533255fcb626b7ad47f1", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "lua"}
-- channel_status.py — portiert nach lua
-- Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

--[[
Channel Status Agent - Automatische Status-Updates
]]

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

local NODE_NAMES = {
    node2 = {"openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122"},
    node3 = {"openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125"},
    node4 = {"openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39"},
    node5 = {"openclaw-node5", "lenovo-node7", "lenovo-node7.taild25fea.ts.net", "100.103.140.35"}
}

function table_contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function fetch_node_status()
    local success, result = pcall(function()
        local handle = io.popen("timeout 10 openclaw nodes status --json 2>/dev/null")
        if not handle then return nil end
        local output = handle:read("*a")
        handle:close()
        
        local payload = {}
        if output and output ~= "" then
            payload = load("return " .. string.gsub(output, "null", "nil"))()
        end
        
        if type(payload) ~= "table" or type(payload.nodes) ~= "table" then
            return nil
        end
        
        local states = {}
        for node, _ in pairs(NODE_NAMES) do
            states[node] = false
        end
        
        for _, item in ipairs(payload.nodes) do
            if type(item) == "table" then
                local names = {}
                if item.displayName then table.insert(names, string.lower(tostring(item.displayName))) end
                if item.nodeId then table.insert(names, string.lower(tostring(item.nodeId))) end
                if item.remoteIp then table.insert(names, string.lower(tostring(item.remoteIp))) end
                
                for node, aliases in pairs(NODE_NAMES) do
                    for _, name in ipairs(names) do
                        if table_contains(aliases, name) and item.connected == true then
                            states[node] = true
                        end
                    end
                end
            end
        end
        states.node1 = true
        return states
    end)
    
    if success then
        return result
    else
        return nil
    end
end

function get_system_status()
    local status = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        nodes = {},
        agents = {},
        system = {}
    }
    
    local states = fetch_node_status()
    local names = {
        node1 = "Gateway",
        node2 = "Node2", 
        node3 = "Node3",
        node4 = "Redmi",
        node5 = "Lenovo"
    }
    
    for node, name in pairs(names) do
        local node_status = "unknown"
        if states ~= nil then
            node_status = (states[node] == true) and "online" or "offline"
        end
        status.nodes[node] = {name = name, status = node_status}
    end
    
    local success, _ = pcall(function()
        local handle = io.popen("crontab -l 2>/dev/null")
        if handle then
            local output = handle:read("*a")
            handle:close()
            local count = 0
            if output then
                for line in string.gmatch(output, "[^\r\n]+") do
                    if not string.match(line, "^%s*#") and line ~= "" then
                        count = count + 1
                    end
                end
            end
            status.agents.active_crons = count
        end
    end)
    
    if not success then
        status.agents.active_crons = "unknown"
    end
    
    local success_df, _ = pcall(function()
        local handle = io.popen("df -h / 2>/dev/null")
        if handle then
            local output = handle:read("*a")
            handle:close()
            for line in string.gmatch(output, "[^\r\n]+") do
                if string.find(line, "/") and string.find(line, "%%") then
                    local parts = {}
                    for part in string.gmatch(line, "%S+") do
                        table.insert(parts, part)
                    end
                    if #parts >= 5 then
                        status.system.disk_used = parts[5]
                        break
                    end
                end
            end
        end
    end)
    
    local success_free, _ = pcall(function()
        local handle = io.popen("free -h 2>/dev/null")
        if handle then
            local output = handle:read("*a")
            handle:close()
            for line in string.gmatch(output, "[^\r\n]+") do
                if string.find(line, "Mem:") then
                    local parts = {}
                    for part in string.gmatch(line, "%S+") do
                        table.insert(parts, part)
                    end
                    if #parts >= 3 then
                        status.system.ram_total = parts[2]
                        status.system.ram_used = parts[3]
                        break
                    end
                end
            end
        end
    end)
    
    return status
end

function format_daily_status(status)
    local nodes = status.nodes
    local online = 0
    for _, n in pairs(nodes) do
        if n.status == "online" then
            online = online + 1
        end
    end
    
    local message = "📊 **Täglicher Status-Report**\n🗓️ " .. os.date("%Y-%m-%d %H:%M") .. "\n\n**🖥️ Nodes (" .. online .. "/" .. #nodes .. " online):**\n"
    
    for node_id, info in pairs(nodes) do
        local emoji = "🟡"
        if info.status == "online" then
            emoji = "🟢"
        elseif info.status == "offline" then
            emoji = "🔴"
        end
        message = message .. emoji .. " " .. info.name .. ": " .. info.status .. "\n"
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
    local lines = {"📈 **Wöchentlicher Report**", "📅 Woche " .. os.date("%V") .. " - " .. os.date("%Y"), "", "**Nodes:**"}
    
    for _, item in pairs(status.nodes) do
        table.insert(lines, "- " .. item.name .. ": " .. item.status)
    end
    
    return table.concat(lines, "\n") .. "\n"
end

function send_to_channel(message, channel_type, channel_id)
    channel_type = channel_type or "telegram"
    channel_id = channel_id or "-1002381931352"
    
    if channel_type == "telegram" then
        local cmd = "openclaw message send --target " .. channel_id .. " --message '" .. message:gsub("'", "'\"'\"'") .. "' 2>&1"
        local handle = io.popen(cmd)
        if handle then
            local result = handle:read("*a")
            local success = handle:close()
            if success then
                log_message("Message sent to " .. channel_type .. " " .. channel_id)
                return true
            else
                log_message("Failed to send: " .. (result or ""), "ERROR")
                return false
            end
        else
            log_message("Send error: Could not execute command", "ERROR")
            return false
        end
    else
        log_message("Channel type " .. channel_type .. " not implemented", "WARN")
        return false
    end
end

function main()
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
        return 1
    end
    
    log_message("Starting " .. args.type .. " status update")
    
    local status = get_system_status()
    
    local message
    if args.type == "daily" then
        message = format_daily_status(status)
    elseif args.type == "weekly" then
        message = format_weekly_status(status)
    elseif args.type == "alert" then
        message = "🚨 **ALERT**\n" .. (args.message or "Manual alert")
    end
    
    if args.dry_run then
        print("\n--- DRY RUN ---")
        print(message)
        print("--- END ---")
    else
        send_to_channel(message, "telegram", args.channel)
    end
    
    log_message("Status update completed")
    return 0
end

os.execute("mkdir -p " .. WORKSPACE .. "/logs")
return main()
