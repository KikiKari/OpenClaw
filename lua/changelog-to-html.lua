#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "8041c2b9765dfe29fd2f8aa8f5ec837ae10d6cd4c4e8e6b8ed8ef504d76043ed", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "lua"}
-- changelog-to-html.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local VERSION = arg[1] or ""
local CHANGELOG_FILE = arg[2] or ""

if VERSION == "" then
  io.stderr:write("Usage: " .. arg[0] .. " <version> [changelog_file]\n")
  os.exit(1)
end

-- Function to get directory of current script (simplified)
local function get_script_dir()
  local script_path = debug.getinfo(1, "S").source:sub(2)
  local dir = script_path:match("(.*/)")
  return dir or "./"
end

local SCRIPT_DIR = get_script_dir()

if CHANGELOG_FILE == "" then
  local possible_paths = {
    SCRIPT_DIR .. "../CHANGELOG.md",
    "CHANGELOG.md",
    "../CHANGELOG.md"
  }
  for _, path in ipairs(possible_paths) do
    local f = io.open(path, "r")
    if f then
      f:close()
      CHANGELOG_FILE = path
      break
    end
  end
  if CHANGELOG_FILE == "" then
    io.stderr:write("Error: Could not find CHANGELOG.md\n")
    os.exit(1)
  end
end

if not io.open(CHANGELOG_FILE, "r") then
  io.stderr:write("Error: Changelog file '" .. CHANGELOG_FILE .. "' not found\n")
  os.exit(1)
end

local function extract_version_section(version, file)
  local lines = {}
  for line in io.lines(file) do
    table.insert(lines, line)
  end
  
  local found = false
  local result = {}
  
  for _, line in ipairs(lines) do
    if line:match("^## ") then
      if line:match("^##%s+" .. version:gsub("%.", "%%.") .. "(%s.*)?$") then
        found = true
      elseif found then
        break
      end
    elseif found then
      table.insert(result, line)
    end
  end
  
  return result
end

local function markdown_to_html(text)
  -- Replace headers
  text = text:gsub("^##### (.*)$", "<h5>%1</h5>")
  text = text:gsub("^#### (.*)$", "<h4>%1</h4>")
  text = text:gsub("^### (.*)$", "<h3>%1</h3>")
  text = text:gsub("^## (.*)$", "<h2>%1</h2>")
  
  -- Replace list items with bold text
  text = text:gsub("^%- %*%*(.-)%*%*(.*)$", "<li><strong>%1</strong>%2</li>")
  
  -- Replace regular list items
  text = text:gsub("^%- ([^*].*)$", "<li>%1</li>")
  
  -- Replace inline bold text
  text = text:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
  
  -- Replace inline code
  text = text:gsub("`([^`]-)`", "<code>%1</code>")
  
  -- Replace links
  text = text:gsub("%[([^%]]-)%]%(([^%)]-)%)", "<a href=\"%2\">%1</a>")
  
  return text
end

local version_content = extract_version_section(VERSION, CHANGELOG_FILE)

if #version_content == 0 then
  print("<h2>OpenClaw " .. VERSION .. "</h2>")
  print("<p>Latest OpenClaw update.</p>")
  print("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>")
  os.exit(0)
end

print("<h2>OpenClaw " .. VERSION .. "</h2>")

local in_list = false
for _, line in ipairs(version_content) do
  if line:match("^%-") then
    if not in_list then
      print("<ul>")
      in_list = true
    end
    print(markdown_to_html(line))
  else
    if in_list then
      print("</ul>")
      in_list = false
    end
    if line ~= "" then
      print(markdown_to_html(line))
    end
  end
end

if in_list then
  print("</ul>")
end

print("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>")
