#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "5fee1e55d23f729b25b433471326df451dbea3f48a819b80bbe5f9b45f2b44c7", "source_sha256": "5a841c728d9c1585b5c3191e88fdd38cf887a0d51560ce803b8c0172412bef3d", "target_language": "lua"}
-- check_nodes.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
-- auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[
Node-Status Checker - Prüft Verfügbarkeit aller Nodes
]]

local json = require("cjson")

-- Node-Konfiguration (sollte aus config file geladen werden)
local NODES = {
    node1 = {
        always_available = true,
        capacity = "medium",
        priority = 2,
        description = "Gateway-Master"
    },
    node2 = {
        always_available = true,
        capacity = "medium",
        priority = 3,
        description = "Stable Worker"
    },
    node3 = {
        always_available = false,
        capacity = "medium",
        priority = 4,
        description = "Bald verfügbar (nach Reorganisation)"
    },
    node5 = {
        always_available = false,
        capacity = "low",
        priority = 5,
        device = "Redmi Note 11S",
        description = "Mobile (bei Internet verfügbar)"
    },
    node7 = {
        always_available = true,
        capacity = "high",
        priority = 1,
        description = "Docker Hauptarbeitspferd (bald verfügbar)"
    },
}

-- Helper function to execute command and get output
local function execute_command(cmd, timeout)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success, _, exit_code = handle:close()
    
    return {
        stdout = result,
        returncode = exit_code or 0,
        success = success ~= nil
    }
end

-- Helper function to check if command exists
local function command_exists(cmd)
    local handle = io.open(cmd, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end

local function check_node_status(node_id)
    -- Prüft Status eines einzelnen Nodes
    local cmd = "openclaw nodes status " .. node_id
    local success, result
    
    -- Check if openclaw command exists
    if not command_exists("/usr/bin/openclaw") and not command_exists("/usr/local/bin/openclaw") then
        return {
            id = node_id,
            online = false,
            available = NODES[node_id].always_available or false,
            response = "Command not found"
        }
    end
    
    -- Try to execute the command
    local status, err = pcall(function()
        result = execute_command(cmd)
    end)
    
    if not status then
        return {
            id = node_id,
            online = false,
            available = NODES[node_id].always_available or false,
            response = "Error: " .. tostring(err)
        }
    end
    
    if result.success then
        local is_online = result.returncode == 0 and (
            string.find(string.lower(result.stdout or ""), "online") or
            string.find(string.lower(result.stdout or ""), "active")
        ) ~= nil
        
        return {
            id = node_id,
            online = is_online,
            available = NODES[node_id].always_available or false,
            response = result.stdout and string.sub(result.stdout, 1, 100) or "No response"
        }
    else
        return {
            id = node_id,
            online = false,
            available = NODES[node_id].always_available or false,
            response = "Command failed"
        }
    end
end

local function print_table(nodes_status)
    -- Gibt Node-Status als Tabelle aus
    print("\n" .. string.rep("=", 90))
    print(string.format("%-8s %-12s %-12s %-10s %-10s %s", "Node", "Status", "Verfügbar", "Kapazität", "Priorität", "Gerät/Beschreibung"))
    print(string.rep("=", 90))
    
    for _, status in ipairs(nodes_status) do
        local node_id = status.id
        local config = NODES[node_id]
        
        local status_icon = status.online and "🟢 Online" or "🔴 Offline"
        local avail_icon = status.available and "✅ Immer" or "📱 Bedingt"
        local capacity = config.capacity or "unknown"
        local priority = config.priority or "-"
        local device = config.device or config.description or ""
        
        print(string.format("%-8s %-12s %-12s %-10s %-10s %s", node_id, status_icon, avail_icon, capacity, priority, device))
    end
    
    print(string.rep("=", 90))
    print("\nGeprüft am: " .. os.date("%Y-%m-%d %H:%M:%S"))
end

local function print_json(nodes_status)
    -- Gibt Node-Status als JSON aus
    local output = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        nodes = {}
    }
    
    for _, status in ipairs(nodes_status) do
        local node_id = status.id
        output.nodes[node_id] = {
            status = status,
            config = NODES[node_id]
        }
    end
    
    print(json.encode(output))
end

local function parse_args(arg)
    local args = {
        format = "table",
        save = nil
    }
    
    for i = 1, #arg do
        if arg[i] == "--format" or arg[i] == "-f" then
            args.format = arg[i + 1]
        elseif arg[i] == "--save" or arg[i] == "-s" then
            args.save = arg[i + 1]
        end
    end
    
    return args
end

local function main()
    local args = parse_args(arg)
    
    print("🔍 Prüfe Node-Status...")
    
    -- Prüfe alle Nodes
    local nodes_status = {}
    local node_ids = {}
    for id in pairs(NODES) do
        table.insert(node_ids, id)
    end
    table.sort(node_ids)
    
    for _, node_id in ipairs(node_ids) do
        io.write("  → " .. node_id .. "... ")
        io.flush()
        local status = check_node_status(node_id)
        table.insert(nodes_status, status)
        print(status.online and "✓" or "✗")
    end
    
    -- Ausgabe
    if args.format == "table" then
        print_table(nodes_status)
    else
        print_json(nodes_status)
    end
    
    -- Speichern
    if args.save then
        local output = {
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            nodes = {}
        }
        
        for _, status in ipairs(nodes_status) do
            output.nodes[status.id] = status
        end
        
        local file = io.open(args.save, "w")
        if file then
            file:write(json.encode(output))
            file:close()
            print("\n💾 Gespeichert: " .. args.save)
        end
    end
    
    -- Zusammenfassung
    local online_count = 0
    for _, s in ipairs(nodes_status) do
        if s.online then
            online_count = online_count + 1
        end
    end
    print("\n📊 Zusammenfassung: " .. online_count .. "/" .. #nodes_status .. " Nodes online")
end

main()
