#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "82d5d30120aaf496d1cbeb1d56da3fe247a09be6f23f8cbd10976927060f69e7", "source_sha256": "44f04cb59342c4d1b0965cd87195e903f79fc80231b0f537dba10313bc29aa00", "target_language": "lua"}
-- source-file-scan-cache.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/source-file-scan-cache.mjs
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local json = require("cjson")

local scanCache = {}

local function normalizeRepoPath(repoRoot, filePath)
  local relativePath = string.gsub(filePath, "^" .. repoRoot .. "[/\\]*", "")
  return string.gsub(relativePath, "\\", "/")
end

local function table_contains(set, value)
  for _, v in ipairs(set) do
    if v == value then
      return true
    end
  end
  return false
end

local function table_sort(t, comp)
  table.sort(t, comp)
  return t
end

local function readdir(dir)
  local entries = {}
  local attr = lfs.attributes(dir)
  if not attr or attr.mode ~= "directory" then
    return entries
  end
  
  for file in lfs.dir(dir) do
    if file ~= "." and file ~= ".." then
      local fullPath = dir .. "/" .. file
      local attrs = lfs.attributes(fullPath)
      if attrs then
        table.insert(entries, {
          name = file,
          isDirectory = function() return attrs.mode == "directory" end,
          isFile = function() return attrs.mode == "file" end
        })
      end
    end
  end
  return entries
end

local function walkFiles(params, rootDir)
  local out = {}
  local entries = {}
  
  local success, result = pcall(function()
    return readdir(rootDir)
  end)
  
  if not success then
    if string.find(result, "No such file or directory") then
      return out
    else
      error(result)
    end
  end
  
  entries = result
  
  table_sort(entries, function(left, right)
    return left.name < right.name
  end)
  
  for _, entry in ipairs(entries) do
    local entryPath = rootDir .. "/" .. entry.name
    if entry.isDirectory() then
      if not table_contains(params.ignoredDirNames, entry.name) then
        local subEntries = walkFiles(params, entryPath)
        for _, subEntry in ipairs(subEntries) do
          table.insert(out, subEntry)
        end
      end
    elseif entry.isFile() then
      local ext = ""
      local dotIndex = string.find(entry.name, "%.[^%.]*$")
      if dotIndex then
        ext = string.sub(entry.name, dotIndex)
      end
      
      if table_contains(params.scanExtensions, ext) then
        table.insert(out, entryPath)
      end
    end
  end
  
  return out
end

local function readFile(filePath)
  local file, err = io.open(filePath, "r")
  if not file then
    error(err)
  end
  
  local content = file:read("*all")
  file:close()
  return content
end

local function stringifyTable(t)
  local result = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      table.insert(result, tostring(k) .. "=" .. "{}")
    else
      table.insert(result, tostring(k) .. "=" .. tostring(v))
    end
  end
  return table.concat(result, ",")
end

local function createCacheKey(params)
  local sortedScanExtensions = {}
  for _, ext in ipairs(params.scanExtensions) do
    table.insert(sortedScanExtensions, ext)
  end
  table_sort(sortedScanExtensions)
  
  local sortedIgnoredDirNames = {}
  for _, name in ipairs(params.ignoredDirNames) do
    table.insert(sortedIgnoredDirNames, name)
  end
  table_sort(sortedIgnoredDirNames)
  
  local keyTable = {
    repoRoot = params.repoRoot,
    scanRoots = table.concat(params.scanRoots, ","),
    scanExtensions = table.concat(sortedScanExtensions, ","),
    ignoredDirNames = table.concat(sortedIgnoredDirNames, ",")
  }
  
  return stringifyTable(keyTable)
end

function collectSourceFileContents(params)
  local cacheKey = createCacheKey(params)
  
  if scanCache[cacheKey] then
    return scanCache[cacheKey]()
  end
  
  local function loadFiles()
    local allFiles = {}
    
    for _, root in ipairs(params.scanRoots) do
      local fullPath = params.repoRoot .. "/" .. root
      local files = walkFiles(params, fullPath)
      for _, file in ipairs(files) do
        table.insert(allFiles, file)
      end
    end
    
    table_sort(allFiles, function(left, right)
      return normalizeRepoPath(params.repoRoot, left) < normalizeRepoPath(params.repoRoot, right)
    end)
    
    local results = {}
    for _, filePath in ipairs(allFiles) do
      local content, err = pcall(function()
        return readFile(filePath)
      end)
      
      if content then
        table.insert(results, {
          filePath = filePath,
          relativeFile = normalizeRepoPath(params.repoRoot, filePath),
          content = content
        })
      else
        error("Failed to read file " .. filePath .. ": " .. err)
      end
    end
    
    return results
  end
  
  scanCache[cacheKey] = loadFiles
  
  local success, result = pcall(loadFiles)
  if not success then
    scanCache[cacheKey] = nil
    error(result)
  end
  
  return result
end

return {
  collectSourceFileContents = collectSourceFileContents
}
