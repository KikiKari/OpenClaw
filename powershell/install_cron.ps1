#!/usr/bin/env pwsh
# install_cron.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
# auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Installiert den DB-Maintainer als Cron-Job
#>

$CRON_JOB = @'
# DB Maintainer - Alle 30 Minuten
*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1
'@.Trim()

function Install-CronJob {
    $workspace = [System.IO.Path]::Combine("/home/openclaw/.openclaw", "workspace")
    $cronFile = [System.IO.Path]::Combine($workspace, "crons", "db-maintainer.cron")
    
    # Erstelle das Verzeichnis falls es nicht existiert
    $cronDir = [System.IO.Path]::GetDirectoryName($cronFile)
    if (!(Test-Path $cronDir)) {
        New-Item -ItemType Directory -Path $cronDir -Force | Out-Null
    }
    
    # Schreibe die Cron-Job Definition in die Datei
    [System.IO.File]::WriteAllText($cronFile, $CRON_JOB)
    
    Write-Host "✅ Cron-Job installiert: $cronFile"
    Write-Host "   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron"
    
    # Auch in OpenClaw cron registrieren
    $jobsJson = [System.IO.Path]::Combine($workspace, ".openclaw", "cron", "jobs.json")
    if (Test-Path $jobsJson) {
        $jobs = Get-Content $jobsJson | ConvertFrom-Json
        
        # Falls jobs kein Dictionary ist, initialisiere es als leeres Dictionary
        if ($null -eq $jobs) {
            $jobs = New-Object PSObject
        }
        
        # Füge den neuen Job hinzu oder aktualisiere ihn
        $jobEntry = @{
            schedule = '*/30 * * * *'
            command = 'python3 skills/db-maintainer/scripts/db_maintainer.py'
            enabled = $true
        }
        
        # Entferne die Property falls sie bereits existiert, dann neu hinzufügen
        $jobs.PSObject.Properties.Remove('db-maintainer')
        $jobs | Add-Member -NotePropertyName 'db-maintainer' -NotePropertyValue $jobEntry
        
        # Konvertiere zurück zu JSON und speichere
        $jobs | ConvertTo-Json -Depth 10 | Set-Content $jobsJson
        
        Write-Host "✅ In OpenClaw cron registriert"
    }
}

# Hauptausführung
Install-CronJob
