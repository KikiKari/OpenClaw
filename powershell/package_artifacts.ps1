#!/usr/bin/env pwsh
# package_artifacts.py — portiert nach powershell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,

    [string]$AndroidApk,

    [string]$AndroidSource = "$PROJECT_ROOT/mobile/android",

    [string]$IosSource = "$PROJECT_ROOT/mobile/ios",

    [string]$NativeSharedSource = "$PROJECT_ROOT/mobile/shared"
)

$ErrorActionPreference = "Stop"

# Define constants
$ROOT = Split-Path $PSScriptRoot -Parent
$PROJECT_ROOT = Split-Path $ROOT -Parent
$EXCLUDED_PARTS = @("__pycache__", ".gradle", ".kotlin", ".cxx", "build", "DerivedData", "xcuserdata", "Pods")

function Add-Tree {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$Source,
        [string]$Prefix = ""
    )

    Get-ChildItem -Path $Source -Recurse -File | ForEach-Object {
        $relativePath = Resolve-Path $_.FullName -Relative:$true
        $relativePath = $relativePath -replace "^\.\\", ""

        # Check if any excluded part is in the path
        $exclude = $false
        foreach ($part in $relativePath.Split('\')) {
            if ($EXCLUDED_PARTS -contains $part) {
                $exclude = $true
                break
            }
        }

        # Skip if excluded or has .pyc/.aar extension
        if ($exclude -or $_.Extension -eq ".pyc" -or $_.Extension -eq ".aar") {
            return
        }

        $archivePath = Join-Path $Prefix $relativePath -Resolve
        $archivePath = $archivePath -replace '\\', '/'

        $entry = $Archive.CreateEntry($archivePath, [System.IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        [System.IO.File]::Copy($_.FullName, $entryStream.BaseStream, $true)
        $entryStream.Close()
    }
}

# Parse arguments and resolve paths
$outputDir = Resolve-Path $OutputDir -ErrorAction SilentlyContinue
if (-not $outputDir) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $outputDir = Resolve-Path $OutputDir
}

# Read manifest and get version
$manifestPath = Join-Path $ROOT "browser-extension" "manifest.json"
$manifest = Get-Content $manifestPath | ConvertFrom-Json
$version = $manifest.version

# Define output file paths
$extensionZip = Join-Path $outputDir "tiktok-live-companion-extension-$version.zip"
$pluginZip = Join-Path $outputDir "tiktok-live-companion-plugin-$version.zip"
$serviceZip = Join-Path $outputDir "tiktok-live-companion-service-$version.zip"
$iosSourceZip = Join-Path $outputDir "tiktok-live-companion-ios-$version-source.zip"
$androidSourceZip = Join-Path $outputDir "tiktok-live-companion-android-$version-source.zip"
$androidApk = Join-Path $outputDir "tiktok-live-companion-android-$version.apk"
$extensionDir = Join-Path $outputDir "tiktok-live-companion-extension-$version"
$checksumFile = Join-Path $outputDir "tiktok-live-companion-$version-SHA256.txt"

# Validate extension directory location
$resolvedExtensionDir = Resolve-Path $extensionDir -ErrorAction SilentlyContinue
if ($resolvedExtensionDir.Parent -ne $outputDir) {
    throw "Refusing to package outside the requested output directory"
}

# Remove existing extension directory if it exists
if (Test-Path $extensionDir) {
    Remove-Item $extensionDir -Recurse -Force
}

# Copy browser-extension and companion-service directories
Copy-Item (Join-Path $ROOT "browser-extension") $extensionDir -Recurse
Copy-Item (Join-Path $ROOT "companion-service") (Join-Path $extensionDir "companion-service") -Recurse

# Create Windows batch script
$batchScriptContent = '@echo off`r`ncall "%~dp0companion-service\Sprachdienst-reparieren.cmd"`r`n'
Set-Content (Join-Path $extensionDir "Sprachdienst-reparieren.cmd") $batchScriptContent -Encoding UTF8

# Create package.json content
$packageJson = @{
    name = "tiktok-live-companion-extension-package"
    private = $true
    version = $version
    scripts = @{
        setup = "npm --prefix companion-service run setup --"
        start = "npm --prefix companion-service start"
        test = "npm --prefix companion-service test"
    }
} | ConvertTo-Json -Depth 10
Set-Content (Join-Path $extensionDir "package.json") "$packageJson`n" -Encoding UTF8

# Create extension zip
[System.IO.Compression.ZipFile]::CreateFromDirectory($extensionDir, $extensionZip)

# Create plugin zip
$tempPluginDir = Join-Path ([System.IO.Path]::GetTempPath()) "temp_plugin"
Remove-Item $tempPluginDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tempPluginDir | Out-Null
Copy-Item "$ROOT/*" $tempPluginDir -Recurse -Exclude @("browser-extension", "companion-service")
$pluginZipTemp = Join-Path ([System.IO.Path]::GetTempPath()) "plugin.zip"
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempPluginDir, $pluginZipTemp)
Move-Item $pluginZipTemp $pluginZip -Force
Remove-Item $tempPluginDir -Recurse -Force

# Create service zip
$serviceDir = Join-Path $ROOT "companion-service"
[System.IO.Compression.ZipFile]::CreateFromDirectory($serviceDir, $serviceZip)

# Resolve source directories
$iosSourceResolved = Resolve-Path $IosSource -ErrorAction Stop
$androidSourceResolved = Resolve-Path $AndroidSource -ErrorAction Stop
$nativeSharedResolved = Resolve-Path $NativeSharedSource -ErrorAction Stop

# Validate source directories
if (-not (Test-Path $iosSourceResolved -PathType Container)) {
    throw "--ios-source must point to an existing source directory"
}
if (-not (Test-Path $androidSourceResolved -PathType Container)) {
    throw "--android-source must point to an existing source directory"
}
if (-not (Test-Path (Join-Path $nativeSharedResolved "native" "tlc_peak_limiter.h") -PathType Leaf)) {
    throw "Shared native limiter source is required for both mobile source packages"
}

# Create iOS source zip
$iosTempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ios_temp"
Remove-Item $iosTempDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $iosTempDir | Out-Null
Copy-Item "$iosSourceResolved/*" (Join-Path $iosTempDir "TikTokLiveCompanion-iOS") -Recurse
Copy-Item "$nativeSharedResolved/*" (Join-Path $iosTempDir "shared") -Recurse
$iosZipTemp = Join-Path ([System.IO.Path]::GetTempPath()) "ios.zip"
[System.IO.Compression.ZipFile]::CreateFromDirectory($iosTempDir, $iosZipTemp)
Move-Item $iosZipTemp $iosSourceZip -Force
Remove-Item $iosTempDir -Recurse -Force

# Create Android source zip
$androidTempDir = Join-Path ([System.IO.Path]::GetTempPath()) "android_temp"
Remove-Item $androidTempDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $androidTempDir | Out-Null
Copy-Item "$androidSourceResolved/*" (Join-Path $androidTempDir "TikTokLiveCompanion-Android") -Recurse
Copy-Item "$nativeSharedResolved/*" (Join-Path $androidTempDir "shared") -Recurse
$androidZipTemp = Join-Path ([System.IO.Path]::GetTempPath()) "android.zip"
[System.IO.Compression.ZipFile]::CreateFromDirectory($androidTempDir, $androidZipTemp)
Move-Item $androidZipTemp $androidSourceZip -Force
Remove-Item $androidTempDir -Recurse -Force

# Handle Android APK
if ($AndroidApk) {
    $sourceApk = Resolve-Path $AndroidApk -ErrorAction Stop
    if ((Get-Item $sourceApk).Extension.ToLower() -ne ".apk") {
        throw "--android-apk must point to an existing APK"
    }
    if ($sourceApk -ne (Resolve-Path $androidApk -ErrorAction SilentlyContinue)) {
        Copy-Item $sourceApk $androidApk -Force
    }
}

# Create list of artifacts
$artifacts = @($extensionZip, $pluginZip, $serviceZip, $iosSourceZip, $androidSourceZip)
if (Test-Path $androidApk) {
    $artifacts += $androidApk
}

# Generate SHA256 checksums
$checksums = @()
foreach ($artifact in $artifacts) {
    $hash = Get-FileHash $artifact -Algorithm SHA256
    $checksums += "$($hash.Hash)  $(Split-Path $artifact -Leaf)"
}
Set-Content $checksumFile ($checksums -join "`n") -Encoding UTF8

# Output JSON result
$result = @{
    extension_dir = $extensionDir
    extension_zip = $extensionZip
    plugin_zip = $pluginZip
    service_zip = $serviceZip
    ios_source_zip = $iosSourceZip
    android_source_zip = $androidSourceZip
    android_apk = if (Test-Path $androidApk) { $androidApk } else { $null }
    checksum_file = $checksumFile
    version = $version
}
$result | ConvertTo-Json -EscapeHandling EscapeNonAscii
