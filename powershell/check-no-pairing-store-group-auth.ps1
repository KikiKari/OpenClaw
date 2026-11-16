#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "ee1941ab5f89066d7f212422c447884b39dc6f287d2719eb78a94d9ad5df6c86", "source_sha256": "a9a15237ac26649d4fe81c84ab0e7be0474d07af42503d8016279ce5a868359c", "target_language": "powershell"}
# check-no-pairing-store-group-auth.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-pairing-store-group-auth.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Helper functions
function Get-RepoRoot {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $repoRoot = Resolve-Path (Join-Path $scriptPath "..")
    return $repoRoot
}

function Resolve-FromRepo($relativePath) {
    $repoRoot = Get-RepoRoot
    return Join-Path $repoRoot $relativePath
}

# Context setup
$repoRoot = Get-RepoRoot
$sourceRoots = @(
    Resolve-FromRepo "src"
)

$allowedFiles = @(
    Resolve-FromRepo "src/security/dm-policy-shared.ts"
    Resolve-FromRepo "src/channels/allow-from.ts"
    Resolve-FromRepo "src/security/fix.ts"
    Resolve-FromRepo "src/security/audit-channel.ts"
) | Sort-Object | Get-Unique

$storeIdentifierRe = "^(?:storeAllowFrom|storedAllowFrom|storeAllowList)$"
$groupNameRe = "(?:groupAllowFrom|effectiveGroupAllowFrom|groupAllowed|groupAllow|groupAuth|groupSender)"
$storeSourceCallNames = @(
    "readChannelAllowFromStore"
    "readChannelAllowFromStoreSync"
    "readStoreAllowFromForDmPolicy"
)
$allowedResolverCallNames = @(
    "resolveEffectiveAllowFromLists"
    "resolveDmGroupAccessWithLists"
    "resolveMattermostEffectiveAllowFromLists"
    "resolveIrcEffectiveAllowlists"
)

function Get-DeclarationNameText($nameNode) {
    # Simplified implementation assuming we're working with text representations
    return $nameNode
}

function Test-ContainsPairingStoreSource($nodeText) {
    # This is a simplified version that checks for regex patterns in text
    if ($nodeText -match $storeIdentifierRe) {
        return $true
    }
    
    foreach ($callName in $storeSourceCallNames) {
        if ($nodeText -match "\b$callName\b") {
            return $true
        }
    }
    
    return $false
}

function Get-CallName($expressionText) {
    # Extract function name from expression text
    if ($expressionText -match "\.(\w+)\s*\(") {
        return $matches[1]
    } elseif ($expressionText -match "(\w+)\s*\(") {
        return $matches[1]
    }
    return $null
}

function Test-IsSuspiciousNormalizeWithStoreCall($lineText) {
    if ($lineText -notmatch "normalizeAllowFromWithStore\s*\(") {
        return $false
    }
    
    # Check if both store and group properties exist in the call
    $hasStoreProp = $lineText -match "storeAllowFrom\s*:" -and (Test-ContainsPairingStoreSource $lineText)
    $hasGroupAllowProp = $lineText -match "allowFrom\s*:" -and ($lineText -match $groupNameRe)
    
    return ($hasStoreProp -and $hasGroupAllowProp)
}

function Find-Violations($content, $filePath) {
    $violations = @()
    $lines = $content -split "`r?`n"
    $lineNumber = 0
    
    foreach ($line in $lines) {
        $lineNumber++
        
        # Skip comments and empty lines
        if ($line -match "^\s*//|^\s*$") {
            continue
        }
        
        # Check for variable declarations with group names that reference store identifiers
        if (($line -match "\b(var|let|const)\s+(\w+)\b" -and ($Matches[2] -match $groupNameRe)) -and (Test-ContainsPairingStoreSource $line)) {
            $varName = $Matches[2]
            $callName = Get-CallName $line
            if ($callName -and $allowedResolverCallNames -contains $callName) {
                continue
            }
            
            $violations += @{
                Line = $lineNumber
                Reason = "group-scoped variable `"$varName`" references pairing-store identifiers"
            }
        }
        
        # Check for property assignments with group names that reference store identifiers
        if ($line -match "\b(\w+)\s*:" -and ($Matches[1] -match $groupNameRe) -and (Test-ContainsPairingStoreSource $line)) {
            $propName = $Matches[1]
            $violations += @{
                Line = $lineNumber
                Reason = "group-scoped property `"$propName`" references pairing-store identifiers"
            }
        }
        
        # Check for suspicious normalize calls
        if (Test-IsSuspiciousNormalizeWithStoreCall $line) {
            $violations += @{
                Line = $lineNumber
                Reason = "group allowlist uses normalizeAllowFromWithStore(...) with pairing-store entries"
            }
        }
    }
    
    return $violations
}

function Get-TypeScriptFiles($rootPaths) {
    $files = @()
    foreach ($path in $rootPaths) {
        if (Test-Path $path) {
            $items = Get-ChildItem -Path $path -Recurse -Include "*.ts", "*.tsx" -Exclude "*.d.ts"
            foreach ($item in $items) {
                $files += $item.FullName
            }
        }
    }
    return $files | Sort-Object | Get-Unique
}

function Main {
    $allViolations = @()
    $files = Get-TypeScriptFiles $sourceRoots
    
    foreach ($file in $files) {
        # Skip allowed files
        if ($allowedFiles -contains $file) {
            continue
        }
        
        try {
            $content = Get-Content -Path $file -Raw
            if ([string]::IsNullOrWhiteSpace($content)) {
                continue
            }
            
            $violations = Find-Violations $content $file
            foreach ($violation in $violations) {
                $allViolations += [PSCustomObject]@{
                    Path = $file
                    Line = $violation.Line
                    Reason = $violation.Reason
                }
            }
        } catch {
            Write-Warning "Could not process file $file`: $_"
        }
    }
    
    if ($allViolations.Count -eq 0) {
        return
    }
    
    Write-Error "Found pairing-store identifiers referenced in group auth composition:"
    foreach ($violation in $allViolations) {
        Write-Error "- $($violation.Path):$($violation.Line) ($($violation.Reason))"
    }
    Write-Error "Group auth must be composed via shared resolvers (resolveDmGroupAccessWithLists / resolveEffectiveAllowFromLists)."
    exit 1
}

# Run script
Main
