#!/data/data/com.termux/files/usr/bin/lua
-- abstraction-provenance: {"artifact_sha256": "3c4abe96138a7b0faaea2862a50877e30a148b55bb9c16cbbc6b1ba26ea4b1aa", "source_sha256": "32acbaa2d9f84dca0c2fd8f987ab23e0153c0e63d20e7ee9c3e279058ab681c6", "target_language": "lua"}
-- termux-quick-auth.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-quick-auth.sh
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

-- Quick Auth Check - Minimal widget for Termux
-- Place in ~/.shortcuts/ for Termux:Widget
--
-- One-tap: shows status toast
-- If expired: directly opens auth URL

local server = os.getenv("OPENCLAW_SERVER") or "l36"

-- Execute SSH command and capture output
local function execute_command(cmd)
    local handle = io.popen(cmd .. " 2>&1")
    local result = handle:read("*a")
    handle:close()
    return result:gsub("%s+$", "") -- trim trailing whitespace
end

local status = execute_command(string.format("ssh -o ConnectTimeout=5 %s '$HOME/openclaw/scripts/claude-auth-status.sh simple'", server))

if status == "OK" then
    os.execute("termux-toast -s \"Auth OK\"")
elseif string.find(status, "EXPIRING") then
    os.execute("termux-vibrate -d 100")
    os.execute("termux-toast \"Auth expiring soon - tap again if needed\"")
elseif string.find(status, "EXPIRED") or string.find(status, "MISSING") then
    os.execute("termux-vibrate -d 200")
    os.execute("termux-toast \"Auth expired - opening console...\"")
    os.execute("termux-open-url \"https://console.anthropic.com/settings/api-keys\"")
    os.execute("sleep 2")
    os.execute("termux-notification -t \"OpenClaw Re-Auth\" -c \"After getting key, run: ssh " .. server .. " '~/openclaw/scripts/mobile-reauth.sh'\" --id openclaw-auth")
else
    os.execute("termux-toast \"Connection error\"")
end
