#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "4e713b20e27a95cf69406b6c95f1180d0052eb91fc66f6968d6ed0d79de84454", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "powershell"}
# frame.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

function Show-Usage {
  Write-Error @"
Usage:
  frame.ps1 <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

Examples:
  frame.ps1 video.mp4 --out /tmp/frame.jpg
  frame.ps1 video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.ps1 video.mp4 --index 0 --out /tmp/frame0.png
"@
  exit 2
}

if ($args.Count -eq 0 -or $args[0] -eq "-h" -or $args[0] -eq "--help") {
  Show-Usage
}

$in = $args[0]
$args = $args[1..$args.Length]

$time = ""
$index = ""
$out = ""

$i = 0
while ($i -lt $args.Count) {
  switch ($args[$i]) {
    "--time" {
      $time = $args[$i + 1]
      $i += 2
    }
    "--index" {
      $index = $args[$i + 1]
      $i += 2
    }
    "--out" {
      $out = $args[$i + 1]
      $i += 2
    }
    default {
      Write-Error "Unknown arg: $($args[$i])"
      Show-Usage
    }
  }
}

if (-not (Test-Path $in)) {
  Write-Error "File not found: $in"
  exit 1
}

if ($out -eq "") {
  Write-Error "Missing --out"
  Show-Usage
}

$dir = Split-Path $out -Parent
if (-not (Test-Path $dir)) {
  New-Item -ItemType Directory -Path $dir | Out-Null
}

if ($index -ne "") {
  ffmpeg -hide_banner -loglevel error -y `
    -i "$in" `
    -vf "select=eq(n\,$index)" `
    -vframes 1 `
    "$out"
} elseif ($time -ne "") {
  ffmpeg -hide_banner -loglevel error -y `
    -ss "$time" `
    -i "$in" `
    -frames:v 1 `
    "$out"
} else {
  ffmpeg -hide_banner -loglevel error -y `
    -i "$in" `
    -vf "select=eq(n\,0)" `
    -vframes 1 `
    "$out"
}

Write-Output $out
