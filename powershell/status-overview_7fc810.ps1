#!/usr/bin/env pwsh
# status-overview.html — portiert nach powershell
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.html
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    Generates an HTML document for STATUS-Overview.
.DESCRIPTION
    This script creates an HTML file with the structure of the STATUS-Overview page,
    including required meta tags, stylesheets, and scripts. The output is written to
    a specified file path.
.PARAMETER OutputPath
    The file path where the generated HTML will be saved.
.EXAMPLE
    .\status-overview.ps1 -OutputPath "C:\temp\status-overview.html"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Create the HTML structure using PowerShell's here-string
$htmlContent = @"
<!doctype html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>STATUS-Overview</title>
    <link rel="stylesheet" href="status-overview.css">
</head>
<body>
    <main id="grid" aria-label="LIVE-Übersicht"></main>
    <script src="vendor-mpegts.js"></script>
    <script src="status-overview-player.js"></script>
</body>
</html>
"@

# Write the content to the specified file
$htmlContent | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "HTML file generated successfully at: $OutputPath"
