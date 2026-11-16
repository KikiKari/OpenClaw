#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "9df4e4d6f75b15227d7e71380b3acbb1f24bf8fb54356a5c8e1a2c5f5755a92e", "source_sha256": "0a86c190e36a7131252f54b73542b2e9f42f2b23547cdb5530f47c8477226123", "target_language": "lua"}
-- channel_status.py — portiert nach lua
-- Quelle: python, workspace@local:skills/channel-status-agent/scripts/channel_status.py
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

--[[
Channel Status Agent - Automatische Status-Updates
]]

local json = require("cjson")
local posix = require("posix")

-- Konfiguration
local WORKSPACE = "/home/openclaw/.openclaw/workspace"
local LOGS_DB = WORKSPACE .. "/db/logs.db"
local CONFIG_FILE = WORKSPACE .. "/config/channel-status.json"
local LOG_FILE = WORKSPACE .. "/logs/channel-status.log"

function log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local entry = string.format("[%s] [%s] %s", timestamp, level, message)
    print(entry)
    local f = io.open(LOG_FILE, "a")
    if f then
        f:write(entry .. "\n")
        f:close()
    end
end

local NODE_NAMES = {
    node2 = {"openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122"},
    node3 = {"openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125"},
    node4 = {"openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39"},
    node5 = {"openclaw-node5"},
    node6 = {"openclaw-node6"},
}

function table_contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function set_intersection(set1, set2)
    for k, _ in pairs(set1) do
        if set2[k] then
            return true
        end
    end
    return false
end

function fetch_node_status()
    -- Return mapped OpenClaw connection states; nil indicates lookup failure.
    local success, result = pcall(function()
        local proc = io.popen("timeout 10 openclaw nodes status --json 2>/dev/null")
        if not proc then
            return nil
        end
        local output = proc:read("*a")
        proc:close()
        
        local payload = json.decode(output)
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
                for _, key in ipairs({"displayName", "nodeId", "remoteIp"}) do
                    if item[key] then
                        names[string.lower(tostring(item[key]))] = true
                    end
                end
                
                for node, aliases in pairs(NODE_NAMES) do
                    local alias_set = {}
                    for _, alias in ipairs(aliases) do
                        alias_set[string.lower(alias)] = true
                    end
                    
                    if set_intersection(names, alias_set) and item.connected == true then
                        states[node] = true
                    end
                end
            end
        end
        
        states.node1 = true  -- successful Gateway status request
        return states
    end)
    
    if success then
        return result
    else
        return nil
    end
end

function get_system_status()
    -- Sammelt System-Status
    local status = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        nodes = {},
        agents = {},
        system = {}
    }
    
    -- Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
    local states = fetch_node_status()
    local names = {
        node1 = "Gateway",
        node2 = "Node2",
        node3 = "Node3",
        node4 = "Redmi",
        node5 = "Lenovo",
        node6 = "Lenovo (Docker)"
    }
    
    for node, name in pairs(names) do
        local node_status = "unknown"
        if states ~= nil then
            node_status = states[node] and "online" or "offline"
        end
        status.nodes[node] = {
            name = name,
            status = node_status
        }
    end

    -- Agent-Status aus Cron
    local success, result = pcall(function()
        local proc = io.popen("crontab -l 2>/dev/null")
        if not proc then
            return "unknown"
        end
        local output = proc:read("*a")
        proc:close()
        
        local count = 0
        for line in string.gmatch(output, "[^\r\n]+") do
            if not string.match(line, "^%s*#") and string.match(line, "%S") then
                count = count + 1
            end
        end
        return count
    end)
    
    status.agents.active_crons = success and result or "unknown"
    
    -- System-Metriken
    local success_df, result_df = pcall(function()
        local proc = io.popen("df -h / 2>/dev/null")
        if not proc then
            return
        end
        local output = proc:read("*a")
        proc:close()
        
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
    end)
    
    local success_free, result_free = pcall(function()
        local proc = io.popen("free -h 2>/dev/null")
        if not proc then
            return
        end
        local output = proc:read("*a")
        proc:close()
        
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
    end)
    
    return status
end

function format_daily_status(status)
    -- Formatiert täglichen Status
    local nodes = status.nodes
    local online = 0
    for _, n in pairs(nodes) do
        if n.status == "online" then
            online = online + 1
        end
    end
    
    local message = string.format("📊 **Täglicher Status-Report**\n🗓️ %s\n\n**🖥️ Nodes (%d/%d online):**\n", 
        os.date("%Y-%m-%d %H:%M"), online, #nodes)
    
    local sorted_nodes = {}
    for k, _ in pairs(nodes) do
        table.insert(sorted_nodes, k)
    end
    table.sort(sorted_nodes)
    
    for _, node_id in ipairs(sorted_nodes) do
        local info = nodes[node_id]
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
    -- Format the weekly report from current node data.
    local lines = {
        "📈 **Wöchentlicher Report**",
        string.format("📅 Woche %s - %s", os.date("%V"), os.date("%Y")),
        "",
        "**Nodes:**"
    }
    
    local sorted_nodes = {}
    for k, _ in pairs(status.nodes) do
        table.insert(sorted_nodes, k)
    end
    table.sort(sorted_nodes)
    
    for _, node_id in ipairs(sorted_nodes) do
        local item = status.nodes[node_id]
        table.insert(lines, "- " .. item.name .. ": " .. item.status)
    end
    
    return table.concat(lines, "\n") .. "\n"
end

function send_to_channel(message, channel_type, channel_id)
    channel_type = channel_type or "telegram"
    channel_id = channel_id or "-1002381931352"
    
    -- Sendet Nachricht an Channel
    if channel_type == "telegram" then
        -- Nutze OpenClaw message tool
        local cmd = string.format("openclaw message send --target %s --message '%s'", channel_id, message)
        local success, result = pcall(function()
            local proc = io.popen(cmd .. " 2>&1")
            if not proc then
                return false, "Failed to execute command"
            end
            local output = proc:read("*a")
            local exit_code = {proc:close()}
            return exit_code[3] == "exit" and exit_code[4] == 0, output
        end)
        
        if success then
            log(string.format("Message sent to %s %s", channel_type, channel_id))
            return true
        else
            log(string.format("Failed to send: %s", result), "ERROR")
            return false
        end
    else
        log(string.format("Channel type %s not implemented", channel_type), "WARN")
        return false
    end
end

function main()
    -- Hauptfunktion
    local argparse = require("argparse")
    
    local parser = argparse.ArgumentParser({description = 'Channel Status Agent'})
    parser:add_argument({'--type'}, {choices = {'daily', 'weekly', 'alert'}, required = true})
    parser:add_argument({'--message'}, {help = 'Alert message'})
    parser:add_argument({'--channel'}, {default = '-1002381931352'})
    parser:add_argument({'--dry-run'}, {action = 'store_true'})
    
    local args = parser:parse_args()
    
    log(string.format("Starting %s status update", args.type))
    
    -- Status sammeln
    local status = get_system_status()
    
    -- Message formatieren
    local message
    if args.type == 'daily' then
        message = format_daily_status(status)
    elseif args.type == 'weekly' then
        message = format_weekly_status(status)
    elseif args.type == 'alert' then
        message = string.format("🚨 **ALERT**\n%s", args.message or 'Manual alert')
    end
    
    -- Senden oder Dry-Run
    if args.dry_run then
        print("\n--- DRY RUN ---")
        print(message)
        print("--- END ---")
    else
        send_to_channel(message, "telegram", args.channel)
    end
    
    log("Status update completed")
end

-- Create log directory if it doesn't exist
posix.mkdir(LOG_FILE:match("(.+)/[^/]*$"), tonumber("0755", 8))

-- Run main function
main()
