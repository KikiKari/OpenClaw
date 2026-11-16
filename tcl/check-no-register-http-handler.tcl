#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "674e3046cf4cbd3a948a2e0e9b093a46e1aa499fa33dca1d9d86837dd61ac26e", "source_sha256": "a01dcf18c06d5aeb081cedf0088a13b316c08622615e4de86febe2deaee2596d", "target_language": "tcl"}
# check-no-register-http-handler.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-register-http-handler.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Lade benötigte Pakete
package require http
package require fileutil

# Globale Variablen
set sourceRoots [list "src" "extensions"]

# Funktion zum Prüfen auf veraltete registerHttpHandler-Aufrufe
proc isDeprecatedRegisterHttpHandlerCall {line} {
    # Prüfe ob die Zeile einen Aufruf von registerHttpHandler enthält
    # aber nicht registerHttpRoute oder registerPluginHttpRoute
    if {[regexp {registerHttpHandler\s*\()} $line] && 
        ![regexp {registerHttpRoute\s*\()} $line] && 
        ![regexp {registerPluginHttpRoute\s*\()} $line]} {
        return 1
    }
    return 0
}

# Funktion zum Finden von Zeilennummern mit veralteten Aufrufen
proc findDeprecatedRegisterHttpHandlerLines {content} {
    set lines [split $content "\n"]
    set result {}
    set lineNumber 1
    
    foreach line $lines {
        if {[isDeprecatedRegisterHttpHandlerCall $line]} {
            lappend result $lineNumber
        }
        incr lineNumber
    }
    
    return $result
}

# Funktion zum Durchsuchen von Dateien in einem Verzeichnis
proc searchFiles {dir} {
    set files {}
    
    # Rekursiv alle .ts und .js Dateien finden
    foreach root $::sourceRoots {
        set fullPath [file join $dir $root]
        if {[file exists $fullPath]} {
            foreach file [glob -nocomplain -directory $fullPath -types f *.ts *.js] {
                lappend files $file
            }
        }
    }
    
    return $files
}

# Hauptfunktion zur Ausführung der Prüfung
proc runCheck {} {
    set currentDir [pwd]
    set foundIssues 0
    
    puts "Suche nach veralteten registerHttpHandler(...) Aufrufen..."
    puts ""
    
    set files [searchFiles $currentDir]
    
    foreach file $files {
        if {[catch {open $file r} fileId]} {
            continue
        }
        
        set content [read $fileId]
        close $fileId
        
        set lineNumbers [findDeprecatedRegisterHttpHandlerLines $content]
        
        if {[llength $lineNumbers] > 0} {
            incr foundIssues
            puts "Datei: $file"
            foreach lineNumber $lineNumbers {
                # Zeige die problematische Zeile an
                set lines [split $content "\n"]
                set problematicLine [lindex $lines [expr {$lineNumber - 1}]]
                puts "  Zeile $lineNumber: $problematicLine"
            }
            puts ""
        }
    }
    
    if {$foundIssues > 0} {
        puts "Gefunden: Veraltete plugin API Aufrufe registerHttpHandler(...):"
        puts ""
        puts "Verwenden Sie stattdessen:"
        puts "  registerHttpRoute({ path, auth, match, handler })"
        puts "  registerPluginHttpRoute für dynamische Webhook-Pfade"
        puts ""
        exit 1
    } else {
        puts "Keine veralteten registerHttpHandler Aufrufe gefunden."
    }
}

# Skript als Hauptprogramm ausführen
if {[info script] eq $argv0} {
    runCheck
}
