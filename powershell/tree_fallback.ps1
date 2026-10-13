#!/usr/bin/env pwsh
# tree_fallback.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:db-maintainer/scripts/tree_fallback.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Fallback tree generator for when the `tree` binary is unavailable.

.DESCRIPTION
Produces output similar to `tree -a -L <depth>` and writes it to
important/openclaw-tree.txt with a timestamp header.
#>

$WORKSPACE = "/workspace"
$DEPTH = 6
$SKIP = @(".git", "node_modules", "__pycache__", "venv", ".cache", ".npm", ".local")
$OUT = Join-Path $WORKSPACE "important" "openclaw-tree.txt"

function Get-TreeLines {
    param(
        [string]$Path,
        [string]$Prefix = "",
        [int]$Depth = 0
    )

    $lines = @()
    if ($Depth -ge $DEPTH) {
        return $lines
    }

    try {
        $entries = Get-ChildItem -Path $Path -Force | Sort-Object @{Expression = {$_.PSIsContainer}; Descending = $true}, Name
    }
    catch {
        return $lines
    }

    $filteredEntries = $entries | Where-Object { $SKIP -notcontains $_.Name }
    for ($i = 0; $i -lt $filteredEntries.Count; $i++) {
        $entry = $filteredEntries[$i]
        $last = ($i -eq ($filteredEntries.Count - 1))
        $connector = if ($last) { "└── " } else { "├── " }
        $suffix = if (Test-Path -Path $entry.FullName -PathType Container) { "/" } else { "" }
        $lines += "$Prefix$connector$($entry.Name)$suffix"
        if ((Test-Path -Path $entry.FullName -PathType Container) -and -not $entry.Target) {
            $extension = if ($last) { "    " } else { "│   " }
            $lines += Get-TreeLines -Path $entry.FullName -Prefix ($Prefix + $extension) -Depth ($Depth + 1)
        }
    }
    return $lines
}

function Main {
    $lines = @($WORKSPACE)
    $lines += Get-TreeLines -Path $WORKSPACE
    $body = ($lines -join "`n") + "`n"
    $header = @"
# OpenClaw Workspace Tree
# Generiert: $((Get-Date).ToString("o"))
# Fallback (tree binary nicht verfuegbar), Tiefe $DEPTH
# Diese Datei wird automatisch von db-maintainer aktualisiert

"@
    $outDir = Split-Path $OUT -Parent
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -Path $OUT -Value ($header + $body) -Encoding UTF8
    Write-Host "openclaw-tree.txt aktualisiert (Fallback): $OUT ($($lines.Count) Eintraege)"
}

Main
