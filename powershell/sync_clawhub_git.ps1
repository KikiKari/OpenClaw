#!/usr/bin/env pwsh
# sync_clawhub_git.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:scripts/sync_clawhub_git.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

<#
Bidirektionale ClawHub ↔ Git Synchronisation
#>

# Konfiguration
$CLAWHUB_DIR = [System.IO.Path]::Combine($env:HOME, ".openclaw", "workspace", "skills")
$GIT_DIR = [System.IO.Path]::Combine($env:HOME, ".openclaw", "workspace", "git", "skills")
$BACKUP_DIR = [System.IO.Path]::Combine($env:HOME, ".openclaw", "workspace", "backups", "sync")
$LOG_FILE = [System.IO.Path]::Combine($env:HOME, ".openclaw", "workspace", "logs", "sync-agent.log")

# Erstelle Verzeichnisse
New-Item -ItemType Directory -Path $GIT_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $LOG_FILE) -Force | Out-Null

# Logging
function Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Entry = "[${Timestamp}] [$Level] $Message"
    Write-Host $Entry
    Add-Content -Path $LOG_FILE -Value $Entry
}

# Validierung
function Validate-Skill {
    param([string]$SkillDir)
    
    $skillPath = [System.IO.Path]::Combine($SkillDir, "SKILL.md")
    if (-not (Test-Path $skillPath)) {
        Log "Validation failed: $(Split-Path $SkillDir -Leaf) missing SKILL.md" "ERROR"
        return $false
    }
    return $true
}

# Backup
function Create-Backup {
    param([string]$Source, [string]$SkillName)
    
    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $BackupPath = [System.IO.Path]::Combine($BACKUP_DIR, "${SkillName}_${Timestamp}")
    
    # Backup verzeichnis löschen falls es existiert
    if (Test-Path $BackupPath) {
        try {
            Remove-Item -Recurse -Force $BackupPath
            Log "Removed existing backup: $BackupPath"
        } catch {
            Log "Failed to remove existing backup ${BackupPath}: $_" "ERROR"
            return $false
        }
    }
    
    try {
        Copy-Item -Recurse -Path $Source -Destination $BackupPath
        Log "Backup created: $BackupPath"
        return $true
    } catch {
        Log "Backup failed: $_" "ERROR"
        return $false
    }
}

# Hash-Vergleich
function Get-FileHash256 {
    param([string]$FilePath)
    
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($FilePath)
        $hashBytes = $hasher.ComputeHash($stream)
        $stream.Close()
        return [BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    } finally {
        $hasher.Dispose()
    }
}

# Sync Richtung ClawHub → Git
function Sync-ToGit {
    param([string]$SkillName, [bool]$DryRun = $true)
    
    $source = [System.IO.Path]::Combine($CLAWHUB_DIR, $SkillName)
    $target = [System.IO.Path]::Combine($GIT_DIR, $SkillName)
    
    if (-not (Validate-Skill $source)) {
        return $false
    }
    
    # Backup vor Änderungen (nur wenn target existiert)
    if (-not $DryRun -and (Test-Path $target)) {
        Create-Backup $target $SkillName | Out-Null
    }
    
    # Änderungen erkennen
    $changes = @()
    $sourceItems = Get-ChildItem -Path $source -Recurse -File
    
    foreach ($item in $sourceItems) {
        $relPath = Resolve-Path -Relative -Path $item.FullName -RelativeBasePath $source
        if ($relPath.StartsWith(".\")) { $relPath = $relPath.Substring(2) }
        $tgtFile = [System.IO.Path]::Combine($target, $relPath)
        
        # Vergleich
        if (-not (Test-Path $tgtFile)) {
            $changes += "ADD $relPath"
        } else {
            $srcHash = Get-FileHash256 $item.FullName
            $tgtHash = Get-FileHash256 $tgtFile
            if ($srcHash -ne $tgtHash) {
                $changes += "UPDATE $relPath"
            }
        }
    }
    
    # Dry-Run Report
    if ($DryRun) {
        Log "DRY-RUN: $SkillName - $($changes.Count) changes"
        foreach ($change in $changes) {
            Log "  $change"
        }
        return $true
    }
    
    # Echte Synchronisation
    Log "SYNC: $SkillName - Applying $($changes.Count) changes"
    if (Test-Path $target) {
        Copy-Item -Recurse -Path "$source/*" -Destination $target -Force -Exclude ".git"
    } else {
        New-Item -ItemType Directory -Path $target | Out-Null
        Copy-Item -Recurse -Path "$source/*" -Destination $target -Exclude ".git"
    }
    Log "SYNC: $SkillName - Complete"
    return $true
}

# Sync Richtung Git → ClawHub
function Sync-ToClawHub {
    param([string]$SkillName, [bool]$DryRun = $true)
    
    $source = [System.IO.Path]::Combine($GIT_DIR, $SkillName)
    $target = [System.IO.Path]::Combine($CLAWHUB_DIR, $SkillName)
    
    if (-not (Validate-Skill $source)) {
        return $false
    }
    
    # Backup vor Änderungen (nur wenn target existiert)
    if (-not $DryRun -and (Test-Path $target)) {
        Create-Backup $target $SkillName | Out-Null
    }

    # Änderungen erkennen (gleiche Logik wie oben)
    $changes = @()
    $sourceItems = Get-ChildItem -Path $source -Recurse -File
    
    foreach ($item in $sourceItems) {
        $relPath = Resolve-Path -Relative -Path $item.FullName -RelativeBasePath $source
        if ($relPath.StartsWith(".\")) { $relPath = $relPath.Substring(2) }
        $tgtFile = [System.IO.Path]::Combine($target, $relPath)
        
        if (-not (Test-Path $tgtFile)) {
            $changes += "ADD $relPath"
        } else {
            $srcHash = Get-FileHash256 $item.FullName
            $tgtHash = Get-FileHash256 $tgtFile
            if ($srcHash -ne $tgtHash) {
                $changes += "UPDATE $relPath"
            }
        }
    }

    # Dry-Run Report
    if ($DryRun) {
        Log "DRY-RUN: $SkillName - $($changes.Count) changes"
        foreach ($change in $changes) {
            Log "  $change"
        }
        return $true
    }

    # Echte Synchronisation
    Log "SYNC: $SkillName - Applying $($changes.Count) changes"
    if (Test-Path $target) {
        Copy-Item -Recurse -Path "$source/*" -Destination $target -Force -Exclude ".git"
    } else {
        New-Item -ItemType Directory -Path $target | Out-Null
        Copy-Item -Recurse -Path "$source/*" -Destination $target -Exclude ".git"
    }
    Log "SYNC: $SkillName - Complete"
    return $true
}

# Hauptfunktion
function Main {
    param(
        [Parameter(Mandatory=$true)][string]$Skill,
        [Parameter(Mandatory=$true)][ValidateSet("to-git", "to-clawhub")][string]$Direction,
        [switch]$DryRun,
        [switch]$Force
    )
    
    Log "Starting sync: $Skill ($Direction)"
    
    $success = $false
    if ($Direction -eq 'to-git') {
        $success = Sync-ToGit $Skill $DryRun.IsPresent
    } else {
        $success = Sync-ToClawHub $Skill $DryRun.IsPresent
    }
    
    if (-not $success) {
        Log "Sync failed" "ERROR"
        exit 1
    }
    
    Log "Sync completed"
}

# Parameter parsing
$paramDictionary = @{}
foreach ($arg in $args) {
    if ($arg -match '^--([^=]+)=(.+)$') {
        $key = $matches[1].Replace('-', '')
        $value = $matches[2]
        $paramDictionary[$key] = $value
    } elseif ($arg -match '^--(.+)$') {
        $key = $matches[1].Replace('-', '')
        $paramDictionary[$key] = $true
    }
}

# Convert parameters to proper types and call main
$params = @{
    Skill = $paramDictionary['skill']
    Direction = $paramDictionary['direction']
    DryRun = [bool]$paramDictionary['dryrun']
    Force = [bool]$paramDictionary['force']
}

Main @params
