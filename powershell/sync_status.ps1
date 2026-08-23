#!/usr/bin/env pwsh
# sync_status.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_status.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_status.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

<#
Sync Status - Zeigt Status aller Skills
#>

# Import sync functions
$scriptPath = "/home/openclaw/.openclaw/workspace/scripts"
if ($env:PATH -notlike "*$scriptPath*") {
    $env:PATH += ":$scriptPath"
}

# Note: PowerShell doesn't have a direct equivalent to Python's custom module import
# We'll need to reimplement the get_file_hash function or skip it if not used directly here

$CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
$GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"
$STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json"

function Check-SkillStatus($skillName) {
    <#
    Prüft Status eines Skills
    #>
    $clawhubPath = Join-Path $CLAWHUB_DIR $skillName
    $gitPath = Join-Path $GIT_DIR $skillName
    
    $status = @{
        name = $skillName
        in_clawhub = Test-Path $clawhubPath -PathType Container
        in_git = Test-Path $gitPath -PathType Container
        has_git_repo = if (Test-Path $gitPath -PathType Container) { Test-Path (Join-Path $gitPath ".git") } else { $false }
        status = "unknown"
        last_modified = @{}
    }
    
    # Status bestimmen
    if ($status.in_clawhub -and -not $status.in_git) {
        $status.status = "only_clawhub"
    }
    elseif ($status.in_git -and -not $status.in_clawhub) {
        $status.status = "only_git"
    }
    elseif ($status.in_clawhub -and $status.in_git) {
        # Timestamps vergleichen
        try {
            # Get latest file modification time in clawhub directory
            $clawhubFiles = Get-ChildItem -Path $clawhubPath -Recurse -File
            if ($clawhubFiles) {
                $clawhubLatest = ($clawhubFiles | Measure-Object -Property LastWriteTime -Maximum).Maximum
                $status.last_modified.clawhub = $clawhubLatest.ToString('yyyy-MM-dd HH:mm:ss')
            }

            # Get latest file modification time in git directory (excluding .git)
            $gitFiles = Get-ChildItem -Path $gitPath -Recurse -File | Where-Object { $_.FullName -notlike "*.git*"}
            if ($gitFiles) {
                $gitLatest = ($gitFiles | Measure-Object -Property LastWriteTime -Maximum).Maximum
                $status.last_modified.git = $gitLatest.ToString('yyyy-MM-dd HH:mm:ss')
            }
            
            if ($clawhubLatest -and $gitLatest) {
                $timeDiff = [Math]::Abs(($clawhubLatest - $gitLatest).TotalSeconds)
                
                if ($timeDiff -lt 60) {
                    $status.status = "synced"
                }
                elseif ($clawhubLatest -gt $gitLatest) {
                    $status.status = "clawhub_newer"
                }
                else {
                    $status.status = "git_newer"
                }
            }
        }
        catch {
            $status.status = "error"
        }
    }
    
    return $status
}

function Main() {
    <#
    Hauptfunktion
    #>
    Write-Output ("=" * 80)
    Write-Output "ClawHub ↔ Git Sync Status"
    Write-Output ("=" * 80)
    Write-Output "Zeitpunkt: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Output ""
    
    # Alle Skills finden
    $allSkills = @()
    if (Test-Path $CLAWHUB_DIR) {
        $clawhubDirs = Get-ChildItem -Path $CLAWHUB_DIR -Directory | Where-Object { !$_.Name.StartsWith('.') }
        $allSkills += $clawhubDirs.Name
    }
    if (Test-Path $GIT_DIR) {
        $gitDirs = Get-ChildItem -Path $GIT_DIR -Directory | Where-Object { !$_.Name.StartsWith('.') }
        $allSkills += $gitDirs.Name
    }
    
    $allSkills = $allSkills | Sort-Object -Unique
    
    # Status-Kategorien
    $categories = @{
        synced = @()
        clawhub_newer = @()
        git_newer = @()
        only_clawhub = @()
        only_git = @()
        error = @()
    }
    
    # Status für jeden Skill prüfen
    foreach ($skill in $allSkills) {
        $status = Check-SkillStatus $skill
        $categories[$status.status] += $status
    }
    
    # Ausgabe
    Write-Output "📊 Gesamt: $($allSkills.Count) Skills`n"
    
    # Synchronisiert
    if ($categories.synced.Count -gt 0) {
        Write-Output "✅ Synchronisiert ($($categories.synced.Count))"
        foreach ($s in $categories.synced) {
            Write-Output "   - $($s.name)"
        }
        Write-Output ""
    }
    
    # ClawHub neuer
    if ($categories.clawhub_newer.Count -gt 0) {
        Write-Output "🔄 ClawHub neuer ($($categories.clawhub_newer.Count))"
        foreach ($s in $categories.clawhub_newer) {
            Write-Output "   - $($s.name) (ClawHub: $($s.last_modified.clawhub))"
        }
        Write-Output ""
    }
    
    # Git neuer
    if ($categories.git_newer.Count -gt 0) {
        Write-Output "🔄 Git neuer ($($categories.git_newer.Count))"
        foreach ($s in $categories.git_newer) {
            Write-Output "   - $($s.name) (Git: $($s.last_modified.git))"
        }
        Write-Output ""
    }
    
    # Nur in ClawHub
    if ($categories.only_clawhub.Count -gt 0) {
        Write-Output "📦 Nur in ClawHub ($($categories.only_clawhub.Count))"
        foreach ($s in $categories.only_clawhub) {
            Write-Output "   - $($s.name)"
        }
        Write-Output ""
    }
    
    # Nur in Git
    if ($categories.only_git.Count -gt 0) {
        Write-Output "📁 Nur in Git ($($categories.only_git.Count))"
        foreach ($s in $categories.only_git) {
            Write-Output "   - $($s.name)"
        }
        Write-Output ""
    }
    
    # Fehler
    if ($categories.error.Count -gt 0) {
        Write-Output "❌ Fehler ($($categories.error.Count))"
        foreach ($s in $categories.error) {
            Write-Output "   - $($s.name)"
        }
        Write-Output ""
    }
    
    # State-File Info
    if (Test-Path $STATE_FILE) {
        $stateContent = Get-Content $STATE_FILE -Raw | ConvertFrom-Json
        if ($stateContent.PSObject.Properties.Name -contains "last_sync") {
            $lastRuns = $stateContent.last_sync.PSObject.Properties.Name
            if ($lastRuns.Count -gt 0) {
                $lastRun = $lastRuns | Sort-Object | Select-Object -Last 1
                Write-Output "📅 Letzter automatischer Sync: $lastRun"
            }
        }
    }
    
    Write-Output ("=" * 80)
}

Main
