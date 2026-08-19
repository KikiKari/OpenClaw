#!/data/data/com.termux/files/usr/bin/tclsh
# openclaw-node-autostart-termux.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Node Mode Autostart für Termux (Node 5 - Redmi Note 11)
# Installiert nach: ~/.termux/boot/openclaw-node.tcl
# Getestet mit: Termux + Android + OpenClaw

set SESSION "openclaw-node"
set LOGFILE "$env(HOME)/.openclaw/node.log"
set GATEWAY "10.10.0.1"
set PORT "18789"

# Log-Verzeichnis erstellen
file mkdir "$env(HOME)/.openclaw"

# Prüfen ob tmux Session bereits läuft
if {[catch {exec tmux has-session -t $SESSION}]} {
    # Session existiert nicht, fortfahren
} else {
    set fp [open $LOGFILE a]
    puts $fp "\[[clock format [clock seconds]]\] OpenClaw Node läuft bereits in tmux Session '$SESSION'"
    close $fp
    exit 0
}

# Neue tmux Session erstellen und OpenClaw starten
set cmd "while true; do\n"
append cmd "    echo '\[[clock format [clock seconds]]\] Starting OpenClaw Node Mode...' | tee -a '$LOGFILE'\n"
append cmd "    \n"
append cmd "    # Prüfe WireGuard Verbindung\n"
append cmd "    if ! ping -c 1 -W 3 $GATEWAY >/dev/null 2>&1; then\n"
append cmd "        echo '\[[clock format [clock seconds]]\] FEHLER: WireGuard Gateway $GATEWAY nicht erreichbar!' | tee -a '$LOGFILE'\n"
append cmd "        echo '\[[clock format [clock seconds]]\] Warte 10 Sekunden...' | tee -a '$LOGFILE'\n"
append cmd "        sleep 10\n"
append cmd "        continue\n"
append cmd "    fi\n"
append cmd "    \n"
append cmd "    # OpenClaw Node Mode starten\n"
append cmd "    openclaw node run --host $GATEWAY --port $PORT 2>&1 | tee -a '$LOGFILE'\n"
append cmd "    \n"
append cmd "    # Wenn der Prozess endet, warte und neustarten\n"
append cmd "    echo '\[[clock format [clock seconds]]\] OpenClaw beendet. Neustart in 5 Sekunden...' | tee -a '$LOGFILE'\n"
append cmd "    sleep 5\n"
append cmd "done"

exec tmux new-session -d -s $SESSION -n "node" "/bin/bash -c {$cmd}" &

set fp [open $LOGFILE a]
puts $fp "\[[clock format [clock seconds]]\] OpenClaw Node Autostart aktiviert (tmux Session: $SESSION)"
close $fp

# Optional: tmux attach Hinweis falls interaktiv gestartet
if {[info exists env(TERMUX_IS_INTERACTIVE)] && $env(TERMUX_IS_INTERACTIVE) eq "1"} {
    puts "OpenClaw Node Mode gestartet in tmux Session '$SESSION'"
    puts "Zum Anschauen: tmux attach -t $SESSION"
    puts "Log-Datei: $LOGFILE"
}
