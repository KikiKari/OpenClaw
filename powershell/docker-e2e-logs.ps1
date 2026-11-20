#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "2ec4feb4d8ce945c7864e20fc46170ca00af8b69066e113e5d6ee895608e0d1c", "source_sha256": "c5da3d5a6d1b96d5dbfcceb3eeaaf1082185c08fa2edcbc7b87c36871484ccf2", "target_language": "powershell"}
# docker-e2e-logs.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/lib/docker-e2e-logs.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

function run_logged {
    param(
        [string]$label,
        [scriptblock]$command
    )
    
    $logFile = New-TemporaryFile
    $logFile = Rename-Item -Path $logFile.FullName -NewName ($logFile.Name -replace '\.tmp$', '.log') -PassThru
    $logFile = Rename-Item -Path $logFile.FullName -NewName "openclaw-${label}.$([System.IO.Path]::GetRandomFileName().Split('.')[0]).log" -PassThru
    
    try {
        # Führe das Kommando aus und leite Ausgabe und Fehler um
        & $command 2>&1 | Out-File -FilePath $logFile.FullName -Encoding UTF8
        
        # Prüfe den Exit-Code des letzten ausgeführten Befehls
        if ($LASTEXITCODE -ne 0) {
            Get-Content $logFile.FullName
            return $false
        }
        return $true
    }
    finally {
        if (Test-Path $logFile.FullName) {
            Remove-Item -Path $logFile.FullName -Force
        }
    }
}
