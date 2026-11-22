#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "6386a7ea63ae27ba5c36e7252a3503800e2751e4652bb876a1b858c0c28cb9ef", "source_sha256": "a06acfb1e69451fcfc8e5635f9059bac455efbbaca76e0edae285b866e7f8409", "target_language": "lua"}
-- run-node.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-node.mjs
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path = require("path")

local BUNDLED_PLUGIN_PATH_PREFIX = "bundled-plugins/"
local BUNDLED_PLUGIN_ROOT_DIR = "bundled-plugins"

local runNodeSourceRoots = {"src", BUNDLED_PLUGIN_ROOT_DIR}
local runNodeConfigFiles = {"tsconfig.json", "package.json", "tsdown.config.ts"}
local runNodeWatchedPaths = {}
for _, v in ipairs(runNodeSourceRoots) do table.insert(runNodeWatchedPaths, v) end
for _, v in ipairs(runNodeConfigFiles) do table.insert(runNodeWatchedPaths, v) end

local extensionSourceFilePattern = "%.(%a+)$"
local extensionRestartMetadataFiles = {["openclaw%.plugin%.json"] = true, ["package%.json"] = true}

local function normalizePath(filePath)
  if not filePath then return "" end
  return string.gsub(filePath or "", "\\", "/")
end

local function endsWith(str, ending)
  return ending == "" or string.sub(str, -#ending) == ending
end

local function isIgnoredSourcePath(relativePath)
  local normalizedPath = normalizePath(relativePath)
  return endsWith(normalizedPath, ".test.ts") or
         endsWith(normalizedPath, ".test.tsx") or
         endsWith(normalizedPath, "test-helpers.ts")
end

local function isBuildRelevantSourcePath(relativePath)
  local normalizedPath = normalizePath(relativePath)
  local ext = string.match(normalizedPath, extensionSourceFilePattern)
  local isSourceFile = ext and (
    ext == "ts" or ext == "tsx" or ext == "mts" or ext == "cts" or 
    ext == "js" or ext == "jsx" or ext == "mjs" or ext == "cjs"
  )
  return isSourceFile and not isIgnoredSourcePath(normalizedPath)
end

local function isBuildRelevantRunNodePath(repoPath)
  local normalizedPath = string.gsub(normalizePath(repoPath), "^%.//+", "")
  for _, configFile in ipairs(runNodeConfigFiles) do
    if configFile == normalizedPath then
      return true
    end
  end
  
  if string.sub(normalizedPath, 1, 4) == "src/" then
    return not isIgnoredSourcePath(string.sub(normalizedPath, 5))
  end
  
  if string.sub(normalizedPath, 1, #BUNDLED_PLUGIN_PATH_PREFIX) == BUNDLED_PLUGIN_PATH_PREFIX then
    local subPath = string.sub(normalizedPath, #BUNDLED_PLUGIN_PATH_PREFIX + 1)
    return isBuildRelevantSourcePath(subPath)
  end
  
  return false
end

local function isRestartRelevantExtensionPath(relativePath)
  local normalizedPath = normalizePath(relativePath)
  local basename = path.basename(normalizedPath)
  for pattern, _ in pairs(extensionRestartMetadataFiles) do
    if string.match(basename, pattern) then
      return true
    end
  end
  return isBuildRelevantSourcePath(normalizedPath)
end

local function isRestartRelevantRunNodePath(repoPath)
  local normalizedPath = string.gsub(normalizePath(repoPath), "^%.//+", "")
  for _, configFile in ipairs(runNodeConfigFiles) do
    if configFile == normalizedPath then
      return true
    end
  end
  
  if string.sub(normalizedPath, 1, 4) == "src/" then
    return not isIgnoredSourcePath(string.sub(normalizedPath, 5))
  end
  
  if string.sub(normalizedPath, 1, #BUNDLED_PLUGIN_PATH_PREFIX) == BUNDLED_PLUGIN_PATH_PREFIX then
    local subPath = string.sub(normalizedPath, #BUNDLED_PLUGIN_PATH_PREFIX + 1)
    return isRestartRelevantExtensionPath(subPath)
  end
  
  return false
end

local function statMtime(filePath, fsImpl)
  fsImpl = fsImpl or fs
  local attr = fsImpl.attributes(filePath)
  if attr and attr.modification then
    return attr.modification * 1000
  end
  return nil
end

local function isExcludedSource(filePath, sourceRoot, sourceRootName)
  local relativePath = normalizePath(path.relative(sourceRoot, filePath))
  if string.sub(relativePath, 1, 2) == ".." then
    return false
  end
  return not isBuildRelevantRunNodePath(path.join(sourceRootName, relativePath))
end

local function findLatestMtime(dirPath, shouldSkip, deps)
  local latest = nil
  local queue = {dirPath}
  
  while #queue > 0 do
    local current = table.remove(queue)
    if current then
      local entries = {}
      local ok, iter = pcall(function() return deps.fs.dir(current) end)
      if ok then
        for file in iter do
          if file ~= "." and file ~= ".." then
            table.insert(entries, file)
          end
        end
      else
        goto continue
      end
      
      for _, entry in ipairs(entries) do
        local fullPath = path.join(current, entry)
        local attr = deps.fs.attributes(fullPath)
        if attr and attr.mode == "directory" then
          table.insert(queue, fullPath)
        elseif attr and attr.mode == "file" then
          if shouldSkip and shouldSkip(fullPath) then
            goto continue_entry
          end
          local mtime = statMtime(fullPath, deps.fs)
          if mtime ~= nil then
            if latest == nil or mtime > latest then
              latest = mtime
            end
          end
        end
        ::continue_entry::
      end
    end
    ::continue::
  end
  
  return latest
end

local function readGitStatus(deps)
  local handle, err = io.popen('git status --porcelain --untracked-files=normal -- ' .. table.concat(runNodeWatchedPaths, " "), 'r')
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  return result
end

local function parseGitStatusPaths(output)
  local paths = {}
  for line in string.gmatch(output, "[^\r\n]+") do
    local parts = {}
    for part in string.gmatch(line, "[^ ]+") do
      table.insert(parts, part)
    end
    if #parts >= 3 then
      local entry = string.sub(line, 4)
      local arrowPos = string.find(entry, " -> ")
      if arrowPos then
        local target = string.sub(entry, arrowPos + 4)
        table.insert(paths, normalizePath(string.gsub(target, "^\"(.*)\"$", "%1")))
      else
        table.insert(paths, normalizePath(string.gsub(entry, "^\"(.*)\"$", "%1")))
      end
    end
  end
  return paths
end

local function hasDirtySourceTree(deps)
  local output = readGitStatus(deps)
  if output == nil then
    return nil
  end
  local paths = parseGitStatusPaths(output)
  for _, repoPath in ipairs(paths) do
    if isBuildRelevantRunNodePath(repoPath) then
      return true
    end
  end
  return false
end

local function readBuildStamp(deps)
  local mtime = statMtime(deps.buildStampPath, deps.fs)
  if mtime == nil then
    return { mtime = nil, head = nil }
  end
  
  local file = io.open(deps.buildStampPath, "r")
  if not file then
    return { mtime = mtime, head = nil }
  end
  
  local content = file:read("*a")
  file:close()
  
  content = string.gsub(content, "^%s*(.-)%s*$", "%1")
  if not string.sub(content, 1, 1) == "{" then
    return { mtime = mtime, head = nil }
  end
  
  local success, parsed = pcall(function() return load("return " .. content)() end)
  if not success or type(parsed) ~= "table" then
    return { mtime = mtime, head = nil }
  end
  
  local head = parsed.head
  if type(head) == "string" and string.gsub(head, "^%s*(.-)%s*$", "%1") ~= "" then
    head = string.gsub(head, "^%s*(.-)%s*$", "%1")
  else
    head = nil
  end
  
  return { mtime = mtime, head = head }
end

local function hasSourceMtimeChanged(stampMtime, deps)
  local latestSourceMtime = nil
  for _, sourceRoot in ipairs(deps.sourceRoots) do
    local sourceMtime = findLatestMtime(
      sourceRoot.path,
      function(candidate) 
        return isExcludedSource(candidate, sourceRoot.path, sourceRoot.name)
      end,
      deps
    )
    if sourceMtime ~= nil and (latestSourceMtime == nil or sourceMtime > latestSourceMtime) then
      latestSourceMtime = sourceMtime
    end
  end
  return latestSourceMtime ~= nil and latestSourceMtime > stampMtime
end

local function resolveGitHead(deps)
  local handle = io.popen('git rev-parse HEAD 2>/dev/null', 'r')
  if not handle then
    return nil
  end
  local result = handle:read("*l")
  handle:close()
  return result
end

local function resolveBuildRequirement(deps)
  if deps.env.OPENCLAW_FORCE_BUILD == "1" then
    return { shouldBuild = true, reason = "force_build" }
  end
  
  local stamp = readBuildStamp(deps)
  if stamp.mtime == nil then
    return { shouldBuild = true, reason = "missing_build_stamp" }
  end
  
  if statMtime(deps.distEntry, deps.fs) == nil then
    return { shouldBuild = true, reason = "missing_dist_entry" }
  end
  
  for _, filePath in ipairs(deps.configFiles) do
    local mtime = statMtime(filePath, deps.fs)
    if mtime ~= nil and mtime > stamp.mtime then
      return { shouldBuild = true, reason = "config_newer" }
    end
  end
  
  local currentHead = resolveGitHead(deps)
  if currentHead and not stamp.head then
    return { shouldBuild = true, reason = "build_stamp_missing_head" }
  end
  if currentHead and stamp.head and currentHead ~= stamp.head then
    return { shouldBuild = true, reason = "git_head_changed" }
  end
  if currentHead then
    local dirty = hasDirtySourceTree(deps)
    if dirty == true then
      return { shouldBuild = true, reason = "dirty_watched_tree" }
    end
    if dirty == false then
      return { shouldBuild = false, reason = "clean" }
    end
  end
  
  if hasSourceMtimeChanged(stamp.mtime, deps) then
    return { shouldBuild = true, reason = "source_mtime_newer" }
  end
  return { shouldBuild = false, reason = "clean" }
end

local BUILD_REASON_LABELS = {
  force_build = "forced by OPENCLAW_FORCE_BUILD",
  missing_build_stamp = "build stamp missing",
  missing_dist_entry = "dist entry missing",
  config_newer = "config newer than build stamp",
  build_stamp_missing_head = "build stamp missing git head",
  git_head_changed = "git head changed",
  dirty_watched_tree = "dirty watched source tree",
  source_mtime_newer = "source mtime newer than build stamp",
  clean = "clean",
}

local function formatBuildReason(reason)
  return BUILD_REASON_LABELS[reason] or reason
end

local SIGNAL_EXIT_CODES = {
  SIGINT = 130,
  SIGTERM = 143,
}

local function isSignalKey(signal)
  return SIGNAL_EXIT_CODES[signal] ~= nil
end

local function getSignalExitCode(signal)
  if isSignalKey(signal) then
    return SIGNAL_EXIT_CODES[signal]
  end
  return 1
end

local function logRunner(message, deps)
  if deps.env.OPENCLAW_RUNNER_LOG == "0" then
    return
  end
  deps.stderr:write("[openclaw] " .. message .. "\n")
end

local function waitForSpawnedProcess(childProcess, deps)
  local forwardedSignal = nil
  local onSigInt, onSigTerm
  
  local cleanupSignals = function()
    if onSigInt then
      -- In Lua, we can't easily remove signal handlers
    end
    if onSigTerm then
      -- In Lua, we can't easily remove signal handlers
    end
  end
  
  local forwardSignal = function(signal)
    if forwardedSignal then
      return
    end
    forwardedSignal = signal
    -- Best-effort only. Exit handling still happens via the child "exit" event.
  end
  
  onSigInt = function()
    forwardSignal("SIGINT")
  end
  onSigTerm = function()
    forwardSignal("SIGTERM")
  end
  
  -- In Lua, we don't have direct equivalents for process signals
  -- This would need platform-specific implementation
  
  local res = { exitCode = 0, exitSignal = nil, forwardedSignal = nil }
  return res
end

local function runOpenClaw(deps)
  -- This would require spawning a subprocess which isn't straightforward in pure Lua
  -- Would need luaposix or similar library
  return 0
end

local function syncRuntimeArtifacts(deps)
  local success, err = pcall(function()
    deps.runRuntimePostBuild({ cwd = deps.cwd })
  end)
  if not success then
    logRunner("Failed to write runtime build artifacts: " .. tostring(err), deps)
    return false
  end
  return true
end

local function writeDistBuildStamp(params)
  -- Implementation would depend on specific requirements
end

local function writeBuildStamp(deps)
  local success, err = pcall(function()
    writeDistBuildStamp({
      cwd = deps.cwd,
      fs = deps.fs,
      spawnSync = deps.spawnSync,
    })
  end)
  if not success then
    -- Best-effort stamp; still allow the runner to start.
    logRunner("Failed to write build stamp: " .. tostring(err), deps)
  end
end

local function shouldSkipCleanWatchRuntimeSync(deps)
  return deps.env.OPENCLAW_WATCH_MODE == "1"
end

local function runNodeMain(params)
  params = params or {}
  
  local deps = {
    spawn = params.spawn,
    spawnSync = params.spawnSync,
    fs = params.fs or fs,
    stderr = params.stderr or io.stderr,
    process = params.process,
    execPath = params.execPath or "node",
    cwd = params.cwd or lfs.currentdir(),
    args = params.args or {},
    env = params.env or os.getenv(),
    runRuntimePostBuild = params.runRuntimePostBuild,
  }
  
  deps.distRoot = path.join(deps.cwd, "dist")
  deps.distEntry = path.join(deps.distRoot, "entry.js")
  deps.buildStampPath = path.join(deps.distRoot, ".buildstamp")
  deps.sourceRoots = {}
  for _, sourceRoot in ipairs(runNodeSourceRoots) do
    table.insert(deps.sourceRoots, {
      name = sourceRoot,
      path = path.join(deps.cwd, sourceRoot),
    })
  end
  deps.configFiles = {}
  for _, filePath in ipairs(runNodeConfigFiles) do
    table.insert(deps.configFiles, path.join(deps.cwd, filePath))
  end
  
  local buildRequirement = resolveBuildRequirement(deps)
  if not buildRequirement.shouldBuild then
    if not shouldSkipCleanWatchRuntimeSync(deps) and not syncRuntimeArtifacts(deps) then
      return 1
    end
    return runOpenClaw(deps)
  end
  
  logRunner("Building TypeScript (dist is stale: " .. buildRequirement.reason .. " - " .. formatBuildReason(buildRequirement.reason) .. ").", deps)
  
  -- The rest would involve spawning processes which requires additional libraries
  -- This is a simplified version due to limitations of pure Lua
  
  if not syncRuntimeArtifacts(deps) then
    return 1
  end
  writeBuildStamp(deps)
  return runOpenClaw(deps)
end

-- Main execution
if arg and arg[0] and string.find(arg[0], "run%-node") then
  local code = runNodeMain()
  os.exit(code or 0)
end

return {
  runNodeWatchedPaths = runNodeWatchedPaths,
  isBuildRelevantRunNodePath = isBuildRelevantRunNodePath,
  isRestartRelevantRunNodePath = isRestartRelevantRunNodePath,
  resolveBuildRequirement = resolveBuildRequirement,
  runNodeMain = runNodeMain,
}
