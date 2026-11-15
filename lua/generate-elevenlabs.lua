#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "de319bddd444b39a9a8193dad5c3ba717c76dcbee6af419ea981d3dcbf9d6432", "source_sha256": "4112b3dbe78c8a495b73f6feaebe05ada553911d2e25f6bd1e2e4d704a6ac1b6", "target_language": "lua"}
-- generate-elevenlabs.mjs — portiert nach lua
-- Quelle: javascript, Onboarding@main:scripts/generate-elevenlabs.mjs
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("cjson")
local io = require("io")
local os = require("os")

-- Helper function to create directories recursively
local function mkdir(path)
    local dirs = {}
    for dir in string.gmatch(path, "([^/]+)") do
        table.insert(dirs, dir)
    end
    local current_path = ""
    for i, dir in ipairs(dirs) do
        current_path = current_path .. dir
        if i < #dirs then
            current_path = current_path .. "/"
        end
        os.execute("mkdir -p " .. current_path)
    end
end

-- Environment variables
local key = os.getenv("ELEVENLABS_API_KEY")
local voiceId = os.getenv("ELEVENLABS_VOICE_ID") or "JBFqnCBsd6RMkjVDRZzb"

if not key then
    error("ELEVENLABS_API_KEY fehlt.")
end

local text = "Neun Projekte. Zwei Plattformen. Ein Ort, an dem Ideen verbunden und weiterentwickelt werden."

-- Prepare request data
local requestData = {
    text = text,
    model_id = "eleven_multilingual_v2",
    voice_settings = {
        stability = 0.58,
        similarity_boost = 0.72,
        style = 0.18,
        use_speaker_boost = true
    }
}

local body = json.encode(requestData)

-- Make the HTTP request
local response_body = {}
local res, code, headers, status = https.request{
    url = "https://api.elevenlabs.io/v1/text-to-speech/" .. voiceId .. "?output_format=mp3_44100_128",
    method = "POST",
    headers = {
        ["xi-api-key"] = key,
        ["Content-Type"] = "application/json",
        ["Content-Length"] = tostring(#body)
    },
    source = ltn12.source.string(body),
    sink = ltn12.sink.table(response_body)
}

if code ~= 200 then
    error("ElevenLabs fehlgeschlagen: " .. tostring(code))
end

-- Create directories
mkdir("public/audio/")
mkdir("media-production/")

-- Write MP3 file
local mp3_file = io.open("public/audio/project-narration.mp3", "wb")
mp3_file:write(table.concat(response_body))
mp3_file:close()

-- Write JSON result file
local resultData = {
    model = "eleven_multilingual_v2",
    voiceId = voiceId,
    characters = #text,
    text = text,
    output = "public/audio/project-narration.mp3"
}

local json_file = io.open("media-production/elevenlabs-result.json", "w")
json_file:write(json.encode(resultData))
json_file:close()

print("ElevenLabs abgeschlossen: " .. #text .. " Zeichen.")
