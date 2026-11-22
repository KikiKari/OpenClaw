#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "d9577672605eb6a9679a16e5ef1bd030eacc17405564fe84ef57bfc9447fc2fb", "source_sha256": "12dffdae6f3576ff268694787ca9415cbb1e307cb0b7cb39a0784412c35e1318", "target_language": "powershell"}
# run-extension-oxlint.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/run-extension-oxlint.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

param(
    [Parameter(Mandatory=$true)]
    [hashtable]$Params
)

# Import required modules
Import-Module Microsoft.PowerShell.Utility -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Define helper functions
function Get-TempDirectory {
    param(
        [string]$Prefix
    )
    $tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $Prefix + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    return $tempDir
}

function Remove-TempDirectory {
    param(
        [string]$Path
    )
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }
}

function Get-RepoRoot {
    return (Get-Location).Path
}

function Resolve-OxlintPath {
    $repoRoot = Get-RepoRoot
    $oxlintPath = Join-Path $repoRoot "node_modules" ".bin" "oxlint"
    if ($IsWindows) {
        $oxlintPath += ".cmd"
    }
    return $oxlintPath
}

function Acquire-LocalHeavyCheckLockSync {
    param(
        [hashtable]$Options
    )
    # Placeholder implementation - actual locking mechanism would be needed here
    Write-Host "Acquiring lock for $($Options.toolName)"
    return {
        Write-Host "Releasing lock for $($Options.toolName)"
    }
}

function Apply-LocalOxlintPolicy {
    param(
        [array]$BaseArgs,
        [hashtable]$EnvVars
    )
    # Placeholder implementation - actual policy application logic would go here
    return @{
        args = $BaseArgs
        env = $EnvVars
    }
}

function Prepare-ExtensionPackageBoundaryArtifacts {
    param(
        [string]$RepoRoot
    )
    
    $releaseLock = Acquire-LocalHeavyCheckLockSync @{
        cwd = $RepoRoot
        env = $env:PROCESS_ENV
        toolName = "extension-package-boundary-artifacts"
        lockName = "extension-package-boundary-artifacts"
    }
    
    try {
        $scriptPath = Join-Path $RepoRoot "scripts" "prepare-extension-package-boundary-artifacts.mjs"
        $nodePath = (Get-Command node).Source
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $nodePath
        $psi.Arguments = "`"$scriptPath`""
        $psi.WorkingDirectory = $RepoRoot
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $process.WaitForExit()
        
        if ($process.ExitCode -ne 0) {
            exit $process.ExitCode
        }
    } finally {
        & $releaseLock
    }
}

function Write-TempOxlintConfig {
    param(
        [string]$RepoRoot,
        [string]$ConfigPath
    )
    
    $configFilePath = Join-Path $RepoRoot ".oxlintrc.json"
    $configContent = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
    
    # Remove $schema property if exists
    $configContent.PSObject.Properties.Remove('$schema')
    
    # Check ignore patterns
    if ($configContent.ignorePatterns -and $configContent.ignorePatterns.GetType().Name -eq 'Object[]') {
        foreach ($pattern in $configContent.ignorePatterns) {
            if (Is-TopLevelExtensionsIgnorePattern $pattern) {
                throw "Refusing to run extension oxlint with .oxlintrc.json ignore pattern '$pattern'. Remove the top-level extensions ignore so root and focused lint agree."
            }
        }
    }
    
    $configContent | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
}

function Is-TopLevelExtensionsIgnorePattern {
    param(
        [string]$Pattern
    )
    
    $normalized = $Pattern.Trim().Replace('\', '/').TrimStart('./').TrimStart('/')
    return ($normalized -eq "extensions" -or $normalized -eq "extensions/" -or $normalized -eq "extensions/**")
}

function Collect-TypeScriptFiles {
    param(
        [string]$DirectoryPath
    )
    
    $files = @()
    $items = Get-ChildItem -Path $DirectoryPath -Recurse | Sort-Object Name
    
    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            continue
        }
        
        if (-not $item.Name.EndsWith(".ts") -and -not $item.Name.EndsWith(".tsx")) {
            continue
        }
        
        $relativePath = Resolve-Path -Relative -Path $item.FullName
        # Normalize path separators to forward slashes
        $relativePath = $relativePath.Replace("\", "/").TrimStart("./")
        $files += $relativePath
    }
    
    return $files
}

# Main function
function Run-ExtensionOxlint {
    param(
        [hashtable]$Params
    )
    
    $repoRoot = Get-RepoRoot
    $oxlintPath = Resolve-OxlintPath
    $releaseLock = Acquire-LocalHeavyCheckLockSync @{
        cwd = $repoRoot
        env = $env:PROCESS_ENV
        toolName = $Params.toolName
        lockName = $Params.lockName
    }
    
    $tempDir = Get-TempDirectory -Prefix $Params.tempDirPrefix
    $tempConfigPath = Join-Path $tempDir "oxlint.json"
    $exitCode = 0
    
    try {
        Prepare-ExtensionPackageBoundaryArtifacts -RepoRoot $repoRoot
        
        $extensionFiles = @()
        foreach ($root in $Params.roots) {
            $fullPath = Join-Path $repoRoot $root
            $collectedFiles = Collect-TypeScriptFiles -DirectoryPath $fullPath
            $extensionFiles += $collectedFiles
        }
        
        if ($extensionFiles.Count -eq 0) {
            Write-Error $Params.emptyMessage
            exit 1
        }
        
        Write-TempOxlintConfig -RepoRoot $repoRoot -ConfigPath $tempConfigPath
        
        # Build base arguments
        $baseArgs = @("-c", $tempConfigPath) + $args + $extensionFiles
        
        $policyResult = Apply-LocalOxlintPolicy -BaseArgs $baseArgs -EnvVars $env:PROCESS_ENV
        $finalArgs = $policyResult.args
        $envVars = $policyResult.env
        
        # Start oxlint process
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $oxlintPath
        $psi.Arguments = ($finalArgs | ForEach-Object { "`"$_`"" }) -join " "
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        
        # Set environment variables
        foreach ($key in $envVars.Keys) {
            if (-not $psi.EnvironmentVariables.ContainsKey($key)) {
                $psi.EnvironmentVariables.Add($key, $envVars[$key])
            } else {
                $psi.EnvironmentVariables[$key] = $envVars[$key]
            }
        }
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $process.WaitForExit()
        
        $exitCode = $process.ExitCode
    } catch {
        Write-Error $_.Exception.Message
        $exitCode = 1
    } finally {
        Remove-TempDirectory -Path $tempDir
        & $releaseLock
    }
    
    exit $exitCode
}

# Execute main function with provided parameters
Run-ExtensionOxlint -Params $Params
