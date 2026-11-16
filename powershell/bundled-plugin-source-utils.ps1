#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "93211c65981d83568bcf8675afa6d9d13079dc54bcc8aa6ac2d2dbcd3edd3680", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "powershell"}
# bundled-plugin-source-utils.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

function Read-IfExists {
    param(
        [string]$FilePath
    )
    try {
        return Get-Content -Path $FilePath -Encoding UTF8 -Raw
    } catch {
        return $null
    }
}

function Collect-BundledPluginSources {
    param(
        [hashtable]$Params = @{}
    )
    
    $repoRoot = if ($Params.ContainsKey("repoRoot")) { 
        Resolve-Path $Params["repoRoot"] 
    } else { 
        Get-Location 
    }
    
    $extensionsRoot = Join-Path $repoRoot "extensions"
    if (-not (Test-Path $extensionsRoot)) {
        return @()
    }

    $requirePackageJson = $Params.ContainsKey("requirePackageJson") -and $Params["requirePackageJson"] -eq $true
    $entries = @()
    
    $items = Get-ChildItem -Path $extensionsRoot -Directory
    foreach ($dirent in $items) {
        $pluginDir = Join-Path $extensionsRoot $dirent.Name
        $manifestPath = Join-Path $pluginDir "openclaw.plugin.json"
        $packageJsonPath = Join-Path $pluginDir "package.json"
        
        if (-not (Test-Path $manifestPath)) {
            continue
        }
        
        if ($requirePackageJson -and -not (Test-Path $packageJsonPath)) {
            continue
        }

        $entry = @{
            dirName = $dirent.Name
            pluginDir = $pluginDir
            manifestPath = $manifestPath
            manifest = Get-Content -Path $manifestPath -Encoding UTF8 -Raw | ConvertFrom-Json
        }
        
        if (Test-Path $packageJsonPath) {
            $entry.packageJsonPath = $packageJsonPath
            $entry.packageJson = Get-Content -Path $packageJsonPath -Encoding UTF8 -Raw | ConvertFrom-Json
        }
        
        $entries += $entry
    }

    return $entries | Sort-Object { $_.dirName }
}
