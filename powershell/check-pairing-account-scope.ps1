#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "59d327aad1d4fbc5d4529c0723de06609ad5f702cefe3bcef591cd29efb850a2", "source_sha256": "03602fb41765aad7878e52af85d1c4c5a8d1d8a752b53a46602deb38e8783f73", "target_language": "powershell"}
# check-pairing-account-scope.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-pairing-account-scope.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Helper functions to mimic TypeScript AST traversal
function Get-PropertyNameText($node) {
    if ($node.name) {
        return $node.name.text
    }
    return $null
}

function Test-IsUndefinedLikeExpression($node) {
    if ($node.type -eq "Identifier" -and $node.text -eq "undefined") {
        return $true
    }
    return $node.type -eq "NullKeyword"
}

function Test-HasRequiredAccountIdProperty($node) {
    if ($node.type -ne "ObjectLiteralExpression") {
        return $false
    }
    
    foreach ($property in $node.properties) {
        if ($property.type -eq "ShorthandPropertyAssignment" -and $property.name.text -eq "accountId") {
            return $true
        }
        
        if ($property.type -ne "PropertyAssignment") {
            continue
        }
        
        $propertyName = Get-PropertyNameText($property)
        if ($propertyName -ne "accountId") {
            continue
        }
        
        if (Test-IsUndefinedLikeExpression($property.initializer)) {
            return $false
        }
        
        return $true
    }
    
    return $false
}

function Find-Violations($content, $filePath) {
    # In PowerShell we don't have a real TypeScript parser, so we'll do basic text parsing
    $lines = $content -split "`r?`n"
    $violations = @()
    $lineNumber = 0
    
    foreach ($line in $lines) {
        $lineNumber++
        
        # Check for readChannelAllowFromStore calls with missing accountId
        if ($line -match "readChannelAllowFromStore\s*\(") {
            # Simple regex to count arguments (very basic parsing)
            $argsMatch = [regex]::Match($line, "readChannelAllowFromStore\s*\(([^)]*)\)")
            if ($argsMatch.Success) {
                $args = $argsMatch.Groups[1].Value -split ","
                if ($args.Count -lt 3 -or $args[2] -match "undefined|null") {
                    $violations += @{
                        line = $lineNumber
                        reason = "readChannelAllowFromStore call must pass explicit accountId as 3rd arg"
                    }
                }
            } else {
                # If we can't parse args, assume it's missing
                $violations += @{
                    line = $lineNumber
                    reason = "readChannelAllowFromStore call must pass explicit accountId as 3rd arg"
                }
            }
        }
        
        # Check for legacy functions
        if ($line -match "readLegacyChannelAllowFromStore(?:Sync)?\s*\(") {
            $matches = [regex]::Matches($line, "(readLegacyChannelAllowFromStore(?:Sync)?)")
            foreach ($match in $matches) {
                $funcName = $match.Value -replace "\s*\(.+$", ""
                $violations += @{
                    line = $lineNumber
                    reason = "$funcName is legacy-only; use account-scoped readChannelAllowFromStore* APIs"
                }
            }
        }
        
        # Check for upsertChannelPairingRequest calls without accountId
        if ($line -match "upsertChannelPairingRequest\s*\(") {
            # Very basic check - look for accountId in the first argument object
            if ($line -notmatch "accountId\s*:|accountId,") {
                $violations += @{
                    line = $lineNumber
                    reason = "upsertChannelPairingRequest call must include accountId in params"
                }
            }
        }
    }
    
    return $violations
}

function Get-SourceRoots {
    # This would need to be adapted based on your project structure
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
    return @("$scriptDir/src")
}

function Get-RepoRoot {
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
    return $scriptDir
}

function Collect-FileViolations {
    param(
        [string[]]$sourceRoots,
        [string]$repoRoot,
        [System.Management.Automation.ScriptBlock]$findViolationsFunc
    )
    
    $allViolations = @()
    
    foreach ($root in $sourceRoots) {
        if (Test-Path $root) {
            $files = Get-ChildItem -Path $root -Recurse -Include "*.ts","*.tsx" -Exclude "*.d.ts"
            
            foreach ($file in $files) {
                $content = Get-Content -Path $file.FullName -Raw
                
                if ([string]::IsNullOrWhiteSpace($content)) {
                    continue
                }
                
                $violations = & $findViolationsFunc $content $file.FullName
                
                foreach ($violation in $violations) {
                    $allViolations += @{
                        path = $file.FullName
                        line = $violation.line
                        reason = $violation.reason
                    }
                }
            }
        }
    }
    
    return $allViolations
}

function Main {
    $sourceRoots = Get-SourceRoots
    $repoRoot = Get-RepoRoot
    
    $violations = Collect-FileViolations -sourceRoots $sourceRoots -repoRoot $repoRoot -findViolationsFunc ${function:Find-Violations}
    
    if ($violations.Count -eq 0) {
        return
    }
    
    Write-Error "Found unscoped pairing-store calls:"
    
    foreach ($violation in $violations) {
        Write-Error "- $($violation.path):$($violation.line) ($($violation.reason))"
    }
    
    exit 1
}

# Run as script
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
