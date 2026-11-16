#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a40604138d6181467226fd7ae407b221fc32c0f67d57aebe6b9feb43d40edc41", "source_sha256": "fe4cfd779f66ea7706f9bdfe3744e5d0a5b102609de3aca3ad086e40c76e8a2f", "target_language": "lua"}
-- build-and-run-mac.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build-and-run-mac.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]*$")
end

local function basename(path)
  return path:match("[/\\]([^/\\]*)$")
end

-- Change directory to apps/macos relative to script location
local script_path = arg[0]
local script_dir = dirname(script_path)
local target_dir = dirname(dirname(script_dir)) .. "/apps/macos"

-- Save current directory and change to target
local original_dir = os.getenv("PWD")
os.execute("cd " .. target_dir)

local BUILD_PATH = ".build-local"
local PRODUCT = "OpenClaw"
local BIN = BUILD_PATH .. "/debug/" .. PRODUCT

print("\n▶️  Building " .. PRODUCT .. " (debug, build path: " .. BUILD_PATH .. ")")
local build_result = os.execute("swift build -c debug --product \"" .. PRODUCT .. "\" --build-path \"" .. BUILD_PATH .. "\"")

if build_result ~= 0 then
  print("Build failed!")
  os.exit(1)
end

print("\n⏹  Stopping existing " .. PRODUCT .. "...")
os.execute("killall -q \"" .. PRODUCT .. "\" 2>/dev/null || true")

print("\n🚀 Launching " .. BIN .. " ...")
local pid = io.popen(BIN .. " >/tmp/openclaw.log 2>&1 & echo $!")

if pid then
  local pid_str = pid:read("*l")
  pid:close()
  
  if pid_str and pid_str ~= "" then
    print("Started " .. PRODUCT .. " (PID " .. pid_str .. "). Logs: /tmp/openclaw.log")
  else
    print("Started " .. PRODUCT .. ". Logs: /tmp/openclaw.log")
  end
else
  print("Failed to start " .. PRODUCT)
end

-- Restore original directory
if original_dir then
  os.execute("cd " .. original_dir)
end
