#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "5c070d555d1cbb701a0ecd750a38e700413a9a3ad7b16db919cfd88585c56b25", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "powershell"}
# check_conflicts.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

<#
Check Conflicts - Erkennt Sync-Konflikte
#>

# Import sync functions
$scriptPath = "/home/openclaw/.openclaw/workspace/scripts"
$env:PYTHONPATH = $scriptPath
$pythonScript = @"
import sys
import hashlib
def get_file_hash(filepath):
    hasher = hashlib.md5()
    with open(filepath, 'rb') as f:
        buf = f.read()
        hasher.update(buf)
    return hasher.hexdigest()
"@

function Get-FileHashPython {
    param(
        [string]$FilePath
    )
    $hash = & python3 -c "$pythonScript; print(get_file_hash('$FilePath'))" 2>$null
    return $hash
}

$CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
$GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"

function Check-Conflicts {
    <#
    .SYNOPSIS
    Prüft auf Konflikte zwischen ClawHub und Git
    #>
    
    $conflicts = @()
    
    # Alle Skills die in beiden Orten existieren
    $commonSkills = @()
    if (Test-Path $CLAWHUB_DIR -and Test-Path $GIT_DIR) {
        $clawhubSkills = Get-ChildItem -Path $CLAWHUB_DIR -Directory | ForEach-Object { $_.Name }
        $gitSkills = Get-ChildItem -Path $GIT_DIR -Directory | ForEach-Object { $_.Name }
        $commonSkills = $clawhubSkills | Where-Object { $gitSkills -contains $_ }
    }
    
    Write-Host "Prüfe $($commonSkills.Count) Skills auf Konflikte...`n"
    
    foreach ($skill in ($commonSkills | Sort-Object)) {
        $clawhubPath = Join-Path $CLAWHUB_DIR $skill
        $gitPath = Join-Path $GIT_DIR $skill
        
        # Alle Dateien vergleichen
        $skillConflicts = @()
        
        # ClawHub Dateien
        $clawhubFiles = @{}
        Get-ChildItem -Path $clawhubPath -Recurse -File | Where-Object { $_.FullName -notlike "*.git*" } | ForEach-Object {
            $relPath = $_.FullName.Substring($clawhubPath.Length + 1)
            $clawhubFiles[$relPath] = $_
        }
        
        # Git Dateien
        $gitFiles = @{}
        Get-ChildItem -Path $gitPath -Recurse -File | Where-Object { $_.FullName -notlike "*.git*" } | ForEach-Object {
            $relPath = $_.FullName.Substring($gitPath.Length + 1)
            $gitFiles[$relPath] = $_
        }
        
        # Vergleiche gemeinsame Dateien
        $commonFiles = $clawhubFiles.Keys | Where-Object { $gitFiles.ContainsKey($_) }
        foreach ($relPath in $commonFiles) {
            $clawhubFile = $clawhubFiles[$relPath]
            $gitFile = $gitFiles[$relPath]
            
            $clawhubHash = Get-FileHashPython -FilePath $clawhubFile.FullName
            $gitHash = Get-FileHashPython -FilePath $gitFile.FullName
            
            if ($clawhubHash -ne $gitHash) {
                $clawhubMtime = [DateTimeOffset]::FromUnixTimeSeconds($clawhubFile.LastWriteTime.ToUnixTimeSeconds()).DateTime
                $gitMtime = [DateTimeOffset]::FromUnixTimeSeconds($gitFile.LastWriteTime.ToUnixTimeSeconds()).DateTime
                
                $newer = if ($clawhubMtime -gt $gitMtime) { "clawhub" } else { "git" }
                
                $skillConflicts += @{
                    "file" = $relPath
                    "clawhub_modified" = $clawhubMtime.ToString('yyyy-MM-dd HH:mm:ss')
                    "git_modified" = $gitMtime.ToString('yyyy-MM-dd HH:mm:ss')
                    "newer" = $newer
                }
            }
        }
        
        if ($skillConflicts.Count -gt 0) {
            $conflicts += @{
                "skill" = $skill
                "conflicts" = $skillConflicts
            }
        }
    }
    
    # Ausgabe
    if ($conflicts.Count -gt 0) {
        Write-Host "⚠️  KONFLIKTE GEFUNDEN:"
        Write-Host ("=" * 80)
        
        foreach ($conflict in $conflicts) {
            Write-Host "`n📦 Skill: $($conflict.skill)"
            Write-Host ("-" * 40)
            
            foreach ($fileConflict in $conflict.conflicts) {
                Write-Host "  📄 $($fileConflict.file)"
                Write-Host "     ClawHub: $($fileConflict.clawhub_modified)"
                Write-Host "     Git:     $($fileConflict.git_modified)"
                Write-Host "     Neuer:   $($fileConflict.newer.ToUpper())"
                Write-Host ""
            }
        }
        
        Write-Host ("=" * 80)
        Write-Host "Gesamt: $($conflicts.Count) Skills mit Konflikten"
        Write-Host "`nNutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen."
    } else {
        Write-Host "✅ Keine Konflikte gefunden!"
        Write-Host "Alle gemeinsamen Skills sind synchron."
    }
}

function Main {
    <#
    .SYNOPSIS
    Hauptfunktion
    #>
    Check-Conflicts
}

Main
