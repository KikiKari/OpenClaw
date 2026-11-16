#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "6ea0d412e99d4b96fdb97c3f44603d3d6facb0a6e06d36426e25794b84f6ac79", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "powershell"}
# changed-extensions.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$repoRoot = Resolve-Path "$PSScriptRoot\..\.."

# Import bundled plugin paths
. "$PSScriptRoot\bundled-plugin-paths.ps1"

function Invoke-GitCommand {
    param(
        [string[]]$Arguments,
        [hashtable]$Options = @{}
    )
    
    $defaultOptions = @{
        WorkingDirectory = $repoRoot
        NoNewWindow = $true
        PassThru = $false
        Wait = $true
    }
    
    $startParams = $defaultOptions + $Options
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "git"
    $psi.Arguments = ($Arguments | ForEach-Object { "`"$_`"" }) -join " "
    $psi.WorkingDirectory = $startParams.WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    
    $output = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    
    if ($process.ExitCode -ne 0) {
        $errorOutput = $process.StandardError.ReadToEnd()
        throw "Git command failed with exit code $($process.ExitCode): $errorOutput"
    }
    
    return $output
}

function Convert-NormalizeRelative {
    param([string]$InputPath)
    return $InputPath -replace "\\", "/"
}

function Test-GitCommit {
    param([string]$Reference)
    
    if (-not $Reference -or $Reference -match "^0+$") {
        return $false
    }
    
    try {
        $null = Invoke-GitCommand -Arguments @("rev-parse", "--verify", "$Reference^{commit}")
        return $true
    } catch {
        return $false
    }
}

function Resolve-ChangedPathsBase {
    param(
        [hashtable]$Parameters = @{}
    )
    
    $base = $Parameters.base
    $head = if ($Parameters.head) { $Parameters.head } else { "HEAD" }
    $fallbackBaseRef = $Parameters.fallbackBaseRef
    
    if (Test-GitCommit -Reference $base) {
        return $base
    }
    
    if ($fallbackBaseRef) {
        $remoteBaseRef = if ($fallbackBaseRef.StartsWith("origin/")) { 
            $fallbackBaseRef 
        } else { 
            "origin/$fallbackBaseRef" 
        }
        
        if (Test-GitCommit -Reference $remoteBaseRef) {
            try {
                $mergeBase = (Invoke-GitCommand -Arguments @("merge-base", $remoteBaseRef, $head)).Trim()
                if (Test-GitCommit -Reference $mergeBase) {
                    return $mergeBase
                }
            } catch {
                # Continue to next check
            }
        }
    }
    
    if (-not $base) {
        throw "A git base revision is required to list changed extensions."
    }
    
    throw "Git base revision is unavailable locally: $base"
}

function Get-ChangedPaths {
    param(
        [string]$Base,
        [string]$Head = "HEAD"
    )
    
    if (-not $Base) {
        throw "A git base revision is required to list changed extensions."
    }
    
    $result = Invoke-GitCommand -Arguments @("diff", "--name-only", $Base, $Head)
    return ($result -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

function Test-ExtensionPackage {
    param([string]$ExtensionId)
    
    $packagePath = Join-Path $repoRoot $BUNDLED_PLUGIN_ROOT_DIR $ExtensionId "package.json"
    return Test-Path $packagePath
}

function Get-AvailableExtensionIds {
    $extensionsDir = Join-Path $repoRoot $BUNDLED_PLUGIN_ROOT_DIR
    if (-not (Test-Path $extensionsDir)) {
        return @()
    }
    
    $extensionDirs = Get-ChildItem -Path $extensionsDir -Directory | ForEach-Object { $_.Name }
    $validExtensions = $extensionDirs | Where-Object { Test-ExtensionPackage -ExtensionId $_ }
    return $validExtensions | Sort-Object
}

function Find-ChangedExtensionIds {
    param([string[]]$ChangedPaths)
    
    $extensionIds = @{}
    
    foreach ($rawPath in $ChangedPaths) {
        $relativePath = Convert-NormalizeRelative -InputPath ($rawPath.Trim())
        if (-not $relativePath) {
            continue
        }
        
        # Match bundled plugin paths
        $escapedPrefix = $BUNDLED_PLUGIN_PATH_PREFIX -replace "/", "\/"
        if ($relativePath -match "^$escapedPrefix([^/]+)(?:/|`$)") {
            $extensionId = $matches[1]
            if (Test-ExtensionPackage -ExtensionId $extensionId) {
                $extensionIds[$extensionId] = $true
            }
            continue
        }
        
        # Match core paths
        if ($relativePath -match "^src/([^/]+)(?:/|`$)") {
            $coreMatch = $matches[1]
            if (Test-ExtensionPackage -ExtensionId $coreMatch) {
                $extensionIds[$coreMatch] = $true
            }
        }
    }
    
    return ($extensionIds.Keys | Sort-Object)
}

function Get-ChangedExtensionIds {
    param(
        [hashtable]$Parameters = @{}
    )
    
    $head = if ($Parameters.head) { $Parameters.head } else { "HEAD" }
    $unavailableBaseBehavior = if ($Parameters.unavailableBaseBehavior) { $Parameters.unavailableBaseBehavior } else { "error" }
    
    try {
        $base = Resolve-ChangedPathsBase -Parameters $Parameters
        $changedPaths = Get-ChangedPaths -Base $base -Head $head
        return Find-ChangedExtensionIds -ChangedPaths $changedPaths
    } catch {
        if ($unavailableBaseBehavior -eq "all") {
            return Get-AvailableExtensionIds
        }
        if ($unavailableBaseBehavior -eq "empty") {
            return @()
        }
        throw $_
    }
}
