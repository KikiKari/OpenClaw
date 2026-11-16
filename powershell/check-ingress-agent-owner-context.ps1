#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "87a47437411d334e20e6146eec1aecbb8d052bfac47fe943e1ab07381cd87502", "source_sha256": "cfa6fdcce252a97fa8be4d621d55955657d2f6616d52330d880db2123e1db43b", "target_language": "powershell"}
# check-ingress-agent-owner-context.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-ingress-agent-owner-context.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation
using namespace Microsoft.PowerShell.Commands

# Define source roots and enforced files
$sourceRoots = @(
    "src/gateway"
    (Join-Path "plugins" "discord" "src" "voice")
)

$enforcedFiles = [HashSet[string]]@(
    (Join-Path "plugins" "discord" "src" "voice" "manager.ts")
    "src/gateway/openai-http.ts"
    "src/gateway/openresponses-http.ts"
    "src/gateway/server-methods/agent.ts"
    "src/gateway/server-node-events.ts"
)

function Find-LegacyAgentCommandCallLines {
    param(
        [string]$Content,
        [string]$FileName = "source.ts"
    )
    
    # This is a simplified implementation since PowerShell doesn't have TypeScript AST parsing
    # We'll use regex to find potential matches
    
    $lines = $Content -split "`r?`n"
    $results = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match "\bagntCommand\b") {
            $results += @{
                line = $i + 1
                text = $line.Trim()
            }
        }
    }
    return $results
}

function Get-RelativePath {
    param([string]$Path)
    $currentDir = Get-Location
    return Resolve-Path -Relative -Path $Path
}

function Test-SkipRelativePath {
    param([string]$RelPath)
    return -not $enforcedFiles.Contains($RelPath.Replace([IO.Path]::DirectorySeparatorChar, "/"))
}

function Invoke-CallsiteGuard {
    param(
        [string[]]$SourceRoots,
        [scriptblock]$FindCallLines,
        [scriptblock]$SkipRelativePath,
        [string]$Header,
        [string]$Footer
    )
    
    Write-Host $Header -ForegroundColor Yellow
    
    $foundIssues = $false
    
    foreach ($root in $SourceRoots) {
        if (-not (Test-Path $root)) {
            continue
        }
        
        $files = Get-ChildItem -Path $root -Include "*.ts" -Recurse
        
        foreach ($file in $files) {
            $relativePath = Get-RelativePath -Path $file.FullName
            
            if (& $SkipRelativePath $relativePath) {
                continue
            }
            
            $content = Get-Content -Path $file.FullName -Raw
            
            if ([string]::IsNullOrWhiteSpace($content)) {
                continue
            }
            
            $calls = & $FindCallLines $content $file.Name
            
            if ($calls.Count -gt 0) {
                $foundIssues = $true
                Write-Host "`n$file" -ForegroundColor Red
                
                foreach ($call in $calls) {
                    Write-Host "  line $($call.line): $($call.text)" -ForegroundColor Gray
                }
            }
        }
    }
    
    if ($foundIssues) {
        Write-Host "`n$Footer" -ForegroundColor Cyan
        exit 1
    }
}

function Main {
    Invoke-CallsiteGuard `
        -SourceRoots $sourceRoots `
        -FindCallLines ${function:Find-LegacyAgentCommandCallLines} `
        -SkipRelativePath ${function:Test-SkipRelativePath} `
        -Header "Found ingress callsites using local agentCommand() (must be explicit owner-aware):" `
        -Footer "Use agentCommandFromIngress(...) and pass senderIsOwner explicitly at ingress boundaries."
}

# Run as script
if ($MyInvocation.InvocationName -eq '.' -or $MyInvocation.Line -match $MyInvocation.MyCommand.Name) {
    Main
}
