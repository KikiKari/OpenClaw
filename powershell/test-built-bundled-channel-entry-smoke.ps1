#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "839d2a99189a8b130780ad11fcf1d2aeba837afe4a0429ef7edb69253f307f72", "source_sha256": "cd0bfcd0719418f4f0877e7488a8136ca9e8ba296aaaf669b43c7da1dca0f581", "target_language": "powershell"}
# test-built-bundled-channel-entry-smoke.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-built-bundled-channel-entry-smoke.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

#Requires -Version 7.0

$ErrorActionPreference = "Stop"

# Simulate installing process warning filter (no-op in PowerShell)
function Install-ProcessWarningFilter {}

Install-ProcessWarningFilter

if (-not $env:OPENCLAW_DISABLE_BUNDLED_ENTRY_SOURCE_FALLBACK) {
    $env:OPENCLAW_DISABLE_BUNDLED_ENTRY_SOURCE_FALLBACK = "1"
}

function Parse-Args {
    param(
        [string[]]$Arguments
    )
    
    $packageRoot = $env:OPENCLAW_BUNDLED_CHANNEL_SMOKE_ROOT
    $index = 0
    
    while ($index -lt $Arguments.Count) {
        $arg = $Arguments[$index]
        
        if ($arg -eq "--package-root") {
            $packageRoot = $Arguments[$index + 1]
            $index += 2
            continue
        }
        
        if ($arg.StartsWith("--package-root=")) {
            $packageRoot = $arg.Substring("--package-root=".Length)
            $index += 1
            continue
        }
        
        throw "unknown argument: $arg"
    }
    
    if (-not $packageRoot) {
        $scriptPath = $MyInvocation.MyCommand.Path
        $scriptDir = Split-Path $scriptPath -Parent
        $packageRoot = Resolve-Path (Join-Path $scriptDir "..")
    }
    
    return @{
        PackageRoot = $packageRoot
    }
}

function Import-BuiltModule {
    param([string]$AbsolutePath)
    
    return Import-Module $AbsolutePath -Force -PassThru
}

function Read-Json {
    param([string]$Pathname)
    
    return Get-Content $Pathname -Raw | ConvertFrom-Json
}

function ExtensionEntry-ToDistFilename {
    param([string]$Entry)
    
    $result = $Entry -replace "^\.\/", ""
    $result = $result -replace "\.[^\.]+$", ".js"
    return $result
}

function Collect-BundledChannelEntryFiles {
    param([string]$DistExtensionsRoot)
    
    $files = @()
    
    Get-ChildItem $DistExtensionsRoot -Directory | ForEach-Object {
        $extensionRoot = $_.FullName
        $packageJsonPath = Join-Path $extensionRoot "package.json"
        
        if (-not (Test-Path $packageJsonPath)) {
            return
        }
        
        try {
            $packageJson = Read-Json $packageJsonPath
        } catch {
            return
        }
        
        if (-not $packageJson.PSObject.Properties.Name -contains "openclaw" -or 
            -not $packageJson.openclaw.PSObject.Properties.Name -contains "channel") {
            return
        }
        
        $extensionEntries = @("./index.ts")
        if ($packageJson.openclaw.PSObject.Properties.Name -contains "extensions" -and 
            $packageJson.openclaw.extensions -is [array] -and 
            $packageJson.openclaw.extensions.Length -gt 0) {
            $extensionEntries = $packageJson.openclaw.extensions
        }
        
        foreach ($entry in $extensionEntries) {
            if ($entry -isnot [string] -or $entry.Trim().Length -eq 0) {
                continue
            }
            
            $files += @{
                id = $_.Name
                kind = "channel"
                path = Join-Path $extensionRoot (ExtensionEntry-ToDistFilename $entry)
            }
        }
        
        if ($packageJson.openclaw.PSObject.Properties.Name -contains "setupEntry") {
            $setupEntry = $packageJson.openclaw.setupEntry
            if ($setupEntry -is [string] -and $setupEntry.Trim().Length -gt 0) {
                $files += @{
                    id = $_.Name
                    kind = "setup"
                    path = Join-Path $extensionRoot (ExtensionEntry-ToDistFilename $setupEntry)
                }
            }
        }
        
        $channelEntryPath = Join-Path $extensionRoot "channel-entry.js"
        if (Test-Path $channelEntryPath) {
            $files += @{
                id = $_.Name
                kind = "channel"
                path = $channelEntryPath
            }
        }
    }
    
    # Sort the files array
    $sortedFiles = $files | Sort-Object { "$($_.id):$($_.kind):$($_.path)" }
    return $sortedFiles
}

function Assert-SecretContractShape {
    param($secrets, [string]$context)
    
    if (-not $secrets -or $secrets.GetType().Name -ne "PSCustomObject") {
        throw "$context`: missing secrets contract"
    }
    
    if ($secrets.PSObject.Properties.Name -notcontains "collectRuntimeConfigAssignments" -or 
        $secrets.collectRuntimeConfigAssignments.GetType().Name -ne "ScriptBlock") {
        throw "$context`: collectRuntimeConfigAssignments must be a function"
    }
    
    if ($secrets.PSObject.Properties.Name -notcontains "secretTargetRegistryEntries" -or 
        $secrets.secretTargetRegistryEntries -isnot [array]) {
        throw "$context`: secretTargetRegistryEntries must be an array"
    }
}

function Assert-EntryFileExists {
    param($entry)
    
    if (-not (Test-Path $entry.path)) {
        throw "$($entry.id) $($entry.kind) entry missing from packed dist: $($entry.path)"
    }
}

function Smoke-ChannelEntry {
    param($entryFile)
    
    Assert-EntryFileExists $entryFile
    
    $module = Import-BuiltModule $entryFile.path
    $entry = $module
    
    if ($entry.kind -ne "bundled-channel-entry") {
        throw "$($entryFile.id) channel entry kind mismatch"
    }
    
    if ($entry.PSObject.Properties.Name -notcontains "loadChannelPlugin" -or 
        $entry.loadChannelPlugin.GetType().Name -ne "ScriptBlock") {
        throw "$($entryFile.id) channel entry missing loadChannelPlugin"
    }
    
    $plugin = & $entry.loadChannelPlugin
    if (-not $plugin -or $plugin.id -ne $entryFile.id) {
        throw "$($entryFile.id) channel plugin failed to load"
    }
    
    if ($entry.PSObject.Properties.Name -contains "loadChannelSecrets" -and 
        $entry.loadChannelSecrets.GetType().Name -eq "ScriptBlock") {
        $secrets = & $entry.loadChannelSecrets
        Assert-SecretContractShape $secrets "$($entryFile.id) channel entry packaged secrets"
    }
}

function Smoke-SetupEntry {
    param($entryFile)
    
    Assert-EntryFileExists $entryFile
    
    $module = Import-BuiltModule $entryFile.path
    $entry = $module
    
    if ($entry.PSObject.Properties.Name -notcontains "kind" -or 
        $entry.kind -ne "bundled-channel-setup-entry") {
        return $false
    }
    
    if ($entry.kind -ne "bundled-channel-setup-entry") {
        throw "$($entryFile.id) setup entry kind mismatch"
    }
    
    if ($entry.PSObject.Properties.Name -notcontains "loadSetupPlugin" -or 
        $entry.loadSetupPlugin.GetType().Name -ne "ScriptBlock") {
        throw "$($entryFile.id) setup entry missing loadSetupPlugin"
    }
    
    $plugin = & $entry.loadSetupPlugin
    if (-not $plugin -or $plugin.id -ne $entryFile.id) {
        throw "$($entryFile.id) setup plugin failed to load"
    }
    
    if ($entry.PSObject.Properties.Name -contains "loadSetupSecrets" -and 
        $entry.loadSetupSecrets.GetType().Name -eq "ScriptBlock") {
        $secrets = & $entry.loadSetupSecrets
        Assert-SecretContractShape $secrets "$($entryFile.id) setup entry packaged secrets"
    }
    
    return $true
}

$parsedArgs = Parse-Args $args
$packageRoot = $parsedArgs.PackageRoot
$distExtensionsRoot = Join-Path $packageRoot "dist\extensions"

$entryFiles = Collect-BundledChannelEntryFiles $distExtensionsRoot
$channelCount = 0
$setupCount = 0
$legacySetupCount = 0

foreach ($entryFile in $entryFiles) {
    if ($entryFile.kind -eq "channel") {
        Smoke-ChannelEntry $entryFile
        $channelCount++
        continue
    }
    
    if (Smoke-SetupEntry $entryFile) {
        $setupCount++
    } else {
        $legacySetupCount++
    }
}

if ($channelCount -le 0) {
    throw "no bundled channel entries found"
}

Write-Host "[build-smoke] bundled channel entry smoke passed packageRoot=$packageRoot channel=$channelCount setup=$setupCount legacySetup=$legacySetupCount"
