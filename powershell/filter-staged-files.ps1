#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "8889c19bfea3932b524326ce7cd6c5fc82792b7aa01fb18072954132eb387da5", "source_sha256": "bf11781342e249f3bb5e5746f94668968b3fed5b83b099b77d5a9bb8ec38b713", "target_language": "powershell"}
# filter-staged-files.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/pre-commit/filter-staged-files.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Prints selected files as NUL-delimited tokens to stdout.

.DESCRIPTION
This script filters staged files based on their extensions and mode (lint or format).
It outputs the filtered file paths separated by NUL characters.

.PARAMETER Mode
Specifies the mode of operation: 'lint' or 'format'.

.PARAMETER Files
An array of file paths to be filtered.

.EXAMPLE
filter-staged-files.ps1 -Mode lint -Files @("file1.ts", "file2.js")
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Mode,
    
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Files
)

# Check if mode is valid
if ($Mode -ne "lint" -and $Mode -ne "format") {
    Write-Error "usage: filter-staged-files.ps1 <lint|format> -- <files...>"
    exit 2
}

# Define extension sets
$lintExts = @(".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs")
$formatExts = @(".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".json", ".md", ".mdx")
$formatIgnoredPaths = @("src/canvas-host/a2ui/a2ui.bundle.js")

# Function to determine if a file should be selected
function ShouldSelect($filePath) {
    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
    
    if ($Mode -eq "lint") {
        return $lintExts -contains $ext
    }
    
    if ($formatIgnoredPaths -contains $filePath) {
        return $false
    }
    
    return $formatExts -contains $ext
}

# Process each file
foreach ($file in $Files) {
    if (ShouldSelect -filePath $file) {
        Write-Host -NoNewline $file
        Write-Host -NoNewline "`0"
    }
}
