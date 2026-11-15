#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "4a4b44390aae8941f0d6b1ba257fb308fc9d5eb02284055549920aaa79d27cd4", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "lua"}
-- frame.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
-- auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

local function usage()
  io.stderr:write([[
Usage:
  frame.lua <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

Examples:
  frame.lua video.mp4 --out /tmp/frame.jpg
  frame.lua video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.lua video.mp4 --index 0 --out /tmp/frame0.png
]])
  os.exit(2)
end

local args = {...}
local in_file = args[1]

if not in_file or in_file == "-h" or in_file == "--help" then
  usage()
end

table.remove(args, 1)

local time = ""
local index = ""
local out = ""

local i = 1
while i <= #args do
  local arg = args[i]
  if arg == "--time" then
    time = args[i + 1] or ""
    i = i + 2
  elseif arg == "--index" then
    index = args[i + 1] or ""
    i = i + 2
  elseif arg == "--out" then
    out = args[i + 1] or ""
    i = i + 2
  else
    io.stderr:write("Unknown arg: " .. arg .. "\n")
    usage()
  end
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

if not file_exists(in_file) then
  io.stderr:write("File not found: " .. in_file .. "\n")
  os.exit(1)
end

if out == "" then
  io.stderr:write("Missing --out\n")
  usage()
end

-- Create directory path
local function dirname(path)
  local dir = path:match("(.*/)")
  if dir then
    return dir:sub(1, -2) -- remove trailing slash
  else
    return "."
  end
end

local dir = dirname(out)
os.execute("mkdir -p " .. dir)

local cmd
if index ~= "" then
  cmd = string.format([[ffmpeg -hide_banner -loglevel error -y -i "%s" -vf "select=eq(n\\,%s)" -vframes 1 "%s"]], in_file, index, out)
elseif time ~= "" then
  cmd = string.format([[ffmpeg -hide_banner -loglevel error -y -ss "%s" -i "%s" -frames:v 1 "%s"]], time, in_file, out)
else
  cmd = string.format([[ffmpeg -hide_banner -loglevel error -y -i "%s" -vf "select=eq(n\\,0)" -vframes 1 "%s"]], in_file, out)
end

local result = os.execute(cmd)
if result ~= true and result ~= 0 then
  os.exit(1)
end

print(out)
