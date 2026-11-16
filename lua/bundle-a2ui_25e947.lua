#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "0d2a71137321c6285bf32b91e50cc169d8138e7803cd1c60ac2f8086ba7cb5ad", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "lua"}
-- bundle-a2ui.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]*$")
end

local function basename(path)
  return path:match("[/\\]([^/\\]*)$")
end

local function realpath(path)
  local current = path
  local link_count = 0
  while true do
    local attr = lfs.attributes(current, "mode")
    if not attr then break end
    if attr == "link" then
      if link_count > 10 then error("Too many links") end
      local target = lfs.readlink(current)
      if not target then error("Cannot read link: " .. current) end
      if target:sub(1,1) ~= "/" then
        current = dirname(current) .. "/" .. target
      else
        current = target
      end
      link_count = link_count + 1
    else
      break
    end
  end
  return current
end

local script_path = arg[0]
if not script_path:match("^/") then
  script_path = lfs.currentdir() .. "/" .. script_path
end

script_path = realpath(script_path)
local script_dir = dirname(script_path)
local root_dir = dirname(script_dir)

local node_executable = "node"
local script_file = root_dir .. "/scripts/bundle-a2ui.mjs"

-- Build command arguments
local cmd_args = {node_executable, script_file}
for i, v in ipairs(arg) do
  table.insert(cmd_args, v)
end

-- Execute the command
local success, exit_code, exit_signal = os.execute(table.concat(cmd_args, " "))
if success == true then
  -- Command succeeded
  os.exit(0)
elseif type(success) == "number" then
  -- Command failed with exit code
  os.exit(success)
else
  -- Command failed
  os.exit(1)
end
