#!/usr/bin/env pwsh
# process-pond-textures.py — portiert nach powershell
# Quelle: python, Onboarding@main:scripts/process-pond-textures.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Chroma-key pond textures to add a clean alpha channel.

.DESCRIPTION
The leaf/blossom source webps ship on solid backgrounds (dark green or white)
rather than transparency, so `alphaTest` clipping in three.js has nothing to
key on. This produces RGBA PNGs with a soft alpha mask so the R3F planes clip
to the real silhouette.
#>

Add-Type -AssemblyName System.Drawing.Common

$BASE = "public/media/pond"
$OUT = "$BASE/processed"

if (!(Test-Path $OUT)) {
    New-Item -ItemType Directory -Path $OUT | Out-Null
}

function Key-Out {
    param(
        [string]$Path,
        [string]$Out,
        [string]$Mode,
        [float]$Feather = 2.0
    )

    $bmp = [System.Drawing.Bitmap]::FromFile($Path)
    $width = $bmp.Width
    $height = $bmp.Height

    # Create a float array for RGB channels
    $r = New-Object 'float[,]' $height, $width
    $g = New-Object 'float[,]' $height, $width
    $b = New-Object 'float[,]' $height, $width

    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $pixel = $bmp.GetPixel($x, $y)
            $r[$y, $x] = $pixel.R
            $g[$y, $x] = $pixel.G
            $b[$y, $x] = $pixel.B
        }
    }

    $alpha = New-Object 'byte[,]' $height, $width

    if ($Mode -eq "green") {
        # Dark-green background: low overall brightness AND green-dominant-but-dark.
        # Foreground leaf is much brighter / lighter green.
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $lum = ($r[$y, $x] + $g[$y, $x] + $b[$y, $x]) / 3.0
                # background pixels: very dark (lum < ~35) — the bg is ~(3,50,0)=17
                if ($lum -lt 40.0) {
                    $alpha[$y, $x] = 0
                } else {
                    $alpha[$y, $x] = 255
                }
            }
        }
    } elseif ($Mode -eq "white") {
        # White background: near-white, low saturation.
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $min_val = [Math]::Min([Math]::Min($r[$y, $x], $g[$y, $x]), $b[$y, $x])
                $max_val = [Math]::Max([Math]::Max($r[$y, $x], $g[$y, $x]), $b[$y, $x])
                # background: bright and low chroma
                if (($min_val -gt 218.0) -and (($max_val - $min_val) -lt 28.0)) {
                    $alpha[$y, $x] = 0
                } else {
                    $alpha[$y, $x] = 255
                }
            }
        }
    } else {
        throw "Invalid mode: $Mode"
    }

    # Convert alpha to grayscale image
    $alphaImg = New-Object System.Drawing.Bitmap $width, $height
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $val = $alpha[$y, $x]
            $color = [System.Drawing.Color]::FromArgb($val, $val, $val)
            $alphaImg.SetPixel($x, $y, $color)
        }
    }

    # Apply Gaussian blur to feather the mask edges
    # Since we can't use PIL filters, we'll simulate a basic blur by averaging neighboring pixels
    if ($Feather -gt 0) {
        $blurredAlpha = New-Object 'byte[,]' $height, $width
        $blurRadius = [Math]::Max(1, [Math]::Round($Feather))
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $sum = 0
                $count = 0
                for ($dy = -$blurRadius; $dy -le $blurRadius; $dy++) {
                    for ($dx = -$blurRadius; $dx -le $blurRadius; $dx++) {
                        $ny = $y + $dy
                        $nx = $x + $dx
                        if ($ny -ge 0 -and $ny -lt $height -and $nx -ge 0 -and $nx -lt $width) {
                            $sum += $alpha[$ny, $nx]
                            $count++
                        }
                    }
                }
                $blurredAlpha[$y, $x] = [Math]::Round($sum / $count)
            }
        }
        # Copy blurred values back to alpha
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $val = $blurredAlpha[$y, $x]
                $color = [System.Drawing.Color]::FromArgb($val, $val, $val)
                $alphaImg.SetPixel($x, $y, $color)
            }
        }
    }

    # Create RGBA image
    $rgbaBmp = New-Object System.Drawing.Bitmap $width, $height
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $original = $bmp.GetPixel($x, $y)
            $alphaValue = $alphaImg.GetPixel($x, $y).R
            $newColor = [System.Drawing.Color]::FromArgb($alphaValue, $original)
            $rgbaBmp.SetPixel($x, $y, $newColor)
        }
    }

    # Find bounding box
    $minX = $width
    $minY = $height
    $maxX = 0
    $maxY = 0

    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            if ($alphaImg.GetPixel($x, $y).R -gt 0) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($minX -lt $maxX -and $minY -lt $maxY) {
        $cropWidth = $maxX - $minX + 1
        $cropHeight = $maxY - $minY + 1
        $croppedBmp = $rgbaBmp.Clone([System.Drawing.Rectangle]::FromLTRB($minX, $minY, $maxX + 1, $maxY + 1), $rgbaBmp.PixelFormat)
        $croppedBmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "$(Split-Path $Path -Leaf) -> $(Split-Path $Out -Leaf) ($($croppedBmp.Width)x$($croppedBmp.Height)) ($Mode)"
    } else {
        $rgbaBmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "$(Split-Path $Path -Leaf) -> $(Split-Path $Out -Leaf) ($width x $height) ($Mode)"
    }

    $bmp.Dispose()
    $alphaImg.Dispose()
    $rgbaBmp.Dispose()
}

# Lily pads
Key-Out -Path "$BASE/blaetter/12130585.webp" -Out "$OUT/leaf-a.png" -Mode "green"
Key-Out -Path "$BASE/blaetter/48178242.webp" -Out "$OUT/leaf-b.png" -Mode "white"

# Blossoms with white backgrounds -> clean cutouts (only these two key cleanly)
Key-Out -Path "$BASE/blueten/78370994.webp" -Out "$OUT/blossom-a.png" -Mode "white" -Feather 3.0
Key-Out -Path "$BASE/blueten/70017289.webp" -Out "$OUT/blossom-b.png" -Mode "white" -Feather 3.0

Write-Host "done"
