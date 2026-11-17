#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "78446743bb6d0c2ae44822b2b7a22194a0c5e2b12fda391edd4c0b74f1286b80", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "lua"}
-- extract-tiktok-streamlink.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

local function emit_json(success, method, username, url, quality, author, title, error_msg, timestamp, status)
    local json = require("cjson")
    local payload = {
        success = success,
        method = method,
        username = username,
        url = url or "",
        quality = quality,
        author = author or "",
        title = title or "",
        error = error_msg or "",
        timestamp = timestamp,
        status = status
    }
    for k, v in pairs(payload) do
        if v == "" then payload[k] = nil end
    end
    if payload.success ~= nil then
        payload.success = payload.success:lower() == "true" or payload.success == true
    end
    print(json.encode(payload))
end

local function validate_username(username)
    return string.match(username, "^[A-Za-z0-9._]{1,24}$") ~= nil
end

local function validate_quality(quality)
    local valid_qualities = {
        best = true, worst = true, original = true,
        ["1080p60"] = true, ["720p60"] = true, ["720p"] = true,
        ["540p"] = true, ["360p"] = true, auto = true
    }
    return valid_qualities[quality] == true
end

local function get_load_per_cpu()
    local f = io.popen("python3 -c 'import os; print(os.getloadavg()[0] / max(1, os.cpu_count() or 1))'")
    local load = f:read("*a")
    f:close()
    return tonumber(load)
end

local function timestamp()
    local f = io.popen("date -u +%Y-%m-%dT%H:%M:%SZ")
    local ts = f:read("*line")
    f:close()
    return ts
end

local function command_exists(cmd)
    local _, _, code = os.execute(string.format("command -v %s > /dev/null 2>&1", cmd))
    return code == 0
end

local function streamlink_json(url, selector)
    local handle = io.popen(string.format("streamlink --json '%s' '%s' 2>/dev/null", url, selector))
    local result = handle:read("*a")
    local code = handle:close()
    return result, code
end

local function streamlink_url(url, selector)
    local handle = io.popen(string.format("streamlink --stream-url '%s' '%s' 2>/dev/null", url, selector))
    local result = handle:read("*line")
    local code = handle:close()
    return result, code
end

local function parse_streamlink_json(output)
    local json = require("cjson")
    local data = json.decode(output)
    local url = data.url or ""
    local streams = data.streams or {}
    
    if url == "" and type(streams) == "table" then
        for _, key in ipairs({"best", "worst"}) do
            local value = streams[key]
            if type(value) == "table" and value.url then
                url = value.url
                break
            end
        end
        if url == "" then
            for key, value in pairs(streams) do
                if type(value) == "table" and value.url then
                    url = value.url
                    break
                end
            end
        end
    end
    
    local metadata = data.metadata or {}
    return json.encode({
        url = url,
        author = metadata.author or "",
        title = metadata.title or ""
    })
end

local function parse_final_fields(parsed)
    local json = require("cjson")
    local data = json.decode(parsed)
    return data.url or "", data.author or "", data.title or ""
end

-- Main script logic
local args = {...}
local USERNAME = string.gsub(args[1] or "", "^@", "")
local QUALITY = args[2] or "best"
local JSON_FLAG = args[3] or ""
local TIMESTAMP = timestamp()

if not validate_username(USERNAME) then
    io.stderr:write("Invalid TikTok username\n")
    os.exit(64)
end

if not validate_quality(QUALITY) then
    io.stderr:write("Invalid stream quality\n")
    os.exit(64)
end

local LOAD_PER_CPU = get_load_per_cpu()
local MAX_LOAD = os.getenv("TIKTOK_MAX_LOAD_PER_CPU") or "1.5"
if LOAD_PER_CPU > tonumber(MAX_LOAD) then
    emit_json("false", "streamlink", USERNAME, nil, QUALITY, nil, nil, 
              "host overloaded", TIMESTAMP, "overloaded")
    os.exit(75)
end

if not command_exists("streamlink") then
    emit_json("false", "streamlink", USERNAME, nil, QUALITY, nil, nil, 
              "streamlink not installed", TIMESTAMP, "dependency_missing")
    os.exit(2)
end

local LIVE_URL = "https://www.tiktok.com/@" .. USERNAME .. "/live"
local selectors = {
    original = "origin,uhd_60,hd_60,hd,sd,ld,best,worst",
    auto = "best,origin,uhd_60,hd_60,hd,sd,ld,worst",
    ["1080p60"] = "uhd_60,hd_60,hd,sd,ld,worst",
    ["720p60"] = "hd_60,hd,sd,ld,worst",
    ["720p"] = "hd,sd,ld,worst",
    ["540p"] = "sd,ld,worst",
    ["360p"] = "ld,worst"
}
local SELECTOR = selectors[QUALITY] or QUALITY

local OUTPUT, EXIT_CODE = streamlink_json(LIVE_URL, SELECTOR)
if EXIT_CODE ~= 0 or OUTPUT == "" then
    local URL, code = streamlink_url(LIVE_URL, SELECTOR)
    if code ~= 0 or URL == nil or URL == "" then
        emit_json("false", "streamlink", USERNAME, nil, QUALITY, nil, nil, 
                  "streamlink failed or no stream found", TIMESTAMP, "offline")
        os.exit(1)
    end
    if JSON_FLAG == "--json" then
        emit_json("true", "streamlink", USERNAME, URL, QUALITY, nil, nil, 
                  nil, TIMESTAMP, "live")
    else
        print(URL)
    end
    os.exit(0)
end

local PARSED = parse_streamlink_json(OUTPUT)
local success, URL, AUTHOR, TITLE = pcall(parse_final_fields, PARSED)
if not success then
    emit_json("false", "streamlink", USERNAME, nil, QUALITY, nil, nil, 
              "invalid streamlink JSON", TIMESTAMP, "technical_error")
    os.exit(2)
end

if URL == "" then
    emit_json("false", "streamlink", USERNAME, nil, QUALITY, AUTHOR, TITLE, 
              "could not extract stream URL", TIMESTAMP, "offline")
    os.exit(1)
end

if JSON_FLAG == "--json" then
    emit_json("true", "streamlink", USERNAME, URL, QUALITY, AUTHOR, TITLE, 
              nil, TIMESTAMP, "live")
else
    print(URL)
end
