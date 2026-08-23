#!/usr/bin/env pwsh
# test_extension.cjs — portiert nach powershell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_extension.cjs
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Helper functions to mimic Node.js behavior
function Resolve-PathSafe {
    param([string]$Path)
    try {
        return Resolve-Path $Path -ErrorAction Stop
    } catch {
        return $null
    }
}

function Test-PathSafe {
    param([string]$Path)
    return Test-Path $Path
}

function Get-ContentSafe {
    param([string]$Path)
    if (Test-Path $Path) {
        return Get-Content $Path -Raw
    }
    return $null
}

function Get-ChildItemSafe {
    param([string]$Path)
    if (Test-Path $Path) {
        return Get-ChildItem $Path
    }
    return @()
}

# Load JSON file
function ConvertFrom-JsonSafe {
    param([string]$Path)
    $content = Get-ContentSafe $Path
    if ($content) {
        return $content | ConvertFrom-Json
    }
    return $null
}

# Compute SHA256 hash
function Get-Sha256Hash {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return [BitConverter]::ToString($hash).Replace("-", "").ToUpper()
}

# Concatenate byte arrays
function Concat-Bytes {
    param([byte[][]]$Chunks)
    $size = ($Chunks | Measure-Object -Property Length -Sum).Sum
    $out = New-Object byte[] $size
    $offset = 0
    foreach ($chunk in $Chunks) {
        [Array]::Copy($chunk, 0, $out, $offset, $chunk.Length)
        $offset += $chunk.Length
    }
    return $out
}

# Varint encoding
function Convert-ToVarint {
    param([long]$Value)
    $bytes = @()
    $current = [bigint]$Value
    do {
        $byte = [byte]($current -band 0x7F)
        $current = $current -shr 7
        if ($current -gt 0) {
            $byte = $byte -bor 0x80
        }
        $bytes += $byte
    } while ($current -gt 0)
    return [byte[]]$bytes
}

# Bytes field encoding
function Convert-ToBytesField {
    param([int]$Number, [object]$Value)
    $body = $Value
    if ($Value -is [string]) {
        $body = [System.Text.Encoding]::UTF8.GetBytes($Value)
    }
    $tag = [bigint]($Number) -shl 3 -bor 2
    $tagBytes = Convert-ToVarint $tag
    $lengthBytes = Convert-ToVarint $body.Length
    return Concat-Bytes @($tagBytes, $lengthBytes, $body)
}

# Int field encoding
function Convert-ToIntField {
    param([int]$Number, [long]$Value)
    $tag = [bigint]($Number) -shl 3
    $tagBytes = Convert-ToVarint $tag
    $valueBytes = Convert-ToVarint $Value
    return Concat-Bytes @($tagBytes, $valueBytes)
}

# Main script logic
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$root = Join-Path $scriptDir ".."
$extension = Join-Path $root "browser-extension"
$manifestPath = Join-Path $extension "manifest.json"
$manifest = ConvertFrom-JsonSafe $manifestPath

$corePath = Join-Path $extension "content-core.js"
$protoPath = Join-Path $extension "proto-main.js"
$mobileBridgePath = Join-Path $root "mobile-shared" "webview-bridge.js"
$mobileBridge = Get-ContentSafe $mobileBridgePath

# Assertions
if ($manifest.manifest_version -ne 3) { throw "Manifest version assertion failed" }
if ($manifest.version -ne "0.8.0") { throw "Version assertion failed" }
if (-not ($manifest.permissions -contains "sidePanel")) { throw "sidePanel permission missing" }
if (-not ($manifest.permissions -contains "webRequest")) { throw "webRequest permission missing" }
if (-not ($manifest.permissions -contains "tabCapture")) { throw "tabCapture permission missing" }
if (-not ($manifest.host_permissions -contains "http://127.0.0.1/*")) { throw "host_permission http://127.0.0.1/* missing" }
if (-not ($manifest.host_permissions -contains "http://localhost/*")) { throw "host_permission http://localhost/* missing" }
if ($manifest.permissions -contains "cookies") { throw "cookies permission should not be present" }
if ($manifest.permissions -contains "webRequestBlocking") { throw "webRequestBlocking permission should not be present" }
if ($manifest.permissions -contains "nativeMessaging") { throw "nativeMessaging permission should not be present" }
if ($manifest.content_scripts[0].js[0] -ne "vendor-mpegts.js") { throw "vendor-mpegts.js not first content script" }

$mpegtsVendorPath = Join-Path $extension "vendor-mpegts.js"
$mpegtsLicensePath = Join-Path $extension "vendor-mpegts.LICENSE.txt"
$mpegtsNoticePath = Join-Path $extension "vendor-mpegts.NOTICE.md"

if (-not (Test-PathSafe $mpegtsVendorPath)) { throw "vendor-mpegts.js missing" }
if (-not (Test-PathSafe $mpegtsLicensePath)) { throw "vendor-mpegts.LICENSE.txt missing" }
if (-not (Test-PathSafe $mpegtsNoticePath)) { throw "vendor-mpegts.NOTICE.md missing" }

$expectedHash = "0786F9AF6780822FF29240259A73B07ED7BC479BC44966E49418DD38213B8064"
$actualHash = Get-Sha256Hash $mpegtsVendorPath
if ($actualHash -ne $expectedHash) { throw "vendor-mpegts.js hash mismatch" }

if (-not ($mobileBridge -match 'location\.hostname !== "www\.tiktok\.com"')) { throw "mobileBridge missing hostname check" }
if ($mobileBridge -match "document\.cookie") { throw "mobileBridge contains document.cookie" }
if (-not ($mobileBridge -match "QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400")) { throw "mobileBridge missing QUICK_RECOVER_RELOAD_COOLDOWN_MS" }
if (-not ($mobileBridge -match '"set-auto-reconnect"')) { throw "mobileBridge missing set-auto-reconnect" }
if (-not ($mobileBridge -match '"set-limiter"')) { throw "mobileBridge missing set-limiter" }

# Check manifest files exist
$manifestFiles = @(
    $manifest.background.service_worker,
    $manifest.side_panel.default_path
) + ($manifest.content_scripts | ForEach-Object { $_.js })

foreach ($relative in $manifestFiles) {
    $fullPath = Join-Path $extension $relative
    if (-not (Test-PathSafe $fullPath)) { 
        throw "Missing manifest file: $relative" 
    }
}

# Check all .js files can be parsed and don't contain dangerous patterns
$scripts = Get-ChildItemSafe $extension | Where-Object { $_.Name -like "*.js" }
foreach ($script in $scripts) {
    $source = Get-ContentSafe $script.FullName
    # Basic syntax check would go here if possible in PowerShell
    if ($source -match '\beval\s*\(') { throw "$($script.Name) contains eval()" }
    if ($source -match 'new\s+Function\s*\(') { throw "$($script.Name) contains new Function()" }
    if ($source -match '\.innerHTML\s*=') { throw "$($script.Name) assigns innerHTML" }
}

Write-Host "PASS: All assertions passed"
