#!/data/data/com.termux/files/usr/bin/lua
-- abstraction-provenance: {"artifact_sha256": "cc907b07f01579574f66dbfb5af0aa7a88669b1f0204b3129cf6ca0e7db1c546", "source_sha256": "5633c73683c9a3e413c1958a2736550b913651537faccecaa22df360eec1c69e", "target_language": "lua"}
-- termux-auth-widget.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-auth-widget.sh
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

-- OpenClaw Auth Widget for Termux
-- Place in ~/.shortcuts/ for Termux:Widget
--
-- This widget checks auth status and helps with re-auth if needed.
-- It's designed for quick one-tap checking from phone home screen.

local function os_capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

local function split(str, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep)
  str:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

-- Server hostname (via Tailscale or SSH config)
local SERVER = os.getenv("OPENCLAW_SERVER") or "l36"

-- Check auth status
os.execute("termux-toast \"Checking OpenClaw auth...\"")

local STATUS, EXIT_CODE = os_capture(string.format("ssh %s '$HOME/openclaw/scripts/claude-auth-status.sh simple' 2>&1", SERVER), true)
EXIT_CODE = 0 -- In lua we can't easily get exit code from os.capture, but script seems to handle errors in output

if STATUS == "OK" then
    -- Get remaining time
    local DETAILS = os_capture(string.format("ssh %s '$HOME/openclaw/scripts/claude-auth-status.sh json' 2>&1", SERVER), true)
    
    -- Simple JSON parsing for our specific case
    local HOURS = "?"
    for match in string.gmatch(DETAILS, '"status":"(%d+)h') do
        HOURS = match
        break
    end
    
    os.execute("termux-vibrate -d 50")
    os.execute(string.format("termux-toast \"Auth OK (%sh left)\"", HOURS))
    
elseif STATUS == "CLAUDE_EXPIRING" or STATUS == "OPENCLAW_EXPIRING" then
    os.execute("termux-vibrate -d 100")
    
    -- Ask if user wants to re-auth now
    local CHOICE = os_capture("termux-dialog radio -t \"Auth Expiring Soon\" -v \"Re-auth now,Check later,Dismiss\"", true)
    
    -- Simple JSON parsing to extract text field
    local SELECTED = "Dismiss"
    for match in string.gmatch(CHOICE, '"text"%s*:%s*"([^"]+)"') do
        SELECTED = match
        break
    end
    
    if SELECTED == "Re-auth now" then
        os.execute("termux-toast \"Opening auth page...\"")
        os.execute("termux-open-url \"https://console.anthropic.com/settings/api-keys\"")
        
        -- Show instructions
        os.execute("termux-dialog confirm -t \"Re-auth Instructions\" -i \"1. Create/copy API key from browser\\n2. Return here and tap OK\\n3. SSH to server and paste key\"")
        
        -- Open terminal to server
        os.execute("am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN")
        os.execute(string.format("termux-toast \"Run: ssh %s '$HOME/openclaw/scripts/mobile-reauth.sh'\"", SERVER))
    else
        os.execute("termux-toast \"Reminder: Auth expires soon\"")
    end
    
elseif STATUS == "CLAUDE_EXPIRED" or STATUS == "OPENCLAW_EXPIRED" then
    os.execute("termux-vibrate -d 300")
    
    local CHOICE = os_capture("termux-dialog radio -t \"Auth Expired!\" -v \"Re-auth now,Dismiss\"", true)
    
    -- Simple JSON parsing to extract text field
    local SELECTED = "Dismiss"
    for match in string.gmatch(CHOICE, '"text"%s*:%s*"([^"]+)"') do
        SELECTED = match
        break
    end
    
    if SELECTED == "Re-auth now" then
        os.execute("termux-toast \"Opening auth page...\"")
        os.execute("termux-open-url \"https://console.anthropic.com/settings/api-keys\"")
        
        os.execute("termux-dialog confirm -t \"Re-auth Steps\" -i \"1. Create/copy API key from browser\\n2. Return here and tap OK to SSH\"")
        
        os.execute("am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN")
        os.execute(string.format("termux-toast \"Run: ssh %s '$HOME/openclaw/scripts/mobile-reauth.sh'\"", SERVER))
    else
        os.execute("termux-toast \"Warning: OpenClaw won't work until re-auth\"")
    end
    
else
    os.execute("termux-vibrate -d 200")
    os.execute(string.format("termux-toast \"Error: %s\"", STATUS))
end
