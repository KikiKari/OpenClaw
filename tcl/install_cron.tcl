#!/usr/bin/env tclsh8.6
# install_cron.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
# auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

#
# Installiert den DB-Maintainer als Cron-Job
#

package require json

set CRON_JOB {
# DB Maintainer - Alle 30 Minuten
*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1
}

proc install {} {
    global CRON_JOB
    
    set workspace "/home/openclaw/.openclaw/workspace"
    set cron_file "$workspace/crons/db-maintainer.cron"
    
    # Erstelle das Verzeichnis falls es nicht existiert
    file mkdir [file dirname $cron_file]
    
    # Schreibe die Cron-Datei
    set f [open $cron_file w]
    puts -nonewline $f [string trim $CRON_JOB]
    close $f
    
    puts "✅ Cron-Job installiert: $cron_file"
    puts "   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron"
    
    # Auch in OpenClaw cron registrieren
    set jobs_json "$workspace/.openclaw/cron/jobs.json"
    if {[file exists $jobs_json]} {
        # Lese die vorhandene JSON-Datei
        set f [open $jobs_json r]
        set json_data [read $f]
        close $f
        
        # Parse JSON
        if {[catch {::json::json2dict $json_data} jobs]} {
            # Falls Parsing fehlschlägt, leeres Dict verwenden
            set jobs [dict create]
        }
        
        # Aktualisiere oder füge neuen Job hinzu
        dict set jobs "db-maintainer" [dict create \
            schedule "*/30 * * * *" \
            command "python3 skills/db-maintainer/scripts/db_maintainer.py" \
            enabled true]
        
        # Schreibe aktualisiertes JSON zurück
        set f [open $jobs_json w]
        puts $f [::json::dict2json $jobs]
        close $f
        
        puts "✅ In OpenClaw cron registriert"
    }
}

# Hauptprogramm
install
