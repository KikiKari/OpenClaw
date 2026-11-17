#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "9d13816c8f8daca5bf0fcf775a87df91a682879fba79a6812bb5e4040443a16f", "source_sha256": "d3ab9d6951153a42390fb59c1a50b0c901cf4c399dcb731b89865fdc293f3ac9", "target_language": "lua"}
-- json_websearch.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/json_websearch.py
-- auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/json_websearch.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
JSON Utils + WebSearch integration.
Fetch API schemas from web, validate real API responses, batch-validate endpoints.
]]

local json = require("cjson")
local pl_path = require("pl.path")
local pl_dir = require("pl.dir")

-- Add json-utils to path
package.path = package.path .. ";" .. pl_path.dirname(pl_path.dirname(pl_path.dirname(arg[0]))) .. "/json-utils/scripts/?.lua"

local JSON_UTILS_AVAILABLE = false
local parse_json, parse_and_validate, validate_with_jsonschema, process_file_batch

local function load_json_utils()
    local success, err = pcall(function()
        local json_processor = require("json_processor")
        local json_schema_validator = require("json_schema_validator")
        local json_batch_processor = require("json_batch_processor")
        parse_json = json_processor.parse_json
        parse_and_validate = json_processor.parse_and_validate
        validate_with_jsonschema = json_schema_validator.validate_with_jsonschema
        process_file_batch = json_batch_processor.process_file_batch
        JSON_UTILS_AVAILABLE = true
    end)
    if not success then
        print("Warning: json-utils not found. Some features disabled.")
    end
end

load_json_utils()

local WebSearchResult = {}
WebSearchResult.__index = WebSearchResult

function WebSearchResult:new(query, json_data, validation_errors, schema_matched, source_url)
    local obj = {
        query = query,
        json_data = json_data,
        validation_errors = validation_errors or {},
        schema_matched = schema_matched or false,
        source_url = source_url
    }
    setmetatable(obj, WebSearchResult)
    return obj
end

local WebSearchJSON = {}
WebSearchJSON.__index = WebSearchJSON

function WebSearchJSON:new(use_repair)
    local obj = {
        use_repair = use_repair or true,
        json_available = JSON_UTILS_AVAILABLE
    }
    setmetatable(obj, WebSearchJSON)
    return obj
end

--[[
Search web for JSON data, validate against schema.

This is a placeholder - in real usage, this would:
1. Call WebSearch to find API docs
2. Extract JSON examples/schemas from results
3. Parse and validate with json-utils
]]
function WebSearchJSON:search_and_validate(query, schema, schema_path)
    -- Simulate web search result (would be actual search in production)
    local mock_response = {
        api = query and query:match("^([^%s]+)") or "unknown",
        version = "1.0",
        endpoints = {
            {path = "/items", method = "GET"},
            {path = "/items", method = "POST"}
        }
    }

    -- Validate with json-utils if available
    local validation_errors = {}
    local schema_matched = false

    if self.json_available and (schema or schema_path) then
        local success, err = pcall(function()
            if schema_path then
                validate_with_jsonschema(mock_response, tostring(schema_path))
            end
            schema_matched = true
        end)
        if not success then
            table.insert(validation_errors, tostring(err))
        end
    end

    return WebSearchResult:new(
        query,
        mock_response,
        validation_errors,
        schema_matched,
        "https://api.github.com/search?q=" .. (query and query:gsub(" ", "+") or "")
    )
end

--[[
Validate an API response with auto-repair.

Uses json-utils for robust parsing.
]]
function WebSearchJSON:validate_api_response(response_data, endpoint, expected_schema)
    if not self.json_available then
        return json.decode(response_data)
    end

    -- Use json-utils parser with auto-repair
    local result = parse_json(response_data, self.use_repair)

    if expected_schema then
        local success, err = pcall(function()
            parse_and_validate(json.encode(result), expected_schema)
        end)
        if not success then
            print("Schema validation failed for " .. endpoint .. ": " .. tostring(err))
        end
    end

    return result
end

--[[
Batch-validate multiple API endpoint responses.
]]
function WebSearchJSON:batch_validate_endpoints(endpoints, responses, schema_path)
    local results = {}
    for i, endpoint in ipairs(endpoints) do
        local response = responses[i]
        local success, result_or_error = pcall(function()
            local json_data = self:validate_api_response(response, endpoint)
            return WebSearchResult:new(endpoint, json_data, {}, true, endpoint)
        end)
        if success then
            table.insert(results, result_or_error)
        else
            table.insert(results, WebSearchResult:new(endpoint, {}, {tostring(result_or_error)}, false, endpoint))
        end
    end
    return results
end

--[[
Generate JSON Schema from sample API response.
]]
function WebSearchJSON:generate_api_schema(sample_response, endpoint)
    if not self.json_available then
        return {}
    end

    local data = parse_json(sample_response)

    -- Basic schema generation
    local function infer_schema(obj, path)
        path = path or "root"
        if type(obj) == "table" then
            if next(obj) ~= nil and type(next(obj)) == "string" then
                -- Object
                local properties = {}
                for k, v in pairs(obj) do
                    properties[k] = infer_schema(v, path .. "." .. k)
                end
                return {
                    type = "object",
                    properties = properties
                }
            elseif #obj > 0 then
                -- Array
                return {
                    type = "array",
                    items = infer_schema(obj[1], path .. "[]")
                }
            else
                return {type = "object", properties = {}}
            end
        elseif type(obj) == "string" then
            return {type = "string"}
        elseif type(obj) == "number" then
            if math.type(obj) == "integer" then
                return {type = "integer"}
            else
                return {type = "number"}
            end
        elseif type(obj) == "boolean" then
            return {type = "boolean"}
        else
            return {type = "null"}
        end
    end

    local schema = {
        ["$schema"] = "http://json-schema.org/draft-07/schema#",
        title = endpoint .. " Response Schema"
    }
    local inferred = infer_schema(data)
    for k, v in pairs(inferred) do
        schema[k] = v
    end

    return schema
end

local function main()
    local argparse = require("argparse")
    local parser = argparse("json_websearch.lua", "JSON Utils + WebSearch integration")
    parser:option("--search", "Search query for API docs")
    parser:option("--validate-file", "JSON file to validate"):convert(pl_path.abspath)
    parser:option("--schema", "Schema file path"):convert(pl_path.abspath)
    parser:option("--generate-schema", "Generate schema from sample JSON file"):convert(pl_path.abspath)
    parser:option("--endpoint", "API endpoint identifier")
    local args = parser:parse()

    local ws = WebSearchJSON:new()

    if args.search then
        local result = ws:search_and_validate(args.search, nil, args.schema)
        print("Query: " .. result.query)
        print("Data: " .. json.encode(result.json_data, {indent = true}))
        print("Schema matched: " .. tostring(result.schema_matched))
        if #result.validation_errors > 0 then
            print("Errors: " .. table.concat(result.validation_errors, ", "))
        end
    elseif args.generate_schema and args.endpoint then
        local file = io.open(args.generate_schema, "r")
        if not file then
            error("Could not open file: " .. args.generate_schema)
        end
        local sample = file:read("*all")
        file:close()
        local schema = ws:generate_api_schema(sample, args.endpoint)
        print(json.encode(schema, {indent = true}))
    end
end

if arg and arg[0] and arg[0]:find("json_websearch.lua") then
    main()
end

return {
    WebSearchResult = WebSearchResult,
    WebSearchJSON = WebSearchJSON
}
