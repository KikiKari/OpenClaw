#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "008624d0c231c3498d8e3b4921a1cc46bd45bb036d2c88fb2601f9807b86991d", "source_sha256": "d8cfbb58894cc82e4e8ba7def8f5bcc6b6c011986e853dba0f1c96ca81a4b49e", "target_language": "lua"}
-- docs-list.js — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-list.js
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local function exists(filename)
  local file = io.open(filename, "r")
  if file then
    file:close()
    return true
  else
    return false
  end
end

local function is_directory(path)
  local attr = lfs.attributes(path, "mode")
  return attr == "directory"
end

local function join_paths(...)
  local parts = {...}
  local result = ""
  for i, part in ipairs(parts) do
    if i == 1 then
      result = part
    else
      result = result .. "/" .. part
    end
  end
  return result
end

local function relative_path(base, path)
  local base_len = #base
  if string.sub(path, 1, base_len) == base then
      return string.sub(path, base_len + 2)
  end
  return path
end

-- Check for docs directory
local cwd = lfs.currentdir()
local DOCS_DIR = join_paths(cwd, "docs")

if not exists(DOCS_DIR) then
  print("docs:list: missing docs directory. Run from repo root.")
  os.exit(1)
end

if not is_directory(DOCS_DIR) then
  print("docs:list: docs path is not a directory.")
  os.exit(1)
end

local EXCLUDED_DIRS = {
  archive = true,
  research = true
}

--[[
 * @param {unknown[]} values
 * @returns {string[]}
]]
local function compactStrings(values)
  local result = {}
  for _, value in ipairs(values) do
    if value ~= nil then
      local normalized
      if type(value) == "string" then
        normalized = string.match(value, "^%s*(.-)%s*$")
      elseif type(value) == "number" or type(value) == "boolean" then
        normalized = tostring(value):match("^%s*(.-)%s*$")
      else
        normalized = nil
      end

      if normalized and #normalized > 0 then
        table.insert(result, normalized)
      end
    end
  end
  return result
end

--[[
 * @param {string} dir
 * @param {string} base
 * @returns {string[]}
]]
local function walkMarkdownFiles(dir, base)
  if not base then base = dir end
  
  local files = {}
  local entries = {}
  
  -- Collect directory entries
  for entry in lfs.dir(dir) do
    if entry ~= "." and entry ~= ".." and not string.match(entry, "^%.") then
      table.insert(entries, entry)
    end
  end
  
  -- Sort entries
  table.sort(entries)
  
  -- Process each entry
  for _, entry_name in ipairs(entries) do
    local fullPath = join_paths(dir, entry_name)
    local attr = lfs.attributes(fullPath)
    
    if attr.mode == "directory" then
      if not EXCLUDED_DIRS[entry_name] then
        local subfiles = walkMarkdownFiles(fullPath, base)
        for _, file in ipairs(subfiles) do
          table.insert(files, file)
        end
      end
    elseif attr.mode == "file" and string.match(entry_name, "%.md$") then
      table.insert(files, relative_path(base, fullPath))
    end
  end
  
  return files
end

--[[
 * @param {string} fullPath
 * @returns {{ summary: string | null; readWhen: string[]; error?: string }}
]]
local function extractMetadata(fullPath)
  local file = io.open(fullPath, "r")
  if not file then
    return { summary = nil, readWhen = {}, error = "cannot open file" }
  end
  
  local content = file:read("*all")
  file:close()

  if not string.match(content, "^---") then
    return { summary = nil, readWhen = {}, error = "missing front matter" }
  end

  local endIndex = string.find(content, "\n---", 4)
  if not endIndex then
    return { summary = nil, readWhen = {}, error = "unterminated front matter" }
  end

  local frontMatter = string.sub(content, 4, endIndex-1):match("^%s*(.-)%s*$")
  local lines = {}
  for line in string.gmatch(frontMatter, "[^\r\n]+") do
    table.insert(lines, line)
  end

  local summaryLine = nil
  local readWhen = {}
  local collectingField = nil

  for _, rawLine in ipairs(lines) do
    local line = rawLine:match("^%s*(.-)%s*$")

    if string.match(line, "^summary:") then
      summaryLine = line
      collectingField = nil
    elseif string.match(line, "^read_when:") then
      collectingField = "read_when"
      local inline = line:sub(11):match("^%s*(.-)%s*$")
      if inline:sub(1,1) == "[" and inline:sub(-1,-1) == "]" then
        -- Parse array manually since we don't have JSON library
        local items = {}
        for item in string.gmatch(inline, "'([^']*)'") do
          table.insert(items, item)
        end
        local compacted = compactStrings(items)
        for _, item in ipairs(compacted) do
          table.insert(readWhen, item)
        end
      end
    elseif collectingField == "read_when" then
      if string.match(line, "^%- ") then
        local hint = line:sub(3):match("^%s*(.-)%s*$")
        if hint and hint ~= "" then
          table.insert(readWhen, hint)
        end
      elseif line == "" then
        -- allow blank lines inside the list
      else
        collectingField = nil
      end
    end
  end

  if not summaryLine then
    return { summary = nil, readWhen = readWhen, error = "summary key missing" }
  end

  local summaryValue = summaryLine:sub(9):match("^%s*(.-)%s*$")
  -- Remove surrounding quotes
  local normalized = string.gsub(summaryValue, "^['\"](.-)['\"]$", "%1")
  -- Replace multiple spaces with single space and trim
  normalized = string.gsub(normalized, "%s+", " "):match("^%s*(.-)%s*$")

  if not normalized or normalized == "" then
    return { summary = nil, readWhen = readWhen, error = "summary is empty" }
  end

  return { summary = normalized, readWhen = readWhen }
end

print("Listing all markdown files in docs folder:")

local markdownFiles = walkMarkdownFiles(DOCS_DIR)

for _, relativePath in ipairs(markdownFiles) do
  local fullPath = join_paths(DOCS_DIR, relativePath)
  local metadata = extractMetadata(fullPath)
  local summary = metadata.summary
  local readWhen = metadata.readWhen
  local error = metadata.error
  
  if summary then
    print(relativePath .. " - " .. summary)
    if #readWhen > 0 then
      print("  Read when: " .. table.concat(readWhen, "; "))
    end
  else
    local reason = error and (" - [" .. error .. "]") or ""
    print(relativePath .. reason)
  end
end

print("\nReminder: keep docs up to date as behavior changes. When your task matches any \"Read when\" hint above (React hooks, cache directives, database work, tests, etc.), read that doc before coding, and suggest new coverage when it is missing.")
