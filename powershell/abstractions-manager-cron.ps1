#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "575a2c6f44c5b66c90c4fcad25b2ac0caf90dc2c8e0b94ff3b72261c7fb765f0", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "powershell"}
# abstractions-manager-cron.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$env:PATH = "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin"

# Load environment variables from file
Get-Content "/home/openclaw/.openclaw/.env" | ForEach-Object {
    if ($_ -match '^(.*?)=(.*)$') {
        $name = $matches[1]
        $value = $matches[2] -replace '^"|"$', '' # Remove surrounding quotes if present
        [System.Environment]::SetEnvironmentVariable($name, $value)
    }
}

# Check if OPENROUTER_API_KEY is set
if ([string]::IsNullOrEmpty($env:OPENROUTER_API_KEY)) {
    Write-Error "OPENROUTER_API_KEY fehlt"
    exit 1
}

# Set GITHUB_TOKEN from alternatives if not already set
if ([string]::IsNullOrEmpty($env:GITHUB_TOKEN)) {
    if (-not [string]::IsNullOrEmpty($env:GH_TOKEN)) {
        $env:GITHUB_TOKEN = $env:GH_TOKEN
    } elseif (-not [string]::IsNullOrEmpty($env:GH_ACCESS_TOKEN)) {
        $env:GITHUB_TOKEN = $env:GH_ACCESS_TOKEN
    }
}

# Define paths
$lockFile = "/home/openclaw/.openclaw/locks/abstractions-manager.lock"
$pythonScript = "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py"

# Try to acquire lock and run the script
try {
    # Create lock file if it doesn't exist
    if (-not (Test-Path $lockFile)) {
        New-Item -ItemType File -Path $lockFile -Force | Out-Null
    }

    # Try to acquire exclusive lock
    $fileStream = [System.IO.File]::Open($lockFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    
    try {
        # Run the Python script with all arguments passed to this script
        & python3 $pythonScript @args
        exit $LASTEXITCODE
    }
    finally {
        $fileStream.Close()
    }
}
catch {
    if ($_.Exception.Message -like "*because it is being used by another process*") {
        Write-Host "Script is already running"
        exit 0
    }
    else {
        Write-Error $_.Exception.Message
        exit 1
    }
}
