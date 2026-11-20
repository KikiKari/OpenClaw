#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "460d081601b83ede6360d60417c33ebaf268a9935292b8ed96d52311b5ee7839", "source_sha256": "f01a1a7ac46054c631b27d8f3e127238ed7417a0fe38ecb59857573bd355603f", "target_language": "lua"}
-- guard-inventory-utils.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/guard-inventory-utils.mjs
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local fs = require("fs")
local path = require("path")

local parsedTypeScriptSourceCache = {}

local function normalizeRepoPath(repoRoot, filePath)
  return string.gsub(path.relative(repoRoot, filePath), path.sep, "/")
end

local function resolveRepoSpecifier(repoRoot, specifier, importerFile)
  if string.sub(specifier, 1, 1) == "." then
    return normalizeRepoPath(repoRoot, path.resolve(path.dirname(importerFile), specifier))
  end
  if string.sub(specifier, 1, 1) == "/" then
    return normalizeRepoPath(repoRoot, specifier)
  end
  return nil
end

local function visitModuleSpecifiers(ts, sourceFile, visit)
  local function walk(node)
    if ts.isImportDeclaration(node) and ts.isStringLiteral(node.moduleSpecifier) then
      visit({
        kind = "import",
        node = node,
        specifier = node.moduleSpecifier.text,
        specifierNode = node.moduleSpecifier,
      })
    elseif ts.isExportDeclaration(node) and node.moduleSpecifier and ts.isStringLiteral(node.moduleSpecifier) then
      visit({
        kind = "export",
        node = node,
        specifier = node.moduleSpecifier.text,
        specifierNode = node.moduleSpecifier,
      })
    elseif ts.isCallExpression(node) and node.expression.kind == ts.SyntaxKind.ImportKeyword and #node.arguments == 1 and ts.isStringLiteral(node.arguments[1]) then
      visit({
        kind = "dynamic-import",
        node = node,
        specifier = node.arguments[1].text,
        specifierNode = node.arguments[1],
      })
    end

    ts.forEachChild(node, walk)
  end

  walk(sourceFile)
end

local function diffInventoryEntries(expected, actual, compareEntries)
  local expectedKeys = {}
  local actualKeys = {}
  
  for _, entry in ipairs(expected) do
    expectedKeys[require("cjson").encode(entry)] = true
  end
  
  for _, entry in ipairs(actual) do
    actualKeys[require("cjson").encode(entry)] = true
  end
  
  local missing = {}
  local unexpected = {}
  
  for _, entry in ipairs(expected) do
    if not actualKeys[require("cjson").encode(entry)] then
      table.insert(missing, entry)
    end
  end
  
  for _, entry in ipairs(actual) do
    if not expectedKeys[require("cjson").encode(entry)] then
      table.insert(unexpected, entry)
    end
  end
  
  table.sort(missing, compareEntries)
  table.sort(unexpected, compareEntries)
  
  return {
    missing = missing,
    unexpected = unexpected,
  }
end

local function writeLine(stream, text)
  stream:write(text .. "\n")
end

local async = require("async")

local function collectTypeScriptInventory(params)
  local inventory = {}
  local scriptKind = params.scriptKind or params.ts.ScriptKind.TS

  for _, filePath in ipairs(params.files) do
    local cacheKey = scriptKind .. ":" .. filePath
    local sourceFile = parsedTypeScriptSourceCache[cacheKey]
    
    if not sourceFile then
      local source = async.await(fs.promises.readFile(filePath, "utf8"))
      if params.shouldParseSource and not params.shouldParseSource(source, filePath) then
        goto continue
      end
      sourceFile = params.ts.createSourceFile(
        filePath,
        source,
        params.ts.ScriptTarget.Latest,
        true,
        scriptKind
      )
      parsedTypeScriptSourceCache[cacheKey] = sourceFile
    end
    
    local entries = params.collectEntries(sourceFile, filePath)
    for _, entry in ipairs(entries) do
      table.insert(inventory, entry)
    end
    
    ::continue::
  end

  table.sort(inventory, params.compareEntries)
  return inventory
end

local function runBaselineInventoryCheck(params)
  local streams = params.io or { stdout = process.stdout, stderr = process.stderr }
  local json = false
  for _, arg in ipairs(params.argv) do
    if arg == "--json" then
      json = true
      break
    end
  end
  
  local actual = async.await(params.collectActual())
  local expected = async.await(params.readExpected())
  local diffResult = params.diffInventory(expected, actual)
  local missing = diffResult.missing
  local unexpected = diffResult.unexpected
  local matchesBaseline = #missing == 0 and #unexpected == 0

  if json then
    writeLine(streams.stdout, require("cjson").encode(actual, true))
  else
    writeLine(streams.stdout, params.formatInventoryHuman(actual))
    local message
    if matchesBaseline then
      message = string.format("Baseline matches (%d entries).", #actual)
    else
      message = string.format("Baseline mismatch (%d unexpected, %d missing).", #unexpected, #missing)
    end
    writeLine(streams.stdout, message)
    
    if not matchesBaseline then
      if #unexpected > 0 then
        writeLine(streams.stderr, "Unexpected entries:")
        for _, entry in ipairs(unexpected) do
          writeLine(streams.stderr, "- " .. params.formatEntry(entry))
        end
      end
      if #missing > 0 then
        writeLine(streams.stderr, "Missing baseline entries:")
        for _, entry in ipairs(missing) do
          writeLine(streams.stderr, "- " .. params.formatEntry(entry))
        end
      end
    end
  end

  return matchesBaseline and 0 or 1
end

return {
  normalizeRepoPath = normalizeRepoPath,
  resolveRepoSpecifier = resolveRepoSpecifier,
  visitModuleSpecifiers = visitModuleSpecifiers,
  diffInventoryEntries = diffInventoryEntries,
  writeLine = writeLine,
  collectTypeScriptInventory = collectTypeScriptInventory,
  runBaselineInventoryCheck = runBaselineInventoryCheck,
}
