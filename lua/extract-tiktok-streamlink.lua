#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "e27f1e2cdec03c5a2eb54df12b9b3fd9f64d3a52a8f2e72afc12b8a9c8462c00", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "lua"}
-- extract-tiktok-streamlink.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

local function emit_json(success, method, username, url, quality, author, title, error_msg, timestamp, status)
    local payload = {}
    if success ~= nil then payload.success = success end
    if method ~= nil then payload.method = method end
    if username ~= nil then payload.username = username end
    if url ~= nil then payload.url = url end
    if quality ~= nil then payload.quality = quality end
    if author ~= nil then payload.author = author end
    if title ~= nil then payload.title = title end
    if error_msg ~= nil then payload.error = error_msg end
    if timestamp ~= nil then payload.timestamp = timestamp end
    if status ~= nil then payload.status = status end
    
    if payload.success ~= nil then
        payload.success = (string.lower(tostring(payload.success)) == "true")
    end
    
    print(require("cjson").encode(payload))
end

local function validate_username(username)
    return string.match(username, "^[A-Za-z0-9._]+$") and 
           string.len(username) >= 1 and string.len(username) <= 24
end

local function validate_quality(quality)
    local valid_qualities = {
        best = true, worst = true, original = true,
        ["1080p60"] = true, ["720p60"] = true, ["720p"] = true,
        ["540p"] = true, ["360p"] = true, auto = true
    }
    return valid_qualities[quality] == true
end

local function get_system_load()
    -- This is a simplified approximation since Lua doesn't have direct access to load averages
    -- In practice, you might want to call out to system commands or use a C extension
    return 0.5  -- placeholder value
end

local function execute_command(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success, _, code = handle:close()
    return result, code or (success and 0 or 1)
end

local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

-- Main script logic
local args = {...}
local USERNAME = args[1] or ""
if USERNAME:sub(1,1) == "@" then
    USERNAME = USERNAME:sub(2)
end
local QUALITY = args[2] or "best"
local JSON_FLAG = args[3] or ""
local TIMESTAMP = os.date("!%Y-%m-%dT%H:%M:%SZ")

if not validate_username(USERNAME) then
    io.stderr:write("Invalid TikTok username\n")
    os.exit(64)
end

if not validate_quality(QUALITY) then
    io.stderr:write("Invalid stream quality\n")
    os.exit(64)
end

local LOAD_PER_CPU = get_system_load()
local MAX_LOAD = tonumber(os.getenv("TIKTOK_MAX_LOAD_PER_CPU") or "1.5")
if LOAD_PER_CPU > MAX_LOAD then
    emit_json(false, "streamlink", USERNAME, nil, QUALITY, nil, nil, 
              "host overloaded", TIMESTAMP, "overloaded")
    os.exit(75)
end

if not file_exists("/usr/bin/streamlink") and not file_exists("/usr/local/bin/streamlink") then
    emit_json(false, "streamlink", USERNAME, nil, QUALITY, nil, nil, 
              "streamlink not installed", TIMESTAMP, "dependency_missing")
    os.exit(2)
end

local LIVE_URL = "https://www.tiktok.com/@" .. USERNAME .. "/live"

local selector_map = {
    original = "origin,uhd_60,hd_60,hd,sd,ld,best,worst",
    auto = "best,origin,uhd_60,hd_60,hd,sd,ld,worst",
    ["1080p60"] = "uhd_60,hd_60,hd,sd,ld,worst",
    ["720p60"] = "hd_60,hd,sd,ld,worst",
    ["720p"] = "hd,sd,ld,worst",
    ["540p"] = "sd,ld,worst",
    ["360p"] = "ld,worst"
}
local SELECTOR = selector_map[QUALITY] or QUALITY

local OUTPUT, exit_code = execute_command("streamlink --json '" .. LIVE_URL .. "' '" .. SELECTOR .. "' 2>/dev/null")

if exit_code ~= 0 or OUTPUT == "" then
    local URL, url_exit_code = execute_command("streamlink --stream-url '" .. LIVE_URL .. "' '" .. SELECTOR .. "' 2>/dev/null")
    URL = URL:gsub("%s+$", "")
    
    if url_exit_code ~= 0 or URL == "" then
        emit_json(false, "streamlink", USERNAME, nil, QUALITY, nil, nil, 
                  "streamlink failed or no stream found", TIMESTAMP, "offline")
        os.exit(1)
    end
    
    if JSON_FLAG == "--json" then
        emit_json(true, "streamlink", USERNAME, URL, QUALITY, nil, nil, nil, TIMESTAMP, "live")
    else
        print(URL)
    end
    os.exit(0)
end

-- Parse JSON output
local cjson = require("cjson")
local data = cjson.decode(OUTPUT)

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
local AUTHOR = metadata.author or ""
local TITLE = metadata.title or ""

if url == "" then
    emit_json(false, "streamlink", USERNAME, nil, QUALITY, AUTHOR, TITLE, 
              "could not extract stream URL", TIMESTAMP, "offline")
    os.exit(1)
end

if JSON_FLAG == "--json" then
    emit_json(true, "streamlink", USERNAME, url, QUALITY, AUTHOR, TITLE, nil, TIMESTAMP, "live")
else
    print(url)
end
