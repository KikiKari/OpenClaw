#!/usr/bin/env pwsh
# sync_agent_cron.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
# auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

<#
ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync
#>

$ErrorActionPreference = "Stop"

# Konfiguration
$CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
$GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"
$LOG_FILE = "/home/openclaw/.openclaw/workspace/logs/sync-agent.log"

# Hilfsfunktionen
function Get-FileModificationTime($path) {
    try {
        $files = Get-ChildItem -Path $path -Recurse -File | Where-Object { $_.FullName -notlike "*.git*" }
        if ($files.Count -eq 0) { return 0 }
        $latest = ($files | Measure-Object -Property LastWriteTime -Maximum).Maximum
        return [double]([DateTimeOffset]$latest).ToUnixTimeSeconds()
    } catch {
        return 0
    }
}

function Write-ToLog($message, $level = "INFO") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[${timestamp}] [${level}] ${message}"
    Write-Host $entry
    Add-Content -Path $LOG_FILE -Value $entry
}

# Importiere externe Funktionen (angenommen sie sind als PowerShell-Funktionen verfügbar)
# In PowerShell müssen diese Funktionen entweder direkt implementiert oder über Module geladen werden
# Für dieses Beispiel nehmen wir an, dass sync_to_git, sync_to_clawhub, validate_skill als Funktionen existieren

function sync_to_git($skill, $dry_run = $true) {
    # Implementierung hier entsprechend der Python-Version
    # Dummy-Implementierung für das Beispiel
    return $true
}

function sync_to_clawhub($skill, $dry_run = $true) {
    # Implementierung hier entsprechend der Python-Version
    # Dummy-Implementierung für das Beispiel
    return $true
}

function validate_skill($path) {
    # Implementierung hier entsprechend der Python-Version
    # Dummy-Implementierung für das Beispiel
    return Test-Path $path
}

# Hauptprogramm
Write-ToLog ("=" * 70)
Write-ToLog "CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF"
Write-ToLog "Zeitstempel: $(Get-Date -Format o)"
Write-ToLog ("=" * 70)

# Hole Skill-Verzeichnisse
$clawhubSkills = @{}
Get-ChildItem -Path $CLAWHUB_DIR -Directory | Where-Object { !$_.Name.StartsWith(".") } | ForEach-Object {
    $clawhubSkills[$_.Name] = $_.FullName
}

$gitSkills = @{}
Get-ChildItem -Path $GIT_DIR -Directory | Where-Object { !$_.Name.StartsWith(".") } | ForEach-Object {
    $gitSkills[$_.Name] = $_.FullName
}

# DRY-RUN: Erkenne Änderungen
Write-ToLog ""
Write-ToLog "[DRY-RUN] Analysiere Änderungen..."

$changesDetected = @{
    new_in_clawhub = @()
    new_in_git = @()
    clawhub_newer = @()
    git_newer = @()
    synced = @()
}

# 1. Neue Skills
$newInClawhub = Compare-Object $clawhubSkills.Keys $gitSkills.Keys | Where-Object { $_.SideIndicator -eq "<=" } | ForEach-Object { $_.InputObject }
$newInGit = Compare-Object $clawhubSkills.Keys $gitSkills.Keys | Where-Object { $_.SideIndicator -eq "=>" } | ForEach-Object { $_.InputObject }

$changesDetected.new_in_clawhub = $newInClawhub | Sort-Object
$changesDetected.new_in_git = $newInGit | Sort-Object

# 2. Existierende prüfen
$inBoth = $clawhubSkills.Keys | Where-Object { $gitSkills.ContainsKey($_) } | Sort-Object
foreach ($skill in $inBoth) {
    $cMtime = Get-FileModificationTime "$CLAWHUB_DIR/$skill"
    $gMtime = Get-FileModificationTime "$GIT_DIR/$skill"
    $diff = $cMtime - $gMtime
    
    if ([Math]::Abs($diff) -gt 60) {
        if ($diff -gt 0) {
            $changesDetected.clawhub_newer += @(@($skill, $diff))
        } else {
            $changesDetected.git_newer += @(@($skill, [Math]::Abs($diff)))
        }
    } else {
        $changesDetected.synced += $skill
    }
}

# Report
$totalChanges = $newInClawhub.Count + $newInGit.Count + $changesDetected.clawhub_newer.Count + $changesDetected.git_newer.Count
Write-ToLog "Neu in ClawHub: $($newInClawhub.Count)"
Write-ToLog "Neu in Git: $($newInGit.Count)"
Write-ToLog "ClawHub neuer: $($changesDetected.clawhub_newer.Count)"
Write-ToLog "Git neuer: $($changesDetected.git_newer.Count)"
Write-ToLog "Synchron: $($changesDetected.synced.Count)"

if ($totalChanges -eq 0) {
    Write-ToLog ""
    Write-ToLog "✅ Keine Änderungen erkannt. Sync nicht nötig."
    Write-ToLog ("=" * 70)
    exit 0
}

Write-ToLog ""
Write-ToLog "🔄 $totalChanges Änderungen erkannt - starte Synchronisation..."

# ECHTE SYNCHRONISATION
$results = @{
    synced_to_git = @()
    synced_to_clawhub = @()
    up_to_date = @()
    errors = @()
}

# 1. NEU in ClawHub → zu Git
foreach ($skill in $newInClawhub) {
    try {
        if (validate_skill "$CLAWHUB_DIR/$skill") {
            Write-ToLog "→ Synchronisiere $skill zu Git..."
            if (sync_to_git $skill $false) {
                $gitPath = "$GIT_DIR/$skill"
                Push-Location $gitPath
                git init -q 2>$null
                git add . -f 2>$null
                $dt = Get-Date -Format "yyyy-MM-dd HH:mm"
                git commit -m "Initial: $skill" -q 2>$null
                Pop-Location
                $results.synced_to_git += $skill
                Write-ToLog "  ✓ $skill synchronisiert"
            }
        } else {
            $results.errors += "${skill} (invalid)"
        }
    } catch {
        Write-ToLog "  ✗ ERROR: $skill - $_" "ERROR"
        $results.errors += $skill
    }
}

# 2. NEU in Git → zu ClawHub
foreach ($skill in $newInGit) {
    try {
        if (validate_skill "$GIT_DIR/$skill") {
            Write-ToLog "→ Synchronisiere $skill zu ClawHub..."
            if (sync_to_clawhub $skill $false) {
                $results.synced_to_clawhub += $skill
                Write-ToLog "  ✓ $skill synchronisiert"
            }
        } else {
            $results.errors += "${skill} (invalid)"
        }
    } catch {
        Write-ToLog "  ✗ ERROR: $skill - $_" "ERROR"
        $results.errors += $skill
    }
}

# 3. Updates
foreach ($item in $changesDetected.clawhub_newer) {
    $skill = $item[0]
    $diff = $item[1]
    try {
        Write-ToLog "→ Update $skill (ClawHub +$([Math]::Round($diff))s neuer)..."
        if (sync_to_git $skill $false) {
            $gitPath = "$GIT_DIR/$skill"
            Push-Location $gitPath
            git add . -f 2>$null
            $dt = Get-Date -Format "yyyy-MM-dd HH:mm"
            git commit -m "Sync from ClawHub: $dt" -q 2>$null
            Pop-Location
            $results.synced_to_git += $skill
            Write-ToLog "  ✓ $skill aktualisiert"
        }
    } catch {
        Write-ToLog "  ✗ ERROR: $skill - $_" "ERROR"
        $results.errors += $skill
    }
}

foreach ($item in $changesDetected.git_newer) {
    $skill = $item[0]
    $diff = $item[1]
    try {
        Write-ToLog "→ Update $skill (Git +$([Math]::Round($diff))s neuer)..."
        if (sync_to_clawhub $skill $false) {
            $results.synced_to_clawhub += $skill
            Write-ToLog "  ✓ $skill aktualisiert"
        }
    } catch {
        Write-ToLog "  ✗ ERROR: $skill - $_" "ERROR"
        $results.errors += $skill
    }
}

$results.up_to_date = $changesDetected.synced

# ZUSAMMENFASSUNG
Write-ToLog ""
Write-ToLog ("=" * 70)
Write-ToLog "SYNCHRONISATION ABGESCHLOSSEN"
Write-ToLog ("=" * 70)
Write-ToLog "Zu Git synchronisiert:     $($results.synced_to_git.Count)"
Write-ToLog "Zu ClawHub synchronisiert: $($results.synced_to_clawhub.Count)"
Write-ToLog "Bereits aktuell:           $($results.up_to_date.Count)"
Write-ToLog "Fehler:                    $($results.errors.Count)"
if ($results.errors.Count -gt 0) {
    Write-ToLog "  Fehlerhafte: $($results.errors -join ', ')"
}
Write-ToLog ("=" * 70)

# State speichern
$STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json"
$stateDir = Split-Path $STATE_FILE -Parent
if (!(Test-Path $stateDir)) {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
}

$state = @{
    last_run = (Get-Date).ToString("o")
    results = $results
    changes_detected = @{
        new_in_clawhub = $changesDetected.new_in_clawhub.Count
        new_in_git = $changesDetected.new_in_git.Count
        clawhub_newer = $changesDetected.clawhub_newer.Count
        git_newer = $changesDetected.git_newer.Count
        synced = $changesDetected.synced.Count
    }
}

$state | ConvertTo-Json -Depth 10 | Set-Content $STATE_FILE
Write-ToLog "State gespeichert: $STATE_FILE"
