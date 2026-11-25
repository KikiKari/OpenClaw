#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2a8041ad10b0d9b2753f1cea7e2fb19bd8b4b70d5b5ebf3deefcb8a2b1b696ba", "source_sha256": "1c74aa0ec785639584af8f4d4e128e120c85d9712a7fca7650c80bfc0c1fe946", "target_language": "lua"}
-- tiktok-get-stream.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
-- auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-get-stream.js
-- auch in: workspace@local:skills/tiktok-live/scripts/tiktok-get-stream.js
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[
TikTok Stream URL Extractor
Führt zuerst den profilgebundenen Status-Checker aus.
Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
Offline wird keine Stream-URL ausgegeben.
]]

local json = require("cjson")
local http = require("socket.http")
local ltn12 = require("ltn12")
local https = require("ssl.https")
local luasec_ok, ssl = pcall(require, "ssl")

-- Helper functions
local function split(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep or " ")
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

local function write_file(path, content)
    local file = io.open(path, "wb")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

local function execute_command(cmd)
    local handle = io.popen(cmd, "r")
    local result = handle:read("*a")
    local success, exit_code, signal = handle:close()
    return result, exit_code
end

local function get_load_avg()
    if package.config:sub(1,1) == '\\' then
        -- Windows does not have load average easily accessible via standard means
        return {0, 0, 0}
    else
        local f = io.open("/proc/loadavg", "r")
        if f then
            local line = f:read("*line")
            f:close()
            if line then
                local parts = split(line, " ")
                return {tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])}
            end
        end
    end
    return {0, 0, 0}
end

local function get_cpu_count()
    if package.config:sub(1,1) == '\\' then
        -- On Windows we can use environment variable NUMBER_OF_PROCESSORS
        return tonumber(os.getenv("NUMBER_OF_PROCESSORS")) or 1
    else
        local f = io.open("/proc/cpuinfo", "r")
        if f then
            local count = 0
            for line in f:lines() do
                if line:match("^processor%s*:") then
                    count = count + 1
                end
            end
            f:close()
            return math.max(count, 1)
        end
    end
    return 1
end

-- Main logic starts here
local args = {...}
local rawUsername = args[1]

if not rawUsername then
    print("Usage: lua tiktok-get-stream.lua <username>")
    os.exit(1)
end

local username = rawUsername:gsub("^@+", "")
if username == "" then
    print("Username must not be empty")
    os.exit(1)
end

local function rejectBusyNode()
    local limit_str = os.getenv("TIKTOK_MAX_LOAD_PER_CPU")
    local limit = tonumber(limit_str)
    if not limit or limit <= 0 then return end

    local cpuCount = math.max(1, get_cpu_count())
    local loadAvg = get_load_avg()
    local normalizedLoad = loadAvg[1] / cpuCount
    if normalizedLoad > limit then
        print(string.format("NODE_BUSY normalizedLoad=%.2f limit=%f", normalizedLoad, limit))
        os.exit(75)
    end
end

rejectBusyNode()

local function verifyLiveStatus(username)
    local checkerPath = "./tiktok-check-profile.lua"
    if not file_exists(checkerPath) then
        -- fallback to JS version if exists
        checkerPath = "./tiktok-check-profile.js"
        if file_exists(checkerPath) then
            local cmd = string.format('node "%s" %s', checkerPath, username)
            local result, exit_code = execute_command(cmd)
            if result and result ~= "" then
                local status, parsed = pcall(json.decode, result)
                if status and parsed then
                    return parsed.isLive == true
                end
            end
        end
        return false
    end
    
    -- Run Lua script version
    local cmd = string.format('lua "%s" %s', checkerPath, username)
    local result, exit_code = execute_command(cmd)
    if result and result ~= "" then
        local status, parsed = pcall(json.decode, result)
        if status and parsed then
            return parsed.isLive == true
        end
    end
    return false
end

local function sleep(n)
    if n <= 0 then return end
    local t0 = os.clock()
    while os.clock() - t0 <= n do end
end

local function urlencode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w ])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

local function http_request(url, headers)
    local response_body = {}
    local res, code, response_headers, status = http.request{
        url = url,
        method = "GET",
        headers = headers or {},
        sink = ltn12.sink.table(response_body)
    }
    return table.concat(response_body), code, response_headers, status
end

local function https_request(url, headers)
    if not luasec_ok then
        error("LuaSec library required for HTTPS requests")
    end
    local response_body = {}
    local res, code, response_headers, status = https.request{
        url = url,
        method = "GET",
        headers = headers or {},
        sink = ltn12.sink.table(response_body)
    }
    return table.concat(response_body), code, response_headers, status
end

local function getStreamUrl(username)
    if not verifyLiveStatus(username) then
        print(json.encode({
            username = username,
            isLive = false,
            error = "User is not currently live.",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }))
        return false
    end

    -- Since we cannot use Playwright in Lua directly,
    -- we'll simulate the behavior using HTTP requests and parsing
    
    local flvUrls = {}
    
    -- We need to make an initial request to get cookies/session info
    local live_url = "https://www.tiktok.com/@" .. username .. "/live"
    
    -- First, let's try to fetch the page with basic headers
    local headers = {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    
    local body, code, headers_ret, status = http_request(live_url, headers)
    
    if code ~= 200 then
        print(json.encode({
            error = true,
            message = "Failed to load live page: HTTP " .. tostring(code),
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }))
        return false
    end
    
    -- Simulate waiting for page load and possible cookie acceptance
    sleep(3)
    
    -- In real scenario, would check for cookie banner and click it
    -- For now, just proceed
    
    -- Wait for stream to potentially load
    sleep(8)
    
    -- Additional wait to capture network requests
    sleep(10)
    
    -- Parse HTML for potential stream URLs
    -- This is a simplified approach since we don't have full browser capabilities
    
    -- Look for common patterns in the HTML source that might indicate stream URLs
    for url in string.gmatch(body, "[https?://][%w%.%/\\%-_~:#@!$&'()*+,;=?]*%.flv") do
        table.insert(flvUrls, {
            url = url,
            type = "flv",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        })
    end
    
    for url in string.gmatch(body, "[https?://][%w%.%/\\%-_~:#@!$&'()*+,;=?]*pull%-flv") do
        table.insert(flvUrls, {
            url = url,
            type = "flv",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        })
    end
    
    -- Also look for JSON data that might contain stream URLs
    for json_match in string.gmatch(body, "{[^{}]*\"url\"%s*:[^{}]*}") do
        -- Very basic attempt to extract URLs from JSON-like structures
        for url in string.gmatch(json_match, "\"(https?://[^\"]*%.flv[^\"]*)\"") do
            table.insert(flvUrls, {
                url = url,
                type = "flv",
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            })
        end
    end
    
    if #flvUrls > 0 then
        -- Deduplicate URLs
        local seen = {}
        local uniqueUrls = {}
        for _, item in ipairs(flvUrls) do
            if not seen[item.url] then
                seen[item.url] = true
                table.insert(uniqueUrls, item)
            end
        end
        
        -- Sort by quality indicator
        table.sort(uniqueUrls, function(a, b)
            local function getQuality(url)
                local suffixRanks = {
                    {"_origin.", 600},
                    {"_uhd_60.", 550},
                    {"_uhd.", 540},
                    {"_hd_60.", 500},
                    {"_hd.", 450},
                    {"_sd.", 350},
                    {"_ld.", 250}
                }
                for _, rank_pair in ipairs(suffixRanks) do
                    local suffix, rank = rank_pair[1], rank_pair[2]
                    if string.find(url, suffix, 1, true) then
                        return rank
                    end
                end
                local match = string.match(url, "(%d+)p")
                return match and tonumber(match) or 0
            end
            return getQuality(b.url) - getQuality(a.url)
        end)
        
        print(json.encode({
            username = username,
            isLive = true,
            streamCount = #uniqueUrls,
            streams = uniqueUrls,
            vlcCommand = string.format('vlc "%s"', uniqueUrls[1].url),
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }, {indent = true}))
        return true
    else
        print(json.encode({
            username = username,
            isLive = false,
            error = "No stream URLs found - user may not be live",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }))
        return false
    end
end

local success, err = pcall(getStreamUrl, username)
if not success then
    print(json.encode({
        error = true,
        message = tostring(err),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }))
    os.exit(1)
else
    os.exit(success and 0 or 1)
end
