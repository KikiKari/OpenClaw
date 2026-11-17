#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "d94d63b3f3b52fead5e2d9c8533c917dce6dffb7f85fbc6515b7ab1f647d5f00", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "powershell"}
# openclaw-node-autostart-termux.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Node Mode Autostart für Termux (Node 5 - Redmi Note 11)
# Installiert nach: ~/.termux/boot/openclaw-node.ps1
# Getestet mit: Termux + Android + OpenClaw

$SESSION = "openclaw-node"
$LOGFILE = "$env:HOME/.openclaw/node.log"
$GATEWAY = "10.10.0.1"
$PORT = "18789"

# Log-Verzeichnis erstellen
New-Item -ItemType Directory -Path "$env:HOME/.openclaw" -Force | Out-Null

# Prüfen ob tmux Session bereits läuft
try {
    $null = & tmux has-session -t $SESSION 2>$null
    if ($LASTEXITCODE -eq 0) {
        Add-Content -Path $LOGFILE -Value "[$(Get-Date)] OpenClaw Node läuft bereits in tmux Session '$SESSION'"
        exit 0
    }
} catch {}

# Neue tmux Session erstellen und OpenClaw starten
$scriptBlock = @"
while (`$true) {
    echo "[$(Get-Date)] Starting OpenClaw Node Mode..." | tee -a '$LOGFILE'
    
    # Prüfe WireGuard Verbindung
    if (! (Test-Connection -Count 1 -TimeoutSeconds 3 $GATEWAY -Quiet)) {
        echo "[$(Get-Date)] FEHLER: WireGuard Gateway $GATEWAY nicht erreichbar!" | tee -a '$LOGFILE'
        echo "[$(Get-Date)] Warte 10 Sekunden..." | tee -a '$LOGFILE'
        Start-Sleep -Seconds 10
        continue
    }
    
    # OpenClaw Node Mode starten
    openclaw node run --host $GATEWAY --port $PORT 2>&1 | tee -a '$LOGFILE'
    
    # Wenn der Prozess endet, warte und neustarten
    echo "[$(Get-Date)] OpenClaw beendet. Neustart in 5 Sekunden..." | tee -a '$LOGFILE'
    Start-Sleep -Seconds 5
}
"@

& tmux new-session -d -s $SESSION -n "node" "pwsh -Command `"$scriptBlock`""

Add-Content -Path $LOGFILE -Value "[$(Get-Date)] OpenClaw Node Autostart aktiviert (tmux Session: $SESSION)"

# Optional: tmux attach Hinweis falls interaktiv gestartet
if ([Environment]::UserInteractive) {
    Write-Host "OpenClaw Node Mode gestartet in tmux Session '$SESSION'"
    Write-Host "Zum Anschauen: tmux attach -t $SESSION"
    Write-Host "Log-Datei: $LOGFILE"
}
