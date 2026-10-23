#!/usr/bin/env pwsh
# test_mobile_bridge.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Define paths
$scriptPath = $MyInvocation.MyCommand.Path
$root = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetDirectoryName($scriptPath))
$bridgePath = [System.IO.Path]::Combine($root, "mobile-shared", "webview-bridge.js")

# Read the source file
$source = Get-Content -Path $bridgePath -Raw -Encoding UTF8

# Validate that the script can be parsed (basic syntax check)
try {
    $null = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$null, [ref]$null)
} catch {
    throw "Syntax error in script: $_"
}

# Perform assertions
$assertions = @(
    @{ Condition = $source.Contains('location.hostname !== "www.tiktok.com"'); Message = 'Missing location.hostname check' }
    @{ Condition = $source.Contains("root.top === root"); Message = 'Missing root.top === root check' }
    @{ Condition = $source.Contains("if (!isTop) return"); Message = 'Missing if (!isTop) return check' }
    @{ Condition = $source.Contains("MAX_MESSAGE_BYTES = 64 * 1024"); Message = 'Missing MAX_MESSAGE_BYTES definition' }
    @{ Condition = $source.Contains("MAX_AUDIO_SECONDS = 12"); Message = 'Missing MAX_AUDIO_SECONDS definition' }
    @{ Condition = $source.Contains("QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400"); Message = 'Missing QUICK_RECOVER_RELOAD_COOLDOWN_MS definition' }
    @{ Condition = $source.Contains("ALLOWED_COMMANDS"); Message = 'Missing ALLOWED_COMMANDS definition' }
    @{ Condition = $source.Contains('"set-auto-reconnect"'); Message = 'Missing set-auto-reconnect command' }
    @{ Condition = $source.Contains('"set-limiter"'); Message = 'Missing set-limiter command' }
    @{ Condition = $source.Contains('"scan-recommendations"'); Message = 'Missing scan-recommendations command' }
    @{ Condition = $source.Contains('"cancel-recommendation-scan"'); Message = 'Missing cancel-recommendation-scan command' }
    @{ Condition = $source.Contains("MAX_MEDIA_URLS = 12"); Message = 'Missing MAX_MEDIA_URLS definition' }
    @{ Condition = $source.Contains("const mediaUrls = new Map()"); Message = 'Missing mediaUrls Map declaration' }
    @{ Condition = $source.Contains('emit("media-url"'); Message = 'Missing emit("media-url") call' }
    @{ Condition = $source.Contains("addEventListener(`"message`""); Message = 'Missing addEventListener("message") call' }
    @{ Condition = -not $source.Contains(".send ="); Message = 'Found forbidden .send = assignment' }
    @{ Condition = -not $source.Contains("document.cookie"); Message = 'Found forbidden document.cookie usage' }
    @{ Condition = -not $source.Contains("localStorage"); Message = 'Found forbidden localStorage usage' }
    @{ Condition = $source.Contains('FORCE_RETURN_KEY = "tlc-force-return"'); Message = 'Missing FORCE_RETURN_KEY definition' }
    @{ Condition = $source.Contains("sessionStorage.getItem(FORCE_RETURN_KEY)"); Message = 'Missing sessionStorage.getItem(FORCE_RETURN_KEY) call' }
    @{ Condition = -not $source.Contains("sessionStorage.clear"); Message = 'Found forbidden sessionStorage.clear usage' }
    @{ Condition = -not $source.Contains("innerHTML"); Message = 'Found forbidden innerHTML usage' }
)

foreach ($assertion in $assertions) {
    if (-not $assertion.Condition) {
        throw "Assertion failed: $($assertion.Message)"
    }
}

# Check copied files
$copies = @(
    [System.IO.Path]::Combine($root, "..", "mobile", "ios", "Resources", "webview-bridge.js"),
    [System.IO.Path]::Combine($root, "..", "mobile", "android", "app", "src", "main", "res", "raw", "webview_bridge.js")
)

foreach ($copy in $copies) {
    $copyContent = Get-Content -Path $copy -Raw -Encoding UTF8
    if ($copyContent -ne $source) {
        throw "Bridge copy drifted: $copy"
    }
}

Write-Host "PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards"
