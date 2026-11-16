#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "ab863d619718da69472a41b7ba4676371732c9e27b1cd3855db8ae4f8ca886cb", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "lua"}
-- bundled-plugin-source-utils.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local json = require("cjson")

local function readIfExists(filePath)
  local file, err = io.open(filePath, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function collectBundledPluginSources(params)
  params = params or {}
  
  local repoRoot = params.repoRoot or lfs.currentdir()
  local extensionsRoot = repoRoot .. "/extensions"
  
  local attr = lfs.attributes(extensionsRoot)
  if not attr or attr.mode ~= "directory" then
    return {}
  end
  
  local requirePackageJson = params.requirePackageJson == true
  local entries = {}
  local dirs = {}
  
  -- Collect directory names first
  for dirent in lfs.dir(extensionsRoot) do
    if dirent ~= "." and dirent ~= ".." then
      local fullPath = extensionsRoot .. "/" .. dirent
      local attr = lfs.attributes(fullPath)
      if attr and attr.mode == "directory" then
        table.insert(dirs, dirent)
      end
    end
  end
  
  -- Sort directory names
  table.sort(dirs)
  
  -- Process each directory
  for _, dirName in ipairs(dirs) do
    local pluginDir = extensionsRoot .. "/" .. dirName
    local manifestPath = pluginDir .. "/openclaw.plugin.json"
    local packageJsonPath = pluginDir .. "/package.json"
    
    if lfs.attributes(manifestPath) then
      if requirePackageJson and not lfs.attributes(packageJsonPath) then
        goto continue
      end
      
      local manifestContent = readIfExists(manifestPath)
      local packageJsonContent = readIfExists(packageJsonPath)
      
      local entry = {
        dirName = dirName,
        pluginDir = pluginDir,
        manifestPath = manifestPath,
        manifest = manifestContent and json.decode(manifestContent) or nil
      }
      
      if packageJsonContent then
        entry.packageJsonPath = packageJsonPath
        entry.packageJson = json.decode(packageJsonContent)
      end
      
      table.insert(entries, entry)
    end
    
    ::continue::
  end
  
  return entries
end

return {
  readIfExists = readIfExists,
  collectBundledPluginSources = collectBundledPluginSources
}
