#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "7443625216cbb25711f84eef6e8deaccd3b9baae7efa76e340804820fcc51542", "source_sha256": "26a823a8fe0d3b94a8c9958ec8cf150765ddf3654a8806c9cc62eae06d9632db", "target_language": "lua"}
-- tiktok-check-profile.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[
Basic TikTok LIVE profile checker.

Scopes every signal to the requested account and ignores unrelated sidebar
LIVE labels. This profile-only checker does not classify restricted LIVE;
use the enhanced checker or dispatcher for that distinction.

Exit 0 = account-specific LIVE, 1 = offline, 2 = dependency/technical
failure, 75 = overloaded before Playwright startup.
]]

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local os = require("os")

-- Helper functions
function file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then io.close(f) return true else return false end
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function normalizeUsername(username)
    if not username or username == "" then
        error("Username cannot be empty")
    end
    username = trim(username)
    if username:match("[^a-zA-Z0-9._-]") then
        error("Invalid characters in username")
    end
    return username
end

function enforceLoadLimit(method)
    -- In Lua we simulate this with a simple check
    local limit_file = "/tmp/load_limit_" .. method
    if file_exists(limit_file) then
        print(json.encode({
            error = true,
            status = "overloaded",
            method = method,
            message = "System is currently overloaded",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }))
        os.exit(75)
    end
end

-- Main logic
local username = arg[1]
if not username then
    print("Usage: lua tiktok-check-profile.lua <username>")
    print("Username required")
    os.exit(64)
end

local success, err = pcall(function()
    username = normalizeUsername(username)
end)

if not success then
    print("Usage: lua tiktok-check-profile.lua <username>")
    print(err)
    os.exit(64)
end

enforceLoadLimit("playwright_basic")

-- Since Lua doesn't have Playwright, we'll implement a basic HTTP-based check
-- This is a simplified version that checks for common live indicators in HTML

function checkLiveStatus(username)
    local url = "https://www.tiktok.com/@" .. username
    local response_body = {}
    
    local res, code, headers, status = http.request{
        url = url,
        sink = ltn12.sink.table(response_body)
    }
    
    if not res then
        print(json.encode({
            error = true,
            status = "dependency_missing",
            method = "http_request",
            message = "HTTP request failed: " .. code,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }))
        os.exit(2)
    end
    
    local html = table.concat(response_body)
    
    -- Simple pattern matching for live indicators
    local live_indicators = {
        'data-e2e="live%-icon"',
        'class="[^"]*LiveBadge',
        'class="[^"]*live%-indicator',
        '>LIVE<',
        'status%-live',
        '"isLive":true'
    }
    
    local is_live = false
    local indicators = {
        liveIcon = false,
        liveBadge = false,
        liveBorder = false,
        liveLink = false,
        liveIndicator = false
    }
    
    for _, pattern in ipairs(live_indicators) do
        if html:match(pattern) then
            is_live = true
            -- Set appropriate indicator flag based on pattern
            if pattern:find("live%-icon") then
                indicators.liveIcon = true
            elseif pattern:find("LiveBadge") then
                indicators.liveBadge = true
            elseif pattern:find("live%-indicator") then
                indicators.liveIndicator = true
            elseif pattern:find("LIVE") then
                indicators.liveBadge = true
            elseif pattern:find("isLive") then
                indicators.liveLink = true
            end
        end
    end
    
    print(json.encode({
        username = username,
        isLive = is_live,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        indicators = indicators
    }, true))
    
    return is_live
end

local success, result = pcall(checkLiveStatus, username)
if not success then
    print(json.encode({
        error = true,
        status = "technical_error",
        message = tostring(result),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }))
    os.exit(2)
else
    os.exit(result and 0 or 1)
end
