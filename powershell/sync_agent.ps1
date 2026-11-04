#!/usr/bin/env pwsh
# sync_agent.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/clawhub-git-sync-agent/scripts/sync_agent.py
# Erzeugt: 2026-11-04 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Permanenter ClawHub ↔ Git Sync Agent
.DESCRIPTION
Multi-Node fähig, stündliche Ausführung
#>

param(
    [switch]$DryRun
)

# Konfiguration
$CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
$GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"
$STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json"
$BACKUP_ROOT = "/home/openclaw/.openclaw/workspace/backups/sync_agent"

# Lade externe Funktionen
$scriptPath = "/home/openclaw/.openclaw/workspace/scripts"
$env:PYTHONPATH = $scriptPath
Import-Module "$scriptPath/sync_clawhub_git.py" -Force

function Load-State {
    if (Test-Path $STATE_FILE) {
        return Get-Content $STATE_FILE | ConvertFrom-Json
    }
    return @{
        sync_history = @()
        pending = @()
    }
}

function Save-State($state) {
    $stateDir = Split-Path $STATE_FILE -Parent
    if (!(Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    $state | ConvertTo-Json -Depth 10 | Set-Content $STATE_FILE
}

function Get-AllSkills {
    $clawhubSkills = Get-ChildItem -Path $CLAWHUB_DIR -Directory | Where-Object {
        !$_.Name.StartsWith('.') -and !$_.Name.StartsWith('_') -and 
        (Test-Path "$($_.FullName)/SKILL.md")
    } | ForEach-Object { $_.Name }
    
    $gitSkills = Get-ChildItem -Path $GIT_DIR -Directory | Where-Object {
        !$_.Name.StartsWith('.') -and !$_.Name.StartsWith('_') -and 
        (Test-Path "$($_.FullName)/SKILL.md")
    } | ForEach-Object { $_.Name }
    
    return ($clawhubSkills + $gitSkills) | Sort-Object -Unique
}

function Init-GitRepo($skillPath, $skillName) {
    $gitDir = Join-Path $skillPath ".git"
    if (!(Test-Path $gitDir)) {
        Push-Location $skillPath
        try {
            git init | Out-Null
            git add . | Out-Null
            git commit -m "Initial commit: $skillName skill" | Out-Null
            Write-Host "Git initialized for $skillName"
        } finally {
            Pop-Location
        }
    }
}

function Backup-SkillDir($skillPath, $skillName) {
    if (!(Test-Path $skillPath)) { return }
    
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $backupDir = Join-Path $BACKUP_ROOT $timestamp
    if (!(Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    
    $archiveName = "${skillName}_${timestamp}.tar.gz"
    $archivePath = Join-Path $backupDir $archiveName
    
    # Entferne die .gz Endung für make-archive
    $tempArchivePath = $archivePath -replace '\.gz$', ''
    
    # Erstelle das Archiv mit tar
    $currentLocation = Get-Location
    try {
        Set-Location (Split-Path $skillPath -Parent)
        $skillDirName = Split-Path $skillPath -Leaf
        & tar czf $archivePath -C (Split-Path $skillPath -Parent) $skillDirName 2>$null
        Write-Host "Backup created for $skillName at $archivePath"
    } finally {
        Set-Location $currentLocation
    }
}

function Get-FileHashCustom($filePath) {
    # Python get_file_hash Funktion aufrufen
    return python -c "
import sys
sys.path.append('$scriptPath')
from sync_clawhub_git import get_file_hash
print(get_file_hash('$filePath'))
" 2>$null
}

function Get-Hashes($skillDir) {
    $hashes = @{}
    Get-ChildItem -Path $skillDir -Recurse -File | Where-Object {
        $_.FullName -notlike "*.git*"
    } | ForEach-Object {
        $relativePath = $_.FullName.Substring($skillDir.Length + 1)
        $hashes[$relativePath] = Get-FileHashCustom $_.FullName
    }
    return $hashes
}

function Sync-SkillBidirectional($skillName) {
    $clawhubPath = Join-Path $CLAWHUB_DIR $skillName
    $gitPath = Join-Path $GIT_DIR $skillName
    
    # Fall 1: Nur in ClawHub → zu Git
    if ((Test-Path $clawhubPath) -and !(Test-Path $gitPath)) {
        Write-Host "NEW in ClawHub: $skillName → syncing to Git"
        if (!$DryRun) {
            Backup-SkillDir $clawhubPath "${skillName}_clawhub"
        }
        if (sync_to_git $skillName -dry_run:$DryRun) {
            if (!$DryRun) {
                Init-GitRepo $gitPath $skillName
            }
            return "synced_to_git"
        }
    }
    # Fall 2: Nur in Git → zu ClawHub
    elseif ((Test-Path $gitPath) -and !(Test-Path $clawhubPath)) {
        Write-Host "NEW in Git: $skillName → syncing to ClawHub"
        if (!$DryRun) {
            Backup-SkillDir $gitPath "${skillName}_git"
        }
        if (sync_to_clawhub $skillName -dry_run:$DryRun) {
            return "synced_to_clawhub"
        }
    }
    # Fall 3: In beiden vorhanden → Vergleiche Timestamps
    elseif ((Test-Path $clawhubPath) -and (Test-Path $gitPath)) {
        # Validierung
        if (!(validate_skill $clawhubPath)) {
            Write-Host "Validation failed for ClawHub skill: $skillName" -ForegroundColor Red
            return "error"
        }
        if (!(validate_skill $gitPath)) {
            Write-Host "Validation failed for Git skill: $skillName" -ForegroundColor Red
            return "error"
        }
        
        # Berechne Hashes
        $clawhubHashes = Get-Hashes $clawhubPath
        $gitHashes = Get-Hashes $gitPath
        
        $hashesEqual = $true
        if ($clawhubHashes.Count -ne $gitHashes.Count) {
            $hashesEqual = $false
        } else {
            foreach ($key in $clawhubHashes.Keys) {
                if ($gitHashes[$key] -ne $clawhubHashes[$key]) {
                    $hashesEqual = $false
                    break
                }
            }
        }
        
        if (!$hashesEqual) {
            Write-Host "Content difference detected for: $skillName"
            
            $clawhubTime = (Get-Item $clawhubPath).LastWriteTime
            $gitTime = (Get-Item $gitPath).LastWriteTime
            $direction = if ($clawhubTime -ge $gitTime) { "to-git" } else { "to-clawhub" }
            
            Write-Host "UPDATE: $skillName → syncing $direction"
            if (!$DryRun) {
                Backup-SkillDir $clawhubPath "${skillName}_clawhub"
                Backup-SkillDir $gitPath "${skillName}_git"
            }
            
            if ($direction -eq "to-git") {
                if (sync_to_git $skillName -dry_run:$DryRun) {
                    if (!$DryRun) {
                        Push-Location $gitPath
                        try {
                            git add . | Out-Null
                            $commitMsg = "Sync from ClawHub content diff: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
                            git commit -m $commitMsg | Out-Null
                        } finally {
                            Pop-Location
                        }
                    }
                    return "updated_git"
                } else {
                    Write-Host "Failed to sync $skillName to Git after content diff" -ForegroundColor Red
                    return "error"
                }
            } else {
                if (sync_to_clawhub $skillName -dry_run:$DryRun) {
                    return "updated_clawhub"
                } else {
                    return "error"
                }
            }
        } else {
            Write-Host "Content is identical for: $skillName"
            return "no_change"
        }
    }
    
    return "no_change"
}

function Main {
    Write-Host "=== ClawHub ↔ Git Sync Agent gestartet ==="
    
    $state = Load-State
    $allSkills = Get-AllSkills
    Write-Host "Gefundene Skills: $($allSkills.Count)"
    
    $results = @{
        synced_to_git = @()
        synced_to_clawhub = @()
        updated_git = @()
        updated_clawhub = @()
        no_change = @()
        errors = @()
    }
    
    foreach ($skill in ($allSkills | Sort-Object)) {
        try {
            $result = Sync-SkillBidirectional $skill
            $results[$result] += $skill
        } catch {
            Write-Host "ERROR syncing $skill`: $($_.Exception.Message)" -ForegroundColor Red
            $results.errors += $skill
        }
    }
    
    # Zusammenfassung
    Write-Host "`n=== SYNC ZUSAMMENFASSUNG ==="
    Write-Host "Neu in Git: $($results.synced_to_git.Count) - $($results.synced_to_git -join ', ')"
    Write-Host "Neu in ClawHub: $($results.synced_to_clawhub.Count) - $($results.synced_to_clawhub -join ', ')"
    Write-Host "Git aktualisiert: $($results.updated_git.Count) - $($results.updated_git -join ', ')"
    Write-Host "ClawHub aktualisiert: $($results.updated_clawhub.Count) - $($results.updated_clawhub -join ', ')"
    Write-Host "Keine Änderung: $($results.no_change.Count)"
    Write-Host "Fehler: $($results.errors.Count) - $($results.errors -join ', ')"
    
    # Speichere State wenn kein Dry-Run
    if (!$DryRun) {
        if (!$state.ContainsKey("sync_history")) {
            $state.sync_history = @()
        }
        $state.sync_history += @{
            timestamp = (Get-Date).ToString("o")
            results = $results
        }
        # Nur letzte 100 Einträge behalten
        if ($state.sync_history.Count -gt 100) {
            $state.sync_history = $state.sync_history[($state.sync_history.Count-100)..($state.sync_history.Count-1)]
        }
        Save-State $state
    }
    
    Write-Host "=== Sync Agent beendet ===`n"
}

Main
