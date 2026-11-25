#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "6f856f2276863b140fb06e0ea7644bcacb62e1b6a5dbe5e8ebf6b81dcef037c2", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "lua"}
-- translation-worker-node.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

-- Run on the selected node after transferring its native worker. JSON stdin is
-- forwarded unchanged to the worker in run mode.
local arg = {...}

if #arg ~= 2 then
  io.stderr:write('Usage: translation-worker-node.lua node2|node3|node4|node6 prepare|health|run\n')
  os.exit(2)
end

local worker, expected
if arg[1] == "node2" then
  worker = "/home/node/.openclaw/workers/translation-worker"
  expected = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286"
elseif arg[1] == "node3" then
  worker = "/home/openclaw/.openclaw/workers/translation-worker"
  expected = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de"
elseif arg[1] == "node4" then
  worker = "/root/.openclaw/workers/translation-worker"
  expected = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286"
elseif arg[1] == "node6" then
  worker = "/home/node/.openclaw/workers/translation-worker"
  expected = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de"
else
  io.stderr:write('Unknown or non-POSIX node\n')
  os.exit(2)
end

if arg[2] ~= "prepare" and arg[2] ~= "health" and arg[2] ~= "run" then
  io.stderr:write('Unknown action\n')
  os.exit(2)
end

local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local function is_symlink(name)
  local attr = lfs.attributes(name, "mode")
  return attr == "link"
end

if not file_exists(worker) or is_symlink(worker) then
  io.stderr:write("Missing worker or symlink rejected: " .. worker .. "\n")
  os.exit(1)
end

local function sha256sum(filename)
  local handle = io.popen("sha256sum '" .. filename .. "'")
  local result = handle:read("*a")
  handle:close()
  return result:match("^%w+")
end

local actual = sha256sum(worker)
if actual ~= expected then
  io.stderr:write("Worker checksum mismatch: " .. worker .. "\n")
  os.exit(1)
end

os.execute("chmod +x '" .. worker .. "'")

if arg[2] == "prepare" then
  print("Worker verified and executable: " .. worker)
elseif arg[2] == "health" then
  os.execute("'" .. worker .. "' --health")
elseif arg[2] == "run" then
  os.execute("'" .. worker .. "'")
end
