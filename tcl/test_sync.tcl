#!/usr/bin/env tclsh
# test_sync.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/test_sync.py
# auch in: OpenClaw@gateway2:scripts/test_sync.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Test für Sync-Script

# Füge das Verzeichnis zum Suchpfad hinzu
lappend auto_path /home/openclaw/.openclaw/workspace/scripts

# Lade das sync_clawhub_git Modul
package require sync_clawhub_git

# Test: db-maintainer ClawHub → Git (DRY-RUN)
puts "=== TEST: db-maintainer sync (DRY-RUN) ==="
set skill "db-maintainer"
set result [sync_clawhub_git::sync_to_git $skill 1]

if {$result} {
    puts "Result: SUCCESS"
} else {
    puts "Result: FAILED"
}

puts "\n=== LOG-Inhalt ==="
set fp [open "/home/openclaw/.openclaw/workspace/logs/sync.log" r]
set log_content [read $fp]
close $fp
puts $log_content
