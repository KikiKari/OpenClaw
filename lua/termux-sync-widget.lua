#!/data/data/com.termux/files/usr/bin/lua
-- abstraction-provenance: {"artifact_sha256": "2920c52bdc8f1c369bd16fccd5c6f72a809fd4481d1a324642b76f2dd2f2a13e", "source_sha256": "5a61490f9c6c3ae52acdce976cbcad0d09396f906ddb85d7ae357ab98e762893", "target_language": "lua"}
-- termux-sync-widget.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-sync-widget.sh
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

-- OpenClaw OAuth Sync Widget
-- Syncs Claude Code tokens to OpenClaw on l36 server
-- Place in ~/.shortcuts/ on phone for Termux:Widget

local function run_command(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success, _, exit_code = handle:close()
    return result, exit_code
end

local function termux_toast(message)
    os.execute("termux-toast " .. string.format("%q", message))
end

local function termux_vibrate(duration)
    os.execute("termux-vibrate -d " .. duration)
end

termux_toast("Syncing OpenClaw auth...")

-- Run sync on l36 server
local server = os.getenv("OPENCLAW_SERVER") or "l36"
local command = "ssh " .. server .. " '/home/admin/openclaw/scripts/sync-claude-code-auth.sh'"
local result, exit_code = run_command(command)

if exit_code == 0 then
    -- Extract expiry time from output
    local expiry = ""
    for line in result:gmatch("[^\r\n]+") do
        if line:find("Token expires:") then
            expiry = line:match("Token expires:(.*)")
            break
        end
    end

    termux_vibrate("100")
    termux_toast("OpenClaw synced! Expires:" .. expiry)

    -- Optional: restart openclaw service
    os.execute("ssh " .. server .. " 'systemctl --user restart openclaw' 2>/dev/null")
else
    termux_vibrate("300")
    termux_toast("Sync failed: " .. result)
end
