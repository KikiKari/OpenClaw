#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "63df60214e237e30b9377d3a73489c8ffd1604248114e62468ca204c51b7b744", "source_sha256": "44c9196ec2dbaf8ef45323397e44f66d128313ddae44f9dfc8bba7439fe6e844", "target_language": "powershell"}
# sync-plugin-sdk-exports.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sync-plugin-sdk-exports.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

$checkOnly = $args -contains "--check"
$packageJsonPath = Join-Path $PWD "package.json"

# Import necessary modules
Import-Module Microsoft.PowerShell.Utility

# Read and parse package.json
$packageJsonContent = Get-Content -Path $packageJsonPath -Raw
$packageJson = $packageJsonContent | ConvertFrom-Json
$currentExports = if ($packageJson.exports) { $packageJson.exports } else { @{} }

# Load the function from external file (simulated here)
# In PowerShell we need to dot-source or include the logic directly
# Assuming buildPluginSdkPackageExports is converted to a PowerShell function
function BuildPluginSdkPackageExports {
    # This would be the PowerShell equivalent of the JavaScript function
    # For now, returning an empty hashtable as placeholder
    return @{}
}

$syncedPluginSdkExports = BuildPluginSdkPackageExports

# Process exports
$nextExports = @{}
$insertedPluginSdkExports = $false

# Convert PSCustomObject to Hashtable for easier manipulation
$currentExportsHashtable = @{}
if ($currentExports -is [PSCustomObject]) {
    $currentExports.psobject.properties | ForEach-Object { 
        $currentExportsHashtable[$_.Name] = $_.Value 
    }
} elseif ($currentExports -is [hashtable]) {
    $currentExportsHashtable = $currentExports
}

foreach ($entry in $currentExportsHashtable.GetEnumerator()) {
    $key = $entry.Key
    $value = $entry.Value
    
    if ($key.StartsWith("./plugin-sdk")) {
        if (-not $insertedPluginSdkExports) {
            foreach ($sdkEntry in $syncedPluginSdkExports.GetEnumerator()) {
                $nextExports[$sdkEntry.Key] = $sdkEntry.Value
            }
            $insertedPluginSdkExports = $true
        }
        continue
    }
    
    $nextExports[$key] = $value
    
    if ($key -eq "." -and -not $insertedPluginSdkExports) {
        foreach ($sdkEntry in $syncedPluginSdkExports.GetEnumerator()) {
            $nextExports[$sdkEntry.Key] = $sdkEntry.Value
        }
        $insertedPluginSdkExports = $true
    }
}

if (-not $insertedPluginSdkExports) {
    foreach ($sdkEntry in $syncedPluginSdkExports.GetEnumerator()) {
        $nextExports[$sdkEntry.Key] = $sdkEntry.Value
    }
}

# Convert hashtables to JSON strings for comparison
$nextExportsJson = $nextExports | ConvertTo-Json -Depth 10
$currentExportsJson = $currentExportsHashtable | ConvertTo-Json -Depth 10

if ($checkOnly) {
    if ($currentExportsJson -ne $nextExportsJson) {
        Write-Error "plugin-sdk exports out of sync. Run `pnpm plugin-sdk:sync-exports`."
        exit 1
    }
    Write-Output "plugin-sdk exports synced."
    exit 0
}

# Update package.json with new exports
$packageJson.exports = $nextExports

# Write back to package.json with proper formatting
$jsonString = $packageJson | ConvertTo-Json -Depth 10
$formattedJson = ($jsonString -split "`n" | ForEach-Object { "  $_" }) -join "`n"
$formattedJson = "{`n$formattedJson`n}"

Set-Content -Path $packageJsonPath -Value $formattedJson -Encoding UTF8
