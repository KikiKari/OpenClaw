#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "034f2137e148b58a0409325b43e4b394997d11a86779e3f696d01f92d82cf804", "source_sha256": "2a279f44187e822afbb6a0af5593a2890c8e99b41f885f5d063355b6ea20b921", "target_language": "powershell"}
# sync_clawhub_git.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:scripts/sync_clawhub_git.py
# auch in: Projects@clawhub:clawhub/Skills/sync_clawhub_git.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Bidirektionale ClawHub ↔ Git Synchronisation
#>

# Konfiguration
# Resolve paths relative to this repository so the helper works both in the
# hosted workspace and in environments without a /workspace mount.
$WORKSPACE_ROOT = (Get-Item $PSScriptRoot).Parent.FullName
$CLAWHUB_DIR = Join-Path $WORKSPACE_ROOT "skills"
$GIT_DIR = Join-Path $WORKSPACE_ROOT "git" "skills"
$BACKUP_DIR = Join-Path $WORKSPACE_ROOT "backups" "sync"
$LOG_FILE = Join-Path $WORKSPACE_ROOT "logs" "sync-agent.log"
$IGNORED_NAMES = @(".git", ".clawhub", "node_modules", "__pycache__", ".pytest_cache")
$RESERVED_SKILL_NAMES = @("github-clones", "skills", "backups", ".restore", "git", "Abstraktionen")
$PRESERVED_TARGET_NAMES = $IGNORED_NAMES

# Erstelle Verzeichnisse
New-Item -ItemType Directory -Path $GIT_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $LOG_FILE -Parent) -Force | Out-Null

# Logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[${timestamp}] [${Level}] ${Message}"
    Write-Output $entry
    Add-Content -Path $LOG_FILE -Value $entry
}

# Validierung
function Test-SkillValidation {
    param([string]$SkillDir)
    
    $skillName = Split-Path $SkillDir -Leaf
    
    if ($RESERVED_SKILL_NAMES -contains $skillName) {
        Write-Log "Validation failed: ${skillName} is reserved and must not be synced as a skill" "ERROR"
        return $false
    }
    
    $skillMdPath = Join-Path $SkillDir "SKILL.md"
    if (-not (Test-Path $skillMdPath)) {
        Write-Log "Validation failed: ${skillName} missing SKILL.md" "ERROR"
        return $false
    }
    
    return $true
}

function Test-IgnoredPath {
    param([string]$Path)
    
    $parts = $Path.Split([System.IO.Path]::DirectorySeparatorChar)
    foreach ($part in $parts) {
        if ($IGNORED_NAMES -contains $part -or $part.StartsWith("__pycache__")) {
            return $true
        }
    }
    
    return $Path.EndsWith(".pyc")
}

function Test-GeneratedDuplicatePath {
    param(
        [string]$Root,
        [string]$RelPath
    )
    
    $rootName = Split-Path $Root -Leaf
    $parts = $RelPath.Split([System.IO.Path]::DirectorySeparatorChar)
    
    if ($parts.Count -eq 0) {
        return $false
    }
    
    if ($parts[0] -eq $rootName) {
        return $true
    }
    
    for ($i = 1; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -eq $parts[$i - 1]) {
            return $true
        }
    }
    
    return $false
}

function Get-SyncFiles {
    param([string]$Root)
    
    $files = @()
    $queue = @($Root)
    
    while ($queue.Count -gt 0) {
        $current = $queue[0]
        $queue = $queue[1..($queue.Count - 1)]
        
        $relRoot = $current.Substring($Root.Length).TrimStart("\")
        if ($relRoot -and (Test-IgnoredPath $relRoot)) {
            continue
        }
        
        $items = Get-ChildItem -Path $current -Force
        $dirs = $items | Where-Object { $_.PSIsContainer }
        $fileItems = $items | Where-Object { -not $_.PSIsContainer }
        
        # Filter directories
        $keptDirs = @()
        foreach ($dir in $dirs) {
            if ($IGNORED_NAMES -contains $dir.Name -or $dir.Name.StartsWith("__pycache__")) {
                continue
            }
            
            $relDir = if ($relRoot) { Join-Path $relRoot $dir.Name } else { $dir.Name }
            if (Test-GeneratedDuplicatePath $Root $relDir) {
                continue
            }
            
            $keptDirs += $dir
        }
        
        # Process files
        foreach ($file in $fileItems) {
            if ($IGNORED_NAMES -contains $file.Name -or $file.Name.EndsWith(".pyc")) {
                continue
            }
            
            $relPath = if ($relRoot) { Join-Path $relRoot $file.Name } else { $file.Name }
            if (Test-IgnoredPath $relPath) {
                continue
            }
            
            if (Test-GeneratedDuplicatePath $Root $relPath) {
                continue
            }
            
            if ($file.Name -eq "SKILL.md" -and $relPath -ne "SKILL.md") {
                continue
            }
            
            if ($file.PSIsContainer) {
                continue
            }
            
            $files += [PSCustomObject]@{
                FullPath = $file.FullName
                RelPath = $relPath
            }
        }
        
        # Add directories to queue
        foreach ($dir in $keptDirs) {
            $queue += $dir.FullName
        }
    }
    
    return $files
}

function Reset-SyncTarget {
    param([string]$Target)
    
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    
    $children = Get-ChildItem -Path $Target -Force
    foreach ($child in $children) {
        if ($PRESERVED_TARGET_NAMES -contains $child.Name) {
            continue
        }
        
        if ($child.PSIsContainer -and -not $child.LinkType) {
            Remove-Item -Path $child.FullName -Recurse -Force
        } else {
            Remove-Item -Path $child.FullName -Force
        }
    }
}

function Copy-SyncFiles {
    param(
        [string]$Source,
        [string]$Target
    )
    
    Reset-SyncTarget -Target $Target
    
    $files = Get-SyncFiles -Root $Source
    foreach ($file in $files) {
        $destFile = Join-Path $Target $file.RelPath
        $destDir = Split-Path $destFile -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        Copy-Item -Path $file.FullPath -Destination $destFile -Force
    }
}

# Backup
function Create-Backup {
    param([string]$Source, [string]$SkillName)
    
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupPath = Join-Path $BACKUP_DIR "${SkillName}_${timestamp}"
    
    # Backup verzeichnis löschen falls es existiert
    if (Test-Path $backupPath) {
        try {
            Remove-Item -Path $backupPath -Recurse -Force
            Write-Log "Removed existing backup: ${backupPath}"
        } catch {
            Write-Log "Failed to remove existing backup ${backupPath}: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    
    try {
        Copy-Item -Path $Source -Destination $backupPath -Recurse -Force
        Write-Log "Backup created: ${backupPath}"
        return $true
    } catch {
        Write-Log "Backup failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Hash-Vergleich
function Get-FileHash {
    param([string]$FilePath)
    
    # Ensure the path points to a regular file.
    if (-not (Test-Path $FilePath -PathType Leaf)) {
        return ""
    }
    
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        return $hash.Hash.ToLower()
    } catch {
        Write-Log "Failed to hash ${FilePath}: $($_.Exception.Message)" "ERROR"
        return ""
    }
}

# Sync Richtung ClawHub → Git
function Sync-ToGit {
    param(
        [string]$SkillName,
        [bool]$DryRun = $true
    )
    
    $source = Join-Path $CLAWHUB_DIR $SkillName
    $target = Join-Path $GIT_DIR $SkillName
    
    if (-not (Test-SkillValidation -SkillDir $source)) {
        return $false
    }
    
    # Backup vor Änderungen (nur wenn target existiert)
    if (-not $DryRun -and (Test-Path $target)) {
        Create-Backup -Source $target -SkillName $SkillName
    }
    
    # Änderungen erkennen
    $changes = @()
    $files = Get-SyncFiles -Root $source
    foreach ($file in $files) {
        $tgtFile = Join-Path $target $file.RelPath
        if (-not (Test-Path $tgtFile)) {
            $changes += "ADD $($file.RelPath)"
        } elseif ((Get-FileHash -FilePath $file.FullPath) -ne (Get-FileHash -FilePath $tgtFile)) {
            $changes += "UPDATE $($file.RelPath)"
        }
    }
    
    # Dry-Run Report
    if ($DryRun) {
        Write-Log "DRY-RUN: ${SkillName} - $($changes.Count) changes"
        foreach ($change in $changes) {
            Write-Log "  ${change}"
        }
        return $true
    }
    
    # Echte Synchronisation
    Write-Log "SYNC: ${SkillName} - Applying $($changes.Count) changes"
    Copy-SyncFiles -Source $source -Target $target
    Write-Log "SYNC: ${SkillName} - Complete"
    return $true
}

# Sync Richtung Git → ClawHub
function Sync-ToClawHub {
    param(
        [string]$SkillName,
        [bool]$DryRun = $true
    )
    
    $source = Join-Path $GIT_DIR $SkillName
    $target = Join-Path $CLAWHUB_DIR $SkillName
    
    if (-not (Test-SkillValidation -SkillDir $source)) {
        return $false
    }
    
    # Backup vor Änderungen (nur wenn target existiert)
    if (-not $DryRun -and (Test-Path $target)) {
        Create-Backup -Source $target -SkillName $SkillName
    }
    
    # Änderungen erkennen (gleiche Logik wie oben)
    $changes = @()
    $files = Get-SyncFiles -Root $source
    foreach ($file in $files) {
        $tgtFile = Join-Path $target $file.RelPath
        if (-not (Test-Path $tgtFile)) {
            $changes += "ADD $($file.RelPath)"
        } elseif ((Get-FileHash -FilePath $file.FullPath) -ne (Get-FileHash -FilePath $tgtFile)) {
            $changes += "UPDATE $($file.RelPath)"
        }
    }
    
    # Dry-Run Report
    if ($DryRun) {
        Write-Log "DRY-RUN: ${SkillName} - $($changes.Count) changes"
        foreach ($change in $changes) {
            Write-Log "  ${change}"
        }
        return $true
    }
    
    # Echte Synchronisation
    Write-Log "SYNC: ${SkillName} - Applying $($changes.Count) changes"
    Copy-SyncFiles -Source $source -Target $target
    Write-Log "SYNC: ${SkillName} - Complete"
    return $true
}

# Hauptfunktion
function Main {
    param(
        [Parameter(Mandatory=$true)][string]$Skill,
        [Parameter(Mandatory=$true)][ValidateSet('to-git', 'to-clawhub')][string]$Direction,
        [switch]$DryRun,
        [switch]$Force
    )
    
    Write-Log "Starting sync: ${Skill} (${Direction})"
    
    $success = $false
    if ($Direction -eq 'to-git') {
        $success = Sync-ToGit -SkillName $Skill -DryRun $DryRun.IsPresent
    } else {
        $success = Sync-ToClawHub -SkillName $Skill -DryRun $DryRun.IsPresent
    }
    
    if (-not $success) {
        Write-Log "Sync failed" "ERROR"
        exit 1
    }
    
    Write-Log "Sync completed"
}

# Parse command line arguments
$params = @{}
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--skill" {
            $i++
            $params.Skill = $args[$i]
        }
        "--direction" {
            $i++
            $params.Direction = $args[$i]
        }
        "--dry-run" {
            $params.DryRun = $true
        }
        "--force" {
            $params.Force = $true
        }
    }
}

Main @params
