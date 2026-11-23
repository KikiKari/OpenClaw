#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "39838ac3f337cffff7240148d456b61d457818efb567f0e89ab83c7419ccea44", "source_sha256": "cb5f3c66f2f8ef6dd2ba9a71832aceb3d4c3af596567dad4241cf94d8e3fd8ba", "target_language": "lua"}
-- setup-auth-system.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/setup-auth-system.sh
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

-- Setup OpenClaw Auth Management System
-- Run this once to set up:
-- 1. Long-lived Claude Code token
-- 2. Auth monitoring with notifications
-- 3. Instructions for Termux widgets

local function exec(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

local function writeFile(filename, content)
    local file = io.open(filename, "w")
    file:write(content)
    file:close()
end

local function readFile(filename)
    local file = io.open(filename, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local function replaceInFile(filename, pattern, replacement)
    local content = readFile(filename)
    if not content then return false end
    content = content:gsub(pattern, replacement)
    writeFile(filename, content)
    return true
end

local script_dir = exec("cd $(dirname " .. arg[0] .. ") && pwd"):gsub("\n", "")
print("=== OpenClaw Auth System Setup ===")
print()

-- Step 1: Check current auth status
print("Step 1: Checking current auth status...")
os.execute(script_dir .. "/claude-auth-status.sh full")
print()

-- Step 2: Set up long-lived token
print("Step 2: Long-lived token setup")
print()
print("Option A: Use 'claude setup-token' (recommended)")
print("  - Creates a long-lived API token")
print("  - No daily re-auth needed")
print("  - Run: claude setup-token")
print()
print("Would you like to set up a long-lived token now? [y/N]")
local setup_token = io.read("*l")

if setup_token:lower():match("^[y]") then
    print()
    print("Opening https://console.anthropic.com/settings/api-keys")
    print("Create a new key or copy existing one, then paste below.")
    print()
    os.execute("claude setup-token")
end

print()

-- Step 3: Set up auth monitoring
print("Step 3: Auth monitoring setup")
print()
print("The auth monitor checks expiry every 30 minutes and notifies you.")
print()
print("Configure notification channels:")
print()

-- Check for ntfy
print("  ntfy.sh: Free push notifications to your phone")
print("  1. Install ntfy app on your phone")
print("  2. Subscribe to a topic (e.g., 'openclaw-alerts')")
print()
print("Enter ntfy.sh topic (or leave blank to skip):")
local ntfy_topic = io.read("*l")

-- Phone notification
print()
print("  OpenClaw message: Send warning via OpenClaw itself")
print("Enter your phone number for alerts (or leave blank to skip):")
local phone_number = io.read("*l")

-- Update service file
local service_file = script_dir .. "/systemd/openclaw-auth-monitor.service"
local temp_service = "/tmp/openclaw-service.tmp"

-- Read original service file
local service_content = readFile(service_file)

-- Update with ntfy topic if provided
if ntfy_topic ~= "" then
    service_content = service_content:gsub("# Environment=NOTIFY_NTFY=.*", "Environment=NOTIFY_NTFY=" .. ntfy_topic)
end

-- Update with phone number if provided
if phone_number ~= "" then
    service_content = service_content:gsub("# Environment=NOTIFY_PHONE=.*", "Environment=NOTIFY_PHONE=" .. phone_number)
end

-- Write updated service file
writeFile(temp_service, service_content)

-- Install systemd units
print()
print("Installing systemd timer...")
os.execute("mkdir -p ~/.config/systemd/user")
os.execute("cp " .. temp_service .. " ~/.config/systemd/user/openclaw-auth-monitor.service")
os.execute("cp " .. script_dir .. "/systemd/openclaw-auth-monitor.timer ~/.config/systemd/user/")
os.execute("systemctl --user daemon-reload")
os.execute("systemctl --user enable --now openclaw-auth-monitor.timer")

os.execute("rm -f " .. temp_service)

print("Auth monitor installed and running.")
print()

-- Step 4: Termux widget setup
print("Step 4: Termux widget setup (for phone)")
print()
print("To set up quick auth from your phone:")
print()
print("1. Install Termux and Termux:Widget from F-Droid")
print("2. Create ~/.shortcuts/ directory in Termux:")
print("   mkdir -p ~/.shortcuts")
print()
print("3. Copy the widget scripts:")
print("   scp " .. script_dir .. "/termux-quick-auth.sh phone:~/.shortcuts/ClawdAuth")
print("   scp " .. script_dir .. "/termux-auth-widget.sh phone:~/.shortcuts/ClawdAuth-Full")
print()
print("4. Make them executable on phone:")
print("   ssh phone 'chmod +x ~/.shortcuts/Clawd*'")
print()
print("5. Add Termux:Widget to your home screen")
print("6. Tap the widget to see your auth scripts")
print()
print("The quick widget (ClawdAuth) shows status and opens auth URL if needed.")
print("The full widget (ClawdAuth-Full) provides guided re-auth flow.")
print()

-- Summary
print("=== Setup Complete ===")
print()
print("What's configured:")
print("  - Auth status: " .. script_dir .. "/claude-auth-status.sh")
print("  - Mobile re-auth: " .. script_dir .. "/mobile-reauth.sh")
print("  - Auth monitor: systemctl --user status openclaw-auth-monitor.timer")
print()
print("Quick commands:")
print("  Check auth:  " .. script_dir .. "/claude-auth-status.sh")
print("  Re-auth:     " .. script_dir .. "/mobile-reauth.sh")
print("  Test monitor: " .. script_dir .. "/auth-monitor.sh")
print()
