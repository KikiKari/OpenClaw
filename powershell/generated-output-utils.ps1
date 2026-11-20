#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "633a9c02fbd26d4bdfb6a7a728a6e548bf5a579a2ce4c7a31512eba4c349e8a1", "source_sha256": "3c225928c07272d97d9f90c9c2134a117467308ab5be4a60ac9e89701f38b3e9", "target_language": "powershell"}
# generated-output-utils.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/generated-output-utils.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

function Write-GeneratedOutput {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter(Mandatory)]
        [string]$Next,
        
        [switch]$Check
    )
    
    $resolvedOutputPath = Join-Path $RepoRoot $OutputPath
    $current = if (Test-Path $resolvedOutputPath) {
        Get-Content -Path $resolvedOutputPath -Raw
    }
    
    $changed = $current -ne $Next
    
    if ($Check) {
        return @{
            Changed = $changed
            Wrote = $false
            OutputPath = $resolvedOutputPath
        }
    }
    
    $wrote = $false
    if ($changed) {
        $Next | Out-File -FilePath $resolvedOutputPath -Encoding UTF8
        $wrote = $true
    }
    
    return @{
        Changed = $changed
        Wrote = $wrote
        OutputPath = $resolvedOutputPath
    }
}

function Report-GeneratedOutputCli {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Run,
        
        [Parameter(Mandatory)]
        [string]$Label,
        
        [Parameter(Mandatory)]
        [string]$ImportMetaUrl
    )
    
    $currentScriptUrl = [System.IO.Path]::GetFullPath($MyInvocation.ScriptName)
    $currentScriptUrl = "file://$currentScriptUrl".Replace('\', '/')
    
    if ($ImportMetaUrl -ne $currentScriptUrl) {
        return
    }
    
    $check = $args -contains "--check"
    $result = & $Run -Check:$check
    
    if (-not $result.Changed) {
        return
    }
    
    $relativeOutputPath = Resolve-Path -Relative -Path $result.OutputPath
    if ($check) {
        Write-Error "[${Label}] stale generated output at ${relativeOutputPath}"
        $global:LASTEXITCODE = 1
        return
    }
    
    Write-Host "[${Label}] wrote ${relativeOutputPath}"
}
