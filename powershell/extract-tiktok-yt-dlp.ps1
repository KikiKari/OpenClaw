#!/usr/bin/env pwsh
# extract-tiktok-yt-dlp.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$Username,
    [string]$Format = "best",
    [string]$JsonFlag
)

$ErrorActionPreference = "Stop"

function Emit-Json {
    param(
        [string]$Success,
        [string]$Method,
        [string]$Username,
        [string]$Url,
        [string]$Format,
        [string]$Error,
        [string]$Timestamp,
        [string]$Status
    )

    $payload = @{
        success = if ($Success) { $Success -eq "true" } else { $null }
        method = $Method
        username = $Username
        url = $Url
        format = $Format
        error = $Error
        timestamp = $Timestamp
        status = $Status
    }

    $payload = $payload.GetEnumerator() | Where-Object { $_.Value -ne "" } | ConvertTo-Json -Compress
    Write-Output $payload
}

$TIMESTAMP = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$TMP_DIR = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path "$_.tmp" }
$USERNAME_CLEAN = $Username.TrimStart('@')

try {
    if ($USERNAME_CLEAN -notmatch '^[A-Za-z0-9._]{1,24}$') {
        Write-Error "Invalid TikTok username" -ErrorAction Stop
        exit 64
    }

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

    $LOAD_PER_CPU = (Get-WmiObject Win32_Processor).LoadPercentage / 100
    $MAX_LOAD = if ($env:TIKTOK_MAX_LOAD_PER_CPU) { [double]$env:TIKTOK_MAX_LOAD_PER_CPU } else { 1.5 }

    if ($LOAD_PER_CPU -gt $MAX_LOAD) {
        Emit-Json "false" "yt-dlp" $USERNAME_CLEAN "" $Format "host overloaded" $TIMESTAMP "overloaded" | Write-Error
        exit 75
    }

    $ytDlpPath = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if (-not $ytDlpPath) {
        Emit-Json "false" "yt-dlp" $USERNAME_CLEAN "" $Format "yt-dlp not installed" $TIMESTAMP "dependency_missing" | Write-Error
        exit 2
    }

    $LIVE_URL = "https://www.tiktok.com/@${USERNAME_CLEAN}/live"
    $stdoutFile = Join-Path $TMP_DIR "stdout.json"
    $stderrFile = Join-Path $TMP_DIR "stderr.log"

    yt-dlp --no-warnings --dump-single-json --skip-download --format "$Format" "$LIVE_URL" > $stdoutFile 2> $stderrFile
    $EXIT_CODE = $LASTEXITCODE

    if ($EXIT_CODE -ne 0) {
        $stderrContent = Get-Content $stderrFile -Raw
        if ($stderrContent -match '(?i)not currently live|No live cdn found|not available|private video') {
            $STATUS = "offline"
            $CODE = 1
        } else {
            $STATUS = "technical_error"
            $CODE = 2
        }
        $errorPreview = ($stderrContent -replace '\s+', ' ').Substring(0, [Math]::Min(1000, $stderrContent.Length))
        Emit-Json "false" "yt-dlp" $USERNAME_CLEAN "" $Format $errorPreview $TIMESTAMP $STATUS | Write-Error
        exit $CODE
    }

    $data = Get-Content $stdoutFile | ConvertFrom-Json
    $candidates = @()

    if ($data.url -and $data.url -is [string]) {
        $candidates += $data.url
    }

    if ($data.formats -and $data.formats.Count -gt 0) {
        foreach ($item in $data.formats) {
            if ($item.url -and $item.url -is [string]) {
                $candidates += $item.url
            }
        }
    }

    $URL = ""
    foreach ($value in $candidates) {
        $low = $value.ToLower()
        if ($value.StartsWith("https://") -and ($low.Contains(".m3u8") -or $low.Contains(".flv")) -and -not $low.Contains("only_audio=1")) {
            $URL = $value
            break
        }
    }

    if (-not $URL) {
        Emit-Json "false" "yt-dlp" $USERNAME_CLEAN "" $Format "could not extract HTTPS video URL" $TIMESTAMP "offline" | Write-Error
        exit 1
    }

    if ($JsonFlag -eq "--json") {
        Emit-Json "true" "yt-dlp" $USERNAME_CLEAN $URL $Format "" $TIMESTAMP "live"
    } else {
        Write-Output $URL
    }
}
finally {
    if (Test-Path $TMP_DIR) {
        Remove-Item -Recurse -Force $TMP_DIR
    }
}
