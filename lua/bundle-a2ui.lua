#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "3117093b7cb16b495fded7386061b64e7ad94dd60c7118e70ea718d6b1f41493", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "lua"}
-- bundle-a2ui.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local uv = require("luv")
local path = require("path")
local fs = require("fs")
local crypto = require("crypto")
local child_process = require("child_process")

local function fileURLToPath(url)
  return url:gsub("file://", "")
end

local function pathToFileURL(filepath)
  return "file://" .. filepath
end

local function dirname(filepath)
  return filepath:match("(.*)[/\\]")
end

local function basename(filepath)
  return filepath:match("[/\\]([^/\\]+)$")
end

local function join(...)
  local parts = {...}
  local result = ""
  for i, part in ipairs(parts) do
    if i == 1 then
      result = part
    else
      result = path.join(result, part)
    end
  end
  return result
end

local function resolve(...)
  local parts = {...}
  local resolved = {}
  for _, part in ipairs(parts) do
    for segment in string.gmatch(part, "[^/\\]+") do
      if segment == ".." then
        table.remove(resolved)
      elseif segment ~= "." then
        table.insert(resolved, segment)
      end
    end
  end
  return table.concat(resolved, "/")
end

local function normalizePath(filePath)
  return filePath:gsub("\\", "/")
end

local scriptPath = arg[0] or debug.getinfo(1).source:sub(2)
local rootDir = resolve(dirname(fileURLToPath(pathToFileURL(scriptPath))), "..")
local hashFile = join(rootDir, "src", "canvas-host", "a2ui", ".bundle.hash")
local outputFile = join(rootDir, "src", "canvas-host", "a2ui", "a2ui.bundle.js")
local a2uiRendererDir = join(rootDir, "vendor", "a2ui", "renderers", "lit")
local a2uiAppDir = join(rootDir, "apps", "shared", "OpenClawKit", "Tools", "CanvasA2UI")
local inputPaths = {
  join(rootDir, "package.json"),
  join(rootDir, "pnpm-lock.yaml"),
  a2uiRendererDir,
  a2uiAppDir,
}
local ignoredBundleHashInputPrefixes = {"vendor/a2ui/renderers/lit/dist"}
local relativeInputPaths = {}
for _, inputPath in ipairs(inputPaths) do
  table.insert(relativeInputPaths, normalizePath(path.relative(rootDir, inputPath)))
end

local function fail(message)
  print(message)
  print("A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle")
  print("If this persists, verify pnpm deps and try again.")
  os.exit(1)
end

local function pathExists(targetPath)
  local stat = uv.fs_stat(targetPath)
  return stat ~= nil
end

function isBundleHashInputPath(filePath, repoRoot)
  repoRoot = repoRoot or rootDir
  local relativePath = normalizePath(path.relative(repoRoot, filePath))
  for _, ignoredPath in ipairs(ignoredBundleHashInputPrefixes) do
    if relativePath == ignoredPath or string.sub(relativePath, 1, #ignoredPath + 1) == ignoredPath .. "/" then
      return false
    end
  end
  return true
end

function getLocalRolldownCliCandidates(repoRoot)
  repoRoot = repoRoot or rootDir
  return {
    join(repoRoot, "node_modules", "rolldown", "bin", "cli.mjs"),
    join(repoRoot, "node_modules", ".pnpm", "node_modules", "rolldown", "bin", "cli.mjs"),
    join(
      repoRoot,
      "node_modules",
      ".pnpm",
      "rolldown@1.0.0-rc.12",
      "node_modules",
      "rolldown",
      "bin",
      "cli.mjs"
    ),
  }
end

local function walkFiles(entryPath, files)
  if not isBundleHashInputPath(entryPath) then
    return
  end
  local stat = uv.fs_stat(entryPath)
  if not stat then return end
  if stat.type ~= "directory" then
    table.insert(files, entryPath)
    return
  end
  local entries = uv.fs_readdir(entryPath)
  if entries then
    for _, entry in ipairs(entries) do
      walkFiles(join(entryPath, entry.name), files)
    end
  end
end

local function listTrackedInputFiles()
  local result = child_process.spawnSync("git", {"ls-files", "--"}, {
    cwd = rootDir,
    encoding = "utf8",
    stdio = {"ignore", "pipe", "pipe"},
  })
  if result.status ~= 0 then
    return nil
  end
  local files = {}
  for line in string.gmatch(result.stdout, "[^\n]+") do
    if line ~= "" then
      local fullPath = join(rootDir, line)
      if isBundleHashInputPath(fullPath) then
        table.insert(files, fullPath)
      end
    end
  end
  return files
end

local function computeHash()
  local files = listTrackedInputFiles()
  if not files then
    files = {}
    for _, inputPath in ipairs(inputPaths) do
      walkFiles(inputPath, files)
    end
  end
  
  table.sort(files, function(left, right)
    return normalizePath(left) < normalizePath(right)
  end)

  local hash = crypto.createHash("sha256")
  for _, filePath in ipairs(files) do
    hash:update(normalizePath(path.relative(rootDir, filePath)))
    hash:update("\0")
    local content = fs.readFileSync(filePath)
    hash:update(content)
    hash:update("\0")
  end
  return hash:digest("hex")
end

local function runStep(command, args, options)
  options = options or {}
  local result = child_process.spawnSync(command, args, {
    cwd = rootDir,
    stdio = "inherit",
    env = os.getenv,
  })
  if result.status ~= 0 then
    os.exit(result.status or 1)
  end
end

local function runPnpm(pnpmArgs)
  -- Simplified pnpm runner logic - in Lua we'll just call pnpm directly
  local cmd = "pnpm"
  local fullArgs = {}
  for _, arg in ipairs(pnpmArgs) do
    table.insert(fullArgs, arg)
  end
  runStep(cmd, fullArgs)
end

local function main()
  local hasRendererDir = pathExists(a2uiRendererDir)
  local hasAppDir = pathExists(a2uiAppDir)
  local hasOutputFile = pathExists(outputFile)
  
  if not hasRendererDir or not hasAppDir then
    if hasOutputFile then
      print("A2UI sources missing; keeping prebuilt bundle.")
      return
    end
    if os.getenv("OPENCLAW_SPARSE_PROFILE") or os.getenv("OPENCLAW_A2UI_SKIP_MISSING") == "1" then
      print("A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set.")
      return
    end
    fail("A2UI sources missing and no prebuilt bundle found at: " .. outputFile)
  end

  local currentHash = computeHash()
  if pathExists(hashFile) then
    local previousHash = fs.readFileSync(hashFile, "utf8"):gsub("^%s*(.-)%s*$", "%1")
    if previousHash == currentHash and hasOutputFile then
      print("A2UI bundle up to date; skipping.")
      return
    end
  end

  runPnpm({"-s", "exec", "tsc", "-p", join(a2uiRendererDir, "tsconfig.json")})

  local localRolldownCliCandidates = getLocalRolldownCliCandidates(rootDir)
  local localRolldownCli = nil
  for _, candidate in ipairs(localRolldownCliCandidates) do
    if pathExists(candidate) then
      localRolldownCli = candidate
      break
    end
  end

  if localRolldownCli then
    runStep("node", {
      localRolldownCli,
      "-c",
      join(a2uiAppDir, "rolldown.config.mjs"),
    })
  else
    runPnpm({"-s", "exec", "rolldown", "-c", join(a2uiAppDir, "rolldown.config.mjs")})
  end

  fs.writeFileSync(hashFile, currentHash .. "\n", "utf8")
end

local function mainWrapper()
  local success, err = pcall(main)
  if not success then
    fail(tostring(err))
  end
end

-- Check if this script is being run directly
if arg[1] and pathToFileURL(arg[1]) == pathToFileURL(scriptPath) then
  mainWrapper()
end

return {
  isBundleHashInputPath = isBundleHashInputPath,
  getLocalRolldownCliCandidates = getLocalRolldownCliCandidates,
}
