#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "1424dad5845d04f483582735df6140876ffc36fae64f083fd19a8259690c3867", "source_sha256": "12dffdae6f3576ff268694787ca9415cbb1e307cb0b7cb39a0784412c35e1318", "target_language": "lua"}
-- run-extension-oxlint.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/run-extension-oxlint.mjs
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local json = require("cjson")
local process = require("process")
local path = require("path")
local child_process = require("childprocess")

local function acquireLocalHeavyCheckLockSync(options)
  -- Placeholder implementation as the actual function is not provided
  return function() end
end

local function applyLocalOxlintPolicy(args, env)
  -- Placeholder implementation as the actual function is not provided
  return { args = args, env = env }
end

local function runExtensionOxlint(params)
  local repoRoot = process.cwd()
  local oxlintPath = path.resolve("node_modules", ".bin", "oxlint")
  local releaseLock = acquireLocalHeavyCheckLockSync({
    cwd = repoRoot,
    env = process.env,
    toolName = params.toolName,
    lockName = params.lockName,
  })
  local tempDir = os.tmpname()
  local tempConfigPath = path.join(tempDir, "oxlint.json")
  local exitCode = 0

  local function cleanup()
    os.remove(tempDir)
    releaseLock()
  end

  local ok, err = pcall(function()
    prepareExtensionPackageBoundaryArtifacts(repoRoot)

    local extensionFiles = {}
    for _, root in ipairs(params.roots) do
      local files = collectTypeScriptFiles(path.resolve(repoRoot, root))
      for _, file in ipairs(files) do
        table.insert(extensionFiles, file)
      end
    end

    if #extensionFiles == 0 then
      print(params.emptyMessage)
      os.exit(1)
    end

    writeTempOxlintConfig(repoRoot, tempConfigPath)

    local baseArgs = {"-c", tempConfigPath}
    for i = 2, #arg do
      table.insert(baseArgs, arg[i])
    end
    for _, file in ipairs(extensionFiles) do
      table.insert(baseArgs, file)
    end

    local policyResult = applyLocalOxlintPolicy(baseArgs, process.env)
    local finalArgs = policyResult.args
    local env = policyResult.env

    local result = child_process.spawnSync(oxlintPath, finalArgs, {
      stdio = "inherit",
      env = env,
      shell = process.platform == "win32",
    })

    if result.error then
      error(result.error)
    end

    exitCode = result.status or 1
  end)

  cleanup()

  if not ok then
    print(err)
    os.exit(1)
  end

  process.exitCode = exitCode
end

local function prepareExtensionPackageBoundaryArtifacts(repoRoot)
  local releaseLock = acquireLocalHeavyCheckLockSync({
    cwd = repoRoot,
    env = process.env,
    toolName = "extension-package-boundary-artifacts",
    lockName = "extension-package-boundary-artifacts",
  })
  local exitCode = 0

  local function cleanup()
    releaseLock()
  end

  local ok, err = pcall(function()
    local scriptPath = path.resolve(repoRoot, "scripts", "prepare-extension-package-boundary-artifacts.mjs")
    local result = child_process.spawnSync(process.execPath, {scriptPath}, {
      cwd = repoRoot,
      stdio = "inherit",
      env = process.env,
    })

    if result.error then
      error(result.error)
    end

    exitCode = result.status or 1
  end)

  cleanup()

  if not ok then
    print(err)
    os.exit(1)
  end

  if exitCode ~= 0 then
    process.exitCode = exitCode
  end
end

local function writeTempOxlintConfig(repoRoot, configPath)
  local configFile = io.open(path.resolve(repoRoot, ".oxlintrc.json"), "r")
  local configContent = configFile:read("*all")
  configFile:close()

  local config = json.decode(configContent)
  config["$schema"] = nil

  if type(config.ignorePatterns) == "table" then
    for _, pattern in ipairs(config.ignorePatterns) do
      if isTopLevelExtensionsIgnorePattern(pattern) then
        error(string.format(
          'Refusing to run extension oxlint with .oxlintrc.json ignore pattern %s. Remove the top-level extensions ignore so root and focused lint agree.',
          json.encode(pattern)
        ))
      end
    end
  end

  local outputFile = io.open(configPath, "w")
  outputFile:write(json.encode(config, {indent = true}))
  outputFile:write("\n")
  outputFile:close()
end

local function isTopLevelExtensionsIgnorePattern(pattern)
  local normalized = string.gsub(string.gsub(string.gsub(pattern, "\\", "/"), "^%./", ""), "^/", "")
  return normalized == "extensions" or normalized == "extensions/" or normalized == "extensions/**"
end

local function collectTypeScriptFiles(directoryPath)
  local files = {}
  for file in fs.dir(directoryPath) do
    local entryPath = path.join(directoryPath, file)
    local attr = fs.attributes(entryPath)
    if attr.mode == "directory" then
      local subFiles = collectTypeScriptFiles(entryPath)
      for _, subFile in ipairs(subFiles) do
        table.insert(files, subFile)
      end
    elseif attr.mode == "file" and (string.sub(file, -3) == ".ts" or string.sub(file, -4) == ".tsx") then
      table.insert(files, string.gsub(path.relative(process.cwd(), entryPath), "\\", "/"))
    end
  end
  return files
end

return {
  runExtensionOxlint = runExtensionOxlint
}
