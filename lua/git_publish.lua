#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "8d0c27d2eaecf2af9931692f081bbd7988728246a2fc2122cea228edb102617d", "source_sha256": "4c10c6b6fd911cb95da119f761f402073d1a836cab6b40a9f3b989536d5df5ec", "target_language": "lua"}
-- git_publish.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/git-publish-agent/scripts/git_publish.py
-- auch in: OpenClaw@gateway2:skills/git-publish-agent/scripts/git_publish.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[Git Publish Agent - Automatisierte Skill-Veröffentlichung]]

local argparse = require "argparse"
local json = require "cjson"
local posix = require "posix"
local socket = require "socket"

local SKILLS_DIR = os.getenv("HOME") .. "/.openclaw/workspace/skills"

-- Helper function to execute shell commands
local function execute_command(command, cwd)
  local old_dir
  if cwd then
    old_dir = posix.getcwd()
    posix.chdir(cwd)
  end
  
  local handle = io.popen(command)
  local result = handle:read("*a")
  local success, _, exit_code = handle:close()
  
  if cwd then
    posix.chdir(old_dir)
  end
  
  return success, result, exit_code
end

-- Commit skill changes
local function git_commit(skill_path, message)
  if not message then
    message = "[skill] Auto-update " .. skill_path:match("([^/]+)/?$") .. " - " .. os.date("%Y-%m-%dT%H:%M:%S")
  end
  
  local parent_dir = SKILLS_DIR:match("(.-)/?[^/]*/*$")
  local add_cmd = string.format("git add '%s'", skill_path)
  local commit_cmd = string.format("git commit -m '%s'", message)
  
  local add_success = execute_command(add_cmd, parent_dir)
  local commit_success, _, exit_code = execute_command(commit_cmd, parent_dir)
  
  return commit_success and exit_code == 0
end

-- Publish to ClawHub
local function clawhub_publish(skill_name)
  local skill_path = SKILLS_DIR .. "/" .. skill_name
  local cmd = string.format("clawhub publish '%s' --slug %s --version 1.0.0", skill_path, skill_name)
  
  local success, output, exit_code = execute_command(cmd)
  return success and exit_code == 0, output
end

-- Publish all changed skills with rate limiting
local function batch_publish()
  -- Check git status
  local cmd = string.format("git status --short '%s'", SKILLS_DIR)
  local parent_dir = SKILLS_DIR:match("(.-)/?[^/]*/*$")
  local success, output = execute_command(cmd, parent_dir)
  
  local changed = {}
  for line in output:gmatch("[^\r\n]+") do
    if line:match("%S") and line:find("skills/") then
      local skill = line:match("skills/([^/]+)")
      if skill and not changed[skill] then
        table.insert(changed, skill)
        changed[skill] = true
      end
    end
  end
  
  print("Changed skills: " .. table.concat(changed, ", "))
  
  -- Publish with delay (simulated)
  for i, skill in ipairs(changed) do
    if i > 1 and i <= 5 then  -- Max 5 per batch
      print("Waiting 15min for rate limit...")
      -- In real: socket.sleep(900)
    end
    
    print("Publishing " .. skill .. "...")
    local commit_ok = git_commit(SKILLS_DIR .. "/" .. skill)
    if commit_ok then
      local pub_ok, output = clawhub_publish(skill)
      print(string.format("  %s %s", pub_ok and "✓" or "✗", output))
    end
  end
end

-- Main function
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
