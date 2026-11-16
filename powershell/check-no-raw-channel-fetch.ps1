#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "624bcfa2e0a7043fa98629cb4deb5cd0eedd4757cea851b35ab0a4cbd58e783b", "source_sha256": "e3a70dc12204181e113d6bd10329e4a0d699a4c3922e73906b5348e1fc3fd07a", "target_language": "powershell"}
# check-no-raw-channel-fetch.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-channel-fetch.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Import necessary modules
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text.RegularExpressions

# Define paths
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$bundledPluginPathsPath = Join-Path $scriptDir "lib" "bundled-plugin-paths.ps1"
$callsiteGuardPath = Join-Path $scriptDir "lib" "callsite-guard.ps1"
$tsGuardUtilsPath = Join-Path $scriptDir "lib" "ts-guard-utils.ps1"

# Source helper functions
. $bundledPluginPathsPath
. $callsiteGuardPath
. $tsGuardUtilsPath

# Define source roots
$sourceRoots = @(
    "src/channels"
    "src/routing"
    "src/line"
    "extensions"
)

# Temporary allowlist for legacy callsites. New raw fetch callsites in channel/plugin runtime
# code should be rejected and migrated to fetchWithSsrFGuard/shared channel helpers.
$allowedRawFetchCallsites = [HashSet[string]]::new()

# Helper function to add callsites to the allowlist
function Add-Callsite {
    param(
        [string]$plugin,
        [string]$file,
        [int]$line
    )
    $callsite = bundledPluginCallsite $plugin $file $line
    [void]$allowedRawFetchCallsites.Add($callsite)
}

# Populate the allowlist
Add-Callsite "bluebubbles" "src/test-harness.ts" 128
Add-Callsite "bluebubbles" "src/types.ts" 181
Add-Callsite "browser" "src/browser/cdp.helpers.ts" 268
Add-Callsite "browser" "src/browser/client-fetch.ts" 192
Add-Callsite "browser" "src/browser/test-fetch.ts" 24
Add-Callsite "browser" "src/browser/test-fetch.ts" 27
Add-Callsite "chutes" "models.ts" 535
Add-Callsite "chutes" "models.ts" 542
Add-Callsite "discord" "src/monitor/gateway-plugin.ts" 322
Add-Callsite "discord" "src/monitor/gateway-plugin.ts" 360
Add-Callsite "discord" "src/voice-message.ts" 298
Add-Callsite "discord" "src/voice-message.ts" 333
Add-Callsite "elevenlabs" "speech-provider.ts" 295
Add-Callsite "elevenlabs" "tts.ts" 116
Add-Callsite "feishu" "src/monitor.webhook.test-helpers.ts" 25
Add-Callsite "github-copilot" "login.ts" 48
Add-Callsite "github-copilot" "login.ts" 80
Add-Callsite "googlechat" "src/auth.ts" 83
Add-Callsite "huggingface" "models.ts" 142
Add-Callsite "kilocode" "provider-models.ts" 130
Add-Callsite "matrix" "src/matrix/sdk/transport.ts" 112
Add-Callsite "microsoft-foundry" "onboard.ts" 479
Add-Callsite "microsoft" "speech-provider.ts" 132
Add-Callsite "minimax" "oauth.ts" 66
Add-Callsite "minimax" "oauth.ts" 107
Add-Callsite "minimax" "tts.ts" 52
Add-Callsite "msteams" "src/graph.ts" 47
Add-Callsite "msteams" "src/sdk.ts" 329
Add-Callsite "msteams" "src/sdk.ts" 370
Add-Callsite "ollama" "src/stream.ts" 649
Add-Callsite "openai" "tts.ts" 133
Add-Callsite "qa-channel" "src/bus-client.ts" 41
Add-Callsite "qa-channel" "src/bus-client.ts" 221
Add-Callsite "qa-lab" "src/docker-up.runtime.ts" 274
Add-Callsite "qa-lab" "src/gateway-child.ts" 489
Add-Callsite "qa-lab" "src/suite.ts" 330
Add-Callsite "qa-lab" "src/suite.ts" 341
Add-Callsite "qa-lab" "web/src/app.ts" 15
Add-Callsite "qa-lab" "web/src/app.ts" 23
Add-Callsite "qa-lab" "web/src/app.ts" 31
Add-Callsite "qqbot" "src/api.ts" 102
Add-Callsite "qqbot" "src/api.ts" 237
Add-Callsite "qqbot" "src/stt.ts" 81
Add-Callsite "qqbot" "src/tools/channel.ts" 180
Add-Callsite "qqbot" "src/utils/audio-convert.ts" 377
Add-Callsite "signal" "src/install-signal-cli.ts" 224
Add-Callsite "slack" "src/monitor/media.ts" 96
Add-Callsite "slack" "src/monitor/media.ts" 115
Add-Callsite "slack" "src/monitor/media.ts" 120
Add-Callsite "tlon" "src/tlon-api.ts" 185
Add-Callsite "tlon" "src/tlon-api.ts" 235
Add-Callsite "tlon" "src/tlon-api.ts" 289
Add-Callsite "venice" "models.ts" 552
Add-Callsite "vercel-ai-gateway" "models.ts" 181
Add-Callsite "voice-call" "src/providers/twilio/api.ts" 23

function Test-RawFetchCall {
    param(
        [object]$expression
    )
    
    $callee = Unwrap-Expression $expression
    
    # Check if it's a simple identifier named 'fetch'
    if ($callee -is [System.String] -and $callee -eq "fetch") {
        return $true
    }
    
    # Check if it's a property access like globalThis.fetch
    if ($null -ne $callee.ParenthesizedExpression) {
        $innerExpr = $callee.ParenthesizedExpression.Expression
        if ($null -ne $innerExpr.Name -and 
            $null -ne $innerExpr.Expression -and
            $innerExpr.Expression.IdentifierName -eq "globalThis" -and
            $innerExpr.Name.IdentifierName -eq "fetch") {
            return $true
        }
    }
    
    return $false
}

function Find-RawFetchCallLines {
    param(
        [string]$content,
        [string]$fileName = "source.ts"
    )
    
    # This is a simplified implementation since we don't have TypeScript AST parsing in PowerShell
    # We'll use regex to find potential fetch calls
    $lines = $content -split "`n"
    $result = @()
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # Simple pattern matching for fetch calls
        if ($line -match "\bfetch\s*\(" -or $line -match "globalThis\.fetch\s*\(") {
            # Skip comments
            if (-not ($line.Trim().StartsWith("//") -or $line.Trim().StartsWith("/*"))) {
                $result += @{
                    LineNumber = $i + 1
                    Expression = $line.Trim()
                }
            }
        }
    }
    
    return $result
}

function Main {
    $params = @{
        ImportMetaUrl = $MyInvocation.MyCommand.Path
        SourceRoots = $sourceRoots
        ExtraTestSuffixes = @(".browser.test.ts", ".node.test.ts")
        FindCallLines = ${function:Find-RawFetchCallLines}
        AllowCallsite = ${function:Allow-Callsite}
        Header = "Found raw fetch() usage in channel/plugin runtime sources outside allowlist:"
        Footer = "Use fetchWithSsrFGuard() or existing channel/plugin SDK wrappers for network calls."
    }
    
    Run-CallsiteGuard @params
}

function Allow-Callsite {
    param([string]$callsite)
    return $allowedRawFetchCallsites.Contains($callsite)
}

# Run as script
if ($MyInvocation.InvocationName -eq '-' -or $MyInvocation.Line -like "*$($MyInvocation.MyCommand.Name)*") {
    Main
}
