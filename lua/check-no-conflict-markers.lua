#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "6878f7c17ca80f129ee4a90f996dcf37135add74f7253731b8525815b4e96942", "source_sha256": "c76d61da97f14736857987d3dd8234160c73b0a1b52ade5aac72de04cc61e7e6", "target_language": "lua"}
-- check-no-conflict-markers.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-conflict-markers.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local uv = require("uv")
local fs = require("fs")
local path = require("path")

-- Helper to check if a string contains binary data (null bytes)
local function is_binary_string(str)
  return string.find(str, "\0") ~= nil
end

-- Find conflict marker lines in content
local function find_conflict_marker_lines(content)
  local lines = {}
  for line in string.gmatch(content, "[^\r\n]+") do
    table.insert(lines, line)
  end
  -- Handle case where content ends with newline
  if string.sub(content, -1) == "\n" or string.sub(content, -1) == "\r" then
    table.insert(lines, "")
  end
  
  local matches = {}
  for i, line in ipairs(lines) do
    if string.sub(line, 1, 8) == "<<<<<<< " or
       string.sub(line, 1, 8) == "||||||| " or
       line == "=======" or
       string.sub(line, 1, 8) == ">>>>>>> " then
      table.insert(matches, i)
    end
  end
  return matches
end

-- List tracked files using git ls-files
local function list_tracked_files(cwd)
  cwd = cwd or uv.cwd()
  local handle, err = io.popen("git ls-files -z", "r")
  if not handle then
    error("Failed to run git ls-files: " .. tostring(err))
  end
  
  local output = handle:read("*a")
  local success, exit_code, signal = handle:close()
  
  if not success and exit_code ~= 0 then
    error("git ls-files failed with exit code: " .. tostring(exit_code))
  end
  
  local files = {}
  for filepath in string.gmatch(output, "[^\0]+") do
    if filepath ~= "" then
      table.insert(files, path.join(cwd, filepath))
    end
  end
  
  return files
end

-- Find conflict markers in files
local function find_conflict_markers_in_files(file_paths)
  local violations = {}
  
  for _, file_path in ipairs(file_paths) do
    local content, err = fs.readFileSync(file_path, "utf8")
    if not content then
      -- Skip unreadable files
      goto continue
    end
    
    -- Check if it's a binary file
    if is_binary_string(content) then
      goto continue
    end
    
    local lines = find_conflict_marker_lines(content)
    if #lines > 0 then
      table.insert(violations, {
        filePath = file_path,
        lines = lines
      })
    end
    
    ::continue::
  end
  
  return violations
end

-- Main function
local function main()
  local cwd = uv.cwd()
  local file_paths = list_tracked_files(cwd)
  local violations = find_conflict_markers_in_files(file_paths)
  
  if #violations == 0 then
    return 0
  end
  
  print("Found unresolved merge conflict markers:")
  for _, violation in ipairs(violations) do
    local relative_path = path.relative(cwd, violation.filePath) or violation.filePath
    local lines_str = table.concat(violation.lines, ",")
    print("- " .. relative_path .. ":" .. lines_str)
  end
  
  return 1
end

-- Run main if this script is executed directly
if arg and arg[0] and path.resolve(arg[0]) == path.resolve(debug.getinfo(1).source:sub(2)) then
  local status, result = pcall(main)
  if not status then
    print(result)
    os.exit(1)
  else
    os.exit(result)
  end
end

return {
  findConflictMarkerLines = find_conflict_marker_lines,
  listTrackedFiles = list_tracked_files,
  findConflictMarkersInFiles = find_conflict_markers_in_files,
  main = main
}
