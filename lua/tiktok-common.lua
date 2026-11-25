#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "4a94a7405f8dbe072c8e4439b08ffaa4e9ac6edaa01af6b0fff5b671159f7078", "source_sha256": "23879e22856f8bcfb0ddda7c9b1d7b0d7f3af474cea8620c1f7c10511ef03ed5", "target_language": "lua"}
-- tiktok-common.js — portiert nach lua
-- Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

--[[
Shared TikTok LIVE safety contract: handle normalization, per-CPU load
preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
validation, and normalized extractor statuses.
]]

local DEFAULT_MAX_LOAD_PER_CPU = 1.5
local USERNAME_PATTERN = "^[A-Za-z0-9._]+$"

local FAILURE_STATUSES = {
    offline = true,
    restricted = true,
    overloaded = true,
    dependency_missing = true,
    technical_error = true
}

local function normalizeUsername(raw)
    local username = string.gsub(string.gsub(tostring(raw or ""), "^%s*(.-)%s*$", "%1"), "^@+", "")
    if #username == 0 or #username > 24 or not string.match(username, USERNAME_PATTERN) then
        error("Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores")
    end
    return username
end

local function loadState(env)
    env = env or os.getenv
    local cpu_count = math.max(1, #os.execute("nproc 2>/dev/null || echo 1") or 1)
    local observed
    if env("TIKTOK_TEST_LOAD_PER_CPU") ~= nil then
        observed = tonumber(env("TIKTOK_TEST_LOAD_PER_CPU"))
    else
        -- Simulate load average reading from /proc/loadavg on Linux systems
        local f = io.open("/proc/loadavg", "r")
        if f then
            local line = f:read("*l")
            f:close()
            if line then
                local load1min = string.match(line, "([^%s]+)")
                observed = (tonumber(load1min) or 0) / cpu_count
            end
        else
            observed = 0 -- Default fallback when unable to read loadavg
        end
    end
    local maximum = env("TIKTOK_MAX_LOAD_PER_CPU") ~= nil and tonumber(env("TIKTOK_MAX_LOAD_PER_CPU")) or DEFAULT_MAX_LOAD_PER_CPU
    if not observed or not maximum or type(observed) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then
        error("Invalid TikTok load configuration")
    end
    return {
        overloaded = observed > maximum,
        loadPerCpu = observed,
        maximum = maximum
    }
end

local function enforceLoadLimit(method)
    local state = loadState()
    if not state.overloaded then return state end
    io.stderr:write(string.format('%s\n', cjson.encode({
        status = "overloaded",
        method = method,
        loadPerCpu = tonumber(string.format("%.3f", state.loadPerCpu)),
        maximum = state.maximum,
        message = "Host is overloaded; retry on another node or later"
    })))
    os.exit(75)
end

local function liveHrefSelectors(username)
    local href = "/@" .. username .. "/live"
    return {"a[href='" .. href .. "']", "a[href^='" .. href .. "?']"}
end

local function isAllowedStreamUrl(value)
    local success, parsed_url = pcall(function()
        return require("socket.url").parse(value)
    end)
    if not success or not parsed_url then return false end
    
    local host = string.lower(parsed_url.host or "")
    local path = string.lower(parsed_url.path or "")
    
    local proto_ok = parsed_url.scheme == "https"
    local flv_ok = string.find(path, "%.flv")
    local cdn_ok = string.match(host, "(%.?)tiktokcdn(%-[a-z0-9%-]*)?%.com$")
    
    return proto_ok and flv_ok and cdn_ok
end

local function isSuccessfulStreamResponse(status, value)
    return type(status) == "number" and status >= 200 and status < 300 and isAllowedStreamUrl(value)
end

-- Order matters: longer keys first so `_uhd_60` never matches as `hd_60`/`hd`.
local QUALITY_URL_PATTERN = "_(uhd_60|hd_60|origin|hd|sd|ld|ao)%.(?:flv|m3u8)"

local function qualityKeyFromUrl(value)
    local success, parsed_url = pcall(function()
        return require("socket.url").parse(value)
    end)
    if not success or not parsed_url then return nil end
    
    local path = string.lower(parsed_url.path or "")
    local match = string.match(path, QUALITY_URL_PATTERN)
    return match
end

local function normalizeExtractorResult(value, method, username)
    local technicalError = {
        success = false,
        status = "technical_error",
        method = method,
        username = username,
        message = "invalid extractor result"
    }
    
    if type(value) ~= "table" or type(value) == "table" and next(value) == nil then
        return technicalError
    end
    
    if value.success == true then
        if value.status ~= "live" or not isAllowedStreamUrl(value.url) then
            return technicalError
        end
        return {
            success = true,
            status = "live",
            url = value.url,
            streams = value.streams,
            allUrls = value.allUrls
        }
    end
    
    if value.success ~= false then
        return technicalError
    end
    
    local result_status = FAILURE_STATUSES[value.status] and value.status or "technical_error"
    local result_method = type(value.method) == "string" and value.method or method
    local result_username = type(value.username) == "string" and value.username or username
    
    return {
        success = false,
        status = result_status,
        method = result_method,
        username = result_username,
        message = value.message
    }
end

local function classifyFinalFailure(results)
    local statuses = {}
    for _, result in ipairs(results) do
        if result and result.status and FAILURE_STATUSES[result.status] then
            statuses[result.status] = true
        end
    end
    
    if statuses.overloaded then return "overloaded" end
    if statuses.restricted then return "restricted" end
    if statuses["technical_error"] then return "technical_error" end
    if statuses.offline then return "offline" end
    if statuses.dependency_missing then return "dependency_missing" end
    return "technical_error"
end

local function exitCodeForResult(result)
    if result and result.success == true and result.status == "live" then return 0 end
    if result and result.status == "overloaded" then return 75 end
    if result and (result.status == "offline" or result.status == "restricted") then return 1 end
    return 2
end

local function classifyDirectLiveState(data)
    local username = data.username
    local currentPath = data.currentPath
    local title = data.title
    local bodyText = data.bodyText
    local successfulStreamResponse = data.successfulStreamResponse
    
    local expectedPath = "/@" .. username .. "/live"
    if currentPath ~= expectedPath then
        return {status = "offline", reason = "target live page redirected"}
    end
    if successfulStreamResponse then
        return {status = "live", reason = "successful TikTok CDN stream response"}
    end
    
    local normalizedBody = string.gsub(string.lower(tostring(bodyText or "")), "%s+", " ")
    local normalizedTitle = string.lower(tostring(title or ""))
    local accountLiveTitle = string.find(normalizedTitle, "@?" .. string.lower(username) .. "%s*%)%s*is%s+live")
    
    local endedMarkers = {
        "live has ended",
        "das live ist beendet",
        "live wurde beendet",
        "dieses live ist beendet",
        "stream has ended"
    }
    for _, marker in ipairs(endedMarkers) do
        if string.find(normalizedBody, marker) then
            return {status = "offline", reason = "target live page reports ended stream"}
        end
    end
    
    local restrictionMarkers = {
        "dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten",
        "melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen",
        "bei tiktok anmelden",
        "melde dich an für das volle live-erlebnis",
        "melde dich an für das vollständige erlebnis",
        "this live may contain content that could be uncomfortable",
        "log in to tiktok",
        "log in for the full live experience",
        "mature content",
        "age-restricted",
        "viewer discretion"
    }
    if accountLiveTitle then
        for _, marker in ipairs(restrictionMarkers) do
            if string.find(normalizedBody, marker) then
                return {status = "restricted", reason = "target live page requires authentication"}
            end
        end
        return {
            status = "restricted",
            reason = "target is live but no accessible media response was available"
        }
    end
    return {status = "offline", reason = "no account-specific live signal"}
end

local function forcedOffline(method, username)
    if os.getenv("TIKTOK_TEST_OFFLINE") ~= "1" then return false end
    io.stderr:write(string.format('%s\n', cjson.encode({
        success = false,
        status = "offline",
        method = method,
        username = username,
        message = "forced offline test mode"
    })))
    return true
end

return {
    classifyDirectLiveState = classifyDirectLiveState,
    classifyFinalFailure = classifyFinalFailure,
    enforceLoadLimit = enforceLoadLimit,
    exitCodeForResult = exitCodeForResult,
    forcedOffline = forcedOffline,
    isAllowedStreamUrl = isAllowedStreamUrl,
    isSuccessfulStreamResponse = isSuccessfulStreamResponse,
    liveHrefSelectors = liveHrefSelectors,
    loadState = loadState,
    normalizeExtractorResult = normalizeExtractorResult,
    normalizeUsername = normalizeUsername,
    qualityKeyFromUrl = qualityKeyFromUrl
}
