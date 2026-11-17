#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "aa45879c25c5dcae42646bfba820cbdd03194667c1a88d71125525ef1eabc945", "source_sha256": "77eca70a7a8f9c0ff8dc240b14d8c37999854c241e031b8167e1fcd650cbd334", "target_language": "tcl"}
# install_cron.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
# auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Installiert den DB-Maintainer als Cron-Job

package require json

set CRON_JOB {
# DB Maintainer - Alle 30 Minuten
*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1
}

proc install {} {
    set workspace "/home/openclaw/.openclaw/workspace"
    set cron_file "$workspace/crons/db-maintainer.cron"
    
    file mkdir [file dirname $cron_file]
    
    set f [open $cron_file w]
    puts $f $::CRON_JOB
    close $f
    
    puts "✅ Cron-Job installiert: $cron_file"
    puts "   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron"
    
    # Auch in OpenClaw cron registrieren
    set jobs_json "$workspace/.openclaw/cron/jobs.json"
    if {[file exists $jobs_json]} {
        set f [open $jobs_json r]
        set content [read $f]
        close $f
        
        if {$content eq ""} {
            set jobs [dict create]
        } else {
            set jobs [::json::json2dict $content]
        }
        
        dict set jobs "db-maintainer" [dict create \
            schedule "*/30 * * * *" \
            command "python3 skills/db-maintainer/scripts/db_maintainer.py" \
            enabled true]
        
        set f [open $jobs_json w]
        puts $f [::json::dict2json $jobs]
        close $f
        
        puts "✅ In OpenClaw cron registriert"
    }
}

install
