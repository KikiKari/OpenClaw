#!/usr/bin/env pwsh
# extract-tiktok-streamlink.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Bounded fallback used by the enhanced extractor. Output is normalized again
# by tiktok-get-stream.js; standalone success must remain URL-only unless
# --json is requested. Exit 75 means preflight overload.
$ErrorActionPreference = "Stop"

$USERNAME = $args[0] -replace '^@', ''
$QUALITY = if ($args.Count -gt 1) { $args[1] } else { "best" }
$JSON_FLAG = if ($args.Count -gt 2) { $args[2] } else { "" }
$TIMESTAMP = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

function emit_json {
    param(
        [string]$success,
        [string]$method,
        [string]$username,
        [string]$url,
        [string]$quality,
        [string]$author,
        [string]$title,
        [string]$error,
        [string]$timestamp,
        [string]$status
    )
    
    $payload = @{
        success = if ($success) { $success -eq "true" } else { $null }
        method = $method
        username = $username
        url = if ($url) { $url } else { $null }
        quality = $quality
        author = if ($author) { $author } else { $null }
        title = if ($title) { $title } else { $null }
        error = if ($error) { $error } else { $null }
        timestamp = $timestamp
        status = $status
    }
    
    $filteredPayload = $payload.GetEnumerator() | Where-Object { $_.Value -ne $null } | ForEach-Object { @{ $_.Key = $_.Value } }
    $result = @{}
    foreach ($item in $filteredPayload) {
        $result[$item.Keys[0]] = $item.Values[0]
    }
    
    return $result | ConvertTo-Json -Compress
}

if ($USERNAME -notmatch '^[A-Za-z0-9._]{1,24}$') {
    Write-Error "Invalid TikTok username" -ErrorAction Stop
    exit 64
}
if ($QUALITY -notmatch '^(best|worst|original|1080p60|720p60|720p|540p|360p|auto)$') {
    Write-Error "Invalid stream quality" -ErrorAction Stop
    exit 64
}

$cpuCount = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$loadAvg = (Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 5 | 
    Measure-Object -Property CounterSamples -Average).Average / 100
$LOAD_PER_CPU = $loadAvg / [Math]::Max(1, $cpuCount)
$MAX_LOAD = if ($env:TIKTOK_MAX_LOAD_PER_CPU) { [double]$env:TIKTOK_MAX_LOAD_PER_CPU } else { 1.5 }

if ($LOAD_PER_CPU -gt $MAX_LOAD) {
    $jsonOutput = emit_json "false" "streamlink" $USERNAME "" $QUALITY "" "" "host overloaded" $TIMESTAMP "overloaded"
    Write-Error $jsonOutput -ErrorAction Stop
    exit 75
}

try {
    $null = Get-Command streamlink -ErrorAction Stop
} catch {
    $jsonOutput = emit_json "false" "streamlink" $USERNAME "" $QUALITY "" "" "streamlink not installed" $TIMESTAMP "dependency_missing"
    Write-Error $jsonOutput -ErrorAction Stop
    exit 2
}

$LIVE_URL = "https://www.tiktok.com/@${USERNAME}/live"
switch ($QUALITY) {
    "original" { $SELECTOR = "origin,uhd_60,hd_60,hd,sd,ld,best,worst" }
    "auto" { $SELECTOR = "best,origin,uhd_60,hd_60,hd,sd,ld,worst" }
    "1080p60" { $SELECTOR = "uhd_60,hd_60,hd,sd,ld,worst" }
    "720p60" { $SELECTOR = "hd_60,hd,sd,ld,worst" }
    "720p" { $SELECTOR = "hd,sd,ld,worst" }
    "540p" { $SELECTOR = "sd,ld,worst" }
    "360p" { $SELECTOR = "ld,worst" }
    default { $SELECTOR = $QUALITY }
}

$OUTPUT = streamlink --json $LIVE_URL $SELECTOR 2>$null
$EXIT_CODE = $LASTEXITCODE
if ($EXIT_CODE -ne 0 -or -not $OUTPUT) {
    $URL = streamlink --stream-url $LIVE_URL $SELECTOR 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $URL) {
        $jsonOutput = emit_json "false" "streamlink" $USERNAME "" $QUALITY "" "" "streamlink failed or no stream found" $TIMESTAMP "offline"
        Write-Error $jsonOutput -ErrorAction Stop
        exit 1
    }
    if ($JSON_FLAG -eq "--json") {
        emit_json "true" "streamlink" $USERNAME $URL $QUALITY "" "" "" $TIMESTAMP "live"
    } else {
        Write-Output $URL
    }
    exit 0
}

try {
    $data = $OUTPUT | ConvertFrom-Json
    $url = $data.url
    $streams = $data.streams
    if (-not $url -and $streams -is [PSCustomObject]) {
        $streamKeys = @("best", "worst") + $streams.PSObject.Properties.Name
        foreach ($key in $streamKeys) {
            $value = $streams.$key
            if ($value -is [PSCustomObject] -and $value.url) {
                $url = $value.url
                break
            }
        }
    }
    $metadata = $data.metadata
    $author = if ($metadata.author) { $metadata.author } else { "" }
    $title = if ($metadata.title) { $metadata.title } else { "" }
    
    $PARSED = @{
        url = $url
        author = $author
        title = $title
    } | ConvertTo-Json
} catch {
    $jsonOutput = emit_json "false" "streamlink" $USERNAME "" $QUALITY "" "" "invalid streamlink JSON" $TIMESTAMP "technical_error"
    Write-Error $jsonOutput -ErrorAction Stop
    exit 2
}

$PARSED_OBJ = $PARSED | ConvertFrom-Json
$URL = $PARSED_OBJ.url
$AUTHOR = $PARSED_OBJ.author
$TITLE = $PARSED_OBJ.title

if (-not $URL) {
    $jsonOutput = emit_json "false" "streamlink" $USERNAME "" $QUALITY $AUTHOR $TITLE "could not extract stream URL" $TIMESTAMP "offline"
    Write-Error $jsonOutput -ErrorAction Stop
    exit 1
}

if ($JSON_FLAG -eq "--json") {
    emit_json "true" "streamlink" $USERNAME $URL $QUALITY $AUTHOR $TITLE "" $TIMESTAMP "live"
} else {
    Write-Output $URL
}
