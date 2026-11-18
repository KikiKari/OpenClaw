#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d252622b26abdac9ffdb90ecf95948f13857229f4ba2eef93097569b2e42ab53", "source_sha256": "f68a161573356fe83ce98ebe454cffaef6896f81d310cd932a9847500e671f9b", "target_language": "lua"}
-- json_processor.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
-- auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local json = require("dkjson")
local argparse = require("argparse")

local HAS_JSON_REPAIR = false
local JSON_REPAIR_WARNING_SHOWN = false

local JSONProcessingError = {name = "JSONProcessingError"}
local JSONValidationError = {name = "JSONValidationError"}
local JSONRepairError = {name = "JSONRepairError"}

function JSONProcessingError:new(message)
    local obj = {message = message}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function JSONValidationError:new(message)
    local obj = {message = message}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function JSONRepairError:new(message)
    local obj = {message = message}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

local function repair_json_string(raw_json)
    if HAS_JSON_REPAIR then
        return raw_json
    else
        if not JSON_REPAIR_WARNING_SHOWN then
            print("Warning: json_repair not available. Using basic repair functions.", io.stderr)
            JSON_REPAIR_WARNING_SHOWN = true
        end
        
        local cleaned = raw_json:gsub("^%s*(.-)%s*$", "%1")
        
        cleaned = cleaned:gsub("//[^\n]*\n", "\n")
        cleaned = cleaned:gsub("/%*.-%*/", "")
        
        cleaned = cleaned:gsub(",(%s*[%]}])", "%1")
        
        cleaned = cleaned:gsub('([^\\]")', function(match)
            return match:gsub('"', '\\"')
        end)
        
        return cleaned
    end
end

local function parse_json(raw_input, repair)
    repair = repair == nil and true or repair
    
    local input = raw_input:gsub("^%s*(.-)%s*$", "%1")
    
    local success, result = pcall(json.decode, input)
    if success then
        return result
    end
    
    if input:find("```") then
        local patterns = {
            "```json%s*(.-)%s*```",
            "```%s*({.-})%s*```",
            "```%s*(%[.-%])%s*```"
        }
        
        for _, pattern in ipairs(patterns) do
            for match in input:gmatch(pattern) do
                local success, parsed = pcall(json.decode, match)
                if success then
                    return parsed
                end
            end
        end
    end
    
    if repair then
        local repaired = repair_json_string(input)
        local success, result = pcall(json.decode, repaired)
        if success then
            return result
        else
            error(JSONProcessingError:new("Could not parse JSON even after repair: " .. tostring(result)))
        end
    end
    
    error(JSONProcessingError:new("Could not parse JSON"))
end

local function parse_and_validate(raw_input, model_class, repair, strict)
    repair = repair == nil and true or repair
    strict = strict or false
    
    local data
    local success, result = pcall(parse_json, raw_input, repair)
    if not success then
        error(JSONValidationError:new("JSON parsing failed: " .. tostring(result)))
    else
        data = result
    end
    
    if model_class and type(model_class.validate) == "function" then
        local success, validated = pcall(model_class.validate, data, strict)
        if not success then
            error(JSONValidationError:new("Validation failed: " .. tostring(validated)))
        end
        return validated
    end
    
    return data
end

local function validate_tool_call(raw_json, tool_name)
    local ToolCall = {
        validate = function(data, strict)
            if type(data) ~= "table" then
                error("Expected table for ToolCall")
            end
            if not data.tool or type(data.tool) ~= "string" then
                error("Missing or invalid 'tool' field")
            end
            if data.arguments and type(data.arguments) ~= "table" then
                error("Invalid 'arguments' field")
            end
            if data.reasoning and type(data.reasoning) ~= "string" then
                error("Invalid 'reasoning' field")
            end
            return {
                tool = data.tool,
                arguments = data.arguments or {},
                reasoning = data.reasoning
            }
        end
    }
    
    local tool_call = parse_and_validate(raw_json, ToolCall, true)
    
    if tool_name and tool_call.tool ~= tool_name then
        error(JSONValidationError:new("Expected tool '" .. tool_name .. "', got '" .. tool_call.tool .. "'"))
    end
    
    return {
        tool = tool_call.tool,
        arguments = tool_call.arguments,
        reasoning = tool_call.reasoning
    }
end

local function safe_json_loads(raw_input, default, repair)
    default = default or nil
    repair = repair == nil and true or repair
    
    local success, result = pcall(parse_json, raw_input, repair)
    if success then
        return result
    else
        return default
    end
end

local function extract_json_from_text(text)
    local results = {}
    
    local function extract_matches(pattern)
        local matches = {}
        for match in text:gmatch(pattern) do
            table.insert(matches, match)
        end
        return matches
    end
    
    local patterns = {
        "{%s*[^{}]*%s*}",
        "%[%s*[^%[%]]*%s*%]"
    }
    
    for _, pattern in ipairs(patterns) do
        local matches = extract_matches(pattern)
        for _, match in ipairs(matches) do
            local success, parsed = pcall(parse_json, match, true)
            if success then
                table.insert(results, parsed)
            end
        end
    end
    
    return results
end

local function main()
    local parser = argparse("json_processor", "JSON Processor with repair")
    parser:argument("input", "JSON string or file path")
    parser:flag("-f --file", "Input is a file path")
    parser:flag("-r --repair", "Enable JSON repair"):default(true)
    parser:flag("--no-repair", "Disable JSON repair"):target("repair"):action("store_false")
    parser:flag("-p --pretty", "Pretty print output")
    
    local args = parser:parse()
    
    local content
    if args.file then
        local file = io.open(args.input, "r")
        if not file then
            print("Error: Could not open file: " .. args.input, io.stderr)
            os.exit(1)
        end
        content = file:read("*a")
        file:close()
    else
        content = args.input
    end
    
    local success, result = pcall(parse_json, content, args.repair)
    if not success then
        print("Error: " .. tostring(result), io.stderr)
        os.exit(1)
    end
    
    local output
    if args.pretty then
        output = json.encode(result, {indent = true})
    else
        output = json.encode(result)
    end
    
    print(output)
end

if pcall(debug.getlocal, 4, 1) then
    return {
        JSONProcessingError = JSONProcessingError,
        JSONValidationError = JSONValidationError,
        JSONRepairError = JSONRepairError,
        repair_json_string = repair_json_string,
        parse_json = parse_json,
        parse_and_validate = parse_and_validate,
        validate_tool_call = validate_tool_call,
        safe_json_loads = safe_json_loads,
        extract_json_from_text = extract_json_from_text
    }
else
    local success, err = pcall(main)
    if not success then
        print("Unexpected error: " .. tostring(err), io.stderr)
        os.exit(1)
    end
end
