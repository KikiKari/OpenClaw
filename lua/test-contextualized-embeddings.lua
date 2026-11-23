#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "cccffe302fec197d512feed5ff2cd665058a539d85c5d27d3f915161a78916b9", "source_sha256": "9b72cb69e140323c5b1a7fb2297d54571e6dc00329fc26e09bf42f52e6dae2ba", "target_language": "lua"}
-- test-contextualized-embeddings.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
-- auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
-- auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
-- auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
-- auch in: 4 weiteren Fundstellen
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local json = require("cjson")
local http = require("socket.http")
local ltn12 = require("ltn12")

-- Prüfe ob PERPLEXITY_API_KEY gesetzt ist
if not os.getenv("PERPLEXITY_API_KEY") then
    error("PERPLEXITY_API_KEY is required")
end

local out = (os.getenv("TMPDIR") or "/tmp") .. "/perplexity-contextualized-embeddings-test.json"

-- Erstelle Payload
local payload = {
    input = {{
        "OpenClaw can route web search through Perplexity.",
        "The Perplexity MCP server exposes search and reasoning tools.",
        "Contextualized embeddings improve document chunk retrieval."
    }},
    model = "pplx-embed-context-v1-4b"
}

local payload_json = json.encode(payload)

-- Führe HTTP-Request durch
local response_body = {}
local res, code, headers, status = http.request{
    url = "https://api.perplexity.ai/v1/contextualizedembeddings",
    method = "POST",
    headers = {
        ["Authorization"] = "Bearer " .. os.getenv("PERPLEXITY_API_KEY"),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #payload_json
    },
    source = ltn12.source.string(payload_json),
    sink = ltn12.sink.table(response_body)
}

-- Schreibe Antwort in Datei
local file = io.open(out, "w")
if file then
    file:write(table.concat(response_body))
    file:close()
end

print("contextualized_embeddings_http=" .. (code or "nil"))

-- Lese und verarbeite JSON-Antwort
local response_json = table.concat(response_body)
local success, response_data = pcall(json.decode, response_json)

if success then
    local result = {
        keys = {},
        model = response_data.model or nil,
        document_count = 0,
        first_chunk_count = 0,
        error = response_data.error or nil
    }
    
    -- Sammle Schlüssel
    for k, _ in pairs(response_data) do
        table.insert(result.keys, k)
    end
    
    -- Zähle Dokumente
    if response_data.data then
        result.document_count = #response_data.data
        
        -- Zähle Chunks im ersten Dokument
        if response_data.data[1] and response_data.data[1].data then
            result.first_chunk_count = #response_data.data[1].data
        end
    end
    
    print(json.encode(result))
else
    print('{"keys":[],"model":null,"document_count":0,"first_chunk_count":0,"error":"Failed to parse JSON"}')
end
