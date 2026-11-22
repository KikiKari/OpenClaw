#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "ef9af1d1b4c879dba993d9bec43c30db41b6a081aa590603a272cc744f4f1ba8", "source_sha256": "29aab8d3e497ddaa7ec77edf107b153fe17970d064df8a91d7cfcedb7e30a7fd", "target_language": "lua"}
-- sandbox-browser-entrypoint.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-browser-entrypoint.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local posix = require("posix")
local socket = require("socket")

-- Set environment variables
os.execute("export DBUS_SESSION_BUS_ADDRESS=/dev/null")

os.execute("export DISPLAY=:1")
os.execute("export HOME=/tmp/openclaw-home")
os.execute("export XDG_CONFIG_HOME=\"${HOME}/.config\"")
os.execute("export XDG_CACHE_HOME=\"${HOME}/.cache\"")

-- Get environment variables with defaults
local CDP_PORT = os.getenv("OPENCLAW_BROWSER_CDP_PORT") or "9222"
local CDP_SOURCE_RANGE = os.getenv("OPENCLAW_BROWSER_CDP_SOURCE_RANGE") or ""
local VNC_PORT = os.getenv("OPENCLAW_BROWSER_VNC_PORT") or "5900"
local NOVNC_PORT = os.getenv("OPENCLAW_BROWSER_NOVNC_PORT") or "6080"
local ENABLE_NOVNC = os.getenv("OPENCLAW_BROWSER_ENABLE_NOVNC") or "1"
local HEADLESS = os.getenv("OPENCLAW_BROWSER_HEADLESS") or "0"
local ALLOW_NO_SANDBOX = os.getenv("OPENCLAW_BROWSER_NO_SANDBOX") or "0"
local NOVNC_PASSWORD = os.getenv("OPENCLAW_BROWSER_NOVNC_PASSWORD") or ""

local DISABLE_GRAPHICS_FLAGS = os.getenv("OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS") or "1"
local DISABLE_EXTENSIONS = os.getenv("OPENCLAW_BROWSER_DISABLE_EXTENSIONS") or "1"
local RENDERER_PROCESS_LIMIT = os.getenv("OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT") or "2"
local AUTO_START_TIMEOUT_MS = os.getenv("OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS") or "12000"

-- Validate unsigned integer function
local function validate_uint(name, value, min, max)
  min = min or 0
  max = max or 4294967295
  
  if not string.match(value, "^%d+$") then
    io.stderr:write("[sandbox] ERROR: " .. name .. " must be an integer, got: " .. value .. "\n")
    os.exit(1)
  end
  
  local num_value = tonumber(value)
  if num_value < min or num_value > max then
    io.stderr:write("[sandbox] ERROR: " .. name .. " out of range (" .. min .. ".." .. max .. "), got: " .. value .. "\n")
    os.exit(1)
  end
end

-- Validate ports and timeout
validate_uint("CDP_PORT", CDP_PORT, 1, 65535)
validate_uint("VNC_PORT", VNC_PORT, 1, 65535)
validate_uint("NOVNC_PORT", NOVNC_PORT, 1, 65535)
validate_uint("AUTO_START_TIMEOUT_MS", AUTO_START_TIMEOUT_MS, 1, 2147483647)
if RENDERER_PROCESS_LIMIT ~= "" then
  validate_uint("RENDERER_PROCESS_LIMIT", RENDERER_PROCESS_LIMIT, 0, 2147483647)
end

-- Global variables for process IDs
local WEBSOCKIFY_PID = nil
local X11VNC_PID = nil
local SOCAT_PID = nil
local CHROME_PID = nil
local XVFB_PID = nil

-- Cleanup function
local function cleanup(code)
  code = code or 1
  
  -- Remove signal handlers
  posix.signal(signal.SIGINT, "SIG_DFL")
  posix.signal(signal.SIGTERM, "SIG_DFL")
  
  local pids = {}
  if WEBSOCKIFY_PID then table.insert(pids, WEBSOCKIFY_PID) end
  if X11VNC_PID then table.insert(pids, X11VNC_PID) end
  if SOCAT_PID then table.insert(pids, SOCAT_PID) end
  if CHROME_PID then table.insert(pids, CHROME_PID) end
  if XVFB_PID then table.insert(pids, XVFB_PID) end
  
  if #pids > 0 then
    -- Send TERM signal
    for _, pid in ipairs(pids) do
      posix.kill(pid, posix.SIGTERM)
    end
    
    -- Wait for processes to terminate
    for i = 1, 10 do
      local alive = false
      for _, pid in ipairs(pids) do
        local status, err = posix.kill(pid, 0)
        if status ~= nil then
          alive = true
          break
        end
      end
      
      if not alive then
        break
      end
      socket.sleep(0.2)
    end
    
    -- Kill remaining processes
    for _, pid in ipairs(pids) do
      posix.kill(pid, posix.SIGKILL)
    end
    
    -- Wait for all processes
    posix.wait(-1)
  end
  
  os.exit(code)
end

-- Set up signal handlers
posix.signal(posix.SIGINT, function() cleanup(130) end)
posix.signal(posix.SIGTERM, function() cleanup(143) end)

-- Create directories
os.execute("mkdir -p \"${HOME}\" \"${HOME}/.chrome\" \"${XDG_CONFIG_HOME}\" \"${XDG_CACHE_HOME}\"")

-- Start Xvfb
local xvfb_cmd = "Xvfb :1 -screen 0 1280x800x24 -ac -nolisten tcp &"
local handle = io.popen(xvfb_cmd .. " echo $!")
XVFB_PID = handle:read("*l")
handle:close()
print("[sandbox] Xvfb started (PID: " .. XVFB_PID .. ")")

-- Calculate Chrome CDP port
local CHROME_CDP_PORT
if tonumber(CDP_PORT) >= 65535 then
  CHROME_CDP_PORT = tostring(tonumber(CDP_PORT) - 1)
else
  CHROME_CDP_PORT = tostring(tonumber(CDP_PORT) + 1)
end

-- Build Chrome arguments
local CHROME_ARGS = {
  "--remote-debugging-address=127.0.0.1",
  "--remote-debugging-port=" .. CHROME_CDP_PORT,
  "--user-data-dir=${HOME}/.chrome",
  "--no-first-run",
  "--no-default-browser-check",
  "--disable-dev-shm-usage",
  "--disable-background-networking",
  "--disable-breakpad",
  "--disable-crash-reporter",
  "--no-zygote",
  "--metrics-recording-only",
  "--password-store=basic",
  "--use-mock-keychain"
}

if HEADLESS == "1" then
  table.insert(CHROME_ARGS, "--headless=new")
end

if ALLOW_NO_SANDBOX == "1" then
  table.insert(CHROME_ARGS, "--no-sandbox")
  table.insert(CHROME_ARGS, "--disable-setuid-sandbox")
end

local DISABLE_GRAPHICS_FLAGS_LOWER = string.lower(DISABLE_GRAPHICS_FLAGS)
if DISABLE_GRAPHICS_FLAGS_LOWER == "1" or 
   DISABLE_GRAPHICS_FLAGS_LOWER == "true" or 
   DISABLE_GRAPHICS_FLAGS_LOWER == "yes" or 
   DISABLE_GRAPHICS_FLAGS_LOWER == "on" then
  table.insert(CHROME_ARGS, "--disable-3d-apis")
  table.insert(CHROME_ARGS, "--disable-gpu")
  table.insert(CHROME_ARGS, "--disable-software-rasterizer")
end

local DISABLE_EXTENSIONS_LOWER = string.lower(DISABLE_EXTENSIONS)
if DISABLE_EXTENSIONS_LOWER == "1" or 
   DISABLE_EXTENSIONS_LOWER == "true" or 
   DISABLE_EXTENSIONS_LOWER == "yes" or 
   DISABLE_EXTENSIONS_LOWER == "on" then
  table.insert(CHROME_ARGS, "--disable-extensions")
end

if string.match(RENDERER_PROCESS_LIMIT, "^%d+$") and tonumber(RENDERER_PROCESS_LIMIT) > 0 then
  table.insert(CHROME_ARGS, "--renderer-process-limit=" .. RENDERER_PROCESS_LIMIT)
end

print("[sandbox] Starting Chromium...")
local chrome_cmd = "chromium " .. table.concat(CHROME_ARGS, " ") .. " about:blank &"
handle = io.popen(chrome_cmd .. " echo $!")
CHROME_PID = handle:read("*l")
handle:close()
print("[sandbox] Chromium started (PID: " .. CHROME_PID .. ")")

-- Wait for CDP to be ready
local start_ms = socket.gettime() * 1000
local deadline_ms = start_ms + tonumber(AUTO_START_TIMEOUT_MS)
local CDP_READY = false
local probe_url = "http://127.0.0.1:" .. CHROME_CDP_PORT .. "/json/version"

print("[sandbox] Waiting up to " .. AUTO_START_TIMEOUT_MS .. "ms for CDP on port " .. CHROME_CDP_PORT .. "...")

while socket.gettime() * 1000 < deadline_ms do
  -- Check if Chrome is still running
  local status, err = posix.kill(tonumber(CHROME_PID), 0)
  if status == nil then
    print("[sandbox] ERROR: Chromium exited before CDP became ready.")
    os.exit(1)
  end
  
  -- Try to connect to CDP endpoint
  local http = require("socket.http")
  local ltn12 = require("ltn12")
  local response_body = {}
  
  local res, code, headers, status_line = http.request{
    url = probe_url,
    method = "GET",
    sink = ltn12.sink.table(response_body),
    timeout = 0.5
  }
  
  if code == 200 then
    CDP_READY = true
    break
  end
  
  socket.sleep(0.2)
end

if not CDP_READY then
  print("[sandbox] ERROR: CDP failed to start within " .. AUTO_START_TIMEOUT_MS .. "ms.")
  os.exit(1)
end

print("[sandbox] CDP ready. Starting socat...")

if CDP_SOURCE_RANGE == "" then
  io.stderr:write("[sandbox-browser] WARNING: CDP_SOURCE_RANGE unset; socat CDP relay will not start.\n")
  io.stderr:write("[sandbox-browser] Set OPENCLAW_BROWSER_CDP_SOURCE_RANGE to an explicit CIDR to enable CDP access.\n")
else
  local SOCAT_LISTEN_ADDR = "TCP-LISTEN:" .. CDP_PORT .. ",fork,reuseaddr,bind=0.0.0.0,range=" .. CDP_SOURCE_RANGE
  local socat_cmd = "socat \"" .. SOCAT_LISTEN_ADDR .. "\" \"TCP:127.0.0.1:" .. CHROME_CDP_PORT .. "\" &"
  handle = io.popen(socat_cmd .. " echo $!")
  SOCAT_PID = handle:read("*l")
  handle:close()
  print("[sandbox] socat started (PID: " .. SOCAT_PID .. ")")
end

if ENABLE_NOVNC == "1" and HEADLESS ~= "1" then
  if NOVNC_PASSWORD == "" then
    -- Generate password from UUID
    handle = io.popen("cat /proc/sys/kernel/random/uuid")
    local uuid = handle:read("*l")
    handle:close()
    NOVNC_PASSWORD = string.gsub(uuid, "-", "")
    NOVNC_PASSWORD = string.sub(NOVNC_PASSWORD, 1, 8)
  end
  
  os.execute("mkdir -p \"${HOME}/.vnc\"")
  os.execute("x11vnc -storepasswd \"" .. NOVNC_PASSWORD .. "\" \"${HOME}/.vnc/passwd\" >/dev/null")
  os.execute("chmod 600 \"${HOME}/.vnc/passwd\"")
  
  local x11vnc_cmd = "x11vnc -display :1 -rfbport " .. VNC_PORT .. " -shared -forever -rfbauth \"${HOME}/.vnc/passwd\" -localhost &"
  handle = io.popen(x11vnc_cmd .. " echo $!")
  X11VNC_PID = handle:read("*l")
  handle:close()
  print("[sandbox] x11vnc started (PID: " .. X11VNC_PID .. ")")
  
  local websockify_cmd = "websockify --web /usr/share/novnc/ " .. NOVNC_PORT .. " localhost:" .. VNC_PORT .. " &"
  handle = io.popen(websockify_cmd .. " echo $!")
  WEBSOCKIFY_PID = handle:read("*l")
  handle:close()
  print("[sandbox] websockify started (PID: " .. WEBSOCKIFY_PID .. ")")
end

print("[sandbox] Container running. Monitoring all sub-processes...")

-- Monitor processes (simplified version)
while true do
  socket.sleep(1)
  -- In a real implementation, you would check if any child processes have exited
end
