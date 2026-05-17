#!/data/data/com.termux/files/usr/bin/bash
# OpenClaw Node Mode Autostart für Termux (Node 5 - Redmi Note 11)
# Installiert nach: ~/.termux/boot/openclaw-node.sh
# Getestet mit: Termux + Android + OpenClaw

SESSION="openclaw-node"
LOGFILE="$HOME/.openclaw/node.log"
GATEWAY="10.10.0.1"
PORT="18789"

# Log-Verzeichnis erstellen
mkdir -p "$HOME/.openclaw"

# Prüfen ob tmux Session bereits läuft
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[$(date)] OpenClaw Node läuft bereits in tmux Session '$SESSION'" >> "$LOGFILE"
    exit 0
fi

# Neue tmux Session erstellen und OpenClaw starten
tmux new-session -d -s "$SESSION" -n "node" "
    while true; do
        echo '[$(date)] Starting OpenClaw Node Mode...' | tee -a '$LOGFILE'
        
        # Prüfe WireGuard Verbindung
        if ! ping -c 1 -W 3 $GATEWAY >/dev/null 2>&1; then
            echo '[$(date)] FEHLER: WireGuard Gateway $GATEWAY nicht erreichbar!' | tee -a '$LOGFILE'
            echo '[$(date)] Warte 10 Sekunden...' | tee -a '$LOGFILE'
            sleep 10
            continue
        fi
        
        # OpenClaw Node Mode starten
        openclaw node run --host $GATEWAY --port $PORT 2>&1 | tee -a '$LOGFILE'
        
        # Wenn der Prozess endet, warte und neustarten
        echo '[$(date)] OpenClaw beendet. Neustart in 5 Sekunden...' | tee -a '$LOGFILE'
        sleep 5
    done
"

echo "[$(date)] OpenClaw Node Autostart aktiviert (tmux Session: $SESSION)" >> "$LOGFILE"

# Optional: tmux attach Hinweis falls interaktiv gestartet
if [ -t 1 ]; then
    echo "OpenClaw Node Mode gestartet in tmux Session '$SESSION'"
    echo "Zum Anschauen: tmux attach -t $SESSION"
    echo "Log-Datei: $LOGFILE"
fi
