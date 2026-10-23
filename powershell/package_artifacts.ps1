#!/usr/bin/env pwsh
# package_artifacts.py — portiert nach powershell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    
    [string]$AndroidApk,
    
    [string]$AndroidSource = "$PSScriptRoot/../../mobile/android",
    
    [string]$IosSource = "$PSScriptRoot/../../mobile/ios",
    
    [string]$NativeSharedSource = "$PSScriptRoot/../../mobile/shared"
)

$ErrorActionPreference = "Stop"

# Define constants
$ROOT = Resolve-Path "$PSScriptRoot/../.."
$PROJECT_ROOT = Resolve-Path "$ROOT/.."
$EXCLUDED_PARTS = @("__pycache__", ".gradle", ".kotlin", ".cxx", "build", "DerivedData", "xcuserdata", "Pods")

function Add-Tree {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$Source,
        [string]$Prefix = ""
    )
    
    $sourcePath = Get-Item $Source
    $files = Get-ChildItem -Path $Source -Recurse -File | Sort-Object FullName
    
    foreach ($file in $files) {
        # Check if any excluded part is in the path
        $excludeFile = $false
        foreach ($part in $file.FullName.Split([System.IO.Path]::DirectorySeparatorChar)) {
            if ($EXCLUDED_PARTS -contains $part) {
                $excludeFile = $true
                break
            }
        }
        
        # Also exclude by extension
        if ($file.Extension -in @(".pyc", ".aar")) {
            $excludeFile = $true
        }
        
        if ($excludeFile) {
            continue
        }
        
        $relativePath = Resolve-Path -Relative -Path $file.FullName -RelativeTo $sourcePath.FullName
        if ($relativePath.StartsWith(".\")) {
            $relativePath = $relativePath.Substring(2)
        }
        
        $archivePath = if ($Prefix) {
            Join-Path $Prefix $relativePath -Resolve
        } else {
            $relativePath
        }
        
        # Normalize path separators to forward slashes for zip
        $archivePath = $archivePath.Replace("\", "/")
        
        # Create entry with fixed timestamp
        $entry = New-Object System.IO.Compression.ZipArchiveEntry($Archive, $archivePath)
        $entry.LastWriteTime = [DateTime]::new(1980, 1, 1, 0, 0, 0)
        
        # Set permissions based on filename
        if ($file.Name -eq "gradlew") {
            # Executable permission (0o100755 << 16)
            $permissions = 0x81ED0000
        } else {
            # Regular file permission (0o100644 << 16)
            $permissions = 0x81A40000
        }
        
        # Read file content
        $content = [System.IO.File]::ReadAllBytes($file.FullName)
        
        # Add to archive
        $zipEntry = $Archive.CreateEntry($archivePath, [System.IO.Compression.CompressionLevel]::Optimal)
        $zipEntry.LastWriteTime = [DateTime]::new(1980, 1, 1, 0, 0, 0)
        
        # Set external attributes for permissions
        $zipEntry.GetType().GetField("_versionMadeBy", [Reflection.BindingFlags]"NonPublic,Instance").SetValue($zipEntry, $permissions)
        
        $stream = $zipEntry.Open()
        $stream.Write($content, 0, $content.Length)
        $stream.Close()
    }
}

# Load manifest to get version
$manifestPath = Join-Path $ROOT "browser-extension" "manifest.json"
$manifest = Get-Content $manifestPath | ConvertFrom-Json
$version = $manifest.version

# Ensure output directory exists
$null = New-Item -ItemType Directory -Path $OutputDir -Force
$outputDirResolved = Resolve-Path $OutputDir

# Define output paths
$extensionZip = Join-Path $OutputDir "tiktok-live-companion-extension-$version.zip"
$pluginZip = Join-Path $OutputDir "tiktok-live-companion-plugin-$version.zip"
$serviceZip = Join-Path $OutputDir "tiktok-live-companion-service-$version.zip"
$iosSourceZip = Join-Path $OutputDir "tiktok-live-companion-ios-$version-source.zip"
$androidSourceZip = Join-Path $OutputDir "tiktok-live-companion-android-$version-source.zip"
$androidApk = Join-Path $OutputDir "tiktok-live-companion-android-$version.apk"
$extensionDir = Join-Path $OutputDir "tiktok-live-companion-extension-$version"
$checksumFile = Join-Path $OutputDir "tiktok-live-companion-$version-SHA256.txt"

# Validate extension directory location
$resolvedExtensionDir = Resolve-Path $extensionDir -ErrorAction SilentlyContinue
if ($resolvedExtensionDir -and (Split-Path $resolvedExtensionDir -Parent) -ne $outputDirResolved) {
    throw "Refusing to package outside the requested output directory"
}

# Clean up existing extension directory
if (Test-Path $extensionDir) {
    Remove-Item $extensionDir -Recurse -Force
}

# Copy browser extension and companion service
Copy-Item -Path "$ROOT/browser-extension" -Destination $extensionDir -Recurse
Copy-Item -Path "$ROOT/companion-service" -Destination "$extensionDir/companion-service" -Recurse

# Create Windows batch file
$batchContent = '@echo off`r`ncall "%~dp0companion-service\Sprachdienst-reparieren.cmd"`r`n'
Set-Content -Path "$extensionDir/Sprachdienst-reparieren.cmd" -Value $batchContent -Encoding UTF8

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
}
$packageJson | ConvertTo-Json -Depth 10 | Out-File "$extensionDir/package.json" -Encoding UTF8

# Create extension zip
[System.IO.Compression.ZipFile]::CreateFromDirectory($extensionDir, $extensionZip)

# Create plugin zip
$tempPluginDir = Join-Path $env:TEMP "temp-plugin-$([Guid]::NewGuid())"
$null = New-Item -ItemType Directory -Path $tempPluginDir
try {
    Copy-Item -Path "$ROOT/*" -Destination $tempPluginDir -Recurse -Exclude @("browser-extension", "companion-service")
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempPluginDir, $pluginZip)
} finally {
    if (Test-Path $tempPluginDir) {
        Remove-Item $tempPluginDir -Recurse -Force
    }
}

# Create service zip
[System.IO.Compression.ZipFile]::CreateFromDirectory("$ROOT/companion-service", $serviceZip)

# Validate source directories
$iosSourceResolved = Resolve-Path $IosSource
$androidSourceResolved = Resolve-Path $AndroidSource
if (-not (Test-Path $iosSourceResolved -PathType Container) -or 
    -not (Test-Path $androidSourceResolved -PathType Container)) {
    throw "--ios-source and --android-source must point to existing source directories"
}

# Validate shared native source
$nativeLimiterHeader = Join-Path $NativeSharedSource "native" "tlc_peak_limiter.h"
if (-not (Test-Path $nativeLimiterHeader -PathType Leaf)) {
    throw "Shared native limiter source is required for both mobile source packages"
}

# Create iOS source zip
$zipStream = [System.IO.File]::Open($iosSourceZip, [System.IO.FileMode]::Create)
$archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    Add-Tree -Archive $archive -Source $iosSourceResolved -Prefix "TikTokLiveCompanion-iOS"
    Add-Tree -Archive $archive -Source $NativeSharedSource -Prefix "shared"
} finally {
    $archive.Dispose()
    $zipStream.Close()
}

# Create Android source zip
$zipStream = [System.IO.File]::Open($androidSourceZip, [System.IO.FileMode]::Create)
$archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    Add-Tree -Archive $archive -Source $androidSourceResolved -Prefix "TikTokLiveCompanion-Android"
    Add-Tree -Archive $archive -Source $NativeSharedSource -Prefix "shared"
} finally {
    $archive.Dispose()
    $zipStream.Close()
}

# Handle Android APK if provided
if ($AndroidApk) {
    $sourceApk = Resolve-Path $AndroidApk
    if (-not (Test-Path $sourceApk -PathType Leaf) -or 
        [System.IO.Path]::GetExtension($sourceApk) -ne ".apk") {
        throw "--android-apk must point to an existing APK"
    }
    
    $targetApk = Resolve-Path $androidApk -ErrorAction SilentlyContinue
    if ($sourceApk -ne $targetApk) {
        Copy-Item $sourceApk $androidApk
    }
}

# Build list of artifacts
$artifacts = @($extensionZip, $pluginZip, $serviceZip, $iosSourceZip, $androidSourceZip)
if (Test-Path $androidApk) {
    $artifacts += $androidApk
}

# Generate checksums
$checksums = @()
foreach ($artifact in $artifacts) {
    $hash = Get-FileHash $artifact -Algorithm SHA256
    $checksums += "{0}  {1}" -f $hash.Hash, (Split-Path $artifact -Leaf)
}
Set-Content -Path $checksumFile -Value ($checksums -join "`n") -Encoding UTF8

# Output result JSON
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

ConvertTo-Json $result -Depth 10
