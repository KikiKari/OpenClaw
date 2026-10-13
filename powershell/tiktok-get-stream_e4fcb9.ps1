#!/usr/bin/env pwsh
# tiktok-get-stream.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Enhanced TikTok LIVE URL extractor.

.DESCRIPTION
Order: Playwright response interception, streamlink, then yt-dlp. Every
result is schema-normalized and must be an allowed HTTPS TikTok-CDN FLV
URL. Fallbacks use fixed argument arrays, bounded output, timeouts, and
process-group cleanup.

Exit 0 = URL, 1 = offline/restricted/no URL, 2 = dependency/technical
failure, 75 = overloaded before Playwright startup.
#>

$ErrorActionPreference = "Stop"

# Import common functions from external file
. "$PSScriptRoot\tiktok-common.ps1"

$FALLBACK_TIMEOUT_MS = 45000
$FALLBACK_MAX_OUTPUT = 1024 * 1024

function Write-Log {
    param([string]$Message)
    Write-Error $Message
}

function Invoke-Fallback {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "bash"
    $psi.Arguments = @($ScriptPath) + $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = ""
    $stderr = ""
    $overflow = $false
    
    $outputHandler = {
        param($sender, $args)
        $data = $args.Data
        if ($data -eq $null) { return }
        $current = if ($sender -eq $process.StandardOutput) { $stdout } else { $stderr }
        $next = $current + $data
        if ([System.Text.Encoding]::UTF8.GetByteCount($next) -gt $FALLBACK_MAX_OUTPUT) {
            $overflow = $true
            return
        }
        if ($sender -eq $process.StandardOutput) {
            $global:stdout = $next
        } else {
            $global:stderr = $next
        }
    }
    
    $process.OutputDataReceived += $outputHandler
    $process.ErrorDataReceived += $outputHandler
    
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    
    $timedOut = $false
    $timer = [System.Threading.Timer]::new({
        $timedOut = $true
        try {
            $null = [System.Diagnostics.Process]::GetProcessById($process.Id)
            $process.Kill()
        } catch { }
    }, $null, $FALLBACK_TIMEOUT_MS, [System.Threading.Timeout.Infinite])
    
    $process.WaitForExit()
    $timer.Dispose()
    
    if ($overflow) {
        return @{ Code = 2; Stdout = ""; Stderr = "fallback output exceeded limit" }
    } elseif ($timedOut) {
        return @{ Code = 2; Stdout = $stdout; Stderr = "$stderr`nfallback timeout" }
    } else {
        return @{ 
            Code = if ($process.ExitCode -eq $null) { 2 } else { $process.ExitCode }
            Stdout = $stdout.Trim()
            Stderr = $stderr.Trim()
        }
    }
}

function Parse-FallbackResult {
    param(
        [string]$Method,
        [string]$Username,
        [hashtable]$Execution
    )
    
    foreach ($text in @($Execution.Stdout, $Execution.Stderr)) {
        if (-not $text) { continue }
        try {
            $value = $text | ConvertFrom-Json
            if ($value -and $value.GetType().Name -eq "PSCustomObject") {
                return Normalize-ExtractorResult $value $Method $Username
            }
        } catch { }
    }
    
    return Normalize-ExtractorResult @{
        success = $false
        status = if ($Execution.Code -eq 75) { "overloaded" } else { "technical_error" }
        method = $Method
        username = $Username
        message = if ($Execution.Stderr) { $Execution.Stderr } else { "fallback exited $($Execution.Code)" }
    } $Method $Username
}

function Test-PlaywrightPreflight {
    try {
        # In PowerShell we assume Playwright is installed via npm
        $executable = "chromium"
        # Just test if command exists
        $exists = Get-Command $executable -ErrorAction SilentlyContinue
        if ($exists) {
            return @{ ok = $true; executable = $executable }
        } else {
            throw "Chromium not found in PATH"
        }
    } catch {
        return @{
            ok = $false
            status = "dependency_missing"
            error = "Playwright Chromium unavailable: $($_.Exception.Message)"
        }
    }
}

function Get-HumanDelay {
    param(
        [int]$Min = 2000,
        [int]$Max = 4000
    )
    $random = New-Object Random
    return $random.Next($Min, $Max + 1)
}

# Placeholder functions for popup handling - would need actual implementation with Selenium or similar
function Handle-Popups {
    param($Page)
    # This would require a full Playwright/Selenium implementation in PowerShell
    # For now just return false as no popups were closed
    return $false
}

function Check-Restrictions {
    param($Page)
    # This would also require actual web automation implementation
    # Return unrestricted by default
    return @{ restricted = $false; reason = $null }
}

function Extract-WithPlaywright {
    param(
        [string]$Username,
        [string]$QualityPreference
    )
    
    $preflight = Test-PlaywrightPreflight
    if (-not $preflight.ok) {
        return @{
            success = $false
            method = "playwright"
            status = $preflight.status
            error = $preflight.error
        }
    }
    
    try {
        # Note: Full Playwright implementation would require additional modules
        # This is a skeleton showing structure only
        
        Write-Log "Playwright functionality not fully implemented in PowerShell version"
        
        # Placeholder for actual implementation
        return @{ 
            success = $false
            method = "playwright"
            status = "technical_error"
            error = "Playwright not fully implemented in PowerShell version"
        }
    } catch {
        Write-Log "Playwright error: $($_.Exception.Message)"
        return @{ 
            success = $false
            method = "playwright"
            status = "technical_error"
            error = $_.Exception.Message
        }
    }
}

function Try-Streamlink {
    param(
        [string]$Username,
        [string]$Quality
    )
    
    $scriptPath = Join-Path $PSScriptRoot "extraction-methods" "extract-tiktok-streamlink.sh"
    $execution = Invoke-Fallback $scriptPath @($Username, $Quality, "--json")
    return Parse-FallbackResult "streamlink" $Username $execution
}

function Try-YtDlp {
    param(
        [string]$Username,
        [string]$Quality
    )
    
    $scriptPath = Join-Path $PSScriptRoot "extraction-methods" "extract-tiktok-yt-dlp.sh"
    
    $ytFormatMap = @{
        original = "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld"
        "1080p60" = "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld"
        "720p60" = "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld"
        "720p" = "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld"
        "540p" = "hls-sd/hls-ld/flv-sd/flv-ld"
        "360p" = "hls-ld/flv-ld"
        auto = "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
    }
    
    $ytFormat = $ytFormatMap[$Quality]
    $execution = Invoke-Fallback $scriptPath @($Username, $ytFormat, "--json")
    return Parse-FallbackResult "yt-dlp" $Username $execution
}

function Get-StreamUrl {
    param(
        [string]$Username,
        [string]$QualityPreference = "auto"
    )
    
    $timestamp = (Get-Date).ToUniversalTime().ToString("o")
    
    # --- 1. Playwright ---
    Write-Log "[1/3] Trying Playwright for @$Username..."
    $pwResult = Extract-WithPlaywright $Username $QualityPreference
    if ($pwResult.success) {
        $pwResult.timestamp = $timestamp
        return $pwResult
    }
    if (@("restricted", "overloaded") -contains $pwResult.status) {
        return $pwResult
    }
    Write-Log "Playwright result: $(if ($pwResult.reason -or $pwResult.error) { $pwResult.reason + $pwResult.error } else { 'failed' })"
    
    # --- 2. Streamlink ---
    Write-Log "[2/3] Trying streamlink for @$Username (quality: $QualityPreference)..."
    $slResult = Try-Streamlink $Username $QualityPreference
    if ($slResult.success) {
        return $slResult
    }
    if (@("restricted", "overloaded") -contains $slResult.status) {
        return $slResult
    }
    Write-Log "Streamlink result: $(if ($slResult.message -or $slResult.error) { $slResult.message + $slResult.error } else { 'failed' })"
    
    # --- 3. yt-dlp ---
    Write-Log "[3/3] Trying yt-dlp for @$Username..."
    $ytResult = Try-YtDlp $Username $QualityPreference
    if ($ytResult.success) {
        return $ytResult
    }
    if (@("restricted", "overloaded") -contains $ytResult.status) {
        return $ytResult
    }
    Write-Log "yt-dlp result: $(if ($ytResult.message -or $ytResult.error) { $ytResult.message + $ytResult.error } else { 'failed' })"
    
    # --- All failed ---
    $status = Classify-FinalFailure @($pwResult, $slResult, $ytResult)
    return @{
        success = $false
        status = $status
        username = $Username
        message = "All extraction methods failed (Playwright, streamlink, yt-dlp)."
        playwrightReason = if ($pwResult.reason -or $pwResult.error) { $pwResult.reason + $pwResult.error } else { $null }
        streamlinkReason = if ($slResult.message -or $slResult.error) { $slResult.message + $slResult.error } else { $null }
        ytdlpReason = if ($ytResult.message -or $ytResult.error) { $ytResult.message + $ytResult.error } else { $null }
        timestamp = $timestamp
    }
}

# --- CLI ---
if ($args.Count -lt 1) {
    Write-Error "Usage: pwsh tiktok-get-stream.ps1 <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]"
    exit 1
}

try {
    $cliUsername = Normalize-Username $args[0]
} catch {
    Write-Error $_.Exception.Message
    exit 64
}

Enforce-LoadLimit "playwright_streamlink_ytdlp"
if (Test-ForcedOffline "playwright_streamlink_ytdlp" $cliUsername) {
    exit 1
}

$cliQuality = "auto"
$cliJson = $false

for ($i = 1; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq "--json") {
        $cliJson = $true
    } elseif (-not $args[$i].StartsWith("--")) {
        $cliQuality = $args[$i]
    }
}

$validQualities = @("original", "1080p60", "720p60", "720p", "540p", "360p", "auto")
if ($validQualities -notcontains $cliQuality) {
    Write-Error "Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto"
    exit 64
}

try {
    $result = Get-StreamUrl $cliUsername $cliQuality
    
    if ($cliJson) {
        $result | ConvertTo-Json -Depth 10
    } else {
        if ($result.success) {
            Write-Output $result.url
        } else {
            Write-Error $result.message
        }
    }
    
    exit (Get-ExitCodeForResult $result)
} catch {
    Write-Error "Unhandled error: $($_.Exception.Message)"
    exit 2
}
