#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "7d8049ee0ec78f378b3e510423637fdb1ce0a42eb88c607983c4a6ecc605ae98", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "lua"}
-- changed-extensions.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local uv = require("uv")
local fs = require("fs")
local path = require("path")
local child_process = require("child_process")

-- Constants (replace with actual values or configuration)
local BUNDLED_PLUGIN_PATH_PREFIX = "extensions/"
local BUNDLED_PLUGIN_ROOT_DIR = "extensions"

local repoRoot = path.resolve(path.dirname(debug.getinfo(1).source:match("@(.*)$")), "..", "..")

local function runGit(args, options)
  options = options or {}
  local cwd = options.cwd or repoRoot
  local stdio = options.stdio or {"ignore", "pipe", "pipe"}
  local encoding = options.encoding or "utf8"

  local result = child_process.execFileSync("git", args, {
    cwd = cwd,
    stdio = stdio,
    encoding = encoding
  })

  return result
end

local function normalizeRelative(inputPath)
  return string.gsub(inputPath, path.sep, "/")
end

local function hasGitCommit(ref)
  if not ref or string.match(ref, "^0+$") then
    return false
  end

  local success, err = pcall(function()
    runGit({"rev-parse", "--verify", ref .. "^{commit}"})
  end)

  return success
end

local function resolveChangedPathsBase(params)
  params = params or {}
  local base = params.base
  local head = params.head or "HEAD"
  local fallbackBaseRef = params.fallbackBaseRef

  if hasGitCommit(base) then
    return base
  end

  if fallbackBaseRef then
    local remoteBaseRef = fallbackBaseRef
    if not string.match(fallbackBaseRef, "^origin/") then
      remoteBaseRef = "origin/" .. fallbackBaseRef
    end

    if hasGitCommit(remoteBaseRef) then
      local mergeBase = runGit({"merge-base", remoteBaseRef, head})
      mergeBase = string.gsub(mergeBase, "%s*$", "")

      if hasGitCommit(mergeBase) then
        return mergeBase
      end
    end
  end

  if not base then
    error("A git base revision is required to list changed extensions.")
  end

  error("Git base revision is unavailable locally: " .. base)
end

local function listChangedPaths(base, head)
  head = head or "HEAD"

  if not base then
    error("A git base revision is required to list changed extensions.")
  end

  local output = runGit({"diff", "--name-only", base, head})
  local paths = {}

  for line in string.gmatch(output, "[^\r\n]+") do
    line = string.gsub(line, "^%s*(.-)%s*$", "%1")
    if #line > 0 then
      table.insert(paths, line)
    end
  end

  return paths
end

local function hasExtensionPackage(extensionId)
  local packagePath = path.join(repoRoot, BUNDLED_PLUGIN_ROOT_DIR, extensionId, "package.json")
  return fs.existsSync(packagePath)
end

local function listAvailableExtensionIds()
  local extensionsDir = path.join(repoRoot, BUNDLED_PLUGIN_ROOT_DIR)
  if not fs.existsSync(extensionsDir) then
    return {}
  end

  local entries = fs.readdirSync(extensionsDir, {withFileTypes = true})
  local extensionIds = {}

  for _, entry in ipairs(entries) do
    if entry.isDirectory and entry:isDirectory() then
      local extensionId = entry.name
      if hasExtensionPackage(extensionId) then
        table.insert(extensionIds, extensionId)
      end
    end
  end

  table.sort(extensionIds, function(a, b)
    return a < b
  end)

  return extensionIds
end

local function detectChangedExtensionIds(changedPaths)
  local extensionIds = {}

  for _, rawPath in ipairs(changedPaths) do
    local relativePath = normalizeRelative(tostring(rawPath):gsub("^%s*(.-)%s*$", "%1"))
    if relativePath ~= "" then
      local pattern = "^" .. string.gsub(BUNDLED_PLUGIN_PATH_PREFIX, "/", "\\/") .. "([^/]+)(?:/|$)"
      local extensionMatch = string.match(relativePath, pattern)
      
      if extensionMatch then
        local extensionId = extensionMatch
        if hasExtensionPackage(extensionId) then
          extensionIds[extensionId] = true
        end
      else
        local pairedCoreMatch = string.match(relativePath, "^src/([^/]+)(?:/|$)")
        if pairedCoreMatch and hasExtensionPackage(pairedCoreMatch) then
          extensionIds[pairedCoreMatch] = true
        end
      end
    end
  end

  local sortedIds = {}
  for id, _ in pairs(extensionIds) do
    table.insert(sortedIds, id)
  end

  table.sort(sortedIds, function(a, b)
    return a < b
  end)

  return sortedIds
end

local function listChangedExtensionIds(params)
  params = params or {}
  local head = params.head or "HEAD"
  local unavailableBaseBehavior = params.unavailableBaseBehavior or "error"

  local success, result = pcall(function()
    local base = resolveChangedPathsBase(params)
    return detectChangedExtensionIds(listChangedPaths(base, head))
  end)

  if success then
    return result
  else
    if unavailableBaseBehavior == "all" then
      return listAvailableExtensionIds()
    elseif unavailableBaseBehavior == "empty" then
      return {}
    else
      error(result)
    end
  end
end

return {
  listAvailableExtensionIds = listAvailableExtensionIds,
  detectChangedExtensionIds = detectChangedExtensionIds,
  listChangedExtensionIds = listChangedExtensionIds
}
