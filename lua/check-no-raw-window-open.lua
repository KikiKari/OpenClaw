#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "ce915a3ea9b4361eb3349bdd1539889652f4af7f6512b91650a4cb2182f5b987", "source_sha256": "b77d7ac77e305afea60b0aa9579426471649732bc9d7cb3bce3f14575d0d0bb6", "target_language": "lua"}
-- check-no-raw-window-open.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-window-open.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")
local ts = require("typescript")

local lib_ts_guard_utils = require("./lib/ts-guard-utils.lua")
local collectTypeScriptFiles = lib_ts_guard_utils.collectTypeScriptFiles
local resolveRepoRoot = lib_ts_guard_utils.resolveRepoRoot
local runAsScript = lib_ts_guard_utils.runAsScript
local toLine = lib_ts_guard_utils.toLine
local unwrapExpression = lib_ts_guard_utils.unwrapExpression

local repoRoot = resolveRepoRoot(debug.getinfo(1).source)
local uiSourceDir = path.join(repoRoot, "ui", "src", "ui")
local allowedCallsites = {}
allowedCallsites[path.join(uiSourceDir, "open-external-url.ts")] = true

local function asPropertyAccess(expression)
  if ts.isPropertyAccessExpression(expression) then
    return expression
  end
  if type(ts.isPropertyAccessChain) == "function" and ts.isPropertyAccessChain(expression) then
    return expression
  end
  return nil
end

local function isRawWindowOpenCall(expression)
  local propertyAccess = asPropertyAccess(unwrapExpression(expression))
  if not propertyAccess or propertyAccess.name.text ~= "open" then
    return false
  end

  local receiver = unwrapExpression(propertyAccess.expression)
  return ts.isIdentifier(receiver) and (receiver.text == "window" or receiver.text == "globalThis")
end

local function findRawWindowOpenLines(content, fileName)
  fileName = fileName or "source.ts"
  local sourceFile = ts.createSourceFile(fileName, content, ts.ScriptTarget.Latest, true)
  local lines = {}

  local function visit(node)
    if ts.isCallExpression(node) and isRawWindowOpenCall(node.expression) then
      table.insert(lines, toLine(sourceFile, node.expression))
    end
    ts.forEachChild(node, visit)
  end

  visit(sourceFile)
  return lines
end

local async = require("async")
local function main()
  return async.run(function()
    local files = collectTypeScriptFiles(uiSourceDir, {
      extraTestSuffixes = {".browser.test.ts", ".node.test.ts"},
      ignoreMissing = true,
    })
    local violations = {}

    for _, filePath in ipairs(files) do
      if allowedCallsites[filePath] then
        goto continue
      end

      local content = fs.readFileSync(filePath, "utf8")
      for _, line in ipairs(findRawWindowOpenLines(content, filePath)) do
        local relPath = path.relative(repoRoot, filePath)
        table.insert(violations, relPath .. ":" .. line)
      end
      ::continue::
    end

    if #violations == 0 then
      return
    end

    print("Found raw window.open usage outside safe helper:")
    for _, violation in ipairs(violations) do
      print("- " .. violation)
    end
    print("Use openExternalUrlSafe(...) from ui/src/ui/open-external-url.ts instead.")
    os.exit(1)
  end)
end

runAsScript(main)
