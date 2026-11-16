#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "9ff1b5831b6249cfc117068fa95ba04bfea153f48b1f2c1b94c67fb79eca77e3", "source_sha256": "cfa6fdcce252a97fa8be4d621d55955657d2f6616d52330d880db2123e1db43b", "target_language": "lua"}
-- check-ingress-agent-owner-context.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-ingress-agent-owner-context.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local path = require("path")
local ts = require("typescript")
local bundledPluginFile = require("./lib/bundled-plugin-paths.lua").bundledPluginFile
local runCallsiteGuard = require("./lib/callsite-guard.lua").runCallsiteGuard
local collectCallExpressionLines = require("./lib/ts-guard-utils.lua").collectCallExpressionLines
local runAsScript = require("./lib/ts-guard-utils.lua").runAsScript
local unwrapExpression = require("./lib/ts-guard-utils.lua").unwrapExpression

local sourceRoots = {
    "src/gateway",
    bundledPluginFile("discord", "src/voice")
}

local enforcedFiles = {
    [bundledPluginFile("discord", "src/voice/manager.ts")] = true,
    ["src/gateway/openai-http.ts"] = true,
    ["src/gateway/openresponses-http.ts"] = true,
    ["src/gateway/server-methods/agent.ts"] = true,
    ["src/gateway/server-node-events.ts"] = true
}

local function findLegacyAgentCommandCallLines(content, fileName)
    fileName = fileName or "source.ts"
    local sourceFile = ts.createSourceFile(fileName, content, ts.ScriptTarget.Latest, true)
    return collectCallExpressionLines(ts, sourceFile, function(node)
        local callee = unwrapExpression(node.expression)
        if ts.isIdentifier(callee) and callee.text == "agentCommand" then
            return callee
        end
        return nil
    end)
end

local function main()
    return runCallsiteGuard({
        importMetaUrl = debug.getinfo(1).source:sub(2),
        sourceRoots = sourceRoots,
        findCallLines = findLegacyAgentCommandCallLines,
        skipRelativePath = function(relPath)
            return not enforcedFiles[relPath:gsub(path.sep, "/")]
        end,
        header = "Found ingress callsites using local agentCommand() (must be explicit owner-aware):",
        footer = "Use agentCommandFromIngress(...) and pass senderIsOwner explicitly at ingress boundaries."
    })
end

runAsScript(debug.getinfo(1).source:sub(2), main)
