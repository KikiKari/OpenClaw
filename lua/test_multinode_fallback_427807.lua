#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "871bcfbef1142a190c1f2a588399f8aae74ce6a7e34ed4d204f2ba3dc86c6366", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "lua"}
-- test_multinode_fallback.py — portiert nach lua
-- Quelle: python, workspace@local:scripts/test_multinode_fallback.py
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[
Testet Multi-Node Fallback-Logik des db-maintainer
Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
]]

local WORKSPACE = "/home/openclaw/.openclaw/workspace"

-- Hilfsfunktion zum Ausführen von Shell-Befehlen
local function run_command(cmd, timeout)
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then return nil, "Failed to execute command" end
    
    local result = handle:read("*a")
    local success, _, exit_code = handle:close()
    
    return result, exit_code
end

local function check_node_reachable(node_id)
    -- Prüft den Verbindungseintrag dieses Nodes, nicht die Gesamtausgabe.
    local aliases = {node_id:lower()}
    local node2_names = {
        ["openclaw-node2"] = true,
        ["arm64-node"] = true,
        ["v2202604104722449961"] = true,
        ["v2202604104722449961.taild25fea.ts.net"] = true
    }
    
    if node2_names[node_id:lower()] then
        for k, v in pairs(node2_names) do
            table.insert(aliases, k)
        end
    end
    
    local success, result, exit_code = pcall(function()
        local output = run_command("openclaw nodes status --json")
        if not output then return false end
        
        local payload = {}
        local func, err = load("return " .. output)
        if not func then return false end
        
        payload = func()
        if type(payload) ~= "table" or type(payload.nodes) ~= "table" then
            return false
        end
        
        for _, node in ipairs(payload.nodes) do
            if type(node) == "table" then
                local display_name = tostring(node.displayName or ""):lower()
                if node.connected == true and vim.tbl_contains(aliases, display_name) then
                    return true
                end
            end
        end
        return false
    end)
    
    if success then
        return result
    else
        return false
    end
end

local function spawn_on_node(node_id, task)
    -- Versucht Task auf Node auszuführen
    print("Versuche Task auf Node " .. node_id .. " zu starten...")
    local success, result = pcall(function()
        -- Simuliert: openclaw agent spawn --node {node_id}
        local cmd = string.format("echo 'Spawned on %s: %s'", node_id, task)
        local output = run_command(cmd)
        print("✅ Erfolgreich delegiert an " .. node_id)
        return true
    end)
    
    if not success then
        print("❌ Node " .. node_id .. " nicht erreichbar: " .. tostring(result))
        return false
    end
    
    return true
end

local function execute_locally(task)
    -- Führt Task lokal aus (Fallback)
    print("🔄 Fallback: Führe Task lokal aus...")
    local success, result = pcall(function()
        if task == 'db_maintainer' then
            local script_path = WORKSPACE .. "/skills/db-maintainer/scripts/db_maintainer.py"
            local cmd = "python3 " .. script_path
            local output, exit_code = run_command(cmd)
            
            if exit_code == 0 then
                print("✅ Lokale Ausführung erfolgreich")
                return true
            else
                local error_msg = output or ""
                if #error_msg > 200 then
                    error_msg = error_msg:sub(1, 200)
                end
                print("❌ Fehler: " .. error_msg)
                return false
            end
        end
    end)
    
    if not success then
        print("❌ Lokale Ausführung fehlgeschlagen: " .. tostring(result))
        return false
    end
    
    return true
end

local function main()
    print(string.rep("=", 60))
    print("MULTI-NODE FALLBACK TEST")
    print(string.rep("=", 60))
    print()
    
    -- Konfiguration
    local primary_node = 'v2202604104722449961.taild25fea.ts.net'  -- Node 2
    local task = 'db_maintainer'
    
    print("Primärer Node: " .. primary_node)
    print("Task: " .. task)
    print()
    
    -- 1. Prüfe Node-Erreichbarkeit
    print("--- 1. Prüfe Node-Erreichbarkeit ---")
    if check_node_reachable(primary_node) then
        print("✅ Node " .. primary_node .. " ist erreichbar")
        
        -- 2. Versuche Delegation
        print("\n--- 2. Versuche Delegation ---")
        if spawn_on_node(primary_node, task) then
            print("\n✅ MULTI-NODE: Task erfolgreich delegiert")
            return 0
        else
            print("\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...")
        end
    else
        print("❌ Node " .. primary_node .. " nicht erreichbar")
        print("🔄 Fallback wird aktiviert...")
    end
    
    -- 3. Lokale Ausführung (Fallback)
    print("\n--- 3. Lokale Ausführung (Fallback) ---")
    if execute_locally(task) then
        print("\n✅ FALLBACK: Task lokal erfolgreich ausgeführt")
        return 0
    else
        print("\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich")
        return 1
    end
end

os.exit(main())
