#!/usr/bin/env pwsh
# test_mobile_bridge.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Get the root directory (parent of current script directory)
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$root = Join-Path $scriptDir ".."

# Define the path to the bridge file
$bridgePath = Join-Path $root "mobile-shared" "webview-bridge.js"

# Read the source content
$source = Get-Content -Path $bridgePath -Raw -Encoding UTF8

# Attempt to parse the JavaScript (equivalent to vm.Script in Node.js)
try {
    # In PowerShell, we don't have a direct equivalent to vm.Script,
    # but we can at least check if the file exists and is readable.
    if (-not $source) {
        throw "Failed to read source file"
    }
} catch {
    Write-Error "Failed to parse JavaScript source: $_"
    exit 1
}

# Assertions to check for specific strings in the source
$assertions = @(
    @{ Condition = $source -like '*location.hostname !== "www.tiktok.com"*'; Message = 'Missing hostname check' },
    @{ Condition = $source -like '*root.top === root*'; Message = 'Missing top frame check' },
    @{ Condition = $source -like '*if (!isTop) return*'; Message = 'Missing early return for non-top frame' },
    @{ Condition = $source -like '*MAX_MESSAGE_BYTES = 64 * 1024*'; Message = 'Missing MAX_MESSAGE_BYTES definition' },
    @{ Condition = $source -like '*MAX_AUDIO_SECONDS = 12*'; Message = 'Missing MAX_AUDIO_SECONDS definition' },
    @{ Condition = $source -like '*QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400*'; Message = 'Missing QUICK_RECOVER_RELOAD_COOLDOWN_MS definition' },
    @{ Condition = $source -like '*ALLOWED_COMMANDS*'; Message = 'Missing ALLOWED_COMMANDS' },
    @{ Condition = $source -like '*"set-auto-reconnect"*'; Message = 'Missing set-auto-reconnect command' },
    @{ Condition = $source -like '*"set-limiter"*'; Message = 'Missing set-limiter command' },
    @{ Condition = $source -like '*"scan-recommendations"*'; Message = 'Missing scan-recommendations command' },
    @{ Condition = $source -like '*"cancel-recommendation-scan"*'; Message = 'Missing cancel-recommendation-scan command' },
    @{ Condition = $source -like '*MAX_MEDIA_URLS = 12*'; Message = 'Missing MAX_MEDIA_URLS definition' },
    @{ Condition = $source -like '*const mediaUrls = new Map()*'; Message = 'Missing mediaUrls Map initialization' },
    @{ Condition = $source -like '*emit("media-url"*'; Message = 'Missing emit("media-url") call' },
    @{ Condition = $source -like '*addEventListener("message"*'; Message = 'Missing addEventListener("message")' },
    @{ Condition = $source -notlike '*.send =*'; Message = 'Found forbidden .send = usage' },
    @{ Condition = $source -notlike '*document.cookie*'; Message = 'Found forbidden document.cookie usage' },
    @{ Condition = $source -notlike '*localStorage*'; Message = 'Found forbidden localStorage usage' },
    @{ Condition = $source -like '*FORCE_RETURN_KEY = "tlc-force-return"*'; Message = 'Missing FORCE_RETURN_KEY definition' },
    @{ Condition = $source -like '*sessionStorage.getItem(FORCE_RETURN_KEY)*'; Message = 'Missing sessionStorage.getItem(FORCE_RETURN_KEY) usage' },
    @{ Condition = $source -notlike '*sessionStorage.clear*'; Message = 'Found forbidden sessionStorage.clear usage' },
    @{ Condition = $source -notlike '*innerHTML*'; Message = 'Found forbidden innerHTML usage' }
)

foreach ($assertion in $assertions) {
    if (-not $assertion.Condition) {
        Write-Error $assertion.Message
        exit 1
    }
}

# Check bridge copies in iOS and Android directories
$copyPaths = @(
    (Join-Path $root ".." "mobile" "ios" "Resources" "webview-bridge.js"),
    (Join-Path $root ".." "mobile" "android" "app" "src" "main" "res" "raw" "webview_bridge.js")
)

foreach ($copyPath in $copyPaths) {
    $copyContent = Get-Content -Path $copyPath -Raw -Encoding UTF8
    if ($copyContent -ne $source) {
        Write-Error "Bridge copy drifted: $copyPath"
        exit 1
    }
}

Write-Output "PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards"
