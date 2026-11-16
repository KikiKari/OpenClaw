#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "bda1cb34345303392121c91de684f8d237ffc47f7534ab1fed5ee312d99a763d", "source_sha256": "cff712785adbfe2fa94661b7b8457fbc21ec0b21bc3bc77e5cfa7018f473e486", "target_language": "powershell"}
# build_icon.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build_icon.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Render the macOS .icon bundle to a padded .icns like Trimmy's pipeline.
# Defaults target the OpenClaw assets so you can just run the script from repo root.

$ROOT_DIR = Join-Path $PSScriptRoot ".." | Resolve-Path

$ICON_FILE = if ($args.Count -gt 0) { $args[0] } else { "$ROOT_DIR/apps/macos/Icon.icon" }
$BASENAME = if ($args.Count -gt 1) { $args[1] } else { "OpenClaw" }
$OUT_ROOT = if ($args.Count -gt 2) { $args[2] } else { "$ROOT_DIR/apps/macos/build/icon" }

$XCODE_APP = if ($env:XCODE_APP) { $env:XCODE_APP } else { "/Applications/Xcode.app" }

# Where the final .icns should live; override DEST_ICNS to change.
$DEST_ICNS = if ($env:DEST_ICNS) { $env:DEST_ICNS } else { "$ROOT_DIR/apps/macos/Sources/OpenClaw/Resources/OpenClaw.icns" }

$ICTOOL = "$XCODE_APP/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
if (-not (Test-Path $ICTOOL -PathType Leaf)) {
    $ICTOOL = "$XCODE_APP/Contents/Applications/Icon Composer.app/Contents/Executables/icontool"
}
if (-not (Test-Path $ICTOOL -PathType Leaf)) {
    Write-Error "ictool/icontool not found. Set XCODE_APP if Xcode is elsewhere."
    exit 1
}

$ICONSET_DIR = "$OUT_ROOT/${BASENAME}.iconset"
$TMP_DIR = "$OUT_ROOT/tmp"

New-Item -ItemType Directory -Path $ICONSET_DIR, $TMP_DIR -Force | Out-Null

$MASTER_ART = "$TMP_DIR/icon_art_824.png"
$MASTER_1024 = "$TMP_DIR/icon_1024.png"

# Render inner art (no margin) with macOS Default appearance
& $ICTOOL $ICON_FILE --export-preview "macOS Default" 824 824 1 -45 $MASTER_ART | Out-Null

# Pad to 1024x1024 with transparent border
# Using ImageMagick convert as sips equivalent in PowerShell
# If ImageMagick is not available, this will fail gracefully
& magick $MASTER_ART -background none -gravity center -extent 1024x1024 $MASTER_1024 | Out-Null

# Generate required sizes
$sizes = @(16, 32, 64, 128, 256, 512, 1024)
foreach ($sz in $sizes) {
    $out = "$ICONSET_DIR/icon_${sz}x${sz}.png"
    & magick $MASTER_1024 -resize "${sz}x${sz}" -background none -gravity center -extent "${sz}x${sz}" $out | Out-Null
    
    if ($sz -ne 1024) {
        $dbl = $sz * 2
        $out2 = "$ICONSET_DIR/icon_${sz}x${sz}@2x.png"
        & magick $MASTER_1024 -resize "${dbl}x${dbl}" -background none -gravity center -extent "${dbl}x${dbl}" $out2 | Out-Null
    }
}

# 512x512@2x already covered by 1024; ensure it exists
Copy-Item $MASTER_1024 "$ICONSET_DIR/icon_512x512@2x.png" -Force

# Create ICNS file using iconutil (requires macOS or compatible environment)
& iconutil -c icns $ICONSET_DIR -o "$OUT_ROOT/${BASENAME}.icns" | Out-Null

# Copy to destination
$destDir = Split-Path $DEST_ICNS -Parent
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
}
Copy-Item "$OUT_ROOT/${BASENAME}.icns" $DEST_ICNS -Force

Write-Output "Icon.icns generated at $DEST_ICNS"
