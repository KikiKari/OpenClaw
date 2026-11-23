#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "53ec4a3901edc2d67563e6362fa0a1eddfbbd575052904370a36bae3c8e13449", "source_sha256": "dc65d4759ce1efe8d0c6f037b64d65c1aa1f73b83a3cd928ceebdaf24ed53da6", "target_language": "lua"}
-- stage-bundled-plugin-runtime.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime.mjs
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path = require("path")

-- Utility functions
local function removePathIfExists(targetPath)
  local attr = fs.attributes(targetPath)
  if attr then
    if attr.mode == "directory" then
      os.execute("rm -rf " .. targetPath)
    else
      os.remove(targetPath)
    end
  end
end

local function symlinkType()
  if package.config:sub(1,1) == "\\" then -- Windows check
    return "junction"
  else
    return "dir"
  end
end

local function relativeSymlinkTarget(sourcePath, targetPath)
  local sourceParts = path.split(sourcePath)
  local targetParts = path.split(targetPath)
  local commonLen = 0
  for i = 1, math.min(#sourceParts, #targetParts) do
    if sourceParts[i] == targetParts[i] then
      commonLen = i
    else
      break
    end
  end

  local upCount = #targetParts - commonLen - 1
  local relPath = {}
  for i = 1, upCount do
    table.insert(relPath, "..")
  end
  for i = commonLen + 1, #sourceParts do
    table.insert(relPath, sourceParts[i])
  end

  return table.concat(relPath, "/") ~= "" and table.concat(relPath, "/") or "."
end

local function shouldFallbackToCopy(error)
  return package.config:sub(1,1) == "\\" and 
         (error:find("EPERM") or error:find("EINVAL") or error:find("UNKNOWN"))
end

local function copyPathFallback(sourcePath, targetPath)
  removePathIfExists(targetPath)
  local attr = fs.attributes(sourcePath)
  local dir = path.dirname(targetPath)
  os.execute("mkdir -p " .. dir)

  if attr.mode == "directory" then
    os.execute("cp -r " .. sourcePath .. " " .. targetPath)
  else
    os.execute("cp " .. sourcePath .. " " .. targetPath)
  end
end

local function ensureSymlink(targetValue, targetPath, type, fallbackSourcePath)
  local success, error = os.execute("ln -sf " .. targetValue .. " " .. targetPath)
  if not success then
    if fallbackSourcePath and shouldFallbackToCopy(error) then
      copyPathFallback(fallbackSourcePath, targetPath)
      return
    end
    if not error:find("EEXIST") then
      error(error)
    end
  end

  -- Check if existing symlink matches
  local handle = io.popen("readlink " .. targetPath)
  local currentTarget = handle:read("*a"):gsub("%s+$", "")
  handle:close()
  
  if currentTarget == targetValue then
    return
  end

  removePathIfExists(targetPath)
  local success, error = os.execute("ln -sf " .. targetValue .. " " .. targetPath)
  if not success then
    if fallbackSourcePath and shouldFallbackToCopy(error) then
      copyPathFallback(fallbackSourcePath, targetPath)
      return
    end
    error(error)
  end
end

local function symlinkPath(sourcePath, targetPath, type)
  ensureSymlink(relativeSymlinkTarget(sourcePath, targetPath), targetPath, type, sourcePath)
end

local function shouldWrapRuntimeJsFile(sourcePath)
  return sourcePath:match("%.js$")
end

local function shouldCopyRuntimeFile(sourcePath)
  local relativePath = sourcePath:gsub("\\", "/")
  return relativePath:match("/package%.json$") or
         relativePath:match("/openclaw%.plugin%.json$") or
         relativePath:match("/%.codex%-plugin/plugin%.json$") or
         relativePath:match("/%.claude%-plugin/plugin%.json$") or
         relativePath:match("/%.cursor%-plugin/plugin%.json$") or
         relativePath:match("/SKILL%.md$")
end

local function writeRuntimeModuleWrapper(sourcePath, targetPath)
  local specifier = relativeSymlinkTarget(sourcePath, targetPath):gsub("\\", "/")
  if not specifier:match("^%.") then
    specifier = "./" .. specifier
  end
  
  local content = string.format([[
export * from %s;
import * as module from %s;
export default module.default;
]], 
    string.format("%q", specifier),
    string.format("%q", specifier)
  )
  
  local file = io.open(targetPath, "w")
  file:write(content)
  file:close()
end

local function stagePluginRuntimeOverlay(sourceDir, targetDir)
  os.execute("mkdir -p " .. targetDir)
  
  for file in fs.dir(sourceDir) do
    if file ~= "." and file ~= ".." and file ~= "node_modules" then
      local sourcePath = path.join(sourceDir, file)
      local targetPath = path.join(targetDir, file)
      local attr = fs.attributes(sourcePath)
      
      if attr.mode == "directory" then
        stagePluginRuntimeOverlay(sourcePath, targetPath)
      elseif attr.mode == "link" then
        local handle = io.popen("readlink " .. sourcePath)
        local linkTarget = handle:read("*a"):gsub("%s+$", "")
        handle:close()
        ensureSymlink(linkTarget, targetPath, nil, sourcePath)
      elseif attr.mode == "file" then
        if shouldWrapRuntimeJsFile(sourcePath) then
          writeRuntimeModuleWrapper(sourcePath, targetPath)
        elseif shouldCopyRuntimeFile(sourcePath) then
          os.execute("cp " .. sourcePath .. " " .. targetPath)
        else
          symlinkPath(sourcePath, targetPath)
        end
      end
    end
  end
end

local function linkPluginNodeModules(params)
  local runtimeNodeModulesDir = path.join(params.runtimePluginDir, "node_modules")
  removePathIfExists(runtimeNodeModulesDir)
  
  if not fs.attributes(params.sourcePluginNodeModulesDir) then
    return
  end
  
  ensureSymlink(
    params.sourcePluginNodeModulesDir,
    runtimeNodeModulesDir,
    symlinkType(),
    params.sourcePluginNodeModulesDir
  )
end

function stageBundledPluginRuntime(params)
  params = params or {}
  local repoRoot = params.cwd or params.repoRoot or os.getenv("PWD")
  local distRoot = path.join(repoRoot, "dist")
  local runtimeRoot = path.join(repoRoot, "dist-runtime")
  local distExtensionsRoot = path.join(distRoot, "extensions")
  local runtimeExtensionsRoot = path.join(runtimeRoot, "extensions")

  if not fs.attributes(distExtensionsRoot) then
    removePathIfExists(runtimeRoot)
    return
  end

  removePathIfExists(runtimeRoot)
  os.execute("mkdir -p " .. runtimeExtensionsRoot)

  for dirent in fs.dir(distExtensionsRoot) do
    if dirent ~= "." and dirent ~= ".." then
      local attr = fs.attributes(path.join(distExtensionsRoot, dirent))
      if attr and attr.mode == "directory" then
        local distPluginDir = path.join(distExtensionsRoot, dirent)
        local runtimePluginDir = path.join(runtimeExtensionsRoot, dirent)
        local distPluginNodeModulesDir = path.join(distPluginDir, "node_modules")

        stagePluginRuntimeOverlay(distPluginDir, runtimePluginDir)
        linkPluginNodeModules({
          runtimePluginDir = runtimePluginDir,
          sourcePluginNodeModulesDir = distPluginNodeModulesDir
        })
      end
    end
  end
end

-- Main execution
if arg and arg[0] and arg[0]:match("stage%-bundled%-plugin%-runtime%.m?js$") then
  stageBundledPluginRuntime()
end
