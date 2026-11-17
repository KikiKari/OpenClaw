#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "87eac82553f725a1cb209e60c90a0573e526f39d707c4677411b5c5f35c9f1fd", "source_sha256": "b00f64d55d344bbcc351ae7ade12137f0d9293b556aa0881ede43bef5bcb778b", "target_language": "powershell"}
# extract-tiktok-yt-dlp.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$Username,
    [string]$Format = "best",
    [string]$JsonFlag = ""
)

$ErrorActionPreference = "Stop"

# Remove @ prefix from username if present
if ($Username.StartsWith("@")) {
    $Username = $Username.Substring(1)
}

# Validate username format
if ($Username -notmatch "^[A-Za-z0-9._]{1,24}$") {
    Write-Error "Invalid TikTok username" -ErrorAction Stop
    exit 64
}

# Validate format
$validFormats = @(
    "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld",
    "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
    "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
    "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld",
    "hls-sd/hls-ld/flv-sd/flv-ld",
    "hls-ld/flv-ld",
    "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
)

if ($validFormats -notcontains $Format) {
    Write-Error "Invalid yt-dlp format" -ErrorAction Stop
    exit 64
}

# Get timestamp in UTC
$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Create temporary directory
$TmpDir = New-TemporaryFile | % { 
    $dir = $_.DirectoryName + "\tiktok-yt-dlp." + [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path $dir
}

# Cleanup function
function Cleanup {
    if (Test-Path $TmpDir) {
        Remove-Item -Recurse -Force $TmpDir
    }
}

# Register cleanup to run on exit
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Cleanup } | Out-Null

function Emit-Json {
    param(
        [string[]]$Args
    )
    
    $keys = @("success", "method", "username", "url", "format", "error", "timestamp", "status")
    $payload = @{}
    
    for ($i = 0; $i -lt [Math]::Min($keys.Count, $Args.Count); $i++) {
        if ($Args[$i] -ne "") {
            $payload[$keys[$i]] = $Args[$i]
        }
    }
    
    if ($payload.ContainsKey("success")) {
        $payload["success"] = ($payload["success"].ToLower() -eq "true")
    }
    
    $payload | ConvertTo-Json -Compress
}

# Check system load
$LoadPerCpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average / 100
$MaxLoad = if ($env:TIKTOK_MAX_LOAD_PER_CPU) { $env:TIKTOK_MAX_LOAD_PER_CPU } else { 1.5 }

if ([double]$LoadPerCpu -gt [double]$MaxLoad) {
    Emit-Json "false", "yt-dlp", $Username, "", $Format, "host overloaded", $Timestamp, "overloaded" | Write-Error
    exit 75
}

# Check if yt-dlp is installed
try {
    yt-dlp --version | Out-Null
} catch {
    Emit-Json "false", "yt-dlp", $Username, "", $Format, "yt-dlp not installed", $Timestamp, "dependency_missing" | Write-Error
    exit 2
}

# Run yt-dlp
$LiveUrl = "https://www.tiktok.com/@${Username}/live"
$StdoutFile = Join-Path $TmpDir "stdout.json"
$StderrFile = Join-Path $TmpDir "stderr.log"

try {
    yt-dlp --no-warnings --dump-single-json --skip-download --format $Format $LiveUrl > $StdoutFile 2> $StderrFile
    $ExitCode = $LASTEXITCODE
} catch {
    $ExitCode = 1
}

if ($ExitCode -ne 0) {
    $StderrContent = Get-Content $StderrFile -Raw
    if ($StderrContent -match "(?i)not currently live|No live cdn found|not available|private video") {
        $Status = "offline"
        $Code = 1
    } else {
        $Status = "technical_error"
        $Code = 2
    }
    
    $ErrorMessage = if ($StderrContent.Length -gt 1000) { $StderrContent.Substring(0, 1000) } else { $StderrContent }
    Emit-Json "false", "yt-dlp", $Username, "", $Format, $ErrorMessage, $Timestamp, $Status | Write-Error
    exit $Code
}

# Extract URL from JSON
$Url = ""
try {
    $JsonData = Get-Content $StdoutFile | ConvertFrom-Json
    $Candidates = @()
    
    if ($JsonData.url -and $JsonData.url -is [string]) {
        $Candidates += $JsonData.url
    }
    
    foreach ($item in $JsonData.formats) {
        if ($item -and $item.url -and $item.url -is [string]) {
            $Candidates += $item.url
        }
    }
    
    foreach ($value in $Candidates) {
        $lowValue = $value.ToLower()
        if ($value.StartsWith("https://") -and ($lowValue.Contains(".m3u8") -or $lowValue.Contains(".flv")) -and $lowValue -notcontains "only_audio=1") {
            $Url = $value
            break
        }
    }
} catch {
    # Ignore errors during parsing
}

if (-not $Url) {
    Emit-Json "false", "yt-dlp", $Username, "", $Format, "could not extract HTTPS video URL", $Timestamp, "offline" | Write-Error
    exit 1
}

if ($JsonFlag -eq "--json") {
    Emit-Json "true", "yt-dlp", $Username, $Url, $Format, "", $Timestamp, "live"
} else {
    Write-Output $Url
}
