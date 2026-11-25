#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "17735626310b1b89458e9094f573d037a98c65ffa469c66e69beaa2b06eabc72", "source_sha256": "52b3516148b12072bbff77599a6faac284607fbc005a73f93c2b7f4f349cf6f1", "target_language": "lua"}
-- test_multinode_fallback.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:scripts/test_multinode_fallback.py
-- auch in: OpenClaw@gateway2:scripts/test_multinode_fallback.py
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[
Testet Multi-Node Fallback-Logik des db-maintainer
Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
]]

local WORKSPACE = "/home/openclaw/.openclaw/workspace"

-- Helper function to execute shell commands and capture output
local function execute_command(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

local function check_node_reachable(node_id)
    -- Prüft ob Node erreichbar ist
    local success, _, exit_code = os.execute("timeout 10 openclaw nodes status > /dev/null 2>&1")
    if not success or exit_code ~= 0 then
        return false
    end
    
    local output = execute_command("timeout 10 openclaw nodes status")
    return string.find(output, node_id) ~= nil and string.find(output, "connected") ~= nil
end

local function spawn_on_node(node_id, task)
    -- Versucht Task auf Node auszuführen
    print("Versuche Task auf Node " .. node_id .. " zu starten...")
    local cmd = "echo 'Spawned on " .. node_id .. ": " .. task .. "'"
    local success, _, exit_code = os.execute(cmd)
    
    if success and exit_code == 0 then
        print("✅ Erfolgreich delegiert an " .. node_id)
        return true
    else
        print("❌ Node " .. node_id .. " nicht erreichbar")
        return false
    end
end

local function execute_locally(task)
    -- Führt Task lokal aus (Fallback)
    print("🔄 Fallback: Führe Task lokal aus...")
    
    if task == 'db_maintainer' then
        local script_path = WORKSPACE .. "/skills/db-maintainer/scripts/db_maintainer.py"
        local cmd = "timeout 60 python3 " .. script_path
        local success, _, exit_code = os.execute(cmd)
        
        if success and exit_code == 0 then
            print("✅ Lokale Ausführung erfolgreich")
            return true
        else
            print("❌ Fehler bei lokaler Ausführung")
            return false
        end
    end
    
    return false
end

local function main()
    print(string.rep("=", 60))
    print("MULTI-NODE FALLBACK TEST")
    print(string.rep("=", 60))
    print()
    
    -- Konfiguration
    local primary_node = 'v2202603104722445775'  -- Node 2
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

-- Program entry point
os.exit(main())
