#!/data/data/com.termux/files/usr/bin/tclsh8.6
# abstraction-provenance: {"artifact_sha256": "84ec56b59c0fa67f83d308eb8027b08d857086df1746c11d8beace98c8f9591d", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "tcl"}
# openclaw-node-autostart-termux.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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
    # tmux session existiert nicht, fortfahren
} else {
    set logfile [open $LOGFILE a]
    puts $logfile "\[[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]\] OpenClaw Node läuft bereits in tmux Session '$SESSION'"
    close $logfile
    exit 0
}

# Skript für die tmux-Session vorbereiten
set script_file "/data/data/com.termux/files/usr/tmp/openclaw_script_[pid].sh"
set script_fh [open $script_file w]
puts $script_fh "#!/bin/bash"
puts $script_fh "while true; do"
puts $script_fh "    echo '\[[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]\] Starting OpenClaw Node Mode...' | tee -a '$LOGFILE'"
puts $script_fh ""
puts $script_fh "    # Prüfe WireGuard Verbindung"
puts $script_fh "    if ! ping -c 1 -W 3 $GATEWAY >/dev/null 2>&1; then"
puts $script_fh "        echo '\[[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]\] FEHLER: WireGuard Gateway $GATEWAY nicht erreichbar!' | tee -a '$LOGFILE'"
puts $script_fh "        echo '\[[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]\] Warte 10 Sekunden...' | tee -a '$LOGFILE'"
puts $script_fh "        sleep 10"
puts $script_fh "        continue"
puts $script_fh "    fi"
puts $script_fh ""
puts $script_fh "    # OpenClaw Node Mode starten"
puts $script_fh "    openclaw node run --host $GATEWAY --port $PORT 2>&1 | tee -a '$LOGFILE'"
puts $script_fh ""
puts $script_fh "    # Wenn der Prozess endet, warte und neustarten"
puts $script_fh "    echo '\[[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]\] OpenClaw beendet. Neustart in 5 Sekunden...' | tee -a '$LOGFILE'"
puts $script_fh "    sleep 5"
puts $script_fh "done"
close $script_fh

# Skript ausführbar machen
exec chmod +x $script_file

# Neue tmux Session erstellen und OpenClaw starten
exec tmux new-session -d -s $SESSION -n "node" bash $script_file &

# Logeintrag schreiben
set logfile [open $LOGFILE a]
puts $logfile "\[[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]\] OpenClaw Node Autostart aktiviert (tmux Session: $SESSION)"
close $logfile

# Optional: tmux attach Hinweis falls interaktiv gestartet
if {[info exists env(TERM)] && $env(TERM) ne ""} {
    puts "OpenClaw Node Mode gestartet in tmux Session '$SESSION'"
    puts "Zum Anschauen: tmux attach -t $SESSION"
    puts "Log-Datei: $LOGFILE"
}
