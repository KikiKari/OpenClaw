#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "29eccdbb017e0296c5c29cb1fa61ed7e2a0a21fff561673292a4023282aeb75c", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "lua"}
-- git_publish.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
-- auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[Git Publish Agent - Automatisierte Skill-Veröffentlichung]]

local argparse = require "argparse"
local posix = require "posix"
local json = require "cjson"

local SKILLS_DIR = os.getenv("HOME") .. "/.openclaw/workspace/skills"

-- Helper function to execute shell commands
local function execute_command(command, cwd)
  local old_dir
  if cwd then
    old_dir = posix.getcwd()
    posix.chdir(cwd)
  end
  
  local handle = io.popen(table.concat(command, " "))
  local result = handle:read("*a")
  local success, _, code = handle:close()
  
  if cwd then
    posix.chdir(old_dir)
  end
  
  return success, result, code
end

local function git_commit(skill_path, message)
  -- Commit skill changes.
  if not message then
    message = "[skill] Auto-update " .. skill_path:match("([^/]+)$") .. " - " .. os.date("%Y-%m-%dT%H:%M:%S")
  end
  
  local add_success = execute_command({"git", "add", skill_path}, posix.dirname(SKILLS_DIR))
  if not add_success then return false end
  
  local commit_success, _, code = execute_command(
    {"git", "commit", "-m", '"' .. message .. '"'},
    posix.dirname(SKILLS_DIR)
  )
  
  return code == 0
end

local function clawhub_publish(skill_name)
  -- Publish to ClawHub.
  local skill_path = SKILLS_DIR .. "/" .. skill_name
  local command = {
    "clawhub", "publish", skill_path,
    "--slug", skill_name,
    "--version", "1.0.0"
  }
  
  local success, output, code = execute_command(command)
  return code == 0, output
end

local function batch_publish()
  -- Publish all changed skills with rate limiting.
  -- Check git status
  local success, output = execute_command(
    {"git", "status", "--short", SKILLS_DIR}
  )
  
  local changed = {}
  for line in output:gmatch("[^\r\n]+") do
    if line:match("%S") and line:match("skills/") then
      local skill = line:match("skills/([^/]+)")
      if skill and not changed[skill] then
        changed[skill] = true
      end
    end
  end
  
  -- Convert to array
  local changed_array = {}
  for skill, _ in pairs(changed) do
    table.insert(changed_array, skill)
  end
  
  print("Changed skills: " .. table.concat(changed_array, ", "))
  
  -- Publish with delay (limited to first 5)
  for i, skill in ipairs(changed_array) do
    if i > 5 then break end
    
    if i > 1 then
      print("Waiting 15min for rate limit...")
      -- In real: posix.sleep(900)
    end
    
    print("Publishing " .. skill .. "...")
    local commit_ok = git_commit(SKILLS_DIR .. "/" .. skill)
    if commit_ok then
      local pub_ok, output = clawhub_publish(skill)
      print(string.format("  %s %s", pub_ok and "✓" or "✗", output))
    end
  end
end

local function main()
  local parser = argparse.ArgumentParser("Git Publish Agent")
  parser:add_argument("--skill", {help = "Single skill to publish"})
  parser:add_argument("--all", {action = "store_true", help = "Publish all changed"})
  parser:add_argument("--no-publish", {action = "store_true", help = "Commit only"})
  parser:add_argument("--message", {help = "Custom commit message"})
  
  local args = parser:parse()
  
  if args.skill then
    local skill_path = SKILLS_DIR .. "/" .. args.skill
    if args.no_publish then
      git_commit(skill_path, args.message)
    else
      git_commit(skill_path, args.message)
      clawhub_publish(args.skill)
    end
  elseif args.all then
    batch_publish()
  else
    print("Use --skill <name> or --all")
  end
end

main()
