#!/usr/bin/env pwsh
# package_artifacts.py — portiert nach powershell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,

    [string]$AndroidApk,

    [string]$AndroidSource = "$PROJECT_ROOT/mobile/android",

    [string]$IosSource = "$PROJECT_ROOT/mobile/ios"
)

$ErrorActionPreference = "Stop"

# Define constants
$ROOT = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$PROJECT_ROOT = Split-Path $ROOT -Parent
$EXCLUDED_PARTS = @("__pycache__", ".gradle", ".kotlin", "build", "DerivedData", "xcuserdata")

function Add-Tree {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$Source,
        [string]$Prefix = ""
    )

    $sourcePath = Resolve-Path $Source
    $items = Get-ChildItem -Path $sourcePath -Recurse -File | Sort-Object FullName

    foreach ($item in $items) {
        $relativePath = Resolve-Path $item.FullName -Relative:$true -RelativeTo $sourcePath
        $shouldExclude = $false

        # Check if any part of the path is in excluded parts
        $pathParts = $item.FullName -split '[\\/]'
        foreach ($part in $pathParts) {
            if ($EXCLUDED_PARTS -contains $part) {
                $shouldExclude = $true
                break
            }
        }

        # Check file extensions
        if ($item.Extension -eq ".pyc" -or $item.Extension -eq ".aar") {
            $shouldExclude = $true
        }

        if ($shouldExclude) {
            continue
        }

        $archivePath = Join-Path $Prefix $relativePath
        $archivePath = $archivePath -replace '\\', '/'

        # Create ZipEntry with fixed timestamp for reproducibility
        $entry = New-Object System.IO.Compression.ZipArchiveEntry($Archive, $archivePath)
        $entry.LastWriteTime = [datetime]"1980-01-01T00:00:00"
        
        # Write file content to zip
        $destStream = $entry.Open()
        $srcStream = [System.IO.File]::OpenRead($item.FullName)
        $srcStream.CopyTo($destStream)
        $srcStream.Close()
        $destStream.Close()
    }
}

# Create output directory
$null = New-Item -ItemType Directory -Path $OutputDir -Force

# Resolve paths
$outputDirResolved = Resolve-Path $OutputDir
$manifestPath = Join-Path $ROOT "browser-extension" "manifest.json"
$manifest = Get-Content $manifestPath | ConvertFrom-Json
$version = $manifest.version

$extensionZip = Join-Path $OutputDir "tiktok-live-companion-extension-$version.zip"
$pluginZip = Join-Path $OutputDir "tiktok-live-companion-plugin-$version.zip"
$serviceZip = Join-Path $OutputDir "tiktok-live-companion-service-$version.zip"
$iosSourceZip = Join-Path $OutputDir "tiktok-live-companion-ios-$version-source.zip"
$androidSourceZip = Join-Path $OutputDir "tiktok-live-companion-android-$version-source.zip"
$androidApk = Join-Path $OutputDir "tiktok-live-companion-android-$version.apk"
$extensionDir = Join-Path $OutputDir "tiktok-live-companion-extension-$version"
$checksumFile = Join-Path $OutputDir "tiktok-live-companion-$version-SHA256.txt"

$resolvedExtensionDir = Resolve-Path $extensionDir -ErrorAction SilentlyContinue
if ($resolvedExtensionDir -and (Split-Path $resolvedExtensionDir.Parent.Path -Leaf) -ne (Split-Path $outputDirResolved -Leaf)) {
    throw "Refusing to package outside the requested output directory"
}

if (Test-Path $extensionDir) {
    Remove-Item $extensionDir -Recurse -Force
}

# Copy browser extension
Copy-Item (Join-Path $ROOT "browser-extension") $extensionDir -Recurse

# Copy companion service
$serviceDest = Join-Path $extensionDir "companion-service"
Copy-Item (Join-Path $ROOT "companion-service") $serviceDest -Recurse

# Create batch file
$batchFilePath = Join-Path $extensionDir "Sprachdienst-reparieren.cmd"
Set-Content $batchFilePath '@echo off
call "%~dp0companion-service\Sprachdienst-reparieren.cmd"
'

# Create package.json
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
Set-Content (Join-Path $extensionDir "package.json") $packageJson

# Load .NET assemblies for ZIP compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

# Package extension zip
$archive = [System.IO.Compression.ZipFile]::Open($extensionZip, "Create")
Add-Tree -Archive $archive -Source $extensionDir
$archive.Dispose()

# Package plugin zip
$archive = [System.IO.Compression.ZipFile]::Open($pluginZip, "Create")
Add-Tree -Archive $archive -Source $ROOT -Prefix "tiktok-live-companion"
$archive.Dispose()

# Package service zip
$archive = [System.IO.Compression.ZipFile]::Open($serviceZip, "Create")
Add-Tree -Archive $archive -Source (Join-Path $ROOT "companion-service")
$archive.Dispose()

# Resolve source paths
$iosSourceResolved = Resolve-Path $IosSource
$androidSourceResolved = Resolve-Path $AndroidSource

if (-not (Test-Path $iosSourceResolved -PathType Container) -or -not (Test-Path $androidSourceResolved -PathType Container)) {
    throw "--ios-source and --android-source must point to existing source directories"
}

# Package iOS source zip
$archive = [System.IO.Compression.ZipFile]::Open($iosSourceZip, "Create")
Add-Tree -Archive $archive -Source $iosSourceResolved -Prefix "TikTokLiveCompanion-iOS"
$archive.Dispose()

# Package Android source zip
$archive = [System.IO.Compression.ZipFile]::Open($androidSourceZip, "Create")
Add-Tree -Archive $archive -Source $androidSourceResolved -Prefix "TikTokLiveCompanion-Android"
$archive.Dispose()

# Handle Android APK if provided
if ($AndroidApk) {
    $sourceApk = Resolve-Path $AndroidApk
    if (-not (Test-Path $sourceApk -PathType Leaf) -or [System.IO.Path]::GetExtension($sourceApk) -ne ".apk") {
        throw "--android-apk must point to an existing APK"
    }
    
    if ((Resolve-Path $sourceApk) -ne (Resolve-Path $androidApk)) {
        Copy-Item $sourceApk $androidApk
    }
}

# Calculate checksums
$artifacts = @($extensionZip, $pluginZip, $serviceZip, $iosSourceZip, $androidSourceZip)
if (Test-Path $androidApk) {
    $artifacts += $androidApk
}

$checksums = @()
foreach ($artifact in $artifacts) {
    $fileBytes = [System.IO.File]::ReadAllBytes($artifact)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($fileBytes)
    $hexHash = -join ($hash | ForEach-Object { "{0:x2}" -f $_ })
    $fileName = Split-Path $artifact -Leaf
    $checksums += "$hexHash  $fileName"
}

Set-Content $checksumFile ($checksums -join "`n") -Encoding UTF8

# Prepare result object
$result = @{
    extension_dir = (Resolve-Path $extensionDir).Path
    extension_zip = (Resolve-Path $extensionZip).Path
    plugin_zip = (Resolve-Path $pluginZip).Path
    service_zip = (Resolve-Path $serviceZip).Path
    ios_source_zip = (Resolve-Path $iosSourceZip).Path
    android_source_zip = (Resolve-Path $androidSourceZip).Path
    android_apk = if (Test-Path $androidApk) { (Resolve-Path $androidApk).Path } else { $null }
    checksum_file = (Resolve-Path $checksumFile).Path
    version = $version
}

# Output result as JSON
ConvertTo-Json $result -EnumsAsStrings
