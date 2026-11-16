#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "5ba6c1c5aa0bf40d3136a6530e7f97141c4b7d4f74935efa001cd4b3a72d457c", "source_sha256": "a01dcf18c06d5aeb081cedf0088a13b316c08622615e4de86febe2deaee2596d", "target_language": "lua"}
-- check-no-register-http-handler.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-register-http-handler.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local ts = require("typescript")
local callsite_guard = require("lib.callsite-guard")
local ts_guard_utils = require("lib.ts-guard-utils")

local sourceRoots = {"src", "extensions"}

local function isDeprecatedRegisterHttpHandlerCall(expression)
  local callee = ts_guard_utils.unwrapExpression(expression)
  return ts.isPropertyAccessExpression(callee) and callee.name.text == "registerHttpHandler"
end

local function findDeprecatedRegisterHttpHandlerLines(content, fileName)
  fileName = fileName or "source.ts"
  local sourceFile = ts.createSourceFile(fileName, content, ts.ScriptTarget.Latest, true)
  return ts_guard_utils.collectCallExpressionLines(ts, sourceFile, function(node)
    if isDeprecatedRegisterHttpHandlerCall(node.expression) then
      return node.expression
    else
      return nil
    end
  end)
end

local function main()
  return callsite_guard.runCallsiteGuard({
    sourceRoots = sourceRoots,
    findCallLines = findDeprecatedRegisterHttpHandlerLines,
    header = "Found deprecated plugin API call registerHttpHandler(...):",
    footer = "Use registerHttpRoute({ path, auth, match, handler }) and registerPluginHttpRoute for dynamic webhook paths.",
  })
end

ts_guard_utils.runAsScript(main)
