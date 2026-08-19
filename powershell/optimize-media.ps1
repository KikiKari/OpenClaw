#!/usr/bin/env pwsh
# optimize-media.mjs — portiert nach powershell
# Quelle: javascript, Onboarding@main:scripts/optimize-media.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# PowerShell 7-Portierung von optimize-media.mjs
# Konvertiert PNG-Bilder in WebP- und AVIF-Formate mit festgelegter Qualität

# Basisverzeichnis für Medien festlegen
$directory = Join-Path (Split-Path $PSScriptRoot -Parent) "public/media"

# Alle PNG-Dateien im Verzeichnis durchlaufen
Get-ChildItem -Path $directory -Filter "*.png" | ForEach-Object {
    $source = $_.FullName
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    
    # WebP-Konvertierung mit Qualität 84
    $webpPath = Join-Path $directory "$stem.webp"
    magick convert $source -quality 84 $webpPath
    
    # AVIF-Konvertierung mit Qualität 58
    $avifPath = Join-Path $directory "$stem.avif"
    magick convert $source -quality 58 $avifPath
}

Write-Output "WebP- und AVIF-Derivate erzeugt."
