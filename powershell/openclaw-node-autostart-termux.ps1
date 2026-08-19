#!/usr/bin/env pwsh
# openclaw-node-autostart-termux.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Node Mode Autostart für Termux (Node 5 - Redmi Note 11)
# Installiert nach: ~/.termux/boot/openclaw-node.ps1
# Getestet mit: Termux + Android + OpenClaw

$SESSION = "openclaw-node"
$LOGFILE = "$env:HOME/.openclaw/node.log"
$GATEWAY = "10.10.0.1"
$PORT = "18789"

# Log-Verzeichnis erstellen
$null = New-Item -ItemType Directory -Path "$env:HOME/.openclaw" -Force

# Prüfen ob tmux Session bereits läuft
try {
    $tmuxCheck = tmux has-session -t $SESSION 2>$null
    if ($LASTEXITCODE -eq 0) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') OpenClaw Node läuft bereits in tmux Session '$SESSION'" | Add-Content -Path $LOGFILE
        exit 0
    }
} catch {}

# Neue tmux Session erstellen und OpenClaw starten
$scriptBlock = @"
while (`$true) {
    Write-Output "`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Starting OpenClaw Node Mode..." | Tee-Object -FilePath '$LOGFILE' -Append
    
    # Prüfe WireGuard Verbindung
    if (-not (Test-Connection -ComputerName $GATEWAY -Count 1 -Quiet -TimeoutSeconds 3)) {
        Write-Output "`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') FEHLER: WireGuard Gateway $GATEWAY nicht erreichbar!" | Tee-Object -Path '$LOGFILE' -Append
        Write-Output "`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Warte 10 Sekunden..." | Tee-Object -Path '$LOGFILE' -Append
        Start-Sleep -Seconds 10
        continue
    }
    
    # OpenClaw Node Mode starten
    openclaw node run --host $GATEWAY --port $PORT 2>&1 | Tee-Object -FilePath '$LOGFILE' -Append
    
    # Wenn der Prozess endet, warte und neustarten
    Write-Output "`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') OpenClaw beendet. Neustart in 5 Sekunden..." | Tee-Object -Path '$LOGFILE' -Append
    Start-Sleep -Seconds 5
}
"@

# Escape double quotes for shell command
$escapedScript = $scriptBlock -replace '"', '\"'

& tmux new-session -d -s $SESSION -n "node" "pwsh -Command `"$escapedScript`""

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') OpenClaw Node Autostart aktiviert (tmux Session: $SESSION)" | Add-Content -Path $LOGFILE

# Optional: tmux attach Hinweis falls interaktiv gestartet
if ([Environment]::UserInteractive) {
    Write-Output "OpenClaw Node Mode gestartet in tmux Session '$SESSION'"
    Write-Output "Zum Anschauen: tmux attach -t $SESSION"
    Write-Output "Log-Datei: $LOGFILE"
}
