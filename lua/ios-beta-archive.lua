#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "1e7e410c3c9808e14e708acee1357483c368084fd663a40eca3d2019868ec33c", "source_sha256": "2cdcdc862375b173b06398d139b611f6f002e0435191f56d26d3e48a3cef02cf", "target_language": "lua"}
-- ios-beta-archive.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-archive.sh
-- Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

local function usage()
  print([[
Usage:
  scripts/ios-beta-archive.sh [--build-number 7]

Archives and exports a beta-release IPA locally without uploading.]])
end

local function split(str, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep)
  str:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

local function dirname(path)
  local parts = split(path, "/")
  if #parts <= 1 then return "." end
  local dir = table.concat(parts, "/", 1, #parts - 1)
  return dir ~= "" and dir or "/"
end

local function abspath(path)
  if path:sub(1,1) == "/" then
    return path
  else
    local current = io.popen("pwd"):read("*l")
    return current .. "/" .. path
  end
end

local function readlink(path)
  local f = io.popen("readlink -f '" .. path .. "' 2>/dev/null")
  local result = f:read("*l")
  f:close()
  return result or path
end

-- Get script directory and root directory
local script_path = debug.getinfo(1).source:match("@(.*)")
if not script_path then script_path = arg[0] end
local script_dir = dirname(script_path)
local root_dir = abspath(script_dir .. "/..")

-- Handle environment variable with default
local build_number = os.getenv("IOS_BETA_BUILD_NUMBER") or ""

-- Parse command line arguments
local i = 1
while i <= #arg do
  local arg_val = arg[i]
  if arg_val == "--" then
    i = i + 1
  elseif arg_val == "--build-number" then
    build_number = arg[i + 1] or ""
    i = i + 2
  elseif arg_val == "-h" or arg_val == "--help" then
    usage()
    os.exit(0)
  else
    if arg_val:sub(1,1) == "-" then
      io.stderr:write("Unknown argument: " .. arg_val .. "\n")
      usage()
      os.exit(1)
    end
    i = i + 1
  end
end

-- Change to iOS app directory and execute fastlane
local ios_dir = root_dir .. "/apps/ios"
local old_pwd = io.popen("pwd"):read("*l")

-- Change directory
local success = os.execute("cd '" .. ios_dir .. "'")
if not success then
  io.stderr:write("Failed to change to directory: " .. ios_dir .. "\n")
  os.exit(1)
end

-- Set environment variable and run fastlane command
local cmd = "IOS_BETA_BUILD_NUMBER='" .. build_number .. "' fastlane ios beta_archive"
local exit_code = os.execute(cmd)

-- Restore original directory
os.execute("cd '" .. old_pwd .. "'")

if exit_code ~= 0 then
  os.exit(1)
end
