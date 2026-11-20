#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "cfb1d98421e41972d62c082216b90f3c6b857cd43b90c12d2af6f459c7cee4fe", "source_sha256": "f6c7bd2581ab63fdb19f7caaff8e9c362e279303a47e4efe1873b2e652a7fbc8", "target_language": "powershell"}
# generate-host-env-security-policy-swift.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/generate-host-env-security-policy-swift.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

param(
    [switch]$Check,
    [switch]$Write
)

# Helper function to resolve script directory
function Get-ScriptDirectory {
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    return Split-Path $Invocation.MyCommand.Path
}

# Validate arguments
if ($Check -and $Write) {
    Write-Error "Use either --Check or --Write, not both."
    exit 1
}

$writeMode = $Write -or (-not $Check)

# Determine paths
$here = Get-ScriptDirectory
$repoRoot = Resolve-Path (Join-Path $here "..")
$policyPath = Join-Path $repoRoot "src" "infra" "host-env-security-policy.json"
$outputPath = Join-Path $repoRoot "apps" "macos" "Sources" "OpenClaw" "HostEnvSecurityPolicy.generated.swift"

# Read and parse policy file
$rawPolicyContent = Get-Content -Path $policyPath -Raw
$rawPolicy = $rawPolicyContent | ConvertFrom-Json

# Load policy (simulate the JavaScript function)
function Load-HostEnvSecurityPolicy($policyData) {
    # This mimics the behavior of loadHostEnvSecurityPolicy by returning the data as-is
    # In a real scenario, you might want to add validation or transformation logic here
    return $policyData
}

$policy = Load-HostEnvSecurityPolicy $rawPolicy

# Render Swift string array helper
function Render-SwiftStringArray($items) {
    if ($null -eq $items) { $items = @() }
    $result = foreach ($item in $items) {
        "        `"$item`""
    }
    return ($result -join ",`n")
}

# Generate Swift code
$generated = @" 
// Generated file. Do not edit directly.
// Source: src/infra/host-env-security-policy.json
// Regenerate: powershell scripts/generate-host-env-security-policy-swift.ps1 --Write

import Foundation

enum HostEnvSecurityPolicy {
    static let blockedInheritedKeys: Set<String> = [
$(Render-SwiftStringArray $policy.blockedInheritedKeys)
    ]

    static let blockedInheritedPrefixes: [String] = [
$(Render-SwiftStringArray $policy.blockedInheritedPrefixes)
    ]

    static let blockedKeys: Set<String> = [
$(Render-SwiftStringArray $policy.blockedKeys)
    ]

    static let blockedOverrideKeys: Set<String> = [
$(Render-SwiftStringArray $policy.blockedOverrideKeys)
    ]

    static let blockedOverridePrefixes: [String] = [
$(Render-SwiftStringArray $policy.blockedOverridePrefixes)
    ]

    static let blockedPrefixes: [String] = [
$(Render-SwiftStringArray $policy.blockedPrefixes)
    ]
}
"@

# Add trailing newline to match original behavior
$generated += "`n"

# Check current content
$current = if (Test-Path $outputPath) {
    Get-Content -Path $outputPath -Raw
} else {
    $null
}

if ($Check) {
    if ($current -eq $generated) {
        Write-Host "OK $($outputPath.Replace($repoRoot, ''))"
        exit 0
    }
    Write-Error "Out of date $($outputPath.Replace($repoRoot, '')).`nRun: powershell scripts/generate-host-env-security-policy-swift.ps1 --Write"
    exit 1
}

if ($writeMode) {
    if ($current -ne $generated) {
        Set-Content -Path $outputPath -Value $generated -NoNewline
    }
    Write-Host "Wrote $($outputPath.Replace($repoRoot, ''))"
}
