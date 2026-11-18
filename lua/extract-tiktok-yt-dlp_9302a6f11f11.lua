#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "3caa344eac1c54b76443983f7040298ec86125fe70c8a40d90939f76c47ec72a", "source_sha256": "b00f64d55d344bbcc351ae7ade12137f0d9293b556aa0881ede43bef5bcb778b", "target_language": "lua"}
-- extract-tiktok-yt-dlp.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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
    
    local json_str = "{"
    local first = true
    for k, v in pairs(payload) do
        if not first then json_str = json_str .. "," else first = false end
        json_str = json_str .. "\"" .. k .. "\":" 
        if type(v) == "boolean" then
            json_str = json_str .. tostring(v):lower()
        else
            json_str = json_str .. "\"" .. v .. "\""
        end
    end
    json_str = json_str .. "}"
    return json_str
end

local function die(msg, code)
    io.stderr:write(msg .. "\n")
    os.exit(code)
end

local function check_load(load_per_cpu, max_load)
    return load_per_cpu > max_load
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
    if f then
        local content = f:read("*all")
        f:close()
        return content
    end
    return ""
end

local function write_file(filename, content)
    local f = io.open(filename, "w")
    if f then
        f:write(content)
        f:close()
    end
end

local function exec_command(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success, _, code = handle:close()
    return result, code
end

-- Main script logic
local USERNAME = arg[1]
if not USERNAME then
    die("Invalid TikTok username", 64)
end
USERNAME = string.gsub(USERNAME, "^@", "")

local FORMAT = arg[2] or "best"
local JSON_FLAG = arg[3] or ""

-- Validate username
if not string.match(USERNAME, "^[A-Za-z0-9._]+$") or #USERNAME > 24 or #USERNAME < 1 then
    die("Invalid TikTok username", 64)
end

-- Validate format
local valid_formats = {
    "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld",
    "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
    "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
    "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld",
    "hls-sd/hls-ld/flv-sd/flv-ld",
    "hls-ld/flv-ld",
    "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
}
local format_valid = false
for _, v in ipairs(valid_formats) do
    if FORMAT == v then
        format_valid = true
        break
    end
end
if not format_valid then
    die("Invalid yt-dlp format", 64)
end

-- Get timestamp
local TIMESTAMP = os.date("!%Y-%m-%dT%H:%M:%SZ")

-- Create temporary directory
local TMP_DIR = "/tmp/tiktok-yt-dlp." .. tostring(math.random(100000, 999999))
os.execute("mkdir -p " .. TMP_DIR)

-- Cleanup on exit
local function cleanup()
    os.execute("rm -rf " .. TMP_DIR)
end
-- Note: Lua doesn't have built-in trap equivalent, so we need to ensure cleanup is called in all exit paths

-- Check system load
local load_result = exec_command("python3 -c 'import os; print(os.getloadavg()[0] / max(1, os.cpu_count() or 1))'")
local LOAD_PER_CPU = tonumber(string.match(load_result, "[%d.]+")) or 0
local MAX_LOAD = tonumber(os.getenv("TIKTOK_MAX_LOAD_PER_CPU") or "1.5")

if check_load(LOAD_PER_CPU, MAX_LOAD) then
    io.stderr:write(emit_json("false", "yt-dlp", USERNAME, "", FORMAT, "host overloaded", TIMESTAMP, "overloaded") .. "\n")
    cleanup()
    os.exit(75)
end

-- Check if yt-dlp exists
local _, exit_code = exec_command("command -v yt-dlp >/dev/null 2>&1")
if exit_code ~= 0 then
    io.stderr:write(emit_json("false", "yt-dlp", USERNAME, "", FORMAT, "yt-dlp not installed", TIMESTAMP, "dependency_missing") .. "\n")
    cleanup()
    os.exit(2)
end

-- Run yt-dlp
local LIVE_URL = "https://www.tiktok.com/@" .. USERNAME .. "/live"
local stdout_file = TMP_DIR .. "/stdout.json"
local stderr_file = TMP_DIR .. "/stderr.log"

local cmd = string.format("yt-dlp --no-warnings --dump-single-json --skip-download --format \"%s\" \"%s\" >\"%s\" 2>\"%s\"", 
                          FORMAT, LIVE_URL, stdout_file, stderr_file)
local _, exit_code = os.execute(cmd)

if exit_code ~= 0 then
    local stderr_content = read_file(stderr_file)
    local status, code
    if string.find(stderr_content:lower(), "not currently live") or 
       string.find(stderr_content:lower(), "no live cdn found") or 
       string.find(stderr_content:lower(), "not available") or 
       string.find(stderr_content:lower(), "private video") then
        status = "offline"
        code = 1
    else
        status = "technical_error"
        code = 2
    end
    
    -- Truncate error message to 1000 characters
    local error_msg = string.sub(stderr_content, 1, 1000)
    io.stderr:write(emit_json("false", "yt-dlp", USERNAME, "", FORMAT, error_msg, TIMESTAMP, status) .. "\n")
    cleanup()
    os.exit(code)
end

-- Extract URL from JSON
local json_content = read_file(stdout_file)
local URL = ""

-- Simple JSON parsing to extract URLs
local function extract_urls(json_str)
    local urls = {}
    
    -- Try direct url field
    local url_match = string.match(json_str, '"url"%s*:%s*"([^"]+)"')
    if url_match then
        table.insert(urls, url_match)
    end
    
    -- Try formats array
    local formats_start = string.find(json_str, '"formats"%s*:')
    if formats_start then
        local formats_section = string.sub(json_str, formats_start)
        for url in string.gmatch(formats_section, '"url"%s*:%s*"([^"]+)"') do
            table.insert(urls, url)
        end
    end
    
    -- Filter valid URLs
    for _, value in ipairs(urls) do
        local low = string.lower(value)
        if string.sub(value, 1, 8) == "https://" and 
           (string.find(low, "%.m3u8") or string.find(low, "%.flv")) and 
           not string.find(low, "only_audio=1") then
            return value
        end
    end
    
    return ""
end

URL = extract_urls(json_content)

if URL == "" then
    io.stderr:write(emit_json("false", "yt-dlp", USERNAME, "", FORMAT, "could not extract HTTPS video URL", TIMESTAMP, "offline") .. "\n")
    cleanup()
    os.exit(1)
end

if JSON_FLAG == "--json" then
    print(emit_json("true", "yt-dlp", USERNAME, URL, FORMAT, "", TIMESTAMP, "live"))
else
    print(URL)
end

cleanup()
