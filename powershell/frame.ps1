#!/usr/bin/env pwsh
# frame.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$Path = "",
    [string]$Time = "",
    [string]$Index = "",
    [string]$Out = "",
    [switch]$Help
)

function Show-Usage {
    Write-Error @"
Usage:
  frame.ps1 <video-file> [--Time HH:MM:SS] [--Index N] --Out /path/to/frame.jpg

Examples:
  frame.ps1 video.mp4 --Out /tmp/frame.jpg
  frame.ps1 video.mp4 --Time 00:00:10 --Out /tmp/frame-10s.jpg
  frame.ps1 video.mp4 --Index 0 --Out /tmp/frame0.png
"@
    exit 2
}

if ($Help -or $Path -eq "" -or $args.Contains("-h") -or $args.Contains("--help")) {
    Show-Usage
}

$remainingArgs = $args
$i = 0
while ($i -lt $remainingArgs.Count) {
    switch ($remainingArgs[$i]) {
        "--Time" {
            if ($i + 1 -lt $remainingArgs.Count) {
                $Time = $remainingArgs[$i + 1]
                $i += 2
            } else {
                Write-Error "Missing value for --Time"
                Show-Usage
            }
        }
        "--Index" {
            if ($i + 1 -lt $remainingArgs.Count) {
                $Index = $remainingArgs[$i + 1]
                $i += 2
            } else {
                Write-Error "Missing value for --Index"
                Show-Usage
            }
        }
        "--Out" {
            if ($i + 1 -lt $remainingArgs.Count) {
                $Out = $remainingArgs[$i + 1]
                $i += 2
            } else {
                Write-Error "Missing value for --Out"
                Show-Usage
            }
        }
        default {
            Write-Error "Unknown arg: $($remainingArgs[$i])"
            Show-Usage
        }
    }
}

if (-not (Test-Path $Path)) {
    Write-Error "File not found: $Path"
    exit 1
}

if ($Out -eq "") {
    Write-Error "Missing --Out"
    Show-Usage
}

$outDir = Split-Path $Out -Parent
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

if ($Index -ne "") {
    & ffmpeg -hide_banner -loglevel error -y `
        -i $Path `
        -vf "select=eq(n\,$Index)" `
        -vframes 1 `
        $Out
} elseif ($Time -ne "") {
    & ffmpeg -hide_banner -loglevel error -y `
        -ss $Time `
        -i $Path `
        -frames:v 1 `
        $Out
} else {
    & ffmpeg -hide_banner -loglevel error -y `
        -i $Path `
        -vf "select=eq(n\,0)" `
        -vframes 1 `
        $Out
}

Write-Output $Out
