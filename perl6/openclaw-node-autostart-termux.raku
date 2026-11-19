#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "6eb544f9dc636afa349788e4f1d7c20ddbb9a8df53848234595d7df660b27fc2", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "perl6"}
# openclaw-node-autostart-termux.sh — portiert nach perl6
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Node Mode Autostart für Termux (Node 5 - Redmi Note 11)
# Installiert nach: ~/.termux/boot/openclaw-node.sh
# Getestet mit: Termux + Android + OpenClaw

my $SESSION = "openclaw-node";
my $LOGFILE = "$*HOME/.openclaw/node.log";
my $GATEWAY = "10.10.0.1";
my $PORT = "18789";

# Log-Verzeichnis erstellen
run 'mkdir', '-p', "$*HOME/.openclaw";

# Prüfen ob tmux Session bereits läuft
if run('tmux', 'has-session', '-t', $SESSION, :out, :err).exitcode == 0 {
    open($LOGFILE, :a).print("[{DateTime.now}]] OpenClaw Node läuft bereits in tmux Session '$SESSION'\n");
    exit 0;
}

# Neue tmux Session erstellen und OpenClaw starten
my @cmd = (
    'tmux', 'new-session', '-d', '-s', $SESSION, '-n', 'node',
    "while true; do
        echo '[\$(date)] Starting OpenClaw Node Mode...' | tee -a '$LOGFILE'
        
        # Prüfe WireGuard Verbindung
        if ! ping -c 1 -W 3 $GATEWAY >/dev/null 2>&1; then
            echo '[\$(date)] FEHLER: WireGuard Gateway $GATEWAY nicht erreichbar!' | tee -a '$LOGFILE'
            echo '[\$(date)] Warte 10 Sekunden...' | tee -a '$LOGFILE'
            sleep 10
            continue
        fi
        
        # OpenClaw Node Mode starten
        openclaw node run --host $GATEWAY --port $PORT 2>&1 | tee -a '$LOGFILE'
        
        # Wenn der Prozess endet, warte und neustarten
        echo '[\$(date)] OpenClaw beendet. Neustart in 5 Sekunden...' | tee -a '$LOGFILE'
        sleep 5
    done"
);

run @cmd;

open($LOGFILE, :a).print("[{DateTime.now}] OpenClaw Node Autostart aktiviert (tmux Session: $SESSION)\n");

# Optional: tmux attach Hinweis falls interaktiv gestartet
if $*OUT.t {
    say "OpenClaw Node Mode gestartet in tmux Session '$SESSION'";
    say "Zum Anschauen: tmux attach -t $SESSION";
    say "Log-Datei: $LOGFILE";
}
