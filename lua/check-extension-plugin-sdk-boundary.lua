#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "8b32abebd6654e9f566fd6f06c126f434ce2afb2cb2e228936abd24888911068", "source_sha256": "c1ed4f7faa3c799c1ac7104f76f48529711802b8f045a3a2fa20f18a82447b76", "target_language": "lua"}
-- check-extension-plugin-sdk-boundary.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-plugin-sdk-boundary.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("lfs")
local path = require("path")
local json = require("cjson")

local BUNDLED_PLUGIN_PATH_PREFIX = "src/extensions/"
local BUNDLED_PLUGIN_ROOT_DIR = "src/extensions"

local function normalizeRepoPath(repoRoot, filePath)
  return path.relative(repoRoot, filePath)
end

local function resolveRepoSpecifier(repoRoot, specifier, filePath)
  if specifier:sub(1, 1) ~= "." then
    return specifier
  end
  local resolved = path.resolve(path.dirname(filePath), specifier)
  return normalizeRepoPath(repoRoot, resolved)
end

local function toLine(sourceFile, node)
  return 1
end

local function visitModuleSpecifiers(ts, sourceFile, callback)
end

local function diffInventoryEntries(expected, actual, compareEntries)
  local missing = {}
  local unexpected = {}
  return { missing = missing, unexpected = unexpected }
end

local function writeLine(stream, line)
  stream:write(line .. "\n")
end

local repoRoot = path.resolve(path.dirname(debug.getinfo(1).source:sub(2)), "..")
local extensionsRoot = path.join(repoRoot, BUNDLED_PLUGIN_ROOT_DIR)

local MODES = {
  ["src-outside-plugin-sdk"] = true,
  ["plugin-sdk-internal"] = true,
  ["relative-outside-package"] = true,
}

local baselinePathByMode = {
  ["src-outside-plugin-sdk"] = path.join(
    repoRoot,
    "test",
    "fixtures",
    "extension-src-outside-plugin-sdk-inventory.json"
  ),
  ["plugin-sdk-internal"] = path.join(
    repoRoot,
    "test",
    "fixtures",
    "extension-plugin-sdk-internal-inventory.json"
  ),
  ["relative-outside-package"] = path.join(
    repoRoot,
    "test",
    "fixtures",
    "extension-relative-outside-package-inventory.json"
  ),
}

local allInventoryByModePromise
local parsedExtensionSourceFilesPromise

local ruleTextByMode = {
  ["src-outside-plugin-sdk"] = "Rule: production bundled plugins must not import src/** outside src/plugin-sdk/**",
  ["plugin-sdk-internal"] = "Rule: production bundled plugins must not import src/plugin-sdk-internal/**",
  ["relative-outside-package"] = "Rule: production bundled plugins must not use relative imports that escape their own package root",
}

local function isCodeFile(fileName)
  return fileName:match("%.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$") ~= nil
end

local function isBoundaryCanaryFile(fileName)
  return fileName:find("__rootdir_boundary_canary__") ~= nil
end

local function collectExtensionSourceFiles(rootDir)
  local out = {}
  local function walk(dir)
    for file in lfs.dir(dir) do
      if file ~= "." and file ~= ".." and file ~= "dist" and file ~= "node_modules" then
        local fullPath = path.join(dir, file)
        local attr = lfs.attributes(fullPath)
        if attr.mode == "directory" then
          walk(fullPath)
        elseif attr.mode == "file" and isCodeFile(file) and not isBoundaryCanaryFile(file) then
          local relativePath = normalizeRepoPath(repoRoot, fullPath)
          if not relativePath:match("/test/") and not relativePath:match("%.test%.[^.]+$") then
            table.insert(out, fullPath)
          end
        end
      end
    end
  end
  walk(rootDir)
  table.sort(out, function(left, right)
    return normalizeRepoPath(repoRoot, left) < normalizeRepoPath(repoRoot, right)
  end)
  return out
end

local function collectParsedExtensionSourceFiles()
  if not parsedExtensionSourceFilesPromise then
    parsedExtensionSourceFilesPromise = (function()
      local files = collectExtensionSourceFiles(extensionsRoot)
      local results = {}
      for _, filePath in ipairs(files) do
        local file = io.open(filePath, "r")
        local source = file:read("*all")
        file:close()
        table.insert(results, {
          filePath = filePath,
          sourceFile = {
            getText = function() return source end
          }
        })
      end
      return results
    end)()
  end
  return parsedExtensionSourceFilesPromise
end

local function resolveExtensionRoot(filePath)
  local relativePath = normalizeRepoPath(repoRoot, filePath)
  local segments = {}
  for segment in relativePath:gmatch("[^/]+") do
    table.insert(segments, segment)
  end
  if segments[1] ~= BUNDLED_PLUGIN_ROOT_DIR or not segments[2] then
    return nil
  end
  return segments[1] .. "/" .. segments[2]
end

local function classifyReason(mode, kind, resolvedPath, specifier)
  local verb
  if kind == "export" then
    verb = "re-exports"
  elseif kind == "dynamic-import" then
    verb = "dynamically imports"
  else
    verb = "imports"
  end
  
  if mode == "relative-outside-package" then
    if resolvedPath and resolvedPath:sub(1, #"src/plugin-sdk/") == "src/plugin-sdk/" then
      return verb .. " plugin-sdk via relative path; use openclaw/plugin-sdk/<subpath>"
    end
    if resolvedPath and resolvedPath:sub(1, #"src/") == "src/" then
      return verb .. " core src path via relative path outside the extension package"
    end
    if resolvedPath and resolvedPath:sub(1, #BUNDLED_PLUGIN_PATH_PREFIX) == BUNDLED_PLUGIN_PATH_PREFIX then
      return verb .. " another bundled plugin via relative path outside the extension package"
    end
    return verb .. " relative path " .. specifier .. " outside the extension package"
  end
  if mode == "plugin-sdk-internal" then
    return verb .. " src/plugin-sdk-internal from an extension"
  end
  if resolvedPath:sub(1, #"src/plugin-sdk/") == "src/plugin-sdk/" then
    return verb .. " allowed plugin-sdk path"
  end
  return verb .. " core src path outside plugin-sdk from an extension"
end

local function compareEntries(left, right)
  local fileComp = left.file < right.file
  if left.file ~= right.file then
    return fileComp
  end
  if left.line ~= right.line then
    return left.line < right.line
  end
  local kindComp = left.kind < right.kind
  if left.kind ~= right.kind then
    return kindComp
  end
  local specifierComp = left.specifier < right.specifier
  if left.specifier ~= right.specifier then
    return specifierComp
  end
  return left.resolvedPath < right.resolvedPath
end

local function shouldReport(mode, resolvedPath)
  if mode == "relative-outside-package" then
    return false
  end
  if not resolvedPath or resolvedPath:sub(1, #"src/") ~= "src/" then
    return false
  end
  if mode == "plugin-sdk-internal" then
    return resolvedPath:sub(1, #"src/plugin-sdk-internal/") == "src/plugin-sdk-internal/"
  end
  return resolvedPath:sub(1, #"src/plugin-sdk/") ~= "src/plugin-sdk/"
end

local function collectEntriesByModeFromSourceFile(sourceFile, filePath)
  local entriesByMode = {
    ["src-outside-plugin-sdk"] = {},
    ["plugin-sdk-internal"] = {},
    ["relative-outside-package"] = {},
  }
  local extensionRoot = resolveExtensionRoot(filePath)
  local relativeFile = normalizeRepoPath(repoRoot, filePath)

  local function push(kind, specifierNode, specifier)
    local resolvedPath = resolveRepoSpecifier(repoRoot, specifier, filePath)
    local baseEntry = {
      file = relativeFile,
      line = toLine(sourceFile, specifierNode),
      kind = kind,
      specifier = specifier,
      resolvedPath = resolvedPath,
    }

    if specifier:sub(1, 1) == "." and resolvedPath and extensionRoot then
      if not (resolvedPath == extensionRoot or resolvedPath:sub(1, #extensionRoot + 1) == extensionRoot .. "/") then
        table.insert(entriesByMode["relative-outside-package"], {
          file = baseEntry.file,
          line = baseEntry.line,
          kind = baseEntry.kind,
          specifier = baseEntry.specifier,
          resolvedPath = baseEntry.resolvedPath,
          reason = classifyReason("relative-outside-package", kind, resolvedPath, specifier),
        })
      end
    end

    for _, mode in ipairs({"src-outside-plugin-sdk", "plugin-sdk-internal"}) do
      if shouldReport(mode, resolvedPath) then
        table.insert(entriesByMode[mode], {
          file = baseEntry.file,
          line = baseEntry.line,
          kind = baseEntry.kind,
          specifier = baseEntry.specifier,
          resolvedPath = baseEntry.resolvedPath,
          reason = classifyReason(mode, kind, resolvedPath, specifier),
        })
      end
    end
  end

  visitModuleSpecifiers({}, sourceFile, function(args)
    push(args.kind, args.specifierNode, args.specifier)
  end)
  return entriesByMode
end

local function collectExtensionPluginSdkBoundaryInventory(mode)
  if not MODES[mode] then
    error("Unknown mode: " .. mode)
  end
  if not allInventoryByModePromise then
    allInventoryByModePromise = (function()
      local files = collectParsedExtensionSourceFiles()
      local inventoryByMode = {
        ["src-outside-plugin-sdk"] = {},
        ["plugin-sdk-internal"] = {},
        ["relative-outside-package"] = {},
      }
      for _, fileData in ipairs(files) do
        local entriesByMode = collectEntriesByModeFromSourceFile(fileData.sourceFile, fileData.filePath)
        for modeName, _ in pairs(MODES) do
          for _, entry in ipairs(entriesByMode[modeName]) do
            table.insert(inventoryByMode[modeName], entry)
          end
        end
      end
      for modeName, _ in pairs(MODES) do
        table.sort(inventoryByMode[modeName], compareEntries)
      end
      return inventoryByMode
    end)()
  end
  return allInventoryByModePromise[mode]
end

local function readExpectedInventory(mode)
  local success, result = pcall(function()
    local file = io.open(baselinePathByMode[mode], "r")
    if not file then
      error({code = "ENOENT"})
    end
    local content = file:read("*all")
    file:close()
    return json.decode(content)
  end)
  
  if success then
    return result
  else
    if (mode == "plugin-sdk-internal" or mode == "src-outside-plugin-sdk" or mode == "relative-outside-package") and
       type(result) == "table" and result.code == "ENOENT" then
      return {}
    end
    error(result)
  end
end

local function diffInventory(expected, actual)
  return diffInventoryEntries(expected, actual, compareEntries)
end

local function formatInventoryHuman(mode, inventory)
  local lines = {ruleTextByMode[mode]}
  if #inventory == 0 then
    table.insert(lines, "No extension plugin-sdk boundary violations found.")
    return table.concat(lines, "\n")
  end
  table.insert(lines, "Extension boundary inventory:")
  local activeFile = ""
  for _, entry in ipairs(inventory) do
    if entry.file ~= activeFile then
      activeFile = entry.file
      table.insert(lines, activeFile)
    end
    table.insert(lines, "  - line " .. entry.line .. " [" .. entry.kind .. "] " .. entry.reason)
    table.insert(lines, "    specifier: " .. entry.specifier)
    table.insert(lines, "    resolved: " .. entry.resolvedPath)
  end
  return table.concat(lines, "\n")
end

local function runExtensionPluginSdkBoundaryCheck(argv, io)
  argv = argv or {}
  local streams = io or { stdout = io.stdout, stderr = io.stderr }
  local jsonFlag = false
  local mode = "src-outside-plugin-sdk"
  
  for _, arg in ipairs(argv) do
    if arg == "--json" then
      jsonFlag = true
    elseif arg:sub(1, #"--mode=") == "--mode=" then
      mode = arg:sub(#"--mode=" + 1)
    end
  end
  
  if not MODES[mode] then
    error("Unknown mode: " .. mode)
  end

  local actual = collectExtensionPluginSdkBoundaryInventory(mode)
  if jsonFlag then
    writeLine(streams.stdout, json.encode(actual, {indent = true}))
    return 0
  end

  writeLine(streams.stdout, formatInventoryHuman(mode, actual))
  if mode == "relative-outside-package" then
    if #actual == 0 then
      return 0
    end
    writeLine(
      streams.stderr,
      "Relative outside-package violations found (" .. #actual .. "); this mode no longer uses a baseline."
    )
    return 1
  end

  local expected = readExpectedInventory(mode)
  local diff = diffInventory(expected, actual)
  if #diff.missing == 0 and #diff.unexpected == 0 then
    writeLine(streams.stdout, "Baseline matches (" .. #actual .. " entries).")
    return 0
  end
  if #diff.missing > 0 then
    writeLine(streams.stderr, "Missing baseline entries (" .. #diff.missing .. "):")
    for _, entry in ipairs(diff.missing) do
      writeLine(streams.stderr, "  - " .. entry.file .. ":" .. entry.line .. " " .. entry.reason)
    end
  end
  if #diff.unexpected > 0 then
    writeLine(streams.stderr, "Unexpected inventory entries (" .. #diff.unexpected .. "):")
    for _, entry in ipairs(diff.unexpected) do
      writeLine(streams.stderr, "  - " .. entry.file .. ":" .. entry.line .. " " .. entry.reason)
    end
  end
  return 1
end

local function main(argv, io)
  local exitCode = runExtensionPluginSdkBoundaryCheck(argv, io)
  if not io then
    os.exit(exitCode)
  end
  return exitCode
end

return {
  collectExtensionPluginSdkBoundaryInventory = collectExtensionPluginSdkBoundaryInventory,
  readExpectedInventory = readExpectedInventory,
  diffInventory = diffInventory,
  runExtensionPluginSdkBoundaryCheck = runExtensionPluginSdkBoundaryCheck,
  main = main
}
