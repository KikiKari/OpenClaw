#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "4d7bca05499976ede42e9fecc57fe9512be0b1c46363f94731c3494e62f66a27", "source_sha256": "748c0fc07a58caf07d4983d358cf0e1ce57c4e180b87ae617d598f53c61efcec", "target_language": "lua"}
-- dispatch_job.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

--[[
Job Dispatcher - Verteilt Jobs auf passende Nodes
]]

local json = require("cjson")

-- Hilfsfunktionen für Dateisystemoperationen
local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local function get_file_size(path)
    local file = io.open(path, "r")
    if file then
        local size = file:seek("end")
        file:close()
        return size
    end
    return 0
end

local function uuid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format("%x", v)
    end)
end

local function split_string(str, delimiter)
    local parts = {}
    for part in string.gmatch(str, "([^" .. delimiter .. "]+)") do
        table.insert(parts, part)
    end
    return parts
end

local function table_contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local function set_intersection(set1, set2)
    for _, v in pairs(set1) do
        if set2[v] then
            return true
        end
    end
    return false
end

local function _job_weight_bytes(script_path, target_langs_count)
    -- Arbeitsvolumen: Dateigröße × Anzahl der Zielsprachen
    return get_file_size(script_path) * target_langs_count
end

-- Node-Konfiguration
local NODES = {
    node1 = {always_available = true, capacity = "medium", priority = 3, description = "Gateway"},
    node2 = {always_available = false, capacity = "high", priority = 1, description = "ARM Server"},
    node3 = {always_available = false, capacity = "medium", priority = 4, description = "AMD Server"},
    node4 = {always_available = false, capacity = "low", priority = 5, device = "Redmi Note 11S"},
    node5 = {always_available = false, capacity = "high", priority = 2, device = "Lenovo"},
    node6 = {always_available = false, device = "Lenovo (Docker)"},
}

local NODE_NAMES = {
    node2 = {["openclaw-node2"] = true, ["arm64-node"] = true, ["v2202604104722449961"] = true, ["v2202604104722449961.taild25fea.ts.net"] = true, ["100.82.198.122"] = true},
    node3 = {["openclaw-node3"] = true, ["openclaw-node3.taild25fea.ts.net"] = true, ["100.73.154.125"] = true},
    node4 = {["openclaw-node4"] = true, ["redmi-note-11s"] = true, ["redmi-note-11s.taild25fea.ts.net"] = true, ["100.94.134.39"] = true},
    node5 = {["openclaw-node5"] = true, ["windows node (lenovo-7)"] = true},
    node6 = {["openclaw-node6"] = true},
}

local function fetch_node_status()
    -- Return mapped OpenClaw connection states; nil indicates lookup failure
    local success, exit_code, output = pcall(function()
        local handle = io.popen("timeout 10 openclaw nodes status --json 2>/dev/null", "r")
        if not handle then
            return nil
        end
        local result = handle:read("*a")
        handle:close()
        return result
    end)
    
    if not success or not output then
        return nil
    end
    
    local status, payload = pcall(json.decode, output)
    if not status or type(payload) ~= "table" or type(payload.nodes) ~= "table" then
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
                if set_intersection(names, aliases) and item.connected == true then
                    states[node] = true
                end
            end
        end
    end
    
    states.node1 = true  -- successful Gateway status request
    return states
end

local JobDispatcher = {}
JobDispatcher.__index = JobDispatcher

function JobDispatcher:new()
    local obj = {}
    setmetatable(obj, JobDispatcher)
    return obj
end

function JobDispatcher:get_job_weight(script_path, target_langs_count)
    -- Bewertet Job-Gewicht
    if not file_exists(script_path) then
        return "medium"
    end
    
    local total_work = _job_weight_bytes(script_path, target_langs_count or 1)
    
    if total_work > 50000 then  -- > 50KB
        return "heavy"
    elseif total_work > 10000 then  -- > 10KB
        return "medium"
    else
        return "light"
    end
end

function JobDispatcher:select_node(job_weight)
    -- Wählt besten Node basierend auf Job-Gewicht
    local preferred = {}
    if job_weight == "heavy" then
        preferred = {"node1", "node2", "node5", "node6"}
    elseif job_weight == "medium" then
        preferred = {"node1", "node2", "node3", "node6"}
    elseif job_weight == "light" then
        preferred = {"node2", "node1", "node3", "node4"}
    else
        error("Unknown job weight: " .. job_weight)
    end

    local states = fetch_node_status()
    for _, node_id in ipairs(preferred) do
        if states and states[node_id] then
            return node_id
        end
    end
    return nil  -- no verified reachable node
end

function JobDispatcher:check_node_available(node_id)
    -- Use the live connection state rather than static availability
    local states = fetch_node_status()
    return not not (states and states[node_id])
end

function JobDispatcher:_check_mobile_online()
    -- Check Node4 (Redmi)
    return self:check_node_available("node4")
end

function JobDispatcher:dispatch(job_script, target_langs, source_text, source_language)
    -- Dispatched Job und gibt Info zurück
    target_langs = target_langs or {"perl5"}
    
    local weight = self:get_job_weight(job_script, #target_langs)
    local selected_node = self:select_node(weight)
    local translation_jobs = {}
    
    for _, language in ipairs(target_langs) do
        local job = {
            job_id = uuid(),
            source = job_script,
            target_language = language,
            selected_node = selected_node,
        }
        if source_text ~= nil then
            job.source_text = source_text
        end
        if source_language ~= nil then
            job.source_language = source_language
        end
        table.insert(translation_jobs, job)
    end
    
    return {
        job = job_script,
        weight = weight,
        selected_node = selected_node,
        target_langs = target_langs,
        translation_jobs = translation_jobs,
        status = (selected_node and "selected" or "unavailable")
    }
end

function execute_translation(job, transport)
    -- Execute via a supplied transport and verify its result belongs to the job
    if not job.selected_node or transport == nil then
        error("no verified node or authorized translation transport")
    end
    local response = transport(job)
    if type(response) ~= "table" then
        error("invalid transport response")
    end
    for _, key in ipairs({"job_id", "selected_node", "target_language"}) do
        if response[key] ~= job[key] then
            error("transport response does not match job")
        end
    end
    local code = response.code
    if response.status ~= "ok" or type(code) ~= "string" or not code:match("%S") then
        error("translation did not complete with code")
    end
    return code
end

function dispatch_abstraction_job(job_script, target_langs)
    -- Erstellt eine Node-Auswahl und je (Skript, Sprache) einen Auftrag
    local dispatcher = JobDispatcher:new()
    return dispatcher:dispatch(job_script, target_langs)
end

local function main()
    -- Simple argument parsing
    local args = {}
    for i = 1, #arg do
        if arg[i] == "--job" or arg[i] == "-j" then
            args.job = arg[i + 1]
        elseif arg[i] == "--langs" or arg[i] == "-l" then
            args.langs = arg[i + 1]
        elseif arg[i] == "--weight" or arg[i] == "-w" then
            args.weight = arg[i + 1]
        elseif arg[i] == "--execute" or arg[i] == "-x" then
            args.execute = true
        end
    end
    
    if not args.job then
        print("Usage: " .. arg[0] .. " --job JOB_FILE [--langs LANGS] [--weight WEIGHT] [--execute]")
        os.exit(1)
    end
    
    if not file_exists(args.job) then
        print("❌ Job not found: " .. args.job)
        os.exit(1)
    end
    
    local dispatcher = JobDispatcher:new()
    local target_langs = args.langs and split_string(args.langs, ",") or {"perl5"}
    
    -- Determine weight
    local weight
    if args.weight then
        weight = args.weight
    else
        weight = dispatcher:get_job_weight(args.job, #target_langs)
    end
    
    -- Select node
    local selected_node = dispatcher:select_node(weight)
    
    -- Output
    print("📦 Job Dispatch Information")
    print(string.rep("=", 50))
    print("Job: " .. args.job)
    print("Size: " .. get_file_size(args.job) .. " bytes")
    print("Target langs: " .. table.concat(target_langs, ", "))
    print("Job weight: " .. weight)
    print("Selected node: " .. (selected_node or "nil"))
    print(string.rep("=", 50))
    
    if args.execute then
        print("\nTranslation dispatch on " .. (selected_node or "unknown") .. " is not implemented.", "*stderr*")
        return 1
    else
        print("\n💡 To execute: " .. table.concat(arg, " ", 0, #arg) .. " --execute")
    end
    return 0
end

-- Wenn das Skript direkt ausgeführt wird
if arg and arg[0] and arg[0]:match("dispatch_job.lua$") then
    os.exit(main())
end

return {
    JobDispatcher = JobDispatcher,
    dispatch_abstraction_job = dispatch_abstraction_job,
    execute_translation = execute_translation,
    fetch_node_status = fetch_node_status
}
