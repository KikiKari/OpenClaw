#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "3d08c6f24711b1c18682cd1aa57d2a9cfffebfef9ea2dfdf98aafa8fb4a1f1dd", "source_sha256": "290dec5062f0c8675bc7304f9c93475a3e9667ed53e93894c5bc66f40e5ae5df", "target_language": "powershell"}
# check-no-random-messaging-tmp.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-random-messaging-tmp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$ImportMetaUrl = $MyInvocation.MyCommand.Path
)

# Define constants
$messagingTmpdirGuardSourceRoots = @(
    "src/channels"
    "src/infra/outbound"
    "src/line"
    "src/media"
    "src/media-understanding"
    "extensions"
)

# Load bundled plugin file helper
function Get-BundledPluginFile {
    param(
        [string]$plugin,
        [string]$file
    )
    # This should match your actual bundled plugin path logic
    return "plugins/$plugin/src/$file"
}

$allowedRelativePaths = @{
    (Get-BundledPluginFile "feishu" "src/dedup.ts") = $true
}

# Function to parse TypeScript and find tmpdir calls
function Find-MessagingTmpdirCallLines {
    param(
        [string]$content,
        [string]$fileName = "source.ts"
    )
    
    # In PowerShell we'll use regex-based parsing since we don't have TypeScript compiler API
    $lines = $content -split "`n"
    $results = @()
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNumber = $i + 1
        
        # Check for direct tmpdir() calls
        if ($line -match '\btmpdir\(\)') {
            $results += [PSCustomObject]@{
                Line = $lineNumber
                Content = $line.Trim()
            }
        }
        
        # Check for os.tmpdir() calls
        if ($line -match '\bos\.tmpdir\(\)') {
            $results += [PSCustomObject]@{
                Line = $lineNumber
                Content = $line.Trim()
            }
        }
    }
    
    return $results
}

# Function to check if a file should be skipped
function Test-SkipRelativePath {
    param([string]$relativePath)
    return $allowedRelativePaths.ContainsKey($relativePath)
}

# Main execution function
function Invoke-Main {
    Write-Host "Checking for os.tmpdir()/tmpdir() usage in messaging/channel runtime sources:"
    
    $violationsFound = $false
    
    # Walk through directories
    foreach ($sourceRoot in $messagingTmpdirGuardSourceRoots) {
        if (Test-Path $sourceRoot) {
            $files = Get-ChildItem -Path $sourceRoot -Recurse -Include "*.ts" -Exclude "*.d.ts"
            
            foreach ($file in $files) {
                $relativePath = Resolve-Path -Relative $file.FullName
                
                # Skip allowed paths
                if (Test-SkipRelativePath -relativePath $relativePath) {
                    continue
                }
                
                $content = Get-Content -Path $file.FullName -Raw
                
                if ($content) {
                    $violations = Find-MessagingTmpdirCallLines -content $content -fileName $file.Name
                    
                    if ($violations.Count -gt 0) {
                        $violationsFound = $true
                        Write-Host "`n$file.FullName"
                        foreach ($violation in $violations) {
                            Write-Host "  line $($violation.Line): $($violation.Content)"
                        }
                    }
                }
            }
        }
    }
    
    if ($violationsFound) {
        Write-Host "`nUse resolvePreferredOpenClawTmpDir() or plugin-sdk temp helpers instead of host tmp defaults."
        exit 1
    } else {
        Write-Host "No violations found."
    }
}

# Run as script
if ($MyInvocation.InvocationName -eq '.' -or $MyInvocation.InvocationName -eq '&') {
    Invoke-Main
}
