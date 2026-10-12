#!/usr/bin/env pwsh
# sync_git_to_clawhub.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:scripts/sync_git_to_clawhub.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Sync die 4 Git-Repos zu ClawHub
#>

# Füge das Verzeichnis zum Modul-Suchpfad hinzu
$env:PSModulePath += [System.IO.Path]::PathSeparator + "/home/openclaw/.openclaw/workspace/scripts"

# Importiere die Funktionen aus dem PowerShell-Modul (Annahme: sync_clawhub_git.ps1)
. "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.ps1"

# Die 4 Git-Repos die zu ClawHub müssen
$gitRepos = @(
    "abstractions-utils",
    "sub-agents-utils", 
    "multi-nodes-utils",
    "Abstraktionen"
)

# Check if in git/
$gitPath = "/home/openclaw/.openclaw/workspace/git"
foreach ($repo in $gitRepos) {
    $repoPath = Join-Path $gitPath $repo
    if (Test-Path $repoPath) {
        log "Syncing $repo from Git to ClawHub..."
        # Rename für sync function
        if ($repo -eq "Abstraktionen") {
            continue  # Skip - ist kein Skill
        }
        sync_to_clawhub $repo -dry_run:$false
        log "✅ $repo synced to ClawHub"
    }
}
