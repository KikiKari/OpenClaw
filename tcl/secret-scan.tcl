#!/usr/bin/env tclsh
# secret-scan.mjs — portiert nach tcl
# Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Globale Variablen
set root [file normalize [file dirname [file dirname [info script]]]]
set skipped [dict create \
    node_modules {} \
    .next {} \
    .git {} \
    .pytest_cache {} \
    __pycache__ {} \
    "media-production/raw" {} \
    "media-production/private" {} \
]
set patterns {
    {sk-(proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,}} 
    {(nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,}}
    {ELEVENLABS_API_KEY\s*=\s*["']?[A-Za-z0-9]{20,}}
    {WAVESPEED_API_KEY\s*=\s*["']?[A-Za-z0-9]{20,}}
}
set findings {}

# Funktion zum rekursiven Durchlaufen des Verzeichnisbaums
proc walk {dir {relative ""}} {
    global skipped patterns findings root
    
    # Verzeichnisinhalt lesen
    if {[catch {glob -nocomplain -directory $dir *} entries]} {
        return
    }
    
    foreach entry $entries {
        set basename [file tail $entry]
        set rel [file join $relative $basename]
        
        # Prüfen ob Eintrag übersprungen werden soll
        set skip 0
        if {$basename eq ".env" || 
            ([string match ".env.*" $basename] && $basename ne ".env.example")} {
            set skip 1
        } else {
            # Prüfen gegen skip-list
            foreach skip_entry [dict keys $skipped] {
                if {$rel eq $skip_entry || 
                    [string match "${skip_entry}/*" $rel] ||
                    [lsearch -exact [file split $rel] $skip_entry] != -1} {
                    set skip 1
                    break
                }
            }
        }
        
        if {$skip} {
            continue
        }
        
        # Prüfen ob es ein Verzeichnis ist
        if {[file isdirectory $entry]} {
            walk $entry $rel
        } else {
            # Dateigröße prüfen (< 2MB)
            if {[file size $entry] < 2000000} {
                # Dateiinhalt lesen
                if {[catch {open $entry r} fh]} {
                    continue
                }
                if {[catch {read $fh} content]} {
                    close $fh
                    continue
                }
                close $fh
                
                # Pattern suchen
                foreach pattern $patterns {
                    if {[regexp $pattern $content]} {
                        lappend findings $rel
                        break
                    }
                }
            }
        }
    }
}

# Hauptausführung
walk $root

# Ergebnisse prüfen
if {[llength $findings] > 0} {
    # Duplikate entfernen
    set unique_findings [lsort -unique $findings]
    puts stderr "Secret-Scan fehlgeschlagen: [join $unique_findings ", "]"
    exit 1
}

puts "Secret-Scan bestanden."
