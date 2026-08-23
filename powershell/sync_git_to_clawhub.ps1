#!/usr/bin/env pwsh
# sync_git_to_clawhub.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:scripts/sync_git_to_clawhub.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Sync die aktiven Skill-Repositories zu ClawHub.
#>

# Füge das Skript-Verzeichnis zum Suchpfad hinzu
$env:PYTHONPATH = "/home/openclaw/.openclaw/workspace/scripts"
Import-Module -Name "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.py" -Force

# Nur aktive Skill-Repositories synchronisieren.
$git_repos = @(
    "sub-agents-utils",
    "multi-nodes-utils"
)

# Check if in git/
$git_path = "/home/openclaw/.openclaw/workspace/git"
foreach ($repo in $git_repos) {
    if (Test-Path "$git_path/$repo") {
        Write-Host "Syncing $repo from Git to ClawHub..."
        sync_to_clawhub $repo $false
        Write-Host "✅ $repo synced to ClawHub"
    }
}
