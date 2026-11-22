#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "ba869096fdd80d2e2a7d2d1f7185c889a8bcd2100ac2c13b732b6fe97526e289", "source_sha256": "5425378c778f4ef6ac0e8404ecffe774c2d3aea6bad539b4fd772554e566f469", "target_language": "powershell"}
# run-tsgo.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-tsgo.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Import necessary modules
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Function to resolve path similar to path.resolve
function Resolve-PathSafe {
    param(
        [string]$Path
    )
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return [System.IO.Path]::GetFullPath((Join-Path $pwd.Path $Path))
}

# Function to mimic applyLocalTsgoPolicy
function Apply-LocalTsgoPolicy {
    param(
        [string[]]$Args,
        [hashtable]$EnvVars
    )
    
    # For now, just return the same args and env
    # In a real scenario, you might modify them based on policy
    return @{
        Args = $Args
        Env = $EnvVars
    }
}

# Function to mimic acquireLocalHeavyCheckLockSync
function Acquire-LocalHeavyCheckLock {
    param(
        [string]$Cwd,
        [hashtable]$Env,
        [string]$ToolName
    )
    
    # Create a simple lock file mechanism
    $lockDir = Join-Path $Cwd "node_modules" ".cache" "tsgo-lock"
    $lockFile = Join-Path $lockDir "lockfile"
    
    # Ensure directory exists
    if (-not (Test-Path $lockDir)) {
        New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
    }
    
    # Wait for lock (simple implementation)
    while (Test-Path "$lockFile.lock") {
        Start-Sleep -Milliseconds 100
    }
    
    # Create lock
    Set-Content -Path "$lockFile.lock" -Value "locked"
    
    # Return release function
    return {
        if (Test-Path "$lockFile.lock") {
            Remove-Item "$lockFile.lock" -Force
        }
    }
}

# Function to read flag value like in JS
function Read-FlagValue {
    param(
        [string[]]$Args,
        [string]$Name
    )
    
    for ($i = 0; $i -lt $Args.Count; $i++) {
        $arg = $Args[$i]
        if ($arg -eq $Name) {
            if (($i + 1) -lt $Args.Count) {
                return $Args[$i + 1]
            }
        }
        if ($arg.StartsWith("$Name=")) {
            return $arg.Substring($Name.Length + 1)
        }
    }
    return $null
}

# Main execution
try {
    # Apply local policy
    $policyResult = Apply-LocalTsgoPolicy -Args $args -Env $env
    $finalArgs = $policyResult.Args
    $envVars = $policyResult.Env
    
    # Determine tsgo path
    $tsgoPath = Resolve-PathSafe "node_modules\.bin\tsgo"
    
    # Handle tsBuildInfoFile
    $tsBuildInfoFile = Read-FlagValue -Args $finalArgs -Name "--tsBuildInfoFile"
    if ($tsBuildInfoFile) {
        $dirPath = [System.IO.Path]::GetDirectoryName((Resolve-PathSafe $tsBuildInfoFile))
        if (-not (Test-Path $dirPath)) {
            New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        }
    }
    
    # Acquire lock
    $releaseLock = Acquire-LocalHeavyCheckLock -Cwd $pwd.Path -Env $envVars -ToolName "tsgo"
    
    try {
        # Prepare arguments for tsgo
        $allArgs = @()
        foreach ($arg in $finalArgs) {
            $allArgs += $arg
        }
        
        # Execute tsgo
        if ($IsWindows) {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c `"$tsgoPath`""
            foreach ($a in $allArgs) {
                $psi.Arguments += " `"$a`""
            }
            $psi.UseShellExecute = $false
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.EnvironmentVariables.Clear()
            foreach ($kv in $envVars.GetEnumerator()) {
                $psi.EnvironmentVariables[$kv.Key] = $kv.Value
            }
            
            $process = [System.Diagnostics.Process]::Start($psi)
            $process.WaitForExit()
            $exitCode = $process.ExitCode
        } else {
            # On non-Windows systems, execute directly
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $tsgoPath
            foreach ($a in $allArgs) {
                $psi.ArgumentList.Add($a)
            }
            $psi.UseShellExecute = $false
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.EnvironmentVariables.Clear()
            foreach ($kv in $envVars.GetEnumerator()) {
                $psi.EnvironmentVariables[$kv.Key] = $kv.Value
            }
            
            $process = [System.Diagnostics.Process]::Start($psi)
            $process.WaitForExit()
            $exitCode = $process.ExitCode
        }
        
        exit $exitCode
    } finally {
        & $releaseLock
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
