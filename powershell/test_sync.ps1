#!/usr/bin/env pwsh
# test_sync.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:scripts/test_sync.py
# auch in: OpenClaw@gateway2:scripts/test_sync.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Test für Sync-Script
#>

# Füge das Verzeichnis zum PowerShell-Modul-Suchpfad hinzu
$env:PSModulePath = "/home/openclaw/.openclaw/workspace/scripts" + [System.IO.Path]::PathSeparator + $env:PSModulePath

# Importiere das benötigte Modul
Import-Module -Name sync_clawhub_git -Force

# Test: db-maintainer ClawHub → Git (DRY-RUN)
Write-Host "=== TEST: db-maintainer sync (DRY-RUN) ==="
$skill = "db-maintainer"
$result = sync_to_git -skill $skill -dry_run $true
Write-Host "Result: $(if ($result) { 'SUCCESS' } else { 'FAILED' })"

Write-Host "`n=== LOG-Inhalt ==="
Get-Content "/home/openclaw/.openclaw/workspace/logs/sync.log" | Write-Host
