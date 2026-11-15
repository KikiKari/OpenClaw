#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f9284c9537008234496d60798f75219e95d3b4f51c4aac0199f57a2fbb5521b9", "source_sha256": "f68a161573356fe83ce98ebe454cffaef6896f81d310cd932a9847500e671f9b", "target_language": "lua"}
-- json_processor.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
-- auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[
JSON Processor mit Validation und JSON-Reparatur.
Für robuste Verarbeitung von LLM-Outputs.
]]

local json = require("cjson")
local argparse = require("argparse")

-- Globale Variablen für Fehlerbehandlung
HAS_JSON_REPAIR = false

-- Hilfsfunktionen für Fehlerbehandlung
function JSONProcessingError(msg)
    return {type = "JSONProcessingError", message = msg}
end

function JSONValidationError(msg)
    return {type = "JSONValidationError", message = msg}
end

function JSONRepairError(msg)
    return {type = "JSONRepairError", message = msg}
end

function throw(error_obj)
    error(error_obj.message .. " (" .. error_obj.type .. ")")
end

-- Funktion zur Reparatur von JSON-Strings
function repair_json_string(raw_json)
    --[[
    Repariert häufige JSON-Fehler aus LLM-Outputs.
    
    Behebt:
    - Trailing commas
    - Einzelne statt doppelte Quotes
    - JavaScript-Style Kommentare
    - Unescaped Zeilenumbrüche in Strings
    ]]
    if HAS_JSON_REPAIR then
        -- Placeholder für tatsächliche Reparaturlogik
        -- In Lua gibt es kein direktes Äquivalent zu json_repair
        -- Daher verwenden wir manuelle Reparaturen als Fallback
    end
    
    local cleaned = raw_json:gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Entferne JavaScript-Kommentare
    cleaned = cleaned:gsub("//.-\n", "\n")
    cleaned = cleaned:gsub("/%*.-%*/", "", 1)
    
    -- Entferne trailing commas vor ] oder }
    cleaned = cleaned:gsub(",(%s*[}%]])", "%1")
    
    return cleaned
end

-- Funktion zum Parsen von JSON
function parse_json(raw_input, repair)
    repair = repair ~= false  -- Standardmäßig true
    
    raw_input = raw_input:gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Versuche zuerst direktes Parsing
    local success, result = pcall(json.decode, raw_input)
    if success then
        return result
    end
    
    -- Extrahiere JSON aus Markdown-Code-Blöcken
    if raw_input:find("```") then
        -- Suche nach JSON in ```json ... ``` oder ``` ... ```
        local patterns = {
            "```json%s*(.-)%s*```",
            "``````%s*({.-})%s*```",
            "``````%s*(%[.-%])%s*```"
        }
        
        for _, pattern in ipairs(patterns) do
            local matches = {}
            for match in raw_input:gmatch(pattern) do
                table.insert(matches, match)
            end
            
            for _, match in ipairs(matches) do
                local success, parsed = pcall(json.decode, match)
                if success then
                    return parsed
                end
            end
        end
    end
    
    -- Versuche Reparatur
    if repair then
        local success, repaired = pcall(repair_json_string, raw_input)
        if success then
            local success2, result2 = pcall(json.decode, repaired)
            if success2 then
                return result2
            else
                throw(JSONProcessingError("Could not parse JSON even after repair: " .. result2))
            end
        else
            throw(JSONRepairError("JSON repair failed: " .. repaired))
        end
    end
    
    throw(JSONProcessingError("Could not parse JSON"))
end

-- Funktion zur sicheren JSON-Ladung mit Default-Wert
function safe_json_loads(raw_input, default, repair)
    repair = repair ~= false  -- Standardmäßig true
    default = default or nil
    
    local success, result = pcall(parse_json, raw_input, repair)
    if success then
        return result
    else
        return default
    end
end

-- Funktion zur Extraktion von JSON aus Text
function extract_json_from_text(text)
    local results = {}
    
    -- Pattern für JSON-Objekte und Arrays
    local patterns = {
        "{[^{}]*(?:{[^{}]*}[^{}]*)*}",  -- Objekte
        "%[[^%[%]]*(?:%[[^%[%]*%][^%[%]]*)*%]"  -- Arrays
    }
    
    for _, pattern in ipairs(patterns) do
        for match in text:gmatch(pattern) do
            local success, parsed = pcall(parse_json, match, true)
            if success then
                table.insert(results, parsed)
            end
        end
    end
    
    return results
end

-- Hauptprogramm
local function main()
    local parser = argparse()
    parser:argument("input", "JSON string or file path")
    parser:flag("-f --file", "Input is a file path")
    parser:flag("-r --repair", "Enable JSON repair"):default(true)
    parser:flag("-p --pretty", "Pretty print output")
    parser:flag("--no-repair", "Disable JSON repair"):action("store_false")
    
    local args = parser:parse()
    
    local content
    if args.file then
        local file = io.open(args.input, "r")
        if not file then
            io.stderr:write("Error: Could not open file " .. args.input .. "\n")
            os.exit(1)
        end
        content = file:read("*all")
        file:close()
    else
        content = args.input
    end
    
    local success, result = pcall(parse_json, content, args.repair)
    if success then
        local output
        if args.pretty then
            -- Pretty-printing in Lua ist begrenzt, daher verwenden wir cjson's encode_pretty falls verfügbar
            if json.encode_pretty then
                output = json.encode_pretty(result)
            else
                output = json.encode(result)
            end
        else
            output = json.encode(result)
        end
        print(output)
    else
        io.stderr:write("Error: " .. result .. "\n")
        os.exit(1)
    end
end

-- Starte das Hauptprogramm, wenn dieses Skript direkt ausgeführt wird
if arg and arg[0] and arg[0]:match("json_processor.lua$") then
    main()
end

-- Exportiere Funktionen für externe Nutzung
return {
    parse_json = parse_json,
    safe_json_loads = safe_json_loads,
    extract_json_from_text = extract_json_from_text,
    repair_json_string = repair_json_string
}
