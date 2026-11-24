#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "c122d738a871335f8448a5c268bfeda67d80d350aa5193d86bba4bc71d602f5a", "source_sha256": "fe4ef822110d5a3d05561b87f0634182183de94f1130dc41ba19fd74bdff1653", "target_language": "tcl"}
# test-extension-batch.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension-batch.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

# Lade benötigte Module
source [file join [file dirname [info script]] lib extension-test-plan.tcl]
source [file join [file dirname [info script]] lib vitest-batch-runner.tcl]

proc printUsage {} {
    puts stderr "Usage: pnpm test:extensions:batch <extension\[,extension...\]> \[vitest args...\]"
    puts stderr "       tclsh scripts/test-extension-batch.tcl <extension\[,extension...\]> \[vitest args...\]"
}

proc parseExtensionIds {rawArgs} {
    set args [list {*}$rawArgs]
    set extensionIds [list]
    
    while {[llength $args] > 0 && ![string match {-*} [lindex $args 0]]} {
        set firstArg [lindex $args 0]
        set args [lreplace $args 0 0]
        
        foreach value [split $firstArg ,] {
            set trimmed [string trim $value]
            if {$trimmed ne ""} {
                lappend extensionIds $trimmed
            }
        }
    }
    
    return [list extensionIds $extensionIds passthroughArgs $args]
}

proc run {} {
    set argvCopy $::argv
    
    # Entferne --help und -h Prüfung
    if {[lsearch -exact $argvCopy "--help"] != -1 || [lsearch -exact $argvCopy "-h"] != -1} {
        printUsage
        return
    }
    
    # Filtere -- Argumente
    set passthroughArgs [list]
    foreach arg $argvCopy {
        if {$arg ne "--"} {
            lappend passthroughArgs $arg
        }
    }
    
    # Parse Extension IDs
    set parseResult [parseExtensionIds $passthroughArgs]
    set extensionIds [dict get $parseResult extensionIds]
    set vitestArgs [dict get $parseResult passthroughArgs]
    
    if {[llength $extensionIds] == 0} {
        printUsage
        exit 1
    }
    
    # Erstelle Batch Plan
    set batchPlan [resolveExtensionBatchPlan [dict create cwd [pwd] extensionIds $extensionIds]]
    
    if {![dict get $batchPlan hasTests]} {
        puts "\[test-extension-batch\] No tests found for the requested extensions. Skipping."
        return
    }
    
    puts "\[test-extension-batch\] Running [dict get $batchPlan testFileCount] test files across [dict get $batchPlan extensionCount] extensions"
    
    # Führe Tests für jede Gruppe aus
    set planGroups [dict get $batchPlan planGroups]
    foreach group $planGroups {
        set config [dict get $group config]
        set extensionIdsList [dict get $group extensionIds]
        set testFileCount [dict get $group testFileCount]
        set roots [dict get $group roots]
        
        puts "\[test-extension-batch\] $config: [join $extensionIdsList ", "] ($testFileCount files)"
        
        set exitCode [runVitestBatch [dict create \
            args $vitestArgs \
            config $config \
            env [array get ::env] \
            targets $roots]]
            
        if {$exitCode != 0} {
            exit $exitCode
        }
    }
}

# Prüfe ob das Skript direkt ausgeführt wird
if {[info script] eq $::argv0} {
    run
}
