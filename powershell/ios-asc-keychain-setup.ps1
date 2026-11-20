#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "eb40ca5552cdf791df5366b01d55b7c2a270b1c8120099817f2b304bbb485a83", "source_sha256": "3c82de39b963e31592918456342c499f4e6477d2ee7404f215a5685c6d02674c", "target_language": "powershell"}
# ios-asc-keychain-setup.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-asc-keychain-setup.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$KeyPath = "",
    [string]$KeyId = "",
    [string]$IssuerId = "",
    [string]$Service = "openclaw-asc-key",
    [string]$Account = $env:USERNAME,
    [switch]$WriteEnv,
    [string]$EnvFile = ""
)

function Show-Usage {
    @"
Usage:
  scripts/ios-asc-keychain-setup.ps1 -KeyPath /path/to/AuthKey_XXXXXX.p8 -IssuerId <issuer-uuid> [options]

Required:
  -KeyPath <path>        Path to App Store Connect API key (.p8)
  -IssuerId <uuid>       App Store Connect issuer ID

Optional:
  -KeyId <id>            API key ID (auto-detected from AuthKey_<id>.p8 if omitted)
  -Service <name>        Keychain service name (default: openclaw-asc-key)
  -Account <name>        Keychain account name (default: `$env:USERNAME)
  -WriteEnv              Upsert non-secret env vars into apps/ios/fastlane/.env
  -EnvFile <path>        Override env file path used with -WriteEnv
  -Help                  Show this help

Example:
  scripts/ios-asc-keychain-setup.ps1 `
    -KeyPath "`$HOME/keys/AuthKey_ABC1234567.p8" `
    -IssuerId "00000000-1111-2222-3333-444444444444" `
    -WriteEnv
"@
}

function Set-EnvLine {
    param(
        [string]$FilePath,
        [string]$Key,
        [string]$Value
    )
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath | ForEach-Object {
            if ($_ -match "^$Key=") {
                "$Key=$Value"
            } else {
                $_
            }
        }
        
        $found = $false
        $lines = @()
        foreach ($line in $content) {
            if ($line -match "^$Key=") {
                $lines += "$Key=$Value"
                $found = $true
            } else {
                $lines += $line
            }
        }
        
        if (-not $found) {
            $lines += "$Key=$Value"
        }
        
        $lines | Set-Content $tempFile
    } else {
        "$Key=$Value" | Set-Content $tempFile
    }
    
    Move-Item -Path $tempFile -Destination $FilePath -Force
}

function Remove-EnvLine {
    param(
        [string]$FilePath,
        [string]$Key
    )
    
    if (-not (Test-Path $FilePath)) {
        return
    }
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    
    Get-Content $FilePath | Where-Object { $_ -notmatch "^$Key=" } | Set-Content $tempFile
    
    Move-Item -Path $tempFile -Destination $FilePath -Force
}

# Check for help parameter
if ($args -contains "-Help" -or $args -contains "--help") {
    Show-Usage
    exit 0
}

# Validate required parameters
if ([string]::IsNullOrEmpty($KeyPath) -or [string]::IsNullOrEmpty($IssuerId)) {
    Write-Error "Missing required arguments."
    Show-Usage
    exit 1
}

if (-not (Test-Path $KeyPath)) {
    Write-Error "Key file not found: $KeyPath"
    exit 1
}

# Auto-detect KeyId if not provided
if ([string]::IsNullOrEmpty($KeyId)) {
    $keyFilename = Split-Path $KeyPath -Leaf
    if ($keyFilename -match "^AuthKey_([A-Za-z0-9]+)\.p8$") {
        $KeyId = $matches[1]
    } else {
        Write-Error "Could not infer -KeyId from filename '$keyFilename'. Pass -KeyId explicitly."
        exit 1
    }
}

if ([string]::IsNullOrEmpty($Account)) {
    Write-Error "Could not determine Keychain account. Pass -Account explicitly."
    exit 1
}

# Read key content
$KeyContent = Get-Content $KeyPath -Raw
if ([string]::IsNullOrEmpty($KeyContent)) {
    Write-Error "Key file is empty: $KeyPath"
    exit 1
}

# Store in Windows Credential Manager using SecretManagement module
try {
    # Convert key content to secure string
    $secureString = ConvertTo-SecureString -String $KeyContent -AsPlainText -Force
    
    # Create credential object
    $credential = New-Object System.Management.Automation.PSCredential("$Service-$Account", $secureString)
    
    # Store in Windows Credential Manager
    $credential | Export-Clixml -Path "$env:TEMP\$Service-$Account.cred"
    
    Write-Host "Stored ASC API private key in Windows Credential Manager (service='$Service', account='$Account')."
} catch {
    Write-Error "Failed to store credential in Windows Credential Manager: $_"
    exit 1
}

Write-Host ""
Write-Host "Export these vars for Fastlane:"
Write-Host "ASC_KEY_ID=$KeyId"
Write-Host "ASC_ISSUER_ID=$IssuerId"
Write-Host "ASC_KEYCHAIN_SERVICE=$Service"
Write-Host "ASC_KEYCHAIN_ACCOUNT=$Account"

if ($WriteEnv) {
    # Determine env file path
    if ([string]::IsNullOrEmpty($EnvFile)) {
        $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
        $repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
        $EnvFile = Join-Path $repoRoot "apps/ios/fastlane/.env"
    }
    
    # Ensure directory exists
    $envDir = Split-Path $EnvFile -Parent
    if (-not (Test-Path $envDir)) {
        New-Item -ItemType Directory -Path $envDir | Out-Null
    }
    
    # Create file if it doesn't exist
    if (-not (Test-Path $EnvFile)) {
        New-Item -ItemType File -Path $EnvFile | Out-Null
    }
    
    # Update environment variables in file
    Set-EnvLine -FilePath $EnvFile -Key "ASC_KEY_ID" -Value $KeyId
    Set-EnvLine -FilePath $EnvFile -Key "ASC_ISSUER_ID" -Value $IssuerId
    Set-EnvLine -FilePath $EnvFile -Key "ASC_KEYCHAIN_SERVICE" -Value $Service
    Set-EnvLine -FilePath $EnvFile -Key "ASC_KEYCHAIN_ACCOUNT" -Value $Account
    
    # Remove file/path based keys so Keychain is used by default
    Remove-EnvLine -FilePath $EnvFile -Key "ASC_KEY_PATH"
    Remove-EnvLine -FilePath $EnvFile -Key "ASC_KEY_CONTENT"
    Remove-EnvLine -FilePath $EnvFile -Key "APP_STORE_CONNECT_API_KEY_PATH"
    
    Write-Host ""
    Write-Host "Updated env file: $EnvFile"
}
