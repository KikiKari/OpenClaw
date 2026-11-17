#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "5683cc2ac0c05850fe3333c718c6c08a251410cacf4143cb2c89cc2b36530cbb", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "powershell"}
# extract-tiktok-streamlink.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$UsernameParam,
    [string]$Quality = "best",
    [string]$JsonFlag = ""
)

$ErrorActionPreference = "Stop"

function Emit-Json {
    param(
        [string[]]$Values
    )
    
    $keys = @("success", "method", "username", "url", "quality", "author", "title", "error", "timestamp", "status")
    $payload = @{}
    
    for ($i = 0; $i -lt [Math]::Min($keys.Length, $Values.Length); $i++) {
        if ($Values[$i] -ne "") {
            $payload[$keys[$i]] = $Values[$i]
        }
    }
    
    if ($payload.ContainsKey("success")) {
        $payload["success"] = ($payload["success"].ToLower() -eq "true")
    }
    
    return $payload | ConvertTo-Json -Compress
}

$Username = $UsernameParam.TrimStart("@")
$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

if ($Username -notmatch "^[A-Za-z0-9._]{1,24}$") {
    Write-Error "Invalid TikTok username" -ErrorAction Stop
    exit 64
}

$validQualities = @("best", "worst", "original", "1080p60", "720p60", "720p", "540p", "360p", "auto")
if ($validQualities -notcontains $Quality) {
    Write-Error "Invalid stream quality" -ErrorAction Stop
    exit 64
}

$cpuCount = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
if ($cpuCount -eq 0) { $cpuCount = 1 }
$loadPerCpu = (Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average / $cpuCount
$maxLoad = if ($env:TIKTOK_MAX_LOAD_PER_CPU) { [double]$env:TIKTOK_MAX_LOAD_PER_CPU } else { 1.5 }

if ($loadPerCpu -gt $maxLoad) {
    $jsonOutput = Emit-Json -Values @("false", "streamlink", $Username, "", $Quality, "", "", "host overloaded", $Timestamp, "overloaded")
    Write-Error $jsonOutput -ErrorAction Stop
    exit 75
}

try {
    $null = Get-Command streamlink -ErrorAction Stop
} catch {
    $jsonOutput = Emit-Json -Values @("false", "streamlink", $Username, "", $Quality, "", "", "streamlink not installed", $Timestamp, "dependency_missing")
    Write-Error $jsonOutput -ErrorAction Stop
    exit 2
}

$LiveUrl = "https://www.tiktok.com/@${Username}/live"

switch ($Quality) {
    "original" { $Selector = "origin,uhd_60,hd_60,hd,sd,ld,best,worst" }
    "auto" { $Selector = "best,origin,uhd_60,hd_60,hd,sd,ld,worst" }
    "1080p60" { $Selector = "uhd_60,hd_60,hd,sd,ld,worst" }
    "720p60" { $Selector = "hd_60,hd,sd,ld,worst" }
    "720p" { $Selector = "hd,sd,ld,worst" }
    "540p" { $Selector = "sd,ld,worst" }
    "360p" { $Selector = "ld,worst" }
    default { $Selector = $Quality }
}

try {
    $output = streamlink --json $LiveUrl $Selector 2>$null
    $exitCode = $LASTEXITCODE
} catch {
    $exitCode = 1
    $output = $null
}

if ($exitCode -ne 0 -or [string]::IsNullOrEmpty($output)) {
    try {
        $url = streamlink --stream-url $LiveUrl $Selector 2>$null
        $urlExitCode = $LASTEXITCODE
    } catch {
        $urlExitCode = 1
        $url = $null
    }
    
    if ($urlExitCode -ne 0 -or [string]::IsNullOrEmpty($url)) {
        $jsonOutput = Emit-Json -Values @("false", "streamlink", $Username, "", $Quality, "", "", "streamlink failed or no stream found", $Timestamp, "offline")
        Write-Error $jsonOutput -ErrorAction Stop
        exit 1
    }
    
    if ($JsonFlag -eq "--json") {
        $jsonOutput = Emit-Json -Values @("true", "streamlink", $Username, $url, $Quality, "", "", "", $Timestamp, "live")
        Write-Output $jsonOutput
    } else {
        Write-Output $url
    }
    exit 0
}

try {
    $data = $output | ConvertFrom-Json
    $url = $data.url
    $streams = $data.streams
    
    if ([string]::IsNullOrEmpty($url) -and $streams -is [System.Collections.IDictionary]) {
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
    
    $parsed = @{
        url = $url
        author = $author
        title = $title
    } | ConvertTo-Json -Compress
} catch {
    $jsonOutput = Emit-Json -Values @("false", "streamlink", $Username, "", $Quality, "", "", "invalid streamlink JSON", $Timestamp, "technical_error")
    Write-Error $jsonOutput -ErrorAction Stop
    exit 2
}

try {
    $parsedData = $parsed | ConvertFrom-Json
    $url = $parsedData.url
    $author = $parsedData.author
    $title = $parsedData.title
} catch {
    $url = ""
    $author = ""
    $title = ""
}

if ([string]::IsNullOrEmpty($url)) {
    $jsonOutput = Emit-Json -Values @("false", "streamlink", $Username, "", $Quality, $author, $title, "could not extract stream URL", $Timestamp, "offline")
    Write-Error $jsonOutput -ErrorAction Stop
    exit 1
}

if ($JsonFlag -eq "--json") {
    $jsonOutput = Emit-Json -Values @("true", "streamlink", $Username, $url, $Quality, $author, $title, "", $Timestamp, "live")
    Write-Output $jsonOutput
} else {
    Write-Output $url
}
