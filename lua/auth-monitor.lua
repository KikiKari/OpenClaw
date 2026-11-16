#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "7aa2194cfdca98dedbd4cf3be5e31625beb20421d26c979408af3e9c77ec2676", "source_sha256": "1a67bf0d8a66b56fba5df9f18c7370e48304461313b9611ab6f238f553332b50", "target_language": "lua"}
-- auth-monitor.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/auth-monitor.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

-- Auth Expiry Monitor
-- Run via cron or systemd timer to get proactive notifications
-- before Claude Code auth expires.
--
-- Suggested cron: */30 * * * * /home/admin/openclaw/scripts/auth-monitor.sh
--
-- Environment variables:
--   NOTIFY_PHONE - Phone number to send OpenClaw notification (e.g., +1234567890)
--   NOTIFY_NTFY  - ntfy.sh topic for push notifications (e.g., openclaw-alerts)
--   WARN_HOURS   - Hours before expiry to warn (default: 2)

local os = require("os")
local io = require("io")
local json = require("cjson")  -- You may need to install this with luarocks
local http = require("socket.http")
local https = require("ssl.https")  -- For HTTPS support
local ltn12 = require("ltn12")

-- Helper functions
local function dirname(path)
    local dir = path:match("(.+)/")
    return dir or "."
end

local function basename(path)
    return path:match("[^/]*$")
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
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

local function write_file(filename, content)
    local f = io.open(filename, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

-- Script configuration
local SCRIPT_DIR = dirname(arg[0])
local CLAUDE_CREDS = os.getenv("HOME") .. "/.claude/.credentials.json"
local STATE_FILE = os.getenv("HOME") .. "/.openclaw/auth-monitor-state"

-- Configuration from environment
local WARN_HOURS = tonumber(os.getenv("WARN_HOURS")) or 2
local NOTIFY_PHONE = os.getenv("NOTIFY_PHONE") or ""
local NOTIFY_NTFY = os.getenv("NOTIFY_NTFY") or ""

-- State tracking to avoid spam
local NOW = os.time()
local MIN_INTERVAL = 3600

-- Create directory for state file
os.execute("mkdir -p '" .. dirname(STATE_FILE) .. "'")

-- Read last notified time
local LAST_NOTIFIED = 0
do
    local content = read_file(STATE_FILE)
    if content then
        LAST_NOTIFIED = tonumber(content) or 0
    end
end

local function send_notification(message, priority)
    priority = priority or "default"
    print(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message)

    -- Check if we notified recently
    if (NOW - LAST_NOTIFIED) < MIN_INTERVAL then
        print("Skipping notification (sent recently)")
        return
    end

    -- Send via OpenClaw if phone configured and auth still valid
    if NOTIFY_PHONE ~= "" then
        -- Check if we can still use openclaw
        local handle = io.popen("'" .. SCRIPT_DIR .. "/claude-auth-status.sh' simple 2>/dev/null", "r")
        local result = handle:read("*a")
        handle:close()

        if result:find("OK") or result:find("EXPIRING") then
            print("Sending via OpenClaw to " .. NOTIFY_PHONE .. "...")
            os.execute("openclaw send --to '" .. NOTIFY_PHONE .. "' --message '" .. message:gsub("'", "'\"'\"'") .. "' 2>/dev/null || true")
        end
    end

    -- Send via ntfy.sh if configured
    if NOTIFY_NTFY ~= "" then
        print("Sending via ntfy.sh to " .. NOTIFY_NTFY .. "...")
        local headers = {
            ["Title"] = "OpenClaw Auth Alert",
            ["Priority"] = priority,
            ["Tags"] = "warning,key"
        }
        local body = message
        local response_body = {}

        local url = "https://ntfy.sh/" .. NOTIFY_NTFY
        local res, code, response_headers, status = https.request{
            url = url,
            method = "POST",
            headers = headers,
            source = ltn12.source.string(body),
            sink = ltn12.sink.table(response_body)
        }

        if not res then
            print("Failed to send notification via ntfy.sh")
        end
    end

    -- Update state
    write_file(STATE_FILE, tostring(NOW))
end

-- Check auth status
if not file_exists(CLAUDE_CREDS) then
    send_notification("Claude Code credentials missing! Run: claude setup-token", "high")
    os.exit(1)
end

-- Read credentials file
local creds_content = read_file(CLAUDE_CREDS)
if not creds_content then
    print("Error reading credentials file")
    os.exit(1)
end

local success, creds_data = pcall(function()
    return json.decode(creds_content)
end)

if not success then
    print("Error parsing JSON credentials file")
    os.exit(1)
end

local EXPIRES_AT = creds_data.claudeAiOauth and creds_data.claudeAiOauth.expiresAt or 0
local NOW_MS = NOW * 1000
local DIFF_MS = EXPIRES_AT - NOW_MS
local HOURS_LEFT = math.floor(DIFF_MS / 3600000)
local MINS_LEFT = math.floor((DIFF_MS % 3600000) / 60000)

if DIFF_MS < 0 then
    send_notification("Claude Code auth EXPIRED! OpenClaw is down. Run: ssh l36 '~/openclaw/scripts/mobile-reauth.sh'", "urgent")
    os.exit(1)
elseif HOURS_LEFT < WARN_HOURS then
    send_notification("Claude Code auth expires in " .. HOURS_LEFT .. "h " .. MINS_LEFT .. "m. Consider re-auth soon.", "high")
    os.exit(0)
else
    print(os.date("%Y-%m-%d %H:%M:%S") .. " - Auth OK: " .. HOURS_LEFT .. "h " .. MINS_LEFT .. "m remaining")
    os.exit(0)
end
