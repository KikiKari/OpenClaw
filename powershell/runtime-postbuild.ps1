#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "a4914afd59100663c7360054593ccd75e8b1491bba43c29a744e8bdb40023f44", "source_sha256": "fd0e09df4d2dcc4aafd9784f264f0b9e5a046c02335886978c614026a9f3648c", "target_language": "powershell"}
# runtime-postbuild.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/runtime-postbuild.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Import required modules
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility

# Define paths
$ScriptPath = $MyInvocation.MyCommand.Path
$ROOT = Split-Path -Parent $ScriptPath
$ROOT = Join-Path $ROOT ".."
$ROOT = Resolve-Path $ROOT

# Import functions from other scripts
. (Join-Path $ROOT "copy-bundled-plugin-metadata.ps1")
. (Join-Path $ROOT "copy-plugin-sdk-root-alias.ps1")
. (Join-Path $ROOT "runtime-postbuild-shared.ps1")
. (Join-Path $ROOT "stage-bundled-plugin-runtime-deps.ps1")
. (Join-Path $ROOT "stage-bundled-plugin-runtime.ps1")
. (Join-Path $ROOT "write-official-channel-catalog.ps1")

# Define STATIC_EXTENSION_ASSETS
$STATIC_EXTENSION_ASSETS = @(
  @{
    src = "extensions/acpx/src/runtime-internals/mcp-proxy.mjs"
    dest = "dist/extensions/acpx/mcp-proxy.mjs"
  },
  @{
    src = "extensions/diffs/assets/viewer-runtime.js"
    dest = "dist/extensions/diffs/assets/viewer-runtime.js"
  }
)

function listStaticExtensionAssetOutputs {
  param(
    [array]$assets = $STATIC_EXTENSION_ASSETS
  )
  
  $outputs = @()
  foreach ($asset in $assets) {
    $outputs += $asset.dest -replace "\\", "/"
  }
  return $outputs | Sort-Object
}

function copyStaticExtensionAssets {
  param(
    [string]$rootDir = $ROOT,
    [array]$assets = $STATIC_EXTENSION_ASSETS,
    [scriptblock]$warn = { Write-Warning $_[0] }
  )
  
  foreach ($asset in $assets) {
    $srcPath = Join-Path $rootDir $asset.src
    $destPath = Join-Path $rootDir $asset.dest
    
    if (Test-Path $srcPath) {
      $destDir = Split-Path $destPath -Parent
      if (!(Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force > $null
      }
      Copy-Item -Path $srcPath -Destination $destPath -Force
    } else {
      & $warn "[runtime-postbuild] static asset not found, skipping: $($asset.src)"
    }
  }
}

function writeStableRootRuntimeAliases {
  param(
    [string]$rootDir = $ROOT
  )
  
  $distDir = Join-Path $rootDir "dist"
  if (!(Test-Path $distDir)) {
    return
  }
  
  $entries = Get-ChildItem -Path $distDir -File
  
  foreach ($entry in $entries) {
    $match = $entry.Name -match "(?<base>.+\.(?:runtime|contract))-([A-Za-z0-9_-]+)\.js$"
    if ($match -and $Matches.base) {
      $aliasPath = Join-Path $distDir "$($Matches.base).js"
      $content = "export * from `"./$($entry.Name)`";`n"
      writeTextFileIfChanged $aliasPath $content
    }
  }
}

function runRuntimePostBuild {
  copyPluginSdkRootAlias
  copyBundledPluginMetadata
  writeOfficialChannelCatalog
  stageBundledPluginRuntimeDeps
  stageBundledPluginRuntime
  writeStableRootRuntimeAliases
  copyStaticExtensionAssets
}

# Main execution
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
  runRuntimePostBuild
}
