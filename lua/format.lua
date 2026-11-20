#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f70b2de2a3d39f783edc0962dfcb45a32bf3e547904a44762372309b345eb39f", "source_sha256": "ed82b1410f121f3b1436d54099143d7010035ba702c64f21d2669fce9dd3f2ae", "target_language": "lua"}
-- format.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/Swabble/scripts/format.sh
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function execute_command(command)
  local handle = io.popen(command .. " 2>&1", "r")
  local result = handle:read("*a")
  local success, _, _ = handle:close()
  return success, result
end

local function get_script_dir()
  local script_path = arg[0]:match("(.*/)")
  if script_path then
    return script_path .. "../"
  else
    return "../"
  end
end

local function realpath(path)
  local success, result = execute_command("cd '" .. path .. "' && pwd")
  if success then
    return result:gsub("%s+$", "")
  else
    error("Failed to resolve path: " .. path)
  end
end

-- Get root directory
local script_dir = get_script_dir()
local root = realpath(script_dir)

-- Set config file path
local config = root .. "/.swiftformat"

-- Execute swiftformat command
local command = string.format("swiftformat --config '%s' '%s/Sources'", config, root)
local success, output = execute_command(command)

if not success then
  io.stderr:write("Error executing swiftformat:\n" .. output)
  os.exit(1)
end

print(output)
