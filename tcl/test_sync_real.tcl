#!/usr/bin/env tclsh
# test_sync_real.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
# auch in: OpenClaw@gateway2:scripts/test_sync_real.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Test echte Synchronisation

# Füge das Verzeichnis zum Suchpfad hinzu
lappend auto_path /home/openclaw/.openclaw/workspace/scripts

# Lade das benötigte Paket
package require sync_clawhub_git

# Test: db-maintainer ClawHub → Git (ECHT)
puts "=== TEST: db-maintainer sync (REAL) ==="
set skill "db-maintainer"
set result [sync_clawhub_git::sync_to_git $skill 0]
puts "Result: [expr {$result ? "SUCCESS" : "FAILED"}]"

# Prüfe Ergebnis
set target "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer"
if {[file exists $target]} {
    puts "\n✅ Git-Repo erstellt: $target"
    
    # Rekursive Ausgabe des Verzeichnisbaums
    proc walk_dir {path {level 0}} {
        set indent [string repeat " " [expr {$level * 2}]]
        puts "${indent}[file tail $path]/"
        
        set subindent [string repeat " " [expr {($level + 1) * 2}]]
        set entries [glob -nocomplain -directory $path *]
        set dirs [list]
        set files [list]
        
        foreach entry $entries {
            if {[file isdirectory $entry]} {
                lappend dirs $entry
            } else {
                lappend files $entry
            }
        }
        
        foreach file $files {
            puts "${subindent}[file tail $file]"
        }
        
        foreach dir $dirs {
            walk_dir $dir [expr {$level + 1}]
        }
    }
    
    walk_dir $target
}
