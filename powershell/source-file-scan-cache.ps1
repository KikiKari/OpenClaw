#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "00edfbec6b7a23b41774e779b9acaf07b9fce8cdfd78ec379a321efd641c171d", "source_sha256": "44f04cb59342c4d1b0965cd87195e903f79fc80231b0f537dba10313bc29aa00", "target_language": "powershell"}
# source-file-scan-cache.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/source-file-scan-cache.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

$scanCache = @{}

function Normalize-RepoPath {
    param(
        [string]$repoRoot,
        [string]$filePath
    )
    $relativePath = Resolve-Path -Path $filePath -RelativeBasePath $repoRoot
    # Entferne das führende ".\" von Resolve-Path
    if ($relativePath.StartsWith(".\")) {
        $relativePath = $relativePath.Substring(2)
    }
    return $relativePath -replace '\\', '/'
}

function Walk-Files {
    param(
        [hashtable]$params,
        [string]$rootDir
    )
    
    $out = @()
    $entries = @()
    
    try {
        $items = Get-ChildItem -Path $rootDir -Force
        foreach ($item in $items) {
            $entries += @{
                Name = $item.Name
                IsDirectory = $item.PSIsContainer
                FullName = $item.FullName
            }
        }
    } catch {
        if ($_.Exception.GetType().Name -eq 'DirectoryNotFoundException') {
            return $out
        }
        throw $_
    }
    
    $entries = $entries | Sort-Object Name
    
    foreach ($entry in $entries) {
        $entryPath = Join-Path -Path $rootDir -ChildPath $entry.Name
        
        if ($entry.IsDirectory) {
            if (-not $params.ignoredDirNames.Contains($entry.Name)) {
                $subResults = Walk-Files -params $params -rootDir $entryPath
                $out += $subResults
            }
            continue
        }
        
        $extension = [System.IO.Path]::GetExtension($entry.Name)
        if ((-not $entry.IsDirectory) -and $params.scanExtensions.Contains($extension)) {
            $out += $entry.FullName
        }
    }
    
    return $out
}

function Collect-SourceFileContents {
    param(
        [hashtable]$params
    )
    
    # Erstelle Cache-Key
    $sortedScanExtensions = $params.scanExtensions | Sort-Object
    $sortedIgnoredDirNames = $params.ignoredDirNames | Sort-Object
    
    $cacheKeyObj = @{
        repoRoot = $params.repoRoot
        scanRoots = $params.scanRoots | Sort-Object
        scanExtensions = $sortedScanExtensions
        ignoredDirNames = $sortedIgnoredDirNames
    }
    
    $cacheKey = $cacheKeyObj | ConvertTo-Json -Depth 10
    
    $cached = $scanCache[$cacheKey]
    if ($cached) {
        return $cached
    }
    
    # Definiere das Promise-ähnliche Verhalten mit einem Skriptblock
    $scriptBlock = {
        param($params, $cacheKey)
        
        $allFiles = @()
        
        foreach ($root in $params.scanRoots) {
            $fullPath = Join-Path -Path $params.repoRoot -ChildPath $root
            $files = Walk-Files -params $params -rootDir $fullPath
            $allFiles += $files
        }
        
        # Entferne Duplikate und sortiere
        $uniqueFiles = $allFiles | Select-Object -Unique
        $sortedFiles = $uniqueFiles | Sort-Object { 
            Normalize-RepoPath -repoRoot $params.repoRoot -filePath $_ 
        }
        
        $result = @()
        foreach ($filePath in $sortedFiles) {
            try {
                $content = Get-Content -Path $filePath -Encoding UTF8 -Raw
                # Entferne mögliche zusätzliche Zeilenumbrüche am Ende
                if ($content -match '\r\n$') {
                    $content = $content.TrimEnd("\r\n")
                } elseif ($content -match '\n$') {
                    $content = $content.TrimEnd("`n")
                }
                
                $result += @{
                    filePath = $filePath
                    relativeFile = Normalize-RepoPath -repoRoot $params.repoRoot -filePath $filePath
                    content = $content
                }
            } catch {
                Write-Error "Fehler beim Lesen der Datei '$filePath': $_"
                throw $_
            }
        }
        
        return $result
    }
    
    try {
        $result = & $scriptBlock $params $cacheKey
        $scanCache[$cacheKey] = $result
        return $result
    } catch {
        if ($scanCache.ContainsKey($cacheKey)) {
            $scanCache.Remove($cacheKey)
        }
        throw $_
    }
}

# Exportieren der Funktion für externe Nutzung
Export-ModuleMember -Function Collect-SourceFileContents
