#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "9ef7d8725081bb79d12fe4774084b872d02e7c8b9dd01a08a35655133027d336", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "powershell"}
# bundle-a2ui.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Helper functions
function Resolve-RootDir {
    $scriptPath = $MyInvocation.MyCommand.Path
    return Split-Path (Split-Path $scriptPath -Parent) -Parent
}

$rootDir = Resolve-RootDir
$hashFile = Join-Path $rootDir "src" "canvas-host" "a2ui" ".bundle.hash"
$outputFile = Join-Path $rootDir "src" "canvas-host" "a2ui" "a2ui.bundle.js"
$a2uiRendererDir = Join-Path $rootDir "vendor" "a2ui" "renderers" "lit"
$a2uiAppDir = Join-Path $rootDir "apps" "shared" "OpenClawKit" "Tools" "CanvasA2UI"
$inputPaths = @(
    Join-Path $rootDir "package.json"
    Join-Path $rootDir "pnpm-lock.yaml"
    $a2uiRendererDir
    $a2uiAppDir
)
$ignoredBundleHashInputPrefixes = @("vendor/a2ui/renderers/lit/dist")

function Fail {
    param([string]$Message)
    Write-Error $Message
    Write-Error "A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle"
    Write-Error "If this persists, verify pnpm deps and try again."
    exit 1
}

function Test-PathExists {
    param([string]$TargetPath)
    return Test-Path $TargetPath
}

function Normalize-Path {
    param([string]$FilePath)
    return $FilePath.Replace("\", "/")
}

function Is-BundleHashInputPath {
    param([string]$FilePath, [string]$RepoRoot = $rootDir)
    $relativePath = Normalize-Path (Resolve-Path -Relative -Path $FilePath -RelativeBasePath $RepoRoot).TrimStart(".\")
    foreach ($ignoredPath in $ignoredBundleHashInputPrefixes) {
        if ($relativePath -eq $ignoredPath -or $relativePath.StartsWith("$ignoredPath/")) {
            return $false
        }
    }
    return $true
}

function Get-LocalRolldownCliCandidates {
    param([string]$RepoRoot = $rootDir)
    return @(
        Join-Path $RepoRoot "node_modules" "rolldown" "bin" "cli.mjs"
        Join-Path $RepoRoot "node_modules" ".pnpm" "node_modules" "rolldown" "bin" "cli.mjs"
        Join-Path $RepoRoot "node_modules" ".pnpm" "rolldown@1.0.0-rc.12" "node_modules" "rolldown" "bin" "cli.mjs"
    )
}

function Walk-Files {
    param([string]$EntryPath, [System.Collections.ArrayList]$Files)
    if (-not (Is-BundleHashInputPath $EntryPath)) {
        return
    }
    $item = Get-Item $EntryPath
    if (-not $item.PSIsContainer) {
        [void]$Files.Add($EntryPath)
        return
    }
    $entries = Get-ChildItem -Path $EntryPath
    foreach ($entry in $entries) {
        Walk-Files -EntryPath $entry.FullName -Files $Files
    }
}

function List-TrackedInputFiles {
    $relativeInputPaths = $inputPaths | ForEach-Object { Normalize-Path (Resolve-Path -Relative -Path $_ -RelativeBasePath $rootDir).TrimStart(".\") }
    $result = & git ls-files -- $relativeInputPaths
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return $result | Where-Object { $_ } | ForEach-Object { Join-Path $rootDir $_ } | Where-Object { Is-BundleHashInputPath $_ }
}

function Compute-Hash {
    $files = List-TrackedInputFiles
    if ($null -eq $files) {
        $files = New-Object System.Collections.ArrayList
        foreach ($inputPath in $inputPaths) {
            Walk-Files -EntryPath $inputPath -Files $files
        }
    }
    $sortedFiles = $files | Sort-Object { Normalize-Path (Resolve-Path -Relative -Path $_ -RelativeBasePath $rootDir).TrimStart(".\") }

    $hash = [System.Security.Cryptography.SHA256]::Create()
    $combinedBytes = [System.Text.StringBuilder]::new()
    foreach ($filePath in $sortedFiles) {
        $relativePath = Normalize-Path (Resolve-Path -Relative -Path $filePath -RelativeBasePath $rootDir).TrimStart(".\")
        [void]$combinedBytes.Append($relativePath)
        [void]$combinedBytes.Append("`0")
        $contentBytes = [System.IO.File]::ReadAllBytes($filePath)
        [void]$combinedBytes.Append([System.Text.Encoding]::UTF8.GetString($contentBytes))
        [void]$combinedBytes.Append("`0")
    }
    $data = [System.Text.Encoding]::UTF8.GetBytes($combinedBytes.ToString())
    $hashBytes = $hash.ComputeHash($data)
    return [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLowerInvariant()
}

function Run-Step {
    param(
        [string]$Command,
        [array]$Args,
        [hashtable]$Options = @{}
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    $psi.Arguments = ($Args | ForEach-Object { "`"$_`"" }) -join " "
    $psi.WorkingDirectory = $rootDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    
    if ($Options.ContainsKey("shell") -and $Options["shell"]) {
        $psi.UseShellExecute = $true
    }
    
    $process = [System.Diagnostics.Process]::Start($psi)
    $process.WaitForExit()
    
    if ($process.ExitCode -ne 0) {
        exit $process.ExitCode
    }
}

function Resolve-PnpmRunner {
    param(
        [array]$PnpmArgs,
        [string]$NodeExecPath,
        [string]$NpmExecPath,
        [string]$ComSpec,
        [string]$Platform
    )
    
    # Simplified version of resolvePnpmRunner logic
    if ($IsWindows) {
        $command = "pnpm.cmd"
        $args = $PnpmArgs
        $shell = $false
        $windowsVerbatimArguments = $false
    } else {
        $command = "pnpm"
        $args = $PnpmArgs
        $shell = $false
        $windowsVerbatimArguments = $false
    }
    
    return @{
        command = $command
        args = $args
        shell = $shell
        windowsVerbatimArguments = $windowsVerbatimArguments
    }
}

function Run-Pnpm {
    param([array]$PnpmArgs)
    $runner = Resolve-PnpmRunner -PnpmArgs $PnpmArgs -NodeExecPath $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($MyInvocation.MyCommand.Path) -NpmExecPath "" -ComSpec $env:ComSpec -Platform $env:OS
    Run-Step -Command $runner.command -Args $runner.args
}

async function Main {
    $hasRendererDir = Test-PathExists $a2uiRendererDir
    $hasAppDir = Test-PathExists $a2uiAppDir
    $hasOutputFile = Test-PathExists $outputFile
    
    if (-not $hasRendererDir -or -not $hasAppDir) {
        if ($hasOutputFile) {
            Write-Host "A2UI sources missing; keeping prebuilt bundle."
            return
        }
        if ($env:OPENCLAW_SPARSE_PROFILE -or $env:OPENCLAW_A2UI_SKIP_MISSING -eq "1") {
            Write-Error "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set."
            return
        }
        Fail "A2UI sources missing and no prebuilt bundle found at: $outputFile"
    }

    $currentHash = Compute-Hash
    if (Test-PathExists $hashFile) {
        $previousHash = (Get-Content $hashFile).Trim()
        if ($previousHash -eq $currentHash -and $hasOutputFile) {
            Write-Host "A2UI bundle up to date; skipping."
            return
        }
    }

    Run-Pnpm -PnpmArgs @("-s", "exec", "tsc", "-p", (Join-Path $a2uiRendererDir "tsconfig.json"))

    $localRolldownCliCandidates = Get-LocalRolldownCliCandidates -RepoRoot $rootDir
    $localRolldownCli = $null
    foreach ($candidate in $localRolldownCliCandidates) {
        if (Test-PathExists $candidate) {
            $localRolldownCli = $candidate
            break
        }
    }

    if ($localRolldownCli) {
        Run-Step -Command $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($MyInvocation.MyCommand.Path) -Args @($localRolldownCli, "-c", (Join-Path $a2uiAppDir "rolldown.config.mjs"))
    } else {
        Run-Pnpm -PnpmArgs @("-s", "exec", "rolldown", "-c", (Join-Path $a2uiAppDir "rolldown.config.mjs"))
    }

    Set-Content -Path $hashFile -Value "$currentHash`n" -Encoding UTF8
}

try {
    Main
} catch {
    Fail $_.Exception.Message
}
