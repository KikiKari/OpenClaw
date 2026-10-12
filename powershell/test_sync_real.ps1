#!/usr/bin/env pwsh
# test_sync_real.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
# auch in: OpenClaw@gateway2:scripts/test_sync_real.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Test echte Synchronisation

.DESCRIPTION
Fuehrt einen echten Synchronisationstest fuer den Skill db-maintainer durch
und ueberprueft das Ergebnis.
#>

# Fuege das Verzeichnis zum Suchpfad hinzu
$env:PYTHONPATH = "/home/openclaw/.openclaw/workspace/scripts"

try {
    # Importiere die Funktionen aus dem Python-Skript
    $pyScript = Get-Content -Path "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.py" -Raw
    Invoke-Expression $pyScript
}
catch {
    Write-Host "Fehler beim Laden des Python-Skripts: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "=== TEST: db-maintainer sync (REAL) ===" -ForegroundColor Cyan

# Definiere die Skill-Variable
$skill = "db-maintainer"

# Fuehre die Synchronisation durch (ECHT)
try {
    # Da wir keine direkte Python-Funktion aufrufen koennen, simulieren wir den Aufruf
    # In PowerShell 7 koennte man hier auch Python direkt aufrufen:
    $result = & python3 -c "
import sys
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git
result = sync_to_git('$skill', dry_run=False)
print('SUCCESS' if result else 'FAILED')
exit(0 if result else 1)
"
    
    # Alternativ koennen wir das Skript auch direkt ausfuehren und den Exit-Code pruefen
    # $proc = Start-Process -FilePath "python3" -ArgumentList @("/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.py", "$skill") -Wait -PassThru -NoNewWindow
    # $result = ($proc.ExitCode -eq 0)
    
    # Da wir den direkten Funktionsaufruf nicht haben, fuehren wir das Python-Skript aus
    $pyArgs = @(
        "-c"
        @"
import sys
sys.path.append('/home/openclaw/.openclaw/workspace/scripts')
from sync_clawhub_git import sync_to_git
result = sync_to_git('$skill', dry_run=False)
print('SUCCESS' if result else 'FAILED')
sys.exit(0 if result else 1)
"@
    )
    
    $proc = Start-Process -FilePath "python3" -ArgumentList $pyArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput stdout.txt -RedirectStandardError stderr.txt
    $resultSuccess = ($proc.ExitCode -eq 0)
    
    Write-Host "Result: $(if ($resultSuccess) { 'SUCCESS' } else { 'FAILED' })" -ForegroundColor $(if ($resultSuccess) { 'Green' } else { 'Red' })
}
catch {
    Write-Host "Result: FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    $resultSuccess = $false
}

# Pruefe Ergebnis
$target = "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer"
if (Test-Path $target) {
    Write-Host "`n✅ Git-Repo erstellt: $target" -ForegroundColor Green
    
    # Zeige die Verzeichnisstruktur an
    Get-ChildItem -Path $target -Recurse | ForEach-Object {
        $level = ($_.FullName.Replace($target, '') -split '/').Count - 1
        $indent = ' ' * 2 * $level
        if ($_.PSIsContainer) {
            Write-Host "${indent}$($_.Name)/" -ForegroundColor Blue
        }
        else {
            $subindent = ' ' * 2 * ($level + 1)
            Write-Host "${subindent}$($_.Name)"
        }
    }
}
else {
    Write-Host "`n❌ Git-Repo nicht gefunden: $target" -ForegroundColor Red
}
