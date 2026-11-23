#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "98fc23c70d7a45a7ee3c20fc79883faf72e243962aad5e6cd9bbfde5a843bb71", "source_sha256": "481f90055fd746cf4af45da5765d09d2a9289bac2b7aa0b2fecc8558803339d5", "target_language": "lua"}
-- stage-bundled-plugin-runtime-deps.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime-deps.mjs
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local json = require("cjson")
local crypto = require("openssl.digest")
local path = require("path")

-- Helper functions
local function readJson(filePath)
  local file = io.open(filePath, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return json.decode(content)
end

local function writeJson(filePath, value)
  local file = io.open(filePath, "w")
  if file then
    file:write(json.encode(value))
    file:close()
  end
end

local function removePathIfExists(targetPath)
  os.remove(targetPath)
end

local function makeTempDir(parentDir, prefix)
  local tempPath = parentDir .. "/" .. prefix .. os.time()
  lfs.mkdir(tempPath)
  return tempPath
end

local function sanitizeTempPrefixSegment(value)
  local normalized = string.gsub(value, "[^A-Za-z0-9._-]+", "-")
  normalized = string.gsub(normalized, "-+", "-")
  if #normalized > 0 then
    return normalized
  else
    return "plugin"
  end
end

local function replaceDir(targetPath, sourcePath)
  removePathIfExists(targetPath)
  local success, err = os.rename(sourcePath, targetPath)
  if not success and err ~= "EXDEV" then
    error(err)
  end
  -- Copy recursively if rename fails due to cross-device link
  if not success then
    -- Implement recursive copy here
    os.execute("cp -r " .. sourcePath .. " " .. targetPath)
    removePathIfExists(sourcePath)
  end
end

local function dependencyNodeModulesPath(nodeModulesDir, depName)
  return path.join(nodeModulesDir, depName:gsub("/", path.sep))
end

local function readInstalledDependencyVersion(nodeModulesDir, depName)
  local packageJsonPath = path.join(
    dependencyNodeModulesPath(nodeModulesDir, depName),
    "package.json"
  )
  if not path.exists(packageJsonPath) then
    return nil
  end
  local packageJson = readJson(packageJsonPath)
  local version = packageJson.version
  if type(version) == "string" then
    return version
  else
    return nil
  end
end

local function dependencyVersionSatisfied(spec, installedVersion)
  -- Simplified semver check - implement proper semver logic as needed
  return spec == installedVersion
end

local stagedRuntimeDepPruneRules = {
  ["@larksuiteoapi/node-sdk"] = {"types"}
}
local runtimeDepsStagingVersion = 2

local function collectInstalledRuntimeClosure(rootNodeModulesDir, dependencySpecs)
  local packageCache = {}
  local closure = {}
  local queue = {}

  for depName, spec in pairs(dependencySpecs) do
    table.insert(queue, {depName, spec})
  end

  while #queue > 0 do
    local item = table.remove(queue, 1)
    local depName, spec = item[1], item[2]
    local installedVersion = readInstalledDependencyVersion(rootNodeModulesDir, depName)
    if installedVersion == nil or not dependencyVersionSatisfied(spec, installedVersion) then
      return nil
    end
    if closure[depName] then
      goto continue
    end

    local packageJsonPath = path.join(
      dependencyNodeModulesPath(rootNodeModulesDir, depName),
      "package.json"
    )
    local packageJson = packageCache[depName] or readJson(packageJsonPath)
    packageCache[depName] = packageJson
    closure[depName] = true

    for childName, childSpec in pairs(packageJson.dependencies or {}) do
      table.insert(queue, {childName, childSpec})
    end
    for childName, childSpec in pairs(packageJson.optionalDependencies or {}) do
      table.insert(queue, {childName, childSpec})
    end
    ::continue::
  end

  local result = {}
  for k in pairs(closure) do
    table.insert(result, k)
  end
  return result
end

local function pruneStagedInstalledDependencyCargo(nodeModulesDir, depName)
  local prunePaths = stagedRuntimeDepPruneRules[depName]
  if not prunePaths then
    return
  end
  local depRoot = dependencyNodeModulesPath(nodeModulesDir, depName)
  for _, relativePath in ipairs(prunePaths) do
    removePathIfExists(path.join(depRoot, relativePath))
  end
end

local function pruneStagedRuntimeDependencyCargo(nodeModulesDir)
  for depName in pairs(stagedRuntimeDepPruneRules) do
    pruneStagedInstalledDependencyCargo(nodeModulesDir, depName)
  end
end

local function listBundledPluginRuntimeDirs(repoRoot)
  local extensionsRoot = path.join(repoRoot, "dist", "extensions")
  if not path.exists(extensionsRoot) then
    return {}
  end

  local result = {}
  for dirent in lfs.dir(extensionsRoot) do
    if dirent ~= "." and dirent ~= ".." then
      local pluginDir = path.join(extensionsRoot, dirent)
      if lfs.attributes(pluginDir, "mode") == "directory" and path.exists(path.join(pluginDir, "package.json")) then
        table.insert(result, pluginDir)
      end
    end
  end
  return result
end

local function hasRuntimeDeps(packageJson)
  return (packageJson.dependencies and next(packageJson.dependencies) ~= nil) or
         (packageJson.optionalDependencies and next(packageJson.optionalDependencies) ~= nil)
end

local function shouldStageRuntimeDeps(packageJson)
  return packageJson.openclaw and packageJson.openclaw.bundle and packageJson.openclaw.bundle.stageRuntimeDependencies == true
end

local function sanitizeBundledManifestForRuntimeInstall(pluginDir)
  local manifestPath = path.join(pluginDir, "package.json")
  local packageJson = readJson(manifestPath)
  local changed = false

  if packageJson.peerDependencies then
    packageJson.peerDependencies = nil
    changed = true
  end

  if packageJson.peerDependenciesMeta then
    packageJson.peerDependenciesMeta = nil
    changed = true
  end

  if packageJson.devDependencies then
    packageJson.devDependencies = nil
    changed = true
  end

  if changed then
    writeJson(manifestPath, packageJson)
  end

  return packageJson
end

local function resolveRuntimeDepsStampPath(pluginDir)
  return path.join(pluginDir, ".openclaw-runtime-deps-stamp.json")
end

local function createRuntimeDepsFingerprint(packageJson)
  local data = {
    packageJson = packageJson,
    pruneRules = {},
    version = runtimeDepsStagingVersion
  }
  for k, v in pairs(stagedRuntimeDepPruneRules) do
    table.insert(data.pruneRules, {k, v})
  end
  local jsonString = json.encode(data)
  local sha256 = crypto.new("sha256")
  sha256:update(jsonString)
  return sha256:final()
end

local function readRuntimeDepsStamp(stampPath)
  if not path.exists(stampPath) then
    return nil
  end
  local success, result = pcall(readJson, stampPath)
  if success then
    return result
  else
    return nil
  end
end

local function stageInstalledRootRuntimeDeps(params)
  local fingerprint = params.fingerprint
  local packageJson = params.packageJson
  local pluginDir = params.pluginDir
  local repoRoot = params.repoRoot

  local dependencySpecs = {}
  for k, v in pairs(packageJson.dependencies or {}) do
    dependencySpecs[k] = v
  end
  for k, v in pairs(packageJson.optionalDependencies or {}) do
    dependencySpecs[k] = v
  end

  local rootNodeModulesDir = path.join(repoRoot, "node_modules")
  if next(dependencySpecs) == nil or not path.exists(rootNodeModulesDir) then
    return false
  end

  local dependencyNames = collectInstalledRuntimeClosure(rootNodeModulesDir, dependencySpecs)
  if dependencyNames == nil then
    return false
  end

  local nodeModulesDir = path.join(pluginDir, "node_modules")
  local stampPath = resolveRuntimeDepsStampPath(pluginDir)
  local tempDir = makeTempDir(
    "/tmp",
    "openclaw-runtime-deps-" .. sanitizeTempPrefixSegment(path.basename(pluginDir)) .. "-"
  )
  local stagedNodeModulesDir = path.join(tempDir, "node_modules")

  local function cleanup()
    removePathIfExists(tempDir)
  end

  local success, err = pcall(function()
    for _, depName in ipairs(dependencyNames) do
      local sourcePath = dependencyNodeModulesPath(rootNodeModulesDir, depName)
      local targetPath = dependencyNodeModulesPath(stagedNodeModulesDir, depName)
      -- Create parent directories
      local parentDir = path.dirname(targetPath)
      local dirs = {}
      local current = parentDir
      while current ~= "" and current ~= "/" do
        table.insert(dirs, 1, current)
        current = path.dirname(current)
      end
      for _, dir in ipairs(dirs) do
        lfs.mkdir(dir)
      end
      -- Copy directory recursively
      os.execute("cp -r " .. sourcePath .. " " .. targetPath)
    end
    pruneStagedRuntimeDependencyCargo(stagedNodeModulesDir)

    replaceDir(nodeModulesDir, stagedNodeModulesDir)
    writeJson(stampPath, {
      fingerprint = fingerprint,
      generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    return true
  end)

  cleanup()
  if success then
    return true
  else
    error(err)
  end
end

local function installPluginRuntimeDeps(params)
  local fingerprint = params.fingerprint
  local packageJson = params.packageJson
  local pluginDir = params.pluginDir
  local pluginId = params.pluginId
  local repoRoot = params.repoRoot

  if repoRoot and stageInstalledRootRuntimeDeps({
    fingerprint = fingerprint,
    packageJson = packageJson,
    pluginDir = pluginDir,
    repoRoot = repoRoot
  }) then
    return
  end

  local nodeModulesDir = path.join(pluginDir, "node_modules")
  local stampPath = resolveRuntimeDepsStampPath(pluginDir)
  local tempInstallDir = makeTempDir(
    "/tmp",
    "openclaw-runtime-deps-" .. sanitizeTempPrefixSegment(pluginId) .. "-"
  )

  local function cleanup()
    removePathIfExists(tempInstallDir)
  end

  local success, err = pcall(function()
    writeJson(path.join(tempInstallDir, "package.json"), packageJson)
    local cmd = "npm install --omit=dev --silent --ignore-scripts --legacy-peer-deps --package-lock=false"
    local result = os.execute(cmd .. " 2>&1")
    if result ~= 0 then
      error("failed to stage bundled runtime deps for " .. pluginId .. ": npm install failed")
    end

    local stagedNodeModulesDir = path.join(tempInstallDir, "node_modules")
    if not path.exists(stagedNodeModulesDir) then
      error("failed to stage bundled runtime deps for " .. pluginId .. ": npm install produced no node_modules directory")
    end

    pruneStagedRuntimeDependencyCargo(stagedNodeModulesDir)

    replaceDir(nodeModulesDir, stagedNodeModulesDir)
    writeJson(stampPath, {
      fingerprint = fingerprint,
      generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
  end)

  cleanup()
  if not success then
    error(err)
  end
end

local function installPluginRuntimeDepsWithRetries(params)
  local attempts = params.attempts or 3
  local lastError
  for attempt = 1, attempts do
    local success, err = pcall(function()
      params.install(params.installParams)
    end)
    if success then
      return
    else
      lastError = err
      if attempt == attempts then
        break
      end
    end
  end
  error(lastError)
end

function stageBundledPluginRuntimeDeps(params)
  params = params or {}
  local repoRoot = params.cwd or params.repoRoot or "."
  local installPluginRuntimeDepsImpl = params.installPluginRuntimeDepsImpl or installPluginRuntimeDeps
  local installAttempts = params.installAttempts or 3

  for _, pluginDir in ipairs(listBundledPluginRuntimeDirs(repoRoot)) do
    local pluginId = path.basename(pluginDir)
    local packageJson = sanitizeBundledManifestForRuntimeInstall(pluginDir)
    local nodeModulesDir = path.join(pluginDir, "node_modules")
    local stampPath = resolveRuntimeDepsStampPath(pluginDir)

    if not hasRuntimeDeps(packageJson) or not shouldStageRuntimeDeps(packageJson) then
      removePathIfExists(nodeModulesDir)
      removePathIfExists(stampPath)
    else
      local fingerprint = createRuntimeDepsFingerprint(packageJson)
      local stamp = readRuntimeDepsStamp(stampPath)
      if path.exists(nodeModulesDir) and stamp and stamp.fingerprint == fingerprint then
        -- Skip - already installed
      else
        installPluginRuntimeDepsWithRetries({
          attempts = installAttempts,
          install = installPluginRuntimeDepsImpl,
          installParams = {
            fingerprint = fingerprint,
            packageJson = packageJson,
            pluginDir = pluginDir,
            pluginId = pluginId,
            repoRoot = repoRoot
          }
        })
      end
    end
  end
end

-- Main execution
if arg[0] == nil or arg[0] == "stage-bundled-plugin-runtime-deps.lua" then
  stageBundledPluginRuntimeDeps()
end
