#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "a59b17dbbe70d20cc2eb11a8591c25389680e2c7a683b4d58a097662e0c906c5", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "lua"}
-- frame.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
-- auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

local function usage()
  io.stderr:write([[
Usage:
  frame.sh <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

Examples:
  frame.sh video.mp4 --out /tmp/frame.jpg
  frame.sh video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.sh video.mp4 --index 0 --out /tmp/frame0.png
]])
  os.exit(2)
end

local args = {...}
local in_file = ""
local time = ""
local index = ""
local out = ""

if #args == 0 or args[1] == "-h" or args[1] == "--help" then
  usage()
end

in_file = table.remove(args, 1)

while #args > 0 do
  local arg = table.remove(args, 1)
  if arg == "--time" then
    time = table.remove(args, 1) or ""
  elseif arg == "--index" then
    index = table.remove(args, 1) or ""
  elseif arg == "--out" then
    out = table.remove(args, 1) or ""
  else
    io.stderr:write("Unknown arg: " .. arg .. "\n")
    usage()
  end
end

if in_file == "" or not in_file then
  io.stderr:write("Missing input file\n")
  os.exit(1)
end

local file = io.open(in_file, "r")
if not file then
  io.stderr:write("File not found: " .. in_file .. "\n")
  os.exit(1)
end
file:close()

if out == "" then
  io.stderr:write("Missing --out\n")
  usage()
end

-- Create directory if it doesn't exist
local out_dir = out:match("(.*/)")
if out_dir then
  os.execute("mkdir -p " .. out_dir)
end

local cmd = "ffmpeg -hide_banner -loglevel error -y "

if index ~= "" then
  cmd = cmd .. "-i '" .. in_file .. "' -vf 'select=eq(n\\," .. index .. ")' -vframes 1 '" .. out .. "'"
elseif time ~= "" then
  cmd = cmd .. "-ss " .. time .. " -i '" .. in_file .. "' -frames:v 1 '" .. out .. "'"
else
  cmd = cmd .. "-i '" .. in_file .. "' -vf 'select=eq(n\\,0)' -vframes 1 '" .. out .. "'"
end

local result = os.execute(cmd)
if result ~= 0 then
  os.exit(1)
end

print(out)
