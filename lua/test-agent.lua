#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "24cc9a99d66be7a53c60554255f2578a39fb46bc4488d1f3f4f525dabf8346ec", "source_sha256": "4206ddea85e6e63865388488399d2e874412555d623d8758c0369a860e6a0315", "target_language": "lua"}
-- test-agent.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-agent.sh
-- auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-agent.sh
-- auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-agent.sh
-- auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-agent.sh
-- auch in: 4 weiteren Fundstellen
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- Function to get environment variable or error if not set
local function getenv_or_error(name)
  local value = os.getenv(name)
  if not value then
    error(name .. " is required")
  end
  return value
end

-- Get API key from environment
local PERPLEXITY_API_KEY = getenv_or_error("PERPLEXITY_API_KEY")

-- Get prompt from command line or use default
local prompt = arg[1] or "Compare recent open-source LLMs in terms of performance, licensing, and practical use."

-- Determine temp directory
local tmpdir = os.getenv("TMPDIR") or "/tmp"
local out = tmpdir .. "/perplexity-agent-test.json"

-- Create JSON payload
local payload = json.encode({
  preset = "fast-search",
  input = prompt
})

-- Prepare request
local response_body = {}
local headers = {
  ["Authorization"] = "Bearer " .. PERPLEXITY_API_KEY,
  ["Content-Type"] = "application/json",
  ["Content-Length"] = tostring(#payload)
}

-- Make HTTP request
local code, headers, status = http.request{
  url = "https://api.perplexity.ai/v1/agent",
  method = "POST",
  headers = headers,
  source = ltn12.source.string(payload),
  sink = ltn12.sink.table(response_body)
}

-- Write response to file
local file = io.open(out, "w")
if file then
  file:write(table.concat(response_body))
  file:close()
end

-- Print status code
print("agent_http=" .. (code or "nil"))

-- Process and print response summary
local success, response_data = pcall(json.decode, table.concat(response_body))
if success then
  local result = {
    keys = {},
    id = response_data.id or nil,
    status = response_data.status or nil,
    output_count = response_data.output and #response_data.output or 0,
    error = response_data.error or nil
  }
  
  -- Collect keys
  for k, _ in pairs(response_data) do
    table.insert(result.keys, k)
  end
  
  print(json.encode(result))
else
  print('{"keys":[],"id":null,"status":null,"output_count":0,"error":"Failed to parse response"}')
end
