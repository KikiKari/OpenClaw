#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "dca8fb9f6ab85181a8bdd649b2c47797c5eac2746969f341e1ba930d602776be", "source_sha256": "28ad3a35010164ac39fa0365d55c13b161321427a1a3be5a36fa3f7c01805c2b", "target_language": "lua"}
-- test-embeddings.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
-- auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
-- auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
-- auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
-- auch in: 4 weiteren Fundstellen
-- Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- Ensure PERPLEXITY_API_KEY is set
local api_key = os.getenv("PERPLEXITY_API_KEY")
if not api_key then
    io.stderr:write("PERPLEXITY_API_KEY is required\n")
    os.exit(1)
end

-- Temporary file path
local tmpdir = os.getenv("TMPDIR") or "/tmp"
local out = tmpdir .. "/perplexity-embeddings-test.json"

-- Payload data
local payload_data = {
    input = {
        "Scientists explore the universe driven by curiosity.",
        "Curiosity compels us to seek explanations, not just observations.",
        "Historical discoveries began with curious questions.",
        "The pursuit of knowledge distinguishes human curiosity from mere stimulus response.",
        "Philosophy examines the nature of curiosity."
    },
    model = "pplx-embed-v1-4b"
}

local payload = json.encode(payload_data)

-- HTTP request
local response_body = {}
local res, code, headers, status = http.request {
    url = "https://api.perplexity.ai/v1/embeddings",
    method = "POST",
    headers = {
        ["Authorization"] = "Bearer " .. api_key,
        ["Content-Type"] = "application/json",
        ["Content-Length"] = tostring(#payload)
    },
    source = ltn12.source.string(payload),
    sink = ltn12.sink.table(response_body)
}

-- Write response to file
local file = io.open(out, "w")
if file then
    file:write(table.concat(response_body))
    file:close()
end

-- Output HTTP status code
print("embeddings_http=" .. (code or "nil"))

-- Read and process JSON response
local file = io.open(out, "r")
if file then
    local content = file:read("*a")
    file:close()
    local data = json.decode(content)

    -- Mimic jq processing
    local result = {
        keys = {},
        model = data.model or nil,
        item_count = data.data and #data.data or 0,
        first_dim = (data.data and data.data[1] and data.data[1].embedding) and #data.data[1].embedding or 0,
        error = data.error or nil
    }

    -- Collect keys
    for k, _ in pairs(data) do
        table.insert(result.keys, k)
    end

    -- Print result as JSON
    print(json.encode(result))
else
    print('{"keys":[],"model":null,"item_count":0,"first_dim":0,"error":"Failed to read response file"}')
end
