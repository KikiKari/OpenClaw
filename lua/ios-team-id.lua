#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "532772d0d81856c6db9ce801509d51d036bafef09723fe1b0c865073ee94ffa7", "source_sha256": "ff0a573c1d18ce8554e3d7311f3c2ae463c9664ad4b824e0cb5888b499733213", "target_language": "lua"}
-- ios-team-id.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-team-id.sh
-- Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

local function getenv_default(var, default)
  local val = os.getenv(var)
  if val == nil or val == "" then
    return default
  end
  return val
end

local function trim(s)
  if s == nil then return "" end
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function split(str, sep)
  local result = {}
  if str == nil then return result end
  local pattern = string.format("([^%s]+)", sep or "%s+")
  for part in str:gmatch(pattern) do
    table.insert(result, trim(part))
  end
  return result
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function command_exists(cmd)
  local handle = io.popen("command -v " .. cmd .. " 2>/dev/null", "r")
  local result = handle:read("*a")
  handle:close()
  return result ~= ""
end

local function run_command(cmd)
  local handle = io.popen(cmd, "r")
  local result = handle:read("*a")
  handle:close()
  return result
end

-- Main logic
local ios_development_team = os.getenv("IOS_DEVELOPMENT_TEAM")
if ios_development_team and ios_development_team ~= "" then
  print(ios_development_team)
  os.exit(0)
end

local preferred_team = getenv_default("IOS_PREFERRED_TEAM_ID", getenv_default("OPENCLAW_IOS_DEFAULT_TEAM_ID", "Y5PE65HELJ"))
local preferred_team_name = getenv_default("IOS_PREFERRED_TEAM_NAME", "")
local allow_keychain_fallback = getenv_default("IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK", "0")
local prefer_non_free_team = getenv_default("IOS_PREFER_NON_FREE_TEAM", "1")

preferred_team = preferred_team:gsub("\r", "")
preferred_team_name = preferred_team_name:gsub("\r", "")

local team_ids = {}
local team_is_free = {}
local team_names = {}

local function detect_python()
  local candidates = {os.getenv("IOS_PYTHON_BIN"), "python3", "python", "/usr/bin/python3"}
  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= "" and command_exists(candidate) then
      return candidate
    end
  end
  return nil
end

local python_cmd = detect_python()

local function append_team(candidate_id, candidate_is_free, candidate_name)
  candidate_id = candidate_id:gsub("\r", "")
  candidate_is_free = candidate_is_free:gsub("\r", "")
  candidate_name = candidate_name:gsub("\r", "")
  
  if candidate_id == "" then return end
  
  for _, id in ipairs(team_ids) do
    if id == candidate_id then
      return
    end
  end
  
  table.insert(team_ids, candidate_id)
  table.insert(team_is_free, candidate_is_free)
  table.insert(team_names, candidate_name)
end

local function load_teams_from_xcode_preferences()
  local plist_path = os.getenv("HOME") .. "/Library/Preferences/com.apple.dt.Xcode.plist"
  if not file_exists(plist_path) or not python_cmd then return end
  
  local cmd = string.format("plutil -extract IDEProvisioningTeams json -o - '%s' 2>/dev/null", plist_path)
  local python_script = [[
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

if not isinstance(data, dict):
    raise SystemExit(0)

for teams in data.values():
    if not isinstance(teams, list):
        continue
    for team in teams:
        if not isinstance(team, dict):
            continue
        team_id = str(team.get("teamID", "")).strip()
        if not team_id:
            continue
        is_free = "1" if bool(team.get("isFreeProvisioningTeam", False)) else "0"
        team_name = str(team.get("teamName", "")).replace("\t", " ").strip()
        print(f"{team_id}\t{is_free}\t{team_name}")
]]
  
  local full_cmd = cmd .. " | " .. python_cmd .. " -c '" .. python_script .. "'"
  local result = run_command(full_cmd)
  
  for line in result:gmatch("[^\r\n]+") do
    local parts = split(line, "\t")
    if #parts >= 1 and parts[1] ~= "" then
      local team_id = parts[1]
      local is_free = (#parts >= 2 and parts[2]) and parts[2] or "0"
      local team_name = (#parts >= 3 and parts[3]) and parts[3] or ""
      append_team(team_id, is_free, team_name)
    end
  end
end

local function load_teams_from_legacy_defaults_key()
  local cmd = "defaults read com.apple.dt.Xcode IDEProvisioningTeamIdentifiers 2>/dev/null | grep -Eo '[A-Z0-9]{10}' || true"
  local result = run_command(cmd)
  
  for line in result:gmatch("[^\r\n]+") do
    if line ~= "" then
      append_team(line, "0", "")
    end
  end
end

local function load_teams_from_xcode_managed_profiles()
  local profiles_dir = os.getenv("HOME") .. "/Library/MobileDevice/Provisioning Profiles"
  if not file_exists(profiles_dir .. "/.") or not python_cmd then return end
  
  local python_script = [[
import plistlib, sys
try:
    raw = sys.stdin.buffer.read()
    if not raw:
        raise SystemExit(0)
    d = plistlib.loads(raw)
    for tid in d.get("TeamIdentifier", []):
        print(tid)
except Exception:
    pass
]]
  
  local teams = {}
  for file in io.popen('ls "' .. profiles_dir .. '"/*.mobileprovision 2>/dev/null'):lines() do
    if file_exists(file) then
      local cmd = string.format('security cms -D -i "%s" 2>/dev/null | %s -c \'%s\' 2>/dev/null', file, python_cmd, python_script)
      local result = run_command(cmd)
      for line in result:gmatch("[^\r\n]+") do
        if line ~= "" then
          teams[line] = true
        end
      end
    end
  end
  
  -- Sort unique teams
  local sorted_teams = {}
  for team in pairs(teams) do
    table.insert(sorted_teams, team)
  end
  table.sort(sorted_teams)
  
  for _, team in ipairs(sorted_teams) do
    append_team(team, "0", "")
  end
end

local function has_xcode_account()
  local plist_path = os.getenv("HOME") .. "/Library/Preferences/com.apple.dt.Xcode.plist"
  if not file_exists(plist_path) then return false end
  
  local cmd = "defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null || true"
  local result = run_command(cmd)
  
  return result ~= "" and not result:find("does not exist") and result:find("identifier")
end

load_teams_from_xcode_preferences()
load_teams_from_legacy_defaults_key()

if #team_ids == 0 then
  load_teams_from_xcode_managed_profiles()
end

if #team_ids == 0 and allow_keychain_fallback == "1" then
  local cmd = "security find-identity -p codesigning -v 2>/dev/null | grep -Eo '\\([A-Z0-9]{10}\\)' | tr -d '()' || true"
  local result = run_command(cmd)
  
  for line in result:gmatch("[^\r\n]+") do
    if line ~= "" then
      append_team(line, "0", "")
    end
  end
end

if #team_ids == 0 then
  if has_xcode_account() then
    io.stderr:write("An Apple account is signed in to Xcode, but no Team ID could be resolved.\n")
    io.stderr:write("\n")
    io.stderr:write("On Xcode 16+, team data is not written until you build a project.\n")
    io.stderr:write("To fix this, do ONE of the following:\n")
    io.stderr:write("\n")
    io.stderr:write("  1. Open the iOS project in Xcode, select your Team in Signing &\n")
    io.stderr:write("     Capabilities, and build once. Then re-run this script.\n")
    io.stderr:write("\n")
    io.stderr:write("  2. Set your Team ID directly:\n")
    io.stderr:write("       export IOS_DEVELOPMENT_TEAM=<your-10-char-team-id>\n")
    io.stderr:write("     Find your Team ID at: https://developer.apple.com/account#MembershipDetailsCard\n")
  elseif allow_keychain_fallback == "1" then
    io.stderr:write("No Apple Team ID found. Open Xcode or install signing certificates first.\n")
  else
    io.stderr:write("No Apple Team ID found in Xcode accounts. Open Xcode → Settings → Accounts and sign in, then retry.\n")
    io.stderr:write("(Set IOS_ALLOW_KEYCHAIN_TEAM_FALLBACK=1 to allow keychain-only team detection.)\n")
  end
  os.exit(1)
end

for i, team_id in ipairs(team_ids) do
  if team_id == preferred_team then
    print(team_id)
    os.exit(0)
  end
end

if preferred_team_name ~= "" then
  local preferred_team_name_lc = preferred_team_name:lower()
  for i, team_name in ipairs(team_names) do
    local team_name_lc = team_name:lower()
    if team_name_lc == preferred_team_name_lc then
      print(team_ids[i])
      os.exit(0)
    end
  end
end

if prefer_non_free_team == "1" then
  for i, is_free in ipairs(team_is_free) do
    if is_free == "0" then
      print(team_ids[i])
      os.exit(0)
    end
  end
end

print(team_ids[1])
