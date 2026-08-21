#!/usr/bin/env pwsh
# sync_agent_run.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_run.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_run.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

<#
ClawHub ↔ Git Sync Agent - Produktionslauf
#>

$env:PYTHONPATH = "/home/openclaw/.openclaw/workspace/scripts"
$CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
$GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"

function file_mtime($path) {
    try {
        $files = Get-ChildItem -Path $path -Recurse -File | Where-Object { $_.FullName -notlike "*.git*" }
        if ($files.Count -eq 0) { return 0 }
        $maxTime = ($files | ForEach-Object { $_.LastWriteTimeUtc.Ticks } | Measure-Object -Maximum).Maximum
        return [double]$maxTime / 10000000  # ticks to seconds
    } catch {
        return 0
    }
}

function log($message, $level = "INFO") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $message"
}

function validate_skill($skillPath) {
    # Call Python function via subprocess since it's defined there
    $cmd = "python3 -c ""import sys; sys.path.append('/home/openclaw/.openclaw/workspace/scripts'); from sync_clawhub_git import validate_skill; print(validate_skill('$skillPath'))"""
    $result = Invoke-Expression $cmd
    return [System.Convert]::ToBoolean($result.Trim())
}

function sync_to_git($skill, $dry_run) {
    # Call Python function via subprocess since it's defined there
    $cmd = "python3 -c ""import sys; sys.path.append('/home/openclaw/.openclaw/workspace/scripts'); from sync_clawhub_git import sync_to_git; print(sync_to_git('$skill', $dry_run))"""
    $result = Invoke-Expression $cmd
    return [System.Convert]::ToBoolean($result.Trim())
}

function sync_to_clawhub($skill, $dry_run) {
    # Call Python function via subprocess since it's defined there
    $cmd = "python3 -c ""import sys; sys.path.append('/home/openclaw/.openclaw/workspace/scripts'); from sync_clawhub_git import sync_to_clawhub; print(sync_to_clawhub('$skill', $dry_run))"""
    $result = Invoke-Expression $cmd
    return [System.Convert]::ToBoolean($result.Trim())
}

log ("=" * 70)
log "CLAWHUB ↔ GIT SYNC AGENT - PRODUKTIONS-LAUF"
log "Zeitstempel: $(Get-Date -Format o)"
log ("=" * 70)

$clawhubDirs = Get-ChildItem -Path $CLAWHUB_DIR -Directory | Where-Object { !$_.Name.StartsWith(".") }
$gitDirs = Get-ChildItem -Path $GIT_DIR -Directory | Where-Object { !$_.Name.StartsWith(".") }

$clawhubSkills = $clawhubDirs | ForEach-Object { $_.Name }
$gitSkills = $gitDirs | ForEach-Object { $_.Name }

$results = @{
    synced_to_git      = @()
    synced_to_clawhub  = @()
    up_to_date         = @()
    errors             = @()
}

# 1. NEU in ClawHub → zu Git syncen
log ""
log "[PHASE 1] ClawHub → Git Synchronisation"
log ("-" * 40)

$newInClawhub = Compare-Object $clawhubSkills $gitSkills | Where-Object { $_.SideIndicator -eq "<=" } | ForEach-Object { $_.InputObject }
$newInClawhub = $newInClawhub | Sort-Object

foreach ($skill in $newInClawhub) {
    try {
        $skillPath = Join-Path $CLAWHUB_DIR $skill
        if (validate_skill $skillPath) {
            log "→ Synchronisiere $skill zu Git..."
            if (sync_to_git $skill $false) {
                # Git init
                $gitPath = Join-Path $GIT_DIR $skill
                Set-Location $gitPath
                git init -q 2>$null
                git add . -f 2>$null
                $dt = Get-Date -Format "yyyy-MM-dd HH:mm"
                git commit -m "Initial: $skill" -q 2>$null
                $results.synced_to_git += $skill
                log "  ✓ $skill synchronisiert & Git initialisiert"
            } else {
                $results.errors += "$skill (sync failed)"
            }
        } else {
            $results.errors += "$skill (invalid)"
        }
    } catch {
        log "  ✗ ERROR: $skill - $_" "ERROR"
        $results.errors += "$skill (exception)"
    }
}

# 2. In beiden - prüfe Änderungen
log ""
log "[PHASE 2] Prüfe existierende Skills auf Änderungen"
log ("-" * 40)

$inBoth = Compare-Object $clawhubSkills $gitSkills -IncludeEqual | Where-Object { $_.SideIndicator -eq "==" } | ForEach-Object { $_.InputObject }
$inBoth = $inBoth | Sort-Object

foreach ($skill in $inBoth) {
    try {
        $cPath = Join-Path $CLAWHUB_DIR $skill
        $gPath = Join-Path $GIT_DIR $skill
        $cMtime = file_mtime $cPath
        $gMtime = file_mtime $gPath
        $diff = $cMtime - $gMtime

        if ([Math]::Abs($diff) -gt 60) {
            if ($diff -gt 0) {
                log "→ $skill`: ClawHub neuer (+$([Math]::Floor($diff))s) → sync zu Git"
                if (sync_to_git $skill $false) {
                    $gitPath = Join-Path $GIT_DIR $skill
                    Set-Location $gitPath
                    git add . -f 2>$null
                    $dt = Get-Date -Format "yyyy-MM-dd HH:mm"
                    git commit -m "Sync from ClawHub: $dt" -q 2>$null
                    $results.synced_to_git += $skill
                } else {
                    $results.errors += "$skill (update failed)"
                }
            } else {
                log "→ $skill`: Git neuer (+$([Math]::Floor([Math]::Abs($diff)))s) → sync zu ClawHub"
                if (sync_to_clawhub $skill $false) {
                    $results.synced_to_clawhub += $skill
                } else {
                    $results.errors += "$skill (update failed)"
                }
            }
        } else {
            $results.up_to_date += $skill
        }
    } catch {
        log "  ✗ ERROR: $skill - $_" "ERROR"
        $results.errors += "$skill (exception)"
    }
}

# ZUSAMMENFASSUNG
log ""
log ("=" * 70)
log "SYNCHRONISATION ABGESCHLOSSEN"
log ("=" * 70)
log "Zu Git synchronisiert:     $($results.synced_to_git.Count)"
if ($results.synced_to_git.Count -gt 0) {
    log "  $($results.synced_to_git -join ', ')"
}
log "Zu ClawHub synchronisiert: $($results.synced_to_clawhub.Count)"
if ($results.synced_to_clawhub.Count -gt 0) {
    log "  $($results.synced_to_clawhub -join ', ')"
}
log "Bereits aktuell:           $($results.up_to_date.Count)"
log "Fehler:                    $($results.errors.Count)"
if ($results.errors.Count -gt 0) {
    log "  $($results.errors -join ', ')"
}
log ("=" * 70)

# Speichere State
$STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json"
$stateDir = Split-Path $STATE_FILE -Parent
if (!(Test-Path $stateDir)) {
    New-Item -ItemType Directory -Path $stateDir -Force > $null
}

$state = @{
    last_run = (Get-Date).ToString("o")
    results  = $results
}

$state | ConvertTo-Json -Depth 10 | Out-File -FilePath $STATE_FILE -Encoding utf8
log "State gespeichert: $STATE_FILE"
