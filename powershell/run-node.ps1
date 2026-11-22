#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "090facc6aab47143a604adef4c9a316e311c4657efd3d2efd9e2f0981c9866fe", "source_sha256": "a06acfb1e69451fcfc8e5635f9059bac455efbbaca76e0edae285b866e7f8409", "target_language": "powershell"}
# run-node.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-node.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Import required modules
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Constants
$buildScript = "scripts/tsdown-build.mjs"
$compilerArgs = @($buildScript, "--no-clean")

$runNodeSourceRoots = @("src", $BUNDLED_PLUGIN_ROOT_DIR)
$runNodeConfigFiles = @("tsconfig.json", "package.json", "tsdown.config.ts")
$runNodeWatchedPaths = @($runNodeSourceRoots + $runNodeConfigFiles)
$extensionSourceFilePattern = "\.(?:[cm]?[jt]sx?)$"
$extensionRestartMetadataFiles = @("openclaw.plugin.json", "package.json")

# Initialize global variables
$BUNDLED_PLUGIN_ROOT_DIR = Join-Path $PSScriptRoot "plugins"
$BUNDLED_PLUGIN_PATH_PREFIX = "plugins/"

function Get-NormalizePath {
    param([string]$filePath)
    return ($filePath -replace "\\", "/").Trim()
}

function Test-IgnoredSourcePath {
    param([string]$relativePath)
    $normalizedPath = Get-NormalizePath $relativePath
    return $normalizedPath.EndsWith(".test.ts") -or 
           $normalizedPath.EndsWith(".test.tsx") -or 
           $normalizedPath.EndsWith("test-helpers.ts")
}

function Test-BuildRelevantSourcePath {
    param([string]$relativePath)
    $normalizedPath = Get-NormalizePath $relativePath
    return [regex]::IsMatch($normalizedPath, $extensionSourceFilePattern) -and 
           (-not (Test-IgnoredSourcePath $normalizedPath))
}

function Test-BuildRelevantRunNodePath {
    param([string]$repoPath)
    $normalizedPath = (Get-NormalizePath $repoPath) -replace "^\.\/+", ""
    
    if ($runNodeConfigFiles -contains $normalizedPath) {
        return $true
    }
    
    if ($normalizedPath.StartsWith("src/")) {
        return -not (Test-IgnoredSourcePath ($normalizedPath.Substring(4)))
    }
    
    if ($normalizedPath.StartsWith($BUNDLED_PLUGIN_PATH_PREFIX)) {
        return Test-BuildRelevantSourcePath ($normalizedPath.Substring($BUNDLED_PLUGIN_PATH_PREFIX.Length))
    }
    
    return $false
}

function Test-RestartRelevantExtensionPath {
    param([string]$relativePath)
    $normalizedPath = Get-NormalizePath $relativePath
    $fileName = Split-Path $normalizedPath -Leaf
    
    if ($extensionRestartMetadataFiles -contains $fileName) {
        return $true
    }
    
    return Test-BuildRelevantSourcePath $normalizedPath
}

function Test-RestartRelevantRunNodePath {
    param([string]$repoPath)
    $normalizedPath = (Get-NormalizePath $repoPath) -replace "^\.\/+", ""
    
    if ($runNodeConfigFiles -contains $normalizedPath) {
        return $true
    }
    
    if ($normalizedPath.StartsWith("src/")) {
        return -not (Test-IgnoredSourcePath ($normalizedPath.Substring(4)))
    }
    
    if ($normalizedPath.StartsWith($BUNDLED_PLUGIN_PATH_PREFIX)) {
        return Test-RestartRelevantExtensionPath ($normalizedPath.Substring($BUNDLED_PLUGIN_PATH_PREFIX.Length))
    }
    
    return $false
}

function Get-StatMtime {
    param([string]$filePath)
    try {
        $item = Get-Item $filePath -ErrorAction Stop
        return (Get-Date $item.LastWriteTime).ToFileTime()/10000
    } catch {
        return $null
    }
}

function Test-ExcludedSource {
    param([string]$filePath, [string]$sourceRoot, [string]$sourceRootName)
    $relativePath = Get-NormalizePath (Resolve-Path -Relative -Path $filePath -RelativeTo $sourceRoot)
    if ($relativePath.StartsWith("..")) {
        return $false
    }
    return -not (Test-BuildRelevantRunNodePath (Join-Path $sourceRootName $relativePath -Separator "/"))
}

function Find-LatestMtime {
    param([string]$dirPath, [scriptblock]$shouldSkip, $deps)
    $latest = $null
    $queue = @($dirPath)
    
    while ($queue.Count -gt 0) {
        $current = $queue[-1]
        $queue = $queue[0..($queue.Count-2)]
        
        if (-not $current) {
            continue
        }
        
        $entries = @()
        try {
            $entries = Get-ChildItem -Path $current -Force -ErrorAction Stop
        } catch {
            continue
        }
        
        foreach ($entry in $entries) {
            $fullPath = $entry.FullName
            
            if (Test-Path -Path $fullPath -PathType Container) {
                $queue += $fullPath
                continue
            }
            
            if (-not (Test-Path -Path $fullPath -PathType Leaf)) {
                continue
            }
            
            if ($shouldSkip -and (& $shouldSkip $fullPath)) {
                continue
            }
            
            $mtime = Get-StatMtime $fullPath
            if ($mtime -eq $null) {
                continue
            }
            
            if ($latest -eq $null -or $mtime -gt $latest) {
                $latest = $mtime
            }
        }
    }
    
    return $latest
}

function Read-GitStatus {
    param($deps)
    try {
        $result = & git status --porcelain --untracked-files=normal -- $($runNodeWatchedPaths | ForEach-Object { "`"$_`"" })
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
        return $result
    } catch {
        return $null
    }
}

function Parse-GitStatusPaths {
    param([string]$output)
    return ($output -split "`n" | ForEach-Object {
        $parts = $_.Substring(3) -split " -> "
        $parts | ForEach-Object { (Get-NormalizePath $_.Trim()) } | Where-Object { $_ }
    }) | Where-Object { $_ }
}

function Test-HasDirtySourceTree {
    param($deps)
    $output = Read-GitStatus $deps
    if ($output -eq $null) {
        return $null
    }
    return (Parse-GitStatusPaths $output | ForEach-Object { Test-BuildRelevantRunNodePath $_ }) -contains $true
}

function Read-BuildStamp {
    param($deps)
    $mtime = Get-StatMtime $deps.buildStampPath
    if ($mtime -eq $null) {
        return @{ mtime = $null; head = $null }
    }
    
    try {
        $raw = Get-Content -Path $deps.buildStampPath -Raw -ErrorAction Stop
        $raw = $raw.Trim()
        if (-not $raw.StartsWith("{")) {
            return @{ mtime = $mtime; head = $null }
        }
        
        $parsed = $raw | ConvertFrom-Json
        $head = if ($parsed.PSObject.Properties["head"] -and $parsed.head -is [string] -and $parsed.head.Trim()) {
            $parsed.head.Trim()
        } else {
            $null
        }
        
        return @{ mtime = $mtime; head = $head }
    } catch {
        return @{ mtime = $mtime; head = $null }
    }
}

function Test-HasSourceMtimeChanged {
    param([double]$stampMtime, $deps)
    $latestSourceMtime = $null
    
    foreach ($sourceRoot in $deps.sourceRoots) {
        $sourceMtime = Find-LatestMtime $sourceRoot.path {
            param($candidate)
            Test-ExcludedSource $candidate $sourceRoot.path $sourceRoot.name
        } $deps
        
        if ($sourceMtime -ne $null -and ($latestSourceMtime -eq $null -or $sourceMtime -gt $latestSourceMtime)) {
            $latestSourceMtime = $sourceMtime
        }
    }
    
    return $latestSourceMtime -ne $null -and $latestSourceMtime -gt $stampMtime
}

function Resolve-BuildRequirement {
    param($deps)
    
    if ($deps.env.OPENCLAW_FORCE_BUILD -eq "1") {
        return @{ shouldBuild = $true; reason = "force_build" }
    }
    
    $stamp = Read-BuildStamp $deps
    if ($stamp.mtime -eq $null) {
        return @{ shouldBuild = $true; reason = "missing_build_stamp" }
    }
    
    if ((Get-StatMtime $deps.distEntry) -eq $null) {
        return @{ shouldBuild = $true; reason = "missing_dist_entry" }
    }
    
    foreach ($filePath in $deps.configFiles) {
        $mtime = Get-StatMtime $filePath
        if ($mtime -ne $null -and $mtime -gt $stamp.mtime) {
            return @{ shouldBuild = $true; reason = "config_newer" }
        }
    }
    
    $currentHead = Resolve-GitHead $deps
    if ($currentHead -and -not $stamp.head) {
        return @{ shouldBuild = $true; reason = "build_stamp_missing_head" }
    }
    
    if ($currentHead -and $stamp.head -and $currentHead -ne $stamp.head) {
        return @{ shouldBuild = $true; reason = "git_head_changed" }
    }
    
    if ($currentHead) {
        $dirty = Test-HasDirtySourceTree $deps
        if ($dirty -eq $true) {
            return @{ shouldBuild = $true; reason = "dirty_watched_tree" }
        }
        if ($dirty -eq $false) {
            return @{ shouldBuild = $false; reason = "clean" }
        }
    }
    
    if (Test-HasSourceMtimeChanged $stamp.mtime $deps) {
        return @{ shouldBuild = $true; reason = "source_mtime_newer" }
    }
    
    return @{ shouldBuild = $false; reason = "clean" }
}

$BUILD_REASON_LABELS = @{
    force_build = "forced by OPENCLAW_FORCE_BUILD"
    missing_build_stamp = "build stamp missing"
    missing_dist_entry = "dist entry missing"
    config_newer = "config newer than build stamp"
    build_stamp_missing_head = "build stamp missing git head"
    git_head_changed = "git head changed"
    dirty_watched_tree = "dirty watched source tree"
    source_mtime_newer = "source mtime newer than build stamp"
    clean = "clean"
}

function Format-BuildReason {
    param([string]$reason)
    return if ($BUILD_REASON_LABELS.ContainsKey($reason)) { $BUILD_REASON_LABELS[$reason] } else { $reason }
}

$SIGNAL_EXIT_CODES = @{
    SIGINT = 130
    SIGTERM = 143
}

function Test-IsSignalKey {
    param([string]$signal)
    return $SIGNAL_EXIT_CODES.ContainsKey($signal)
}

function Get-SignalExitCode {
    param([string]$signal)
    if (Test-IsSignalKey $signal) {
        return $SIGNAL_EXIT_CODES[$signal]
    }
    return 1
}

function Write-LogRunner {
    param([string]$message, $deps)
    if ($deps.env.OPENCLAW_RUNNER_LOG -eq "0") {
        return
    }
    [System.Console]::Error.WriteLine("[openclaw] $message")
}

function Wait-ForSpawnedProcess {
    param([System.Diagnostics.Process]$childProcess, $deps)
    
    $forwardedSignal = $null
    $exitCode = $null
    $exitSignal = $null
    
    # Register signal handlers
    $sigIntHandler = [System.EventHandler[System.ConsoleCancelEventArgs]]{
        param($sender, $args)
        if (-not $forwardedSignal) {
            $forwardedSignal = "SIGINT"
            try {
                $childProcess.Kill()
            } catch {
                # Best-effort only
            }
        }
        $args.Cancel = $true
    }
    
    $sigTermHandler = [System.EventHandler]{
        if (-not $forwardedSignal) {
            $forwardedSignal = "SIGTERM"
            try {
                $childProcess.Kill()
            } catch {
                # Best-effort only
            }
        }
    }
    
    [System.Console]::CancelKeyPress.Add($sigIntHandler)
    
    # Wait for process to exit
    $childProcess.WaitForExit()
    $exitCode = $childProcess.ExitCode
    
    # Cleanup
    [System.Console]::CancelKeyPress.Remove($sigIntHandler)
    
    return @{
        exitCode = $exitCode
        exitSignal = $exitSignal
        forwardedSignal = $forwardedSignal
    }
}

function Invoke-OpenClaw {
    param($deps)
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $deps.execPath
    $psi.Arguments = "openclaw.mjs " + ($deps.args -join " ")
    $psi.WorkingDirectory = $deps.cwd
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    
    $nodeProcess = [System.Diagnostics.Process]::Start($psi)
    $res = Wait-ForSpawnedProcess $nodeProcess $deps
    
    if ($res.exitSignal) {
        return Get-SignalExitCode $res.exitSignal
    }
    
    if ($res.forwardedSignal) {
        return Get-SignalExitCode $res.forwardedSignal
    }
    
    return if ($res.exitCode -ne $null) { $res.exitCode } else { 1 }
}

function Sync-RuntimeArtifacts {
    param($deps)
    
    try {
        # Call the runtime post build function
        # This would need to be implemented based on your specific requirements
        Write-Host "Syncing runtime artifacts..." -ForegroundColor Yellow
        return $true
    } catch {
        Write-LogRunner "Failed to write runtime build artifacts: $($_.Exception.Message)" $deps
        return $false
    }
}

function Write-BuildStamp {
    param($deps)
    
    try {
        # Write dist build stamp
        # This would need to be implemented based on your specific requirements
        Write-Host "Writing build stamp..." -ForegroundColor Yellow
    } catch {
        # Best-effort stamp; still allow the runner to start.
        Write-LogRunner "Failed to write build stamp: $($_.Exception.Message)" $deps
    }
}

function Test-ShouldSkipCleanWatchRuntimeSync {
    param($deps)
    return $deps.env.OPENCLAW_WATCH_MODE -eq "1"
}

function Start-RunNodeMain {
    param($params = @{})
    
    # Setup dependencies
    $deps = @{
        cwd = if ($params.ContainsKey('cwd')) { $params.cwd } else { Get-Location }
        args = if ($params.ContainsKey('args')) { $params.args } else { $args[1..($args.Length-1)] }
        env = if ($params.ContainsKey('env')) { $params.env } else { [System.Environment]::GetEnvironmentVariables() }
        execPath = if ($params.ContainsKey('execPath')) { $params.execPath } else { "node" }
        stderr = [System.Console]::Error
        process = [System.Diagnostics.Process]::GetCurrentProcess()
    }
    
    $deps.distRoot = Join-Path $deps.cwd "dist"
    $deps.distEntry = Join-Path $deps.distRoot "entry.js"
    $deps.buildStampPath = Join-Path $deps.distRoot ".buildstamp"
    $deps.sourceRoots = $runNodeSourceRoots | ForEach-Object {
        @{
            name = $_
            path = Join-Path $deps.cwd $_
        }
    }
    $deps.configFiles = $runNodeConfigFiles | ForEach-Object { Join-Path $deps.cwd $_ }
    
    $buildRequirement = Resolve-BuildRequirement $deps
    
    if (-not $buildRequirement.shouldBuild) {
        if (-not (Test-ShouldSkipCleanWatchRuntimeSync $deps) -and -not (Sync-RuntimeArtifacts $deps)) {
            return 1
        }
        return Invoke-OpenClaw $deps
    }
    
    Write-LogRunner "Building TypeScript (dist is stale: $($buildRequirement.reason) - $(Format-BuildReason $buildRequirement.reason))." $deps
    
    $buildCmd = $deps.execPath
    $buildArgs = $compilerArgs
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $buildCmd
    $psi.Arguments = $buildArgs -join " "
    $psi.WorkingDirectory = $deps.cwd
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    
    $build = [System.Diagnostics.Process]::Start($psi)
    $buildRes = Wait-ForSpawnedProcess $build $deps
    
    if ($buildRes.exitSignal) {
        return Get-SignalExitCode $buildRes.exitSignal
    }
    
    if ($buildRes.forwardedSignal) {
        return Get-SignalExitCode $buildRes.forwardedSignal
    }
    
    if ($buildRes.exitCode -ne 0 -and $buildRes.exitCode -ne $null) {
        return $buildRes.exitCode
    }
    
    if (-not (Sync-RuntimeArtifacts $deps)) {
        return 1
    }
    
    Write-BuildStamp $deps
    return Invoke-OpenClaw $deps
}

# Main execution
try {
    $exitCode = Start-RunNodeMain
    exit $exitCode
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
