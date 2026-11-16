#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f94000619fc24dea4d73c2560cc07e26dfa5a5207bf23dae4ee8078c42bde55f", "source_sha256": "e3a70dc12204181e113d6bd10329e4a0d699a4c3922e73906b5348e1fc3fd07a", "target_language": "lua"}
-- check-no-raw-channel-fetch.mjs — portiert nach lua
-- Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-channel-fetch.mjs
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

local ts = require("typescript")
local bundledPluginCallsite = require("./lib/bundled-plugin-paths.lua").bundledPluginCallsite
local runCallsiteGuard = require("./lib/callsite-guard.lua").runCallsiteGuard
local collectCallExpressionLines = require("./lib/ts-guard-utils.lua").collectCallExpressionLines
local runAsScript = require("./lib/ts-guard-utils.lua").runAsScript
local unwrapExpression = require("./lib/ts-guard-utils.lua").unwrapExpression

local sourceRoots = {"src/channels", "src/routing", "src/line", "extensions"}

-- Temporary allowlist for legacy callsites. New raw fetch callsites in channel/plugin runtime
-- code should be rejected and migrated to fetchWithSsrFGuard/shared channel helpers.
local allowedRawFetchCallsites = {
    [bundledPluginCallsite("bluebubbles", "src/test-harness.ts", 128)] = true,
    [bundledPluginCallsite("bluebubbles", "src/types.ts", 181)] = true,
    [bundledPluginCallsite("browser", "src/browser/cdp.helpers.ts", 268)] = true,
    [bundledPluginCallsite("browser", "src/browser/client-fetch.ts", 192)] = true,
    [bundledPluginCallsite("browser", "src/browser/test-fetch.ts", 24)] = true,
    [bundledPluginCallsite("browser", "src/browser/test-fetch.ts", 27)] = true,
    [bundledPluginCallsite("chutes", "models.ts", 535)] = true,
    [bundledPluginCallsite("chutes", "models.ts", 542)] = true,
    [bundledPluginCallsite("discord", "src/monitor/gateway-plugin.ts", 322)] = true,
    [bundledPluginCallsite("discord", "src/monitor/gateway-plugin.ts", 360)] = true,
    [bundledPluginCallsite("discord", "src/voice-message.ts", 298)] = true,
    [bundledPluginCallsite("discord", "src/voice-message.ts", 333)] = true,
    [bundledPluginCallsite("elevenlabs", "speech-provider.ts", 295)] = true,
    [bundledPluginCallsite("elevenlabs", "tts.ts", 116)] = true,
    [bundledPluginCallsite("feishu", "src/monitor.webhook.test-helpers.ts", 25)] = true,
    [bundledPluginCallsite("github-copilot", "login.ts", 48)] = true,
    [bundledPluginCallsite("github-copilot", "login.ts", 80)] = true,
    [bundledPluginCallsite("googlechat", "src/auth.ts", 83)] = true,
    [bundledPluginCallsite("huggingface", "models.ts", 142)] = true,
    [bundledPluginCallsite("kilocode", "provider-models.ts", 130)] = true,
    [bundledPluginCallsite("matrix", "src/matrix/sdk/transport.ts", 112)] = true,
    [bundledPluginCallsite("microsoft-foundry", "onboard.ts", 479)] = true,
    [bundledPluginCallsite("microsoft", "speech-provider.ts", 132)] = true,
    [bundledPluginCallsite("minimax", "oauth.ts", 66)] = true,
    [bundledPluginCallsite("minimax", "oauth.ts", 107)] = true,
    [bundledPluginCallsite("minimax", "tts.ts", 52)] = true,
    [bundledPluginCallsite("msteams", "src/graph.ts", 47)] = true,
    [bundledPluginCallsite("msteams", "src/sdk.ts", 329)] = true,
    [bundledPluginCallsite("msteams", "src/sdk.ts", 370)] = true,
    [bundledPluginCallsite("ollama", "src/stream.ts", 649)] = true,
    [bundledPluginCallsite("openai", "tts.ts", 133)] = true,
    [bundledPluginCallsite("qa-channel", "src/bus-client.ts", 41)] = true,
    [bundledPluginCallsite("qa-channel", "src/bus-client.ts", 221)] = true,
    [bundledPluginCallsite("qa-lab", "src/docker-up.runtime.ts", 274)] = true,
    [bundledPluginCallsite("qa-lab", "src/gateway-child.ts", 489)] = true,
    [bundledPluginCallsite("qa-lab", "src/suite.ts", 330)] = true,
    [bundledPluginCallsite("qa-lab", "src/suite.ts", 341)] = true,
    [bundledPluginCallsite("qa-lab", "web/src/app.ts", 15)] = true,
    [bundledPluginCallsite("qa-lab", "web/src/app.ts", 23)] = true,
    [bundledPluginCallsite("qa-lab", "web/src/app.ts", 31)] = true,
    [bundledPluginCallsite("qqbot", "src/api.ts", 102)] = true,
    [bundledPluginCallsite("qqbot", "src/api.ts", 237)] = true,
    [bundledPluginCallsite("qqbot", "src/stt.ts", 81)] = true,
    [bundledPluginCallsite("qqbot", "src/tools/channel.ts", 180)] = true,
    [bundledPluginCallsite("qqbot", "src/utils/audio-convert.ts", 377)] = true,
    [bundledPluginCallsite("signal", "src/install-signal-cli.ts", 224)] = true,
    [bundledPluginCallsite("slack", "src/monitor/media.ts", 96)] = true,
    [bundledPluginCallsite("slack", "src/monitor/media.ts", 115)] = true,
    [bundledPluginCallsite("slack", "src/monitor/media.ts", 120)] = true,
    [bundledPluginCallsite("tlon", "src/tlon-api.ts", 185)] = true,
    [bundledPluginCallsite("tlon", "src/tlon-api.ts", 235)] = true,
    [bundledPluginCallsite("tlon", "src/tlon-api.ts", 289)] = true,
    [bundledPluginCallsite("venice", "models.ts", 552)] = true,
    [bundledPluginCallsite("vercel-ai-gateway", "models.ts", 181)] = true,
    [bundledPluginCallsite("voice-call", "src/providers/twilio/api.ts", 23)] = true,
}

local function isRawFetchCall(expression)
    local callee = unwrapExpression(expression)
    if ts.isIdentifier(callee) then
        return callee.text == "fetch"
    end
    if ts.isPropertyAccessExpression(callee) then
        return ts.isIdentifier(callee.expression) and
               callee.expression.text == "globalThis" and
               callee.name.text == "fetch"
    end
    return false
end

local function findRawFetchCallLines(content, fileName)
    fileName = fileName or "source.ts"
    local sourceFile = ts.createSourceFile(fileName, content, ts.ScriptTarget.Latest, true)
    return collectCallExpressionLines(ts, sourceFile, function(node)
        if isRawFetchCall(node.expression) then
            return node.expression
        else
            return nil
        end
    end)
end

local function main()
    return runCallsiteGuard({
        importMetaUrl = debug.getinfo(1).source,
        sourceRoots = sourceRoots,
        extraTestSuffixes = {".browser.test.ts", ".node.test.ts"},
        findCallLines = findRawFetchCallLines,
        allowCallsite = function(callsite)
            return allowedRawFetchCallsites[callsite] == true
        end,
        header = "Found raw fetch() usage in channel/plugin runtime sources outside allowlist:",
        footer = "Use fetchWithSsrFGuard() or existing channel/plugin SDK wrappers for network calls.",
    })
end

runAsScript(debug.getinfo(1).source, main)
