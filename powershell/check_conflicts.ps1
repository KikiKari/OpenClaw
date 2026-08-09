#!/usr/bin/env pwsh
# check_conflicts.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
# auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Check Conflicts - Erkennt Sync-Konflikte
#>

# Import sync functions
$syncScriptPath = "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.ps1"
if (Test-Path $syncScriptPath) {
    . $syncScriptPath
} else {
    Write-Error "Sync script not found at $syncScriptPath"
    exit 1
}

$CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
$GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"

function Get-FileHashCustom {
    param(
        [string]$Path
    )
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return [BitConverter]::ToString($hash).Replace("-", "").ToLower()
}

function Check-Conflicts {
    <#
    .SYNOPSIS
    Prüft auf Konflikte zwischen ClawHub und Git
    #>
    $conflicts = @()
    
    # Alle Skills die in beiden Orten existieren
    $common_skills = @()
    if (Test-Path $CLAWHUB_DIR -and Test-Path $GIT_DIR) {
        $clawhub_skills = Get-ChildItem -Path $CLAWHUB_DIR -Directory | ForEach-Object { $_.Name }
        $git_skills = Get-ChildItem -Path $GIT_DIR -Directory | ForEach-Object { $_.Name }
        $common_skills = $clawhub_skills | Where-Object { $git_skills -contains $_ }
    }
    
    Write-Host "Prüfe $($common_skills.Count) Skills auf Konflikte...`n"
    
    foreach ($skill in ($common_skills | Sort-Object)) {
        $clawhub_path = Join-Path $CLAWHUB_DIR $skill
        $git_path = Join-Path $GIT_DIR $skill
        
        # Alle Dateien vergleichen
        $skill_conflicts = @()
        
        # ClawHub Dateien
        $clawhub_files = @{}
        Get-ChildItem -Path $clawhub_path -Recurse -File | Where-Object { $_.FullName -notlike "*.git*" } | ForEach-Object {
            $rel_path = $_.FullName.Substring($clawhub_path.Length + 1)
            $clawhub_files[$rel_path] = $_.FullName
        }
        
        # Git Dateien
        $git_files = @{}
        Get-ChildItem -Path $git_path -Recurse -File | Where-Object { $_.FullName -notlike "*.git*" } | ForEach-Object {
            $rel_path = $_.FullName.Substring($git_path.Length + 1)
            $git_files[$rel_path] = $_.FullName
        }
        
        # Vergleiche gemeinsame Dateien
        $common_files = $clawhub_files.Keys | Where-Object { $git_files.Keys -contains $_ }
        foreach ($rel_path in $common_files) {
            $clawhub_file = $clawhub_files[$rel_path]
            $git_file = $git_files[$rel_path]
            
            if ((Get-FileHashCustom $clawhub_file) -ne (Get-FileHashCustom $git_file)) {
                $clawhub_mtime = (Get-Item $clawhub_file).LastWriteTime
                $git_mtime = (Get-Item $git_file).LastWriteTime
                
                $skill_conflicts += @{
                    "file" = $rel_path
                    "clawhub_modified" = $clawhub_mtime.ToString('yyyy-MM-dd HH:mm:ss')
                    "git_modified" = $git_mtime.ToString('yyyy-MM-dd HH:mm:ss')
                    "newer" = if ($clawhub_mtime -gt $git_mtime) { "clawhub" } else { "git" }
                }
            }
        }
        
        if ($skill_conflicts.Count -gt 0) {
            $conflicts += @{
                "skill" = $skill
                "conflicts" = $skill_conflicts
            }
        }
    }
    
    # Ausgabe
    if ($conflicts.Count -gt 0) {
        Write-Host "⚠️  KONFLIKTE GEFUNDEN:"
        Write-Host ("=" * 80)
        
        foreach ($conflict in $conflicts) {
            Write-Host "`n📦 Skill: $($conflict['skill'])"
            Write-Host ("-" * 40)
            
            foreach ($file_conflict in $conflict['conflicts']) {
                Write-Host "  📄 $($file_conflict['file'])"
                Write-Host "     ClawHub: $($file_conflict['clawhub_modified'])"
                Write-Host "     Git:     $($file_conflict['git_modified'])"
                Write-Host "     Neuer:   $($file_conflict['newer'].ToUpper())"
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
