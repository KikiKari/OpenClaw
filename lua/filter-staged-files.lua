#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "9311fd46dbff50d6436e08a08b0331b853f46882961e1902e1c9785dac3ce930", "source_sha256": "bf11781342e249f3bb5e5746f94668968b3fed5b83b099b77d5a9bb8ec38b713", "target_language": "lua"}
-- filter-staged-files.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/pre-commit/filter-staged-files.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

--[[
  Prints selected files as NUL-delimited tokens to stdout.

  Usage:
    lua filter-staged-files.lua lint -- <files...>
    lua filter-staged-files.lua format -- <files...>

  Keep this dependency-free: the pre-commit hook runs in many environments.
]]

local mode = arg[1]
local files = {}

-- Parse arguments, skipping "--" if present
local start_index = 2
if arg[2] == "--" then
  start_index = 3
end

for i = start_index, #arg do
  table.insert(files, arg[i])
end

if mode ~= "lint" and mode ~= "format" then
  io.stderr:write("usage: filter-staged-files.lua <lint|format> -- <files...>\n")
  os.exit(2)
end

-- Define extensions sets
local lintExts = { [".ts"] = true, [".tsx"] = true, [".js"] = true, [".jsx"] = true, [".mjs"] = true, [".cjs"] = true }
local formatExts = { [".ts"] = true, [".tsx"] = true, [".js"] = true, [".jsx"] = true, [".mjs"] = true, [".cjs"] = true, [".json"] = true, [".md"] = true, [".mdx"] = true }
local formatIgnoredPaths = { ["src/canvas-host/a2ui/a2ui.bundle.js"] = true }

-- Function to get file extension
local function getFileExtension(filePath)
  local match = string.match(filePath, "%.[^.]*$")
  return match and string.lower(match) or ""
end

-- Selection logic
local function shouldSelect(filePath)
  local ext = getFileExtension(filePath)
  if mode == "lint" then
    return lintExts[ext] == true
  end
  if formatIgnoredPaths[filePath] == true then
    return false
  end
  return formatExts[ext] == true
end

-- Process files
for _, file in ipairs(files) do
  if shouldSelect(file) then
    io.stdout:write(file)
    io.stdout:write("\0")
  end
end
