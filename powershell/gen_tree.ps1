#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "037eaeb4b6359659b732dde51270d4ca7aa661a51a35614eb22a12f665dcd4cf", "source_sha256": "0a55a33f11db266892b50c887fd8d01783f387e3072c8c5b9ed86ca6788a8c52", "target_language": "powershell"}
# gen_tree.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
# (used because the `tree` binary is unavailable in this sandbox).
$ROOT = "/workspace"
$OUT = "/workspace/important/openclaw-tree.txt"
$MAX_DEPTH = 6

function Collect-Tree {
    param(
        [string]$Path,
        [string]$Prefix = "",
        [int]$Depth = 1
    )
    
    $lines = @()
    try {
        $entries = Get-ChildItem -Path $Path -Force -ErrorAction Stop | Sort-Object Name
    }
    catch {
        return $lines
    }
    
    $total = $entries.Count
    for ($i = 0; $i -lt $total; $i++) {
        $isLast = ($i -eq $total - 1)
        $connector = if ($isLast) { "└── " } else { "├── " }
        $lines += $Prefix + $connector + $entries[$i].Name
        
        $fullPath = Join-Path $Path $entries[$i].Name
        if ($Depth -lt $MAX_DEPTH -and $entries[$i].PSIsContainer -and -not $entries[$i].LinkType) {
            $nextPrefix = $Prefix + (if ($isLast) { "    " } else { "│   " })
            $lines += Collect-Tree -Path $fullPath -Prefix $nextPrefix -Depth ($Depth + 1)
        }
    }
    
    return $lines
}

$body = Collect-Tree -Path $ROOT
$header = @"
# OpenClaw Workspace Tree
# Generiert: $((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffffff"))
# Befehl: tree -a -L 6 $ROOT (emuliert via PowerShell)
# Diese Datei wird automatisch von db-maintainer aktualisiert

.
"@
$content = $header + "`n" + ($body -join "`n") + "`n"

Set-Content -Path $OUT -Value $content -Encoding UTF8

Write-Host "written $OUT : $($body.Count+1) lines, $($content.Length) bytes"
