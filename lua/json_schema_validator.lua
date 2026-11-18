#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "3ea9751c751d115876a0448c46b060243cf7177d8c0c5141d1d5d32383975bf0", "source_sha256": "f55ff3c9a1d0fb13ff0d5dd08f91e1c1a304c7d83f3d1bb93f165f2437d276b9", "target_language": "lua"}
-- json_schema_validator.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
-- auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

local json = require("dkjson")
local argparse = require("argparse")

local HAS_JSONSCHEMA = pcall(require, "jsonschema")

local SchemaValidationError = {}
SchemaValidationError.__index = SchemaValidationError

function SchemaValidationError.new(message)
    local self = setmetatable({}, SchemaValidationError)
    self.message = message
    return self
end

function SchemaValidationError:__tostring()
    return "SchemaValidationError: " .. self.message
end

local function load_schema(schema_source)
    if type(schema_source) == "table" then
        return schema_source
    end
    
    local file = io.open(schema_source, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local ok, result = pcall(json.decode, content)
        if not ok then
            error(SchemaValidationError.new("Invalid JSON in schema file: " .. result))
        end
        return result
    end
    
    local ok, result = pcall(json.decode, schema_source)
    if not ok then
        error(SchemaValidationError.new("Schema not found or invalid: " .. schema_source))
    end
    return result
end

local function validate_with_jsonschema(data, schema, draft)
    if not HAS_JSONSCHEMA then
        error(SchemaValidationError.new("jsonschema not installed. Run: luarocks install jsonschema"))
    end
    
    local schema_dict = load_schema(schema)
    local jsonschema = require("jsonschema")
    
    local ok, err = pcall(jsonschema.validate, data, schema_dict)
    if not ok then
        if type(err) == "table" and err.message then
            local path = {}
            if err.path then
                for segment in string.gmatch(err.path, "[^%.]+") do
                    table.insert(path, segment)
                end
            end
            error(SchemaValidationError.new("Schema validation failed: " .. err.message .. " at " .. json.encode(path)))
        else
            error(SchemaValidationError.new("Schema validation failed: " .. tostring(err)))
        end
    end
    return true
end

local function pydantic_to_jsonschema(model_class)
    error(SchemaValidationError.new("Pydantic conversion not supported in Lua"))
end

local function parse_json(raw_input, repair)
    if repair then
        raw_input = string.gsub(raw_input, "([^,:{}%[%]\"']-):", "%1:")
        raw_input = string.gsub(raw_input, "(['\"])-([^\"']*)(['\"])", function(open, content, close)
            if open == close then
                return open .. content .. close
            else
                return open .. content .. open
            end
        end)
    end
    
    local ok, result = pcall(json.decode, raw_input)
    if not ok then
        error(SchemaValidationError.new("JSON parsing failed: " .. result))
    end
    return result
end

local function validate_and_convert(raw_input, schema, repair)
    repair = repair == nil and true or repair
    local data = parse_json(raw_input, repair)
    validate_with_jsonschema(data, schema)
    return data
end

local SchemaBuilder = {}

function SchemaBuilder.object(properties, required)
    local schema = {
        type = "object",
        properties = properties
    }
    if required then
        schema.required = required
    end
    return schema
end

function SchemaBuilder.string(enum, pattern, min_length)
    local schema = {type = "string"}
    if enum then
        schema.enum = enum
    end
    if pattern then
        schema.pattern = pattern
    end
    if min_length then
        schema.minLength = min_length
    end
    return schema
end

function SchemaBuilder.integer(minimum, maximum)
    local schema = {type = "integer"}
    if minimum then
        schema.minimum = minimum
    end
    if maximum then
        schema.maximum = maximum
    end
    return schema
end

function SchemaBuilder.array(items, min_items)
    local schema = {type = "array", items = items}
    if min_items then
        schema.minItems = min_items
    end
    return schema
end

local function main()
    local parser = argparse("json_schema_validator", "JSON Schema Validator")
    parser:argument("input", "JSON file or string")
    parser:option("-s --schema", "Schema file"):count(1)
    parser:flag("-f --file", "Input is file")
    parser:flag("-r --repair", "Attempt repair"):default(true)
    
    local args = parser:parse()
    
    local raw_input
    local file = io.open(args.input, "r")
    if args.file or file then
        if file then
            raw_input = file:read("*a")
            file:close()
        else
            io.stderr:write("File not found: " .. args.input .. "\n")
            os.exit(1)
        end
    else
        raw_input = args.input
    end
    
    local ok, result = pcall(validate_and_convert, raw_input, args.schema, args.repair)
    if not ok then
        io.stderr:write("✗ Validation failed: " .. tostring(result) .. "\n")
        os.exit(1)
    else
        print(json.encode(result, {indent = true}))
        io.stderr:write("\n✓ Validation passed\n")
    end
end

if arg and #arg > 0 and not string.match(arg[0], "lua$") and not string.match(arg[0], "luajit$") then
    main()
end
