#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d3cd4e51d6f327b79112b23d119d7665ad32aa136620fd124697bd1bbc1c41b3", "source_sha256": "b00f64d55d344bbcc351ae7ade12137f0d9293b556aa0881ede43bef5bcb778b", "target_language": "lua"}
-- extract-tiktok-yt-dlp.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

local function emit_json(success, method, username, url, format, error_msg, timestamp, status)
    local payload = {}
    if success ~= nil and success ~= "" then
        payload.success = (string.lower(success) == "true")
    end
    if method ~= nil and method ~= "" then payload.method = method end
    if username ~= nil and username ~= "" then payload.username = username end
    if url ~= nil and url ~= "" then payload.url = url end
    if format ~= nil and format ~= "" then payload.format = format end
    if error_msg ~= nil and error_msg ~= "" then payload.error = error_msg end
    if timestamp ~= nil and timestamp ~= "" then payload.timestamp = timestamp end
    if status ~= nil and status ~= "" then payload.status = status end
    
    print(require("cjson").encode(payload))
end

local function validate_username(username)
    return string.match(username, "^[A-Za-z0-9._]+$") ~= nil and 
           string.len(username) >= 1 and string.len(username) <= 24
end

local function validate_format(format)
    local valid_formats = {
        "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld",
        "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
        "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
        "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld",
        "hls-sd/hls-ld/flv-sd/flv-ld",
        "hls-ld/flv-ld",
        "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
    }
    
    for _, valid in ipairs(valid_formats) do
        if format == valid then
            return true
        end
    end
    return false
end

local function get_load_per_cpu()
    local f = io.popen("python3 -c 'import os; print(os.getloadavg()[0] / max(1, os.cpu_count() or 1))'")
    local load = f:read("*a")
    f:close()
    return tonumber(load)
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

local function read_file(filename)
    local f = io.open(filename, "r")
    if not f then return "" end
    local content = f:read("*all")
    f:close()
    return content
end

local function write_file(filename, content)
    local f = io.open(filename, "w")
    if f then
        f:write(content)
        f:close()
    end
end

-- Main script logic
local args = {...}
local USERNAME = args[1] or ""
if USERNAME:sub(1, 1) == "@" then
    USERNAME = USERNAME:sub(2)
end

local FORMAT = args[2] or "best"
local JSON_FLAG = args[3] or ""
local TIMESTAMP = os.date("!%Y-%m-%dT%H:%M:%SZ")

-- Create temporary directory
local TMP_DIR = "/tmp/tiktok-yt-dlp." .. tostring(math.random(100000, 999999))
os.execute("mkdir -p " .. TMP_DIR)

-- Cleanup on exit
local function cleanup()
    os.execute("rm -rf " .. TMP_DIR)
end

-- Set trap for cleanup
local original_exit = os.exit
os.exit = function(code)
    cleanup()
    original_exit(code)
end

if not validate_username(USERNAME) then
    io.stderr:write("Invalid TikTok username\n")
    os.exit(64)
end

if not validate_format(FORMAT) then
    io.stderr:write("Invalid yt-dlp format\n")
    os.exit(64)
end

local LOAD_PER_CPU = get_load_per_cpu()
local MAX_LOAD = tonumber(os.getenv("TIKTOK_MAX_LOAD_PER_CPU") or "1.5")

if LOAD_PER_CPU > MAX_LOAD then
    emit_json("false", "yt-dlp", USERNAME, "", FORMAT, "host overloaded", TIMESTAMP, "overloaded")
    os.exit(75)
end

-- Check if yt-dlp exists
local f = io.popen("command -v yt-dlp >/dev/null 2>&1 && echo found")
local result = f:read("*l")
f:close()

if result ~= "found" then
    emit_json("false", "yt-dlp", USERNAME, "", FORMAT, "yt-dlp not installed", TIMESTAMP, "dependency_missing")
    os.exit(2)
end

local LIVE_URL = "https://www.tiktok.com/@" .. USERNAME .. "/live"
local stdout_file = TMP_DIR .. "/stdout.json"
local stderr_file = TMP_DIR .. "/stderr.log"

-- Run yt-dlp command
local cmd = string.format(
    "yt-dlp --no-warnings --dump-single-json --skip-download --format '%s' '%s' >'%s' 2>'%s'",
    FORMAT, LIVE_URL, stdout_file, stderr_file
)

local EXIT_CODE = os.execute(cmd) == true and 0 or 1

if EXIT_CODE ~= 0 then
    local stderr_content = read_file(stderr_file)
    local STATUS, CODE
    
    if string.find(string.lower(stderr_content), "not currently live") or
       string.find(string.lower(stderr_content), "no live cdn found") or
       string.find(string.lower(stderr_content), "not available") or
       string.find(string.lower(stderr_content), "private video") then
        STATUS = "offline"
        CODE = 1
    else
        STATUS = "technical_error"
        CODE = 2
    end
    
    -- Truncate error message to 1000 characters
    local error_msg = string.sub(stderr_content, 1, 1000)
    emit_json("false", "yt-dlp", USERNAME, "", FORMAT, error_msg, TIMESTAMP, STATUS)
    os.exit(CODE)
end

-- Extract URL from JSON
local json_content = read_file(stdout_file)
local URL = ""

-- Simple JSON parsing to extract URLs
local function extract_urls_from_json(json_str)
    local urls = {}
    
    -- Find direct url field
    local url_match = string.match(json_str, '"url"%s*:%s*"([^"]+)"')
    if url_match then
        table.insert(urls, url_match)
    end
    
    -- Find formats array entries
    local formats_start, formats_end = string.find(json_str, '"formats"%s*:%s*%[')
    if formats_start then
        local formats_section = string.sub(json_str, formats_end + 1)
        local bracket_count = 1
        local i = 1
        
        while i <= #formats_section and bracket_count > 0 do
            local char = string.sub(formats_section, i, i)
            if char == '[' then
                bracket_count = bracket_count + 1
            elseif char == ']' then
                bracket_count = bracket_count - 1
            end
            i = i + 1
        end
        
        if bracket_count == 0 then
            local formats_json = string.sub(formats_section, 1, i - 2)
            for url_in_format in string.gmatch(formats_json, '"url"%s*:%s*"([^"]+)"') do
                table.insert(urls, url_in_format)
            end
        end
    end
    
    return urls
end

local candidate_urls = extract_urls_from_json(json_content)

for _, value in ipairs(candidate_urls) do
    local lower_value = string.lower(value)
    if string.sub(value, 1, 8) == "https://" and 
       (string.find(lower_value, "%.m3u8") or string.find(lower_value, "%.flv")) and
       not string.find(lower_value, "only_audio=1") then
        URL = value
        break
    end
end

if URL == "" then
    emit_json("false", "yt-dlp", USERNAME, "", FORMAT, "could not extract HTTPS video URL", TIMESTAMP, "offline")
    os.exit(1)
end

if JSON_FLAG == "--json" then
    emit_json("true", "yt-dlp", USERNAME, URL, FORMAT, "", TIMESTAMP, "live")
else
    print(URL)
end
