#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "be3d6e2a1723bce3cfa11e9be0e36052174106f8feb6b297287cb0a0689ee443", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "tcl"}
# translation-worker-node5.ps1 — portiert nach tcl
# Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Prüfe, ob die richtige Anzahl an Argumenten übergeben wurde
if {$argc != 1} {
    puts stderr "Usage: $argv0 <prepare|run>"
    exit 1
}

set action [lindex $argv 0]

# Validierung der Action
if {![string equal $action "prepare"] && ![string equal $action "run"]} {
    puts stderr "Invalid action. Must be 'prepare' or 'run'."
    exit 1
}

# Fehlerbehandlung aktivieren
if {[catch {
    # Bestimme den Pfad zum Worker-Skript
    set userprofile $env(HOME)
    if {[info exists env(USERPROFILE)]} {
        set userprofile $env(USERPROFILE)
    }
    set worker [file normalize [file join $userprofile .openclaw workers translation_worker.py]]
    
    set expected "9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b"
    
    # Prüfe, ob die Worker-Datei existiert
    if {![file exists $worker]} {
        error "Worker missing: $worker"
    }
    
    # Prüfe, ob es ein symbolischer Link ist (wird abgelehnt)
    if {[file type $worker] eq "link"} {
        error "Worker link rejected"
    }
    
    # Berechne den SHA256-Hash der Datei
    if {[catch {exec openssl sha256 -r $worker} hash_result]} {
        error "Failed to compute checksum for $worker"
    }
    
    # Extrahiere nur den Hash-Wert (erster Teil der Ausgabe)
    set computed_hash [lindex [split $hash_result " "] 0]
    
    # Vergleiche den Hash (Groß-/Kleinschreibung ignorieren)
    if {[string tolower $computed_hash] ne [string tolower $expected]} {
        error "Worker checksum mismatch"
    }
    
    # Suche nach Python
    if {[catch {exec which python} python_path]} {
        if {[catch {exec where python} python_path]} {
            error "Python executable not found"
        }
    }
    
    # Bei prepare-Aktion gib Erfolgsmeldung aus und beende
    if {[string equal $action "prepare"]} {
        puts "Worker verified: $worker"
        exit 0
    }
    
    # Führe das Python-Skript aus
    if {[catch {exec $python_path $worker} result]} {
        # Wenn das Skript mit einem Exit-Code ungleich 0 endet, geben wir diesen weiter
        if {[info exists ::errorCode]} {
            # Extrahiere den Exit-Code, falls verfügbar
            if {[regexp {CHILDSTATUS (\d+) (\d+)} $::errorCode -> pid exitcode]} {
                exit $exitcode
            }
        }
        exit 1
    } else {
        # Bei erfolgreicher Ausführung beende mit Code 0
        exit 0
    }
} errmsg]} {
    puts stderr $errmsg
    exit 1
}
