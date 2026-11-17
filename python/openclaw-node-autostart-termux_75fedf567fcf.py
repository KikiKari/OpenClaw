#!/data/data/com.termux/files/usr/bin/python3
# abstraction-provenance: {"artifact_sha256": "b1977d63d42fd168b5b53c4133c4b017f101845760c59debf916d4be27163310", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "python"}
# openclaw-node-autostart-termux.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] {message}"
    with open(LOGFILE, "a") as f:
        f.write(log_entry + "\n")
    print(log_entry)

def check_tmux_session():
    try:
        result = subprocess.run(["tmux", "has-session", "-t", SESSION], 
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return result.returncode == 0
    except FileNotFoundError:
        log_message("FEHLER: tmux nicht gefunden!")
        sys.exit(1)

def create_tmux_session():
    cmd = [
        "tmux", "new-session", "-d", "-s", SESSION, "-n", "node",
        f"""while true; do
            echo "[$(date)] Starting OpenClaw Node Mode..." | tee -a '{LOGFILE}'
            
            if ! ping -c 1 -W 3 {GATEWAY} >/dev/null 2>&1; then
                echo "[$(date)] FEHLER: WireGuard Gateway {GATEWAY} nicht erreichbar!" | tee -a '{LOGFILE}'
                echo "[$(date)] Warte 10 Sekunden..." | tee -a '{LOGFILE}'
                sleep 10
                continue
            fi
            
            openclaw node run --host {GATEWAY} --port {PORT} 2>&1 | tee -a '{LOGFILE}'
            
            echo "[$(date)] OpenClaw beendet. Neustart in 5 Sekunden..." | tee -a '{LOGFILE}'
            sleep 5
        done"""
    ]
    
    try:
        subprocess.run(cmd, check=True)
        log_message(f"OpenClaw Node Autostart aktiviert (tmux Session: {SESSION})")
        
        if sys.stdout.isatty():
            print(f"OpenClaw Node Mode gestartet in tmux Session '{SESSION}'")
            print(f"Zum Anschauen: tmux attach -t {SESSION}")
            print(f"Log-Datei: {LOGFILE}")
    except subprocess.CalledProcessError as e:
        log_message(f"FEHLER beim Starten der tmux Session: {e}")
        sys.exit(1)

def main():
    os.makedirs(os.path.dirname(LOGFILE), exist_ok=True)
    
    if check_tmux_session():
        log_message(f"OpenClaw Node läuft bereits in tmux Session '{SESSION}'")
        sys.exit(0)
    
    create_tmux_session()

if __name__ == "__main__":
    main()
