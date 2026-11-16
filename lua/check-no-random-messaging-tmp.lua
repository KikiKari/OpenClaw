#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "cfb66b8d104d4c2a420b5faef89bccc6a95fdf944b6dd3e77ba51157900a3627", "source_sha256": "290dec5062f0c8675bc7304f9c93475a3e9667ed53e93894c5bc66f40e5ae5df", "target_language": "lua"}
-- check-no-random-messaging-tmp.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-random-messaging-tmp.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local ts = require("typescript")
local bundledPluginFile = require("./lib/bundled-plugin-paths.lua").bundledPluginFile
local runCallsiteGuard = require("./lib/callsite-guard.lua").runCallsiteGuard
local collectCallExpressionLines = require("./lib/ts-guard-utils.lua").collectCallExpressionLines
local runAsScript = require("./lib/ts-guard-utils.lua").runAsScript
local unwrapExpression = require("./lib/ts-guard-utils.lua").unwrapExpression

local messagingTmpdirGuardSourceRoots = {
  "src/channels",
  "src/infra/outbound",
  "src/line",
  "src/media",
  "src/media-understanding",
  "extensions"
}

local allowedRelativePaths = {
  [bundledPluginFile("feishu", "src/dedup.ts")] = true
}

local function collectOsTmpdirImports(sourceFile)
  local osModuleSpecifiers = {
    ["node:os"] = true,
    ["os"] = true
  }
  local osNamespaceOrDefault = {}
  local namedTmpdir = {}
  
  for _, statement in ipairs(sourceFile.statements) do
    if not ts.isImportDeclaration(statement) then
      goto continue
    end
    
    if not statement.importClause or not ts.isStringLiteral(statement.moduleSpecifier) then
      goto continue
    end
    
    if not osModuleSpecifiers[statement.moduleSpecifier.text] then
      goto continue
    end
    
    local clause = statement.importClause
    if clause.name then
      osNamespaceOrDefault[clause.name.text] = true
    end
    
    if not clause.namedBindings then
      goto continue
    end
    
    if ts.isNamespaceImport(clause.namedBindings) then
      osNamespaceOrDefault[clause.namedBindings.name.text] = true
      goto continue
    end
    
    for _, element in ipairs(clause.namedBindings.elements) do
      local propertyName = element.propertyName and element.propertyName.text or element.name.text
      if propertyName == "tmpdir" then
        namedTmpdir[element.name.text] = true
      end
    end
    
    ::continue::
  end
  
  return {
    osNamespaceOrDefault = osNamespaceOrDefault,
    namedTmpdir = namedTmpdir
  }
end

local function findMessagingTmpdirCallLines(content, fileName)
  fileName = fileName or "source.ts"
  local sourceFile = ts.createSourceFile(fileName, content, ts.ScriptTarget.Latest, true)
  local imports = collectOsTmpdirImports(sourceFile)
  local osNamespaceOrDefault = imports.osNamespaceOrDefault
  local namedTmpdir = imports.namedTmpdir
  
  return collectCallExpressionLines(ts, sourceFile, function(node)
    local callee = unwrapExpression(node.expression)
    
    if ts.isPropertyAccessExpression(callee) and
       callee.name.text == "tmpdir" and
       ts.isIdentifier(callee.expression) and
       osNamespaceOrDefault[callee.expression.text] then
      return callee
    end
    
    if ts.isIdentifier(callee) and namedTmpdir[callee.text] then
      return callee
    end
    
    return nil
  end)
end

local function main()
  return runCallsiteGuard({
    importMetaUrl = debug.getinfo(1, "S").source:sub(2),
    sourceRoots = messagingTmpdirGuardSourceRoots,
    findCallLines = findMessagingTmpdirCallLines,
    skipRelativePath = function(relativePath)
      return allowedRelativePaths[relativePath] == true
    end,
    header = "Found os.tmpdir()/tmpdir() usage in messaging/channel runtime sources:",
    footer = "Use resolvePreferredOpenClawTmpDir() or plugin-sdk temp helpers instead of host tmp defaults.",
    sortViolations = false
  })
end

-- Export functions
_G.findMessagingTmpdirCallLines = findMessagingTmpdirCallLines
_G.main = main

runAsScript(debug.getinfo(1, "S").source:sub(2), main)
