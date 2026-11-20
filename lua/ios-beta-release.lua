#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "32daa55195fc4d767fa25b694ccce7722837b437e196a6f526274befa2cdfd5d", "source_sha256": "74168ccc75bdca2481fb7bf1298fad30cea4e5fdd917205e7f1815e86948ca0c", "target_language": "lua"}
-- ios-beta-release.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-release.sh
-- Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

local function usage()
  print([[
Usage:
  scripts/ios-beta-release.sh [--build-number 7]

Archives and uploads a beta-release IPA to TestFlight locally.
]])
end

local function split(str, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep or " ")
  str:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

local function dirname(path)
  local dir = path:match("(.*/)")
  return dir and dir:sub(1, -2) or "."
end

local function basename(path)
  return path:match("([^/]-)$")
end

local function abspath(path)
  if path:sub(1,1) == "/" then
    return path
  else
    local cwd = io.popen("pwd"):read("*l")
    return cwd .. "/" .. path
  end
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  else
    return false
  end
end

local args = {...}
local build_number = os.getenv("IOS_BETA_BUILD_NUMBER") or ""
local root_dir = abspath(dirname(debug.getinfo(1).source:sub(2)) .. "/..")

local i = 1
while i <= #args do
  local arg = args[i]
  if arg == "--" then
    i = i + 1
  elseif arg == "--build-number" then
    if i+1 <= #args then
      build_number = args[i+1]
      i = i + 2
    else
      print("Error: --build-number requires a value")
      os.exit(1)
    end
  elseif arg == "-h" or arg == "--help" then
    usage()
    os.exit(0)
  else
    print("Unknown argument: " .. arg)
    usage()
    os.exit(1)
  end
end

local old_pwd = io.popen("pwd"):read("*l")
local success, err = pcall(function()
  os.execute("cd " .. root_dir .. "/apps/ios && IOS_BETA_BUILD_NUMBER=" .. build_number .. " fastlane ios beta")
end)

os.execute("cd " .. old_pwd)

if not success then
  print("Error executing command: " .. tostring(err))
  os.exit(1)
end
