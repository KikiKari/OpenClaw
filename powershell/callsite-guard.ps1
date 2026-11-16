#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "6dab9ee055e057382de0e3ce5e891218f081d7fc5f1b967b698ade5b313ac3ac", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "powershell"}
# callsite-guard.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Import necessary modules
using module './ts-guard-utils.psm1'

function Run-CallsiteGuard {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Params
    )

    $repoRoot = Resolve-RepoRoot $Params.importMetaUrl
    $sourceRoots = Resolve-SourceRoots $repoRoot $Params.sourceRoots
    $files = Collect-TypeScriptFilesFromRoots $sourceRoots @{
        extraTestSuffixes = $Params.extraTestSuffixes
    }
    $violations = @()

    foreach ($filePath in $files) {
        # Convert backslashes to forward slashes for consistent path handling
        $relPath = (Resolve-Path -Relative -Path $filePath -RelativeTo $repoRoot).Replace("\", "/")
        
        if ($Params.skipRelativePath -and (& $Params.skipRelativePath $relPath)) {
            continue
        }
        
        $content = Get-Content -Path $filePath -Encoding UTF8 -Raw
        $callLines = & $Params.findCallLines $content $filePath
        
        foreach ($line in $callLines) {
            $callsite = "${relPath}:${line}"
            if ($Params.allowCallsite -and (& $Params.allowCallsite $callsite)) {
                continue
            }
            $violations += $callsite
        }
    }

    if ($violations.Count -eq 0) {
        return
    }

    Write-Error $Params.header
    $output = $violations
    
    if ($Params.sortViolations -ne $false) {
        $output = $violations | Sort-Object
    }
    
    foreach ($violation in $output) {
        Write-Error "- ${violation}"
    }
    
    if ($Params.footer) {
        Write-Error $Params.footer
    }
    
    exit 1
}
