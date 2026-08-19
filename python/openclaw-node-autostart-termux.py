#!/data/data/com.termux/files/usr/bin/python3.12
# openclaw-node-autostart-termux.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Node Mode Autostart für Termux (Node 5 - Redmi Note 11)
# Installiert nach: ~/.termux/boot/openclaw-node.py
# Getestet mit: Termux + Android + OpenClaw

import os
import sys
import time
import subprocess
from datetime import datetime

SESSION = "openclaw-node"
LOGFILE = os.path.expanduser("~/.openclaw/node.log")
GATEWAY = "10.10.0.1"
PORT = "18789"

def log_message(message):
    """Schreibe eine Nachricht mit Zeitstempel in die Logdatei"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] {message}\n"
    
    # Stelle sicher dass das Verzeichnis existiert
    os.makedirs(os.path.dirname(LOGFILE), exist_ok=True)
    
    with open(LOGFILE, "a") as f:
        f.write(log_entry)
    
    # Ausgabe auf stdout wenn interaktiv
    if sys.stdout.isatty():
        print(f"{timestamp} {message}")

def check_tmux_session_exists(session_name):
    """Prüfe ob eine tmux Session bereits existiert"""
    try:
        result = subprocess.run(
            ["tmux", "has-session", "-t", session_name],
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    except FileNotFoundError:
        log_message("FEHLER: tmux nicht gefunden!")
        return False

def create_tmux_session():
    """Erstelle eine neue tmux Session mit dem OpenClaw Node Skript"""
    # Tmux Befehl zum Starten des OpenClaw Nodes
    tmux_command = f"""
while true; do
    echo "[$(date)] Starting OpenClaw Node Mode..." | tee -a '{LOGFILE}'
    
    # Prüfe WireGuard Verbindung
    if ! ping -c 1 -W 3 {GATEWAY} >/dev/null 2>&1; then
        echo "[$(date)] FEHLER: WireGuard Gateway {GATEWAY} nicht erreichbar!" | tee -a '{LOGFILE}'
        echo "[$(date)] Warte 10 Sekunden..." | tee -a '{LOGFILE}'
        sleep 10
        continue
    fi
    
    # OpenClaw Node Mode starten
    openclaw node run --host {GATEWAY} --port {PORT} 2>&1 | tee -a '{LOGFILE}'
    
    # Wenn der Prozess endet, warte und neustarten
    echo "[$(date)] OpenClaw beendet. Neustart in 5 Sekunden..." | tee -a '{LOGFILE}'
    sleep 5
done
"""

    # Starte tmux im detached mode
    try:
        subprocess.run([
            "tmux", "new-session", "-d", "-s", SESSION, "-n", "node", 
            tmux_command
        ], check=True)
        return True
    except subprocess.CalledProcessError as e:
        log_message(f"FEHLER beim Erstellen der tmux Session: {e}")
        return False
    except FileNotFoundError:
        log_message("FEHLER: tmux nicht gefunden!")
        return False

def main():
    """Hauptprogramm"""
    # Prüfen ob tmux Session bereits läuft
    if check_tmux_session_exists(SESSION):
        log_message(f"OpenClaw Node läuft bereits in tmux Session '{SESSION}'")
        sys.exit(0)

    # Neue tmux Session erstellen und OpenClaw starten
    if create_tmux_session():
        log_message(f"OpenClaw Node Autostart aktiviert (tmux Session: {SESSION})")
        
        # Optional: tmux attach Hinweis falls interaktiv gestartet
        if sys.stdout.isatty():
            print(f"OpenClaw Node Mode gestartet in tmux Session '{SESSION}'")
            print(f"Zum Anschauen: tmux attach -t {SESSION}")
            print(f"Log-Datei: {LOGFILE}")
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
