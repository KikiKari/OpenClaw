#!/usr/bin/env pwsh
# sync-local.sh — portiert nach powershell
# Quelle: shell, Onboarding@main:scripts/sync-local.sh
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

# PowerShell-Äquivalent zu sync-local.sh — inkrementeller Git-Sync für den Dev-Stack.
# Nutzung: scripts/sync-local.ps1 [-Branch <name>] [-Interval <s>] [-Once]

param(
    [string]$Branch = "claude/onboarding-persistent-sandbox-vjfmcx",
    [int]$Interval = 20,
    [switch]$Once,
    [string]$ComposeFile = "docker-compose.dev.yml"
)

function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

function Compose {
    param([string[]]$Arguments)
    $result = docker compose -f $ComposeFile @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        Log "WARNUNG: docker compose $($Arguments -join ' ') fehlgeschlagen"
    }
    return $result
}

Set-Location (Join-Path $PSScriptRoot "..")

$current = git rev-parse --abbrev-ref HEAD
if ($current -ne $Branch) {
    Log "Wechsle von '$current' auf '$Branch' …"
    git fetch origin $Branch
    try {
        git switch $Branch 2>$null
    } catch {
        git switch -c $Branch --track "origin/$Branch"
    }
}

Log "Sync aktiv: origin/$Branch -> $(Get-Location) (Intervall ${Interval}s, Compose: $ComposeFile)"

while ($true) {
    try {
        git fetch origin $Branch --quiet
        if ($LASTEXITCODE -ne 0) {
            throw "Fetch failed"
        }
        
        $localRev = git rev-parse HEAD
        $remoteRev = git rev-parse "origin/$Branch"
        
        if ($localRev -ne $remoteRev) {
            # Prüfe, ob lokaler Stand vom Remote abgewichen ist
            $mergeBaseResult = git merge-base --is-ancestor $localRev $remoteRev
            if ($LASTEXITCODE -ne 0) {
                Log "ACHTUNG: Lokaler Stand von origin/$Branch abgewichen — kein automatischer Merge, bitte manuell auflösen."
            } else {
                $changedFiles = git diff --name-only "$localRev..$remoteRev"
                git merge --ff-only $remoteRev --quiet
                
                $fileCount = if ($changedFiles) { ($changedFiles | Measure-Object).Count } else { 0 }
                Log "Aktualisiert $($localRev.Substring(0,7)) -> $($remoteRev.Substring(0,7)) ($fileCount Datei(en))"
                
                $needsNone = $true
                
                if ($changedFiles -contains $ComposeFile) {
                    Log "Compose-Datei geändert — erzeuge Dev-Stack neu …"
                    Compose("up", "-d")
                    $needsNone = $false
                }
                
                $backendChanged = $changedFiles | Where-Object { 
                    $_ -match "^backend/(Dockerfile|requirements.*\.txt)$" 
                }
                if ($backendChanged) {
                    Log "Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …"
                    Compose("up", "-d", "--build", "backend")
                    $needsNone = $false
                }
                
                $frontendChanged = $changedFiles | Where-Object { 
                    $_ -match "^(package\.json|package-lock\.json)$" 
                }
                if ($frontendChanged) {
                    Log "Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …"
                    Compose("restart", "frontend")
                    $needsNone = $false
                }
                
                if ($needsNone) {
                    Log "Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig."
                }
            }
        }
    } catch {
        Log "Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in ${Interval}s"
    }
    
    if ($Once) { break }
    Start-Sleep -Seconds $Interval
}
