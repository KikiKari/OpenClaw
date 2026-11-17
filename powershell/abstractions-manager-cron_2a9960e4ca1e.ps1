#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "67403bdb7d8aae1e8e0bba5869ab38dee16fe25775c9f989d4ceb1c197391693", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "powershell"}
# abstractions-manager-cron.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

$env:PATH = "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin"

# Load environment variables from file
Get-Content "/home/openclaw/.openclaw/.env" | ForEach-Object {
    if ($_ -match "^([^=]+)=(.*)$") {
        $name = $matches[1]
        $value = $matches[2]
        Set-Item "env:$name" $value
    }
}

# Check required environment variable
if ([string]::IsNullOrEmpty($env:OPENROUTER_API_KEY)) {
    Write-Error "OPENROUTER_API_KEY fehlt"
    exit 1
}

# Set GITHUB_TOKEN with fallback logic
$githubToken = $env:GITHUB_TOKEN, $env:GH_TOKEN, $env:GH_ACCESS_TOKEN | Where-Object { $_ } | Select-Object -First 1
if ($githubToken) {
    $env:GITHUB_TOKEN = $githubToken
}

# Create lock file path
$lockFilePath = "/home/openclaw/.openclaw/locks/abstractions-manager.lock"

# Function to acquire lock and execute command
function Invoke-WithLock {
    $lockAcquired = $false
    $fileStream = $null
    $lockFileStream = $null
    
    try {
        # Open the lock file
        $fileStream = [System.IO.File]::Open($lockFilePath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite)
        
        # Try to acquire exclusive lock
        $lockFileStream = [System.IO.File]::Open($lockFilePath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $lockAcquired = $true
        
        # Execute the Python script with all arguments
        & /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py @args
        $exitCode = $LASTEXITCODE
        
        # Exit with the same code as the Python script
        exit $exitCode
        
    } catch {
        if (-not $lockAcquired) {
            Write-Error "Could not acquire lock on $lockFilePath"
            exit 1
        } else {
            Write-Error "Error executing command: $_"
            exit 1
        }
    } finally {
        if ($lockFileStream) {
            $lockFileStream.Close()
            $lockFileStream.Dispose()
        }
        if ($fileStream) {
            $fileStream.Close()
            $fileStream.Dispose()
        }
    }
}

# Call the function with all passed arguments
Invoke-WithLock @args
