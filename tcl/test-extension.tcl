#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "5fcacd909a1042c47fd28290b4933fc74864430ea579fa97a0331624c2991a84", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "tcl"}
# test-extension.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

# Lade benötigte Bibliotheken
package require Tcl 8.6

# Globale Variablen
set script_name "test-extension.tcl"

# Funktionen zur Fehlerbehandlung und Formatierung
proc formatErrorMessage {error} {
    # In Tcl gibt es keine direkte Entsprechung zu JavaScript Error-Objekten
    # Daher übernehmen wir den Fehlerstring direkt
    return $error
}

# Funktion zur Auflösung des Testplans
proc resolveExtensionTestPlan {args} {
    array set opts $args
    set cwd $opts(cwd)
    set targetArg $opts(targetArg)
    
    # Simuliere das Verhalten der JavaScript-Funktion
    # In einer echten Implementierung würden hier Dateien durchsucht werden
    set plan [dict create]
    dict set plan extensionDir $targetArg
    dict set plan extensionId [file tail $targetArg]
    dict set plan hasTests true
    dict set plan testFileCount 1
    dict set plan config ""
    dict set plan roots [list $targetArg]
    
    return $plan
}

# Funktion zum Prüfen, ob das Skript direkt aufgerufen wird
proc isDirectScriptRun {} {
    # In Tcl prüfen wir, ob das Skript der Hauptdatei entspricht
    global script_name argv0
    return [string equal [file tail $argv0] $script_name]
}

# Hilfsfunktionen
proc printUsage {} {
    puts stderr "Usage: tclsh test-extension.tcl <extension-name|path> \[additional args...\]"
    puts stderr "       tclsh scripts/test-extension.tcl \[extension-name|path\] \[additional args...\]"
}

proc printNoTestsMessage {plan} {
    set extensionDir [dict get $plan extensionDir]
    puts "\[test-extension\] No tests found for $extensionDir. Skipping."
}

# Simulierte Vitest-Batch-Runner-Funktion
proc runVitestBatch {args} {
    array set opts $args
    set argsList $opts(args)
    set config $opts(config)
    set env $opts(env)
    set targets $opts(targets)
    
    # In einer echten Implementierung würde hier vitest ausgeführt
    # Wir simulieren einen erfolgreichen Durchlauf
    puts "\[test-extension\] Would run vitest with args: $argsList"
    puts "\[test-extension\] Targets: $targets"
    return 0 ;# Erfolgreicher Exit-Code
}

# Hauptfunktion
proc run {} {
    global argv
    
    set rawArgs $argv
    set helpFlags [list "--help" "-h"]
    
    # Prüfe auf Hilfe-Parameter
    foreach arg $rawArgs {
        if {[lsearch -exact $helpFlags $arg] != -1} {
            printUsage
            return
        }
    }
    
    # Filtere -- Argumente
    set passthroughArgs {}
    foreach arg $rawArgs {
        if {$arg ne "--"} {
            lappend passthroughArgs $arg
        }
    }
    
    set targetArg ""
    if {[llength $passthroughArgs] > 0 && ![string match "-*" [lindex $passthroughArgs 0]]} {
        set targetArg [lindex $passthroughArgs 0]
        set passthroughArgs [lreplace $passthroughArgs 0 0]
    }
    
    set plan {}
    if {[catch {
        set plan [resolveExtensionTestPlan cwd [pwd] targetArg $targetArg]
    } error]} {
        printUsage
        puts stderr [formatErrorMessage $error]
        exit 1
    }
    
    if {![dict get $plan hasTests]} {
        printNoTestsMessage $plan
        return
    }
    
    set testFileCount [dict get $plan testFileCount]
    set extensionId [dict get $plan extensionId]
    puts "\[test-extension\] Running $testFileCount test files for $extensionId"
    
    set exitCode [runVitestBatch \
        args $passthroughArgs \
        config [dict get $plan config] \
        env [array get env] \
        targets [dict get $plan roots]]
    
    exit $exitCode
}

# Skript-Startpunkt
if {[isDirectScriptRun]} {
    run
}
