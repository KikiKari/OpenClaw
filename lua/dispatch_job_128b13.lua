#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "5e6ee798dec810f1320cc984c4a6318f0e9663883e4cd669f8fa1b298fb9bfe7", "source_sha256": "128b137e5c7d86f81ea7fdb61718540c70e4ed38de4430ae6a23a5739962c024", "target_language": "lua"}
-- dispatch_job.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
Job Dispatcher - Verteilt Jobs auf passende Nodes
]]

local pl_path = require 'pl.path'
local pl_utils = require 'pl.utils'
local tablex = require 'pl.tablex'

-- Node-Konfiguration
local NODES = {
    node1 = {always_available = true, capacity = "medium", priority = 2},
    node2 = {always_available = true, capacity = "medium", priority = 3},
    node3 = {always_available = false, capacity = "medium", priority = 4},
    node5 = {always_available = false, capacity = "low", priority = 5, device = "Redmi Note 11S"},
    node7 = {always_available = true, capacity = "high", priority = 1},
}

local JobDispatcher = {}

function JobDispatcher:new()
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function JobDispatcher:get_job_weight(script_path, target_langs_count)
    --[[
    Bewertet Job-Gewicht
    ]]
    if not pl_path.exists(script_path) then
        return "medium"
    end
    
    local stat = pl_path.attrib(script_path, 'size')
    local script_size = stat or 0
    local total_work = script_size * (target_langs_count or 1)
    
    if total_work > 50000 then  -- > 50KB
        return "heavy"
    elseif total_work > 10000 then  -- > 10KB
        return "medium"
    else
        return "light"
    end
end

function JobDispatcher:select_node(job_weight)
    --[[
    Wählt besten Node basierend auf Job-Gewicht
    ]]
    local preferred
    
    if job_weight == "heavy" then
        -- Schwere Jobs → Node 7 (Docker), dann Node 2, dann Node 1
        preferred = {"node7", "node2", "node1"}
    elseif job_weight == "medium" then
        -- Mittlere Jobs → Stable Nodes
        preferred = {"node2", "node1", "node7"}
    else  -- light
        -- Leichte Jobs → Mobile/verfügbare Nodes
        preferred = {"node5", "node1", "node2"}
    end
    
    -- Prüfe Verfügbarkeit
    for _, node_id in ipairs(preferred) do
        if self:check_node_available(node_id) then
            return node_id
        end
    end
    
    -- Fallback
    return "node1"
end

function JobDispatcher:check_node_available(node_id)
    --[[
    Prüft ob Node erreichbar ist
    ]]
    if not NODES[node_id] then
        return false
    end
    
    local node = NODES[node_id]
    
    -- Nicht immer-verfügbare Nodes nur wenn explizit requested
    if not node.always_available then
        -- Für light-jobs prüfen wir ob online
        if node_id == "node5" then  -- Redmi
            return self:_check_mobile_online()
        end
        return false
    end
    
    -- Für immer-verfügbare Nodes: prüfe ob wirklich online
    local success, result = pcall(function()
        local handle = io.popen("timeout 3 openclaw nodes status " .. node_id .. " 2>/dev/null", 'r')
        if handle then
            local output = handle:read("*a")
            handle:close()
            return output ~= nil
        end
        return false
    end)
    
    if success then
        return result
    else
        return node.always_available or false
    end
end

function JobDispatcher:_check_mobile_online()
    --[[
    Prüft ob Redmi (Node 5) Internet hat
    ]]
    local success, result = pcall(function()
        local handle = io.popen("timeout 5 openclaw nodes status node5 2>/dev/null", 'r')
        if handle then
            local output = handle:read("*a")
            handle:close()
            return output and string.find(string.lower(output), "online") ~= nil
        end
        return false
    end)
    
    return success and result or false
end

function JobDispatcher:dispatch(job_script, target_langs)
    --[[
    Dispatched Job und gibt Info zurück
    ]]
    if target_langs == nil then
        target_langs = {"perl5"}
    end
    
    local weight = self:get_job_weight(job_script, #target_langs)
    local selected_node = self:select_node(weight)
    
    return {
        job = job_script,
        weight = weight,
        selected_node = selected_node,
        target_langs = target_langs,
        status = "dispatched"
    }
end

local function split(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

local function main()
    local argparse = require 'argparse'
    
    local parser = argparse("dispatch_job.lua")
    parser:description("Dispatch job to optimal node")
    parser:option("-j --job", "Path to job script"):count(1):required(true)
    parser:option("-l --langs", "Comma-separated target languages"):default("perl5")
    parser:option("-w --weight", "Force job weight"):choices({"light", "medium", "heavy"})
    parser:flag("-x --execute", "Actually execute on selected node")
    
    local args = parser:parse()
    
    local job_path = args.job
    if not pl_path.exists(job_path) then
        print("❌ Job not found: " .. job_path)
        os.exit(1)
    end
    
    local dispatcher = JobDispatcher:new()
    local target_langs = split(args.langs, ",")
    
    -- Determine weight
    local weight
    if args.weight then
        weight = args.weight
    else
        weight = dispatcher:get_job_weight(job_path, #target_langs)
    end
    
    -- Select node
    local selected_node = dispatcher:select_node(weight)
    
    -- Output
    print("📦 Job Dispatch Information")
    print(string.rep("=", 50))
    print("Job: " .. job_path)
    print("Size: " .. tostring(pl_path.attrib(job_path, 'size')) .. " bytes")
    print("Target langs: " .. table.concat(target_langs, ", "))
    print("Job weight: " .. weight)
    print("Selected node: " .. selected_node)
    print(string.rep("=", 50))
    
    if args.execute then
        print("\n🚀 Executing on " .. selected_node .. "...")
        -- TODO: Implement remote execution
        print("(Remote execution not yet implemented)")
    else
        print("\n💡 To execute: " .. arg[0] .. " --job " .. args.job .. " --execute")
    end
end

if not package.loaded['dispatch_job'] then
    main()
end

return JobDispatcher
