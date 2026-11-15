#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "03d65f91a4eb06dcb15dc83bd15e80936b821679c1f97974b5c24241490bfdf6", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "lua"}
-- json_batch_processor.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
-- auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[
Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).
]]

local json = require("cjson")
local argparse = require("argparse")
local pl_path = require("pl.path")
local pl_utils = require("pl.utils")
local pl_tablex = require("pl.tablex")

-- Globale Variablen
HAS_PYDANTIC = false -- In Lua nicht verfügbar

-- Hilfsfunktionen
function split(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Fehlerbehandlung
JSONProcessingError = {}
JSONProcessingError.__index = JSONProcessingError

function JSONProcessingError:new(message)
    local instance = {
        message = message
    }
    setmetatable(instance, JSONProcessingError)
    return instance
end

function JSONProcessingError:__tostring()
    return self.message
end

-- BatchResult Klasse
BatchResult = {}
BatchResult.__index = BatchResult

function BatchResult:new(index, source, success, data, error_msg)
    local instance = {
        index = index or 0,
        source = source or "",
        success = success or false,
        data = data,
        error = error_msg
    }
    setmetatable(instance, BatchResult)
    return instance
end

function BatchResult:to_dict()
    return {
        index = self.index,
        source = self.source,
        success = self.success,
        data = self.data,
        error = self.error
    }
end

-- JSON Processor Funktionen
function parse_json(content, repair)
    -- In Lua einfache JSON-Validierung
    local status, result = pcall(json.decode, content)
    if not status then
        if repair then
            -- Versuche einfache Reparaturen
            local repaired = content:gsub("\\\"", "\"") -- Entferne überflüssige Escapes
            status, result = pcall(json.decode, repaired)
        end
        
        if not status then
            error(JSONProcessingError:new("Invalid JSON: " .. tostring(result)))
        end
    end
    return result
end

function parse_and_validate(content, validate_model, repair)
    -- In Lua ohne Pydantic nur Basisvalidierung
    return parse_json(content, repair)
end

-- Liest JSON-Lines (NDJSON) Datei Zeile für Zeile
function read_jsonl(file_path)
    local results = {}
    local file, err = io.open(file_path, "r")
    if not file then
        error("Cannot open file: " .. err)
    end
    
    local line_num = 1
    for line in file:lines() do
        line = trim(line)
        if line ~= "" then
            local status, data = pcall(json.decode, line)
            if status then
                table.insert(results, data)
            else
                table.insert(results, BatchResult:new(
                    line_num,
                    file_path .. ":" .. line_num,
                    false,
                    nil,
                    "JSON decode error: " .. tostring(data)
                ))
            end
        end
        line_num = line_num + 1
    end
    file:close()
    return results
end

-- Verarbeitet eine Liste von Inputs parallel (sequentiell in Lua)
function process_batch(inputs, processor, max_workers)
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
                "Unexpected error: " .. tostring(result)
            ))
        end
    end
    
    -- Sortiere nach Index
    table.sort(results, function(a, b) return a.index < b.index end)
    return results
end

-- Verarbeitet mehrere JSON-Dateien im Batch
function process_file_batch(file_paths, repair, validate_model, max_workers)
    local function processor(path, idx)
        local content, err = pl_utils.readfile(path)
        if not content then
            return BatchResult:new(
                idx,
                tostring(path),
                false,
                nil,
                "File read error: " .. tostring(err)
            )
        end
        
        local status, data = pcall(function()
            if validate_model and HAS_PYDANTIC then
                return parse_and_validate(content, validate_model, repair)
            else
                return parse_json(content, repair)
            end
        end)
        
        if status then
            return BatchResult:new(
                idx,
                tostring(path),
                true,
                data
            )
        else
            return BatchResult:new(
                idx,
                tostring(path),
                false,
                nil,
                tostring(data)
            )
        end
    end
    
    return process_batch(file_paths, processor, max_workers)
end

-- Verarbeitet eine JSON-Lines Datei
function process_jsonl_file(file_path, repair, validate_model)
    local results = {}
    local file, err = io.open(file_path, "r")
    if not file then
        error("Cannot open file: " .. err)
    end
    
    local line_num = 1
    for line in file:lines() do
        line = trim(line)
        if line ~= "" then
            local status, data = pcall(function()
                if validate_model and HAS_PYDANTIC then
                    return parse_and_validate(line, validate_model, repair)
                else
                    return parse_json(line, repair)
                end
            end)
            
            if status then
                table.insert(results, BatchResult:new(
                    line_num,
                    file_path .. ":" .. line_num,
                    true,
                    data
                ))
            else
                table.insert(results, BatchResult:new(
                    line_num,
                    file_path .. ":" .. line_num,
                    false,
                    nil,
                    tostring(data)
                ))
            end
        end
        line_num = line_num + 1
    end
    file:close()
    return results
end

-- Schreibt BatchResult-Liste als JSON-Lines
function write_jsonl(results, output_path, only_successful)
    only_successful = only_successful or true
    local file, err = io.open(output_path, "w")
    if not file then
        error("Cannot write to file: " .. err)
    end
    
    for _, result in ipairs(results) do
        if not (only_successful and not result.success) then
            file:write(json.encode(result:to_dict()) .. "\n")
        end
    end
    file:close()
end

-- Hauptprogramm
function main()
    local parser = argparse.ArgumentParser()
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
        local file_paths = args.inputs
        all_results = process_file_batch(file_paths, args.repair, nil, args.workers)
    end
    
    -- Ausgabe
    local successful = 0
    for _, r in ipairs(all_results) do
        if r.success then
            successful = successful + 1
        end
    end
    local failed = #all_results - successful
    
    if args.summary then
        print("Processed: " .. #all_results)
        print("Successful: " .. successful)
        print("Failed: " .. failed)
    else
        for _, result in ipairs(all_results) do
            if result.success then
                print(json.encode(result.data))
            else
                io.stderr:write("ERROR [" .. result.source .. "]: " .. tostring(result.error) .. "\n")
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
