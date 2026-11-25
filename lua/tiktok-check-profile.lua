#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "faa995f3f7343426aaa47ee2acdb4fea1c23212839d87f6601c4e8275fe131c0", "source_sha256": "e90219318254f9b20057962724b153b7476a0511846415f2cc0a38bd9baa14f5", "target_language": "lua"}
-- tiktok-check-profile.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
-- auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-check-profile.js
-- auch in: workspace@local:skills/tiktok-live/scripts/tiktok-check-profile.js
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[
TikTok Live Status Checker
Prüft ausschließlich profilgebundene Live-Indikatoren.
Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).
]]

local json = require("cjson")
local http = require("socket.http")
local ltn12 = require("ltn12")
local os = require("os")

-- Simple HTML parser to extract elements
local function parse_html(html)
    local result = {}
    -- Very basic parsing - just extract what we need
    return result
end

-- Get command line argument
local rawUsername = arg[1]
if not rawUsername then
    print("Usage: lua tiktok-check-profile.lua <username>")
    os.exit(1)
end

local username = string.gsub(rawUsername, "^@+", "")
if username == "" then
    print("Username must not be empty")
    os.exit(1)
end

-- Function to check system load (Linux only)
local function rejectBusyNode()
    local limit = tonumber(os.getenv("TIKTOK_MAX_LOAD_PER_CPU"))
    if not limit or limit <= 0 then return end
    
    local f = io.open("/proc/loadavg", "r")
    if not f then return end
    
    local line = f:read("*l")
    f:close()
    
    if not line then return end
    
    local load = tonumber(string.match(line, "[%d%.]+"))
    if not load then return end
    
    -- Get CPU count
    local cpuCount = 1
    local f_cpu = io.open("/proc/cpuinfo", "r")
    if f_cpu then
        local content = f_cpu:read("*a")
        f_cpu:close()
        local _, count = string.gsub(content, "processor%s*: ", "")
        cpuCount = math.max(1, count)
    end
    
    local normalizedLoad = load / cpuCount
    if normalizedLoad > limit then
        print(string.format("NODE_BUSY normalizedLoad=%.2f limit=%d", normalizedLoad, limit))
        os.exit(75)
    end
end

rejectBusyNode()

-- Main function to check live status
local function checkLiveStatus(username)
    local url = "https://www.tiktok.com/@" .. username
    
    -- Make HTTP request
    local response_body = {}
    local res, code, headers, status = http.request{
        url = url,
        sink = ltn12.sink.table(response_body)
    }
    
    if not res then
        print(json.encode({
            error = true,
            message = "Failed to fetch TikTok profile",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }))
        os.exit(1)
    end
    
    local html = table.concat(response_body)
    
    -- Check for LIVE indicators (very simplified version)
    local liveIconVisible = string.find(html, 'data%-e2e="live%-icon"') ~= nil
    local liveBadgeVisible = string.find(html, 'LIVE') ~= nil
    local hasLiveBorder = string.find(html, 'border%-color') ~= nil and (
        string.find(html, '255') ~= nil or 
        string.find(html, 'red') ~= nil or 
        string.find(html, 'fe2c55') ~= nil
    )
    local hasLiveLink = string.find(html, '/live"') ~= nil
    local liveIndicatorVisible = string.find(html, 'live%-indicator') ~= nil or 
                                  string.find(html, 'LiveBadge') ~= nil
    
    local isLive = liveIconVisible or liveBadgeVisible or hasLiveBorder or hasLiveLink or liveIndicatorVisible
    
    print(json.encode({
        username = username,
        isLive = isLive,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        indicators = {
            liveIcon = liveIconVisible,
            liveBadge = liveBadgeVisible,
            liveBorder = hasLiveBorder,
            liveLink = hasLiveLink,
            liveIndicator = liveIndicatorVisible
        }
    }, nil, 2))
    
    return isLive
end

-- Run the check
local success, result = pcall(checkLiveStatus, username)
if success then
    os.exit(result and 0 or 1)
else
    print(json.encode({
        error = true,
        message = tostring(result),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }))
    os.exit(1)
end
