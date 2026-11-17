#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "79cb011d39fdb836a5df697d9ccaa48abe68b8e7a8370f707177f998557a6e85", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "lua"}
-- json_batch_processor.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
-- auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).
]]

local json = require("cjson")
local argparse = require("argparse")

-- Hilfsfunktionen für Dateioperationen
local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        error("Could not open file: " .. path)
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function write_file(path, content)
    local file = io.open(path, "w")
    if not file then
        error("Could not write to file: " .. path)
    end
    file:write(content)
    file:close()
end

-- BatchResult Klasse
local BatchResult = {}
BatchResult.__index = BatchResult

function BatchResult:new(index, source, success, data, error_msg)
    local obj = {
        index = index,
        source = source,
        success = success,
        data = data,
        error = error_msg
    }
    setmetatable(obj, BatchResult)
    return obj
end

function BatchResult:to_table()
    return {
        index = self.index,
        source = self.source,
        success = self.success,
        data = self.data,
        error = self.error
    }
end

-- JSON Processing Funktionen (vereinfacht)
local function parse_json(content, repair)
    -- Vereinfachte Implementierung ohne Reparatur
    local status, result = pcall(json.decode, content)
    if not status then
        error("JSON decode error: " .. result)
    end
    return result
end

-- Liest JSON-Lines Datei
local function read_jsonl(file_path)
    local lines = {}
    local file = io.open(file_path, "r")
    if not file then
        error("Could not open file: " .. file_path)
    end
    
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    return lines
end

-- Verarbeitet eine Liste von Inputs parallel (simuliert)
local function process_batch(inputs, processor, max_workers)
    local results = {}
    
    for idx, inp in ipairs(inputs) do
        local status, result = pcall(processor, inp, idx)
        if status then
            table.insert(results, result)
        else
            table.insert(results, BatchResult:new(
                idx,
                tostring(inp),
                false,
                nil,
                "Unexpected error: " .. result
            ))
        end
    end
    
    -- Sortieren nach Index
    table.sort(results, function(a, b) return a.index < b.index end)
    return results
end

-- Verarbeitet mehrere JSON-Dateien im Batch
local function process_file_batch(file_paths, repair, max_workers)
    local function processor(path, idx)
        local content = read_file(path)
        local data = parse_json(content, repair)
        return BatchResult:new(idx, path, true, data, nil)
    end
    
    return process_batch(file_paths, processor, max_workers)
end

-- Verarbeitet eine JSON-Lines Datei
local function process_jsonl_file(file_path, repair)
    local results = {}
    local lines = read_jsonl(file_path)
    
    for line_num, line in ipairs(lines) do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            local status, data = pcall(parse_json, line, repair)
            if status then
                table.insert(results, BatchResult:new(
                    line_num,
                    file_path .. ":" .. line_num,
                    true,
                    data,
                    nil
                ))
            else
                table.insert(results, BatchResult:new(
                    line_num,
                    file_path .. ":" .. line_num,
                    false,
                    nil,
                    data
                ))
            end
        end
    end
    
    return results
end

-- Schreibt BatchResult-Liste als JSON-Lines
local function write_jsonl(results, output_path, only_successful)
    local file = io.open(output_path, "w")
    if not file then
        error("Could not write to file: " .. output_path)
    end
    
    for _, result in ipairs(results) do
        if not only_successful or result.success then
            file:write(json.encode(result:to_table()) .. "\n")
        end
    end
    file:close()
end

-- Hauptfunktion
local function main()
    local parser = argparse("json_batch_processor", "Batch JSON Processor")
    parser:argument("inputs", "JSON files to process"):args("+")
    parser:flag("-l --jsonl", "Treat inputs as JSON-Lines files")
    parser:flag("-r --repair", "Enable JSON repair"):default(true)
    parser:option("-w --workers", "Parallel workers"):default(4):convert(tonumber)
    parser:option("-o --output", "Output JSON-Lines file")
    parser:flag("-s --summary", "Show summary only")
    
    local args = parser:parse()
    
    local all_results = {}
    
    if args.jsonl then
        -- JSON-Lines Modus
        for _, input_path in ipairs(args.inputs) do
            local results = process_jsonl_file(input_path, args.repair)
            for _, result in ipairs(results) do
                table.insert(all_results, result)
            end
        end
    else
        -- Standard JSON Batch
        all_results = process_file_batch(args.inputs, args.repair, args.workers)
    end
    
    -- Statistiken
    local successful = 0
    for _, result in ipairs(all_results) do
        if result.success then
            successful = successful + 1
        end
    end
    local failed = #all_results - successful
    
    -- Ausgabe
    if args.summary then
        print("Processed: " .. #all_results)
        print("Successful: " .. successful)
        print("Failed: " .. failed)
    else
        for _, result in ipairs(all_results) do
            if result.success then
                print(json.encode(result.data))
            else
                io.stderr:write("ERROR [" .. result.source .. "]: " .. (result.error or "Unknown error") .. "\n")
            end
        end
    end
    
    -- Optional: JSONL Output
    if args.output then
        write_jsonl(all_results, args.output, false)
        io.stderr:write("\nResults written to: " .. args.output .. "\n")
    end
    
    -- Exit code
    os.exit(failed == 0 and 0 or 1)
end

main()
