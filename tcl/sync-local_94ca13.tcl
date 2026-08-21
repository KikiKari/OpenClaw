#!/usr/bin/env tclsh
# sync-local.sh — portiert nach tcl
# Quelle: shell, Onboarding@main:scripts/sync-local.sh
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

# Tcl-Äquivalent zu sync-local.ps1 — inkrementeller Git-Sync für den Dev-Stack.
# Nutzung: scripts/sync-local.tcl [--branch <name>] [--interval <s>] [--once]

package require Tcl 8.6

set BRANCH "claude/onboarding-persistent-sandbox-vjfmcx"
set INTERVAL 20
set COMPOSE_FILE "docker-compose.dev.yml"
set ONCE 0

# Argumente parsen
for {set i 0} {$i < [llength $argv]} {incr i} {
    set arg [lindex $argv $i]
    switch -- $arg {
        --branch {
            incr i
            set BRANCH [lindex $argv $i]
        }
        --interval {
            incr i
            set INTERVAL [lindex $argv $i]
        }
        --once {
            set ONCE 1
        }
        default {
            puts stderr "Unbekannte Option: $arg"
            exit 1
        }
    }
}

# In das Hauptverzeichnis wechseln
set script_dir [file dirname [info script]]
cd [file join $script_dir ..]

# Logging-Funktion
proc log {msg} {
    set time [clock format [clock seconds] -format "%H:%M:%S"]
    puts "\[$time\] $msg"
}

# Docker Compose Wrapper
proc compose {args} {
    global COMPOSE_FILE
    set cmd [list docker compose -f $COMPOSE_FILE {*}$args]
    if {[catch {exec {*}$cmd} result]} {
        log "WARNUNG: docker compose [join $args " "] fehlgeschlagen"
    } else {
        return $result
    }
}

# Aktuellen Branch ermitteln
set current [exec git rev-parse --abbrev-ref HEAD]

# Branch wechseln falls nötig
if {$current ne $BRANCH} {
    log "Wechsle von '$current' auf '$BRANCH' …"
    exec git fetch origin $BRANCH
    if {[catch {exec git switch $BRANCH}]} {
        exec git switch -c $BRANCH --track origin/$BRANCH
    }
}

log "Sync aktiv: origin/$BRANCH -> [pwd] (Intervall ${INTERVAL}s, Compose: $COMPOSE_FILE)"

# Hauptschleife
while {true} {
    # Fetch versuchen
    if {[catch {exec git fetch origin $BRANCH --quiet}]} {
        log "Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in ${INTERVAL}s"
    } else {
        # Revisionen vergleichen
        set local_rev [exec git rev-parse HEAD]
        set remote_rev [exec git rev-parse origin/$BRANCH]
        
        if {$local_rev ne $remote_rev} {
            # Prüfen ob Merge möglich ist
            if {[catch {exec git merge-base --is-ancestor $local_rev $remote_rev}]} {
                log "ACHTUNG: Lokaler Stand von origin/$BRANCH abgewichen — kein automatischer Merge, bitte manuell auflösen."
            } else {
                # Geänderte Dateien ermitteln
                set changed [split [exec git diff --name-only $local_rev..$remote_rev] "\n"]
                if {[llength $changed] > 0 && [lindex $changed end] eq ""} {
                    set changed [lrange $changed 0 end-1]
                }
                
                # Merge durchführen
                exec git merge --ff-only $remote_rev --quiet
                set file_count [llength $changed]
                log "Aktualisiert [string range $local_rev 0 6] -> [string range $remote_rev 0 6] ($file_count Datei(en))"
                
                # Änderungen prüfen und entsprechend reagieren
                set needs_none 1
                
                # Compose-Datei geändert?
                if {[lsearch -exact $changed $COMPOSE_FILE] != -1} {
                    log "Compose-Datei geändert — erzeuge Dev-Stack neu …"
                    compose up -d
                    set needs_none 0
                }
                
                # Backend-Dependencies/Dockerfile geändert?
                foreach file $changed {
                    if {[regexp {^backend/(Dockerfile|requirements.*\.txt)$} $file]} {
                        log "Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …"
                        compose up -d --build backend
                        set needs_none 0
                        break
                    }
                }
                
                # Frontend-Dependencies geändert?
                foreach file $changed {
                    if {[regexp {^(package\.json|package-lock\.json)$} $file]} {
                        log "Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …"
                        compose restart frontend
                        set needs_none 0
                        break
                    }
                }
                
                # Nur Quellcode/Assets?
                if {$needs_none} {
                    log "Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig."
                }
            }
        }
    }
    
    # Einmaliger Durchlauf?
    if {$ONCE} {
        break
    }
    
    # Warten
    after [expr {$INTERVAL * 1000}]
}
