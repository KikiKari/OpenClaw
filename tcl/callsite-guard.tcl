#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "6a8f7c16964abe3cc27a989ce1af8055e5b3ca7e81aad1324446f33964cee3aa", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "tcl"}
# callsite-guard.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Lade benötigte Module
source [file join [file dirname $argv0] ts-guard-utils.tcl]

proc runCallsiteGuard {params} {
    # Extrahiere Parameter
    set importMetaUrl [dict get $params importMetaUrl]
    set sourceRoots [dict get $params sourceRoots]
    set extraTestSuffixes [dict get $params extraTestSuffixes]
    set skipRelativePath [dict get $params skipRelativePath]
    set findCallLines [dict get $params findCallLines]
    set allowCallsite [dict get $params allowCallsite]
    set header [dict get $params header]
    set footer [dict get $params footer]
    set sortViolations [dict get $params sortViolations]
    
    # Bestimme Repo-Root und Source-Roots
    set repoRoot [resolveRepoRoot $importMetaUrl]
    set sourceRoots [resolveSourceRoots $repoRoot $sourceRoots]
    
    # Sammle TypeScript-Dateien
    set files [collectTypeScriptFilesFromRoots $sourceRoots [list extraTestSuffixes $extraTestSuffixes]]
    set violations [list]
    
    # Prüfe jede Datei
    foreach filePath $files {
        # Berechne relativen Pfad
        set relPath [string map {\\ /} [file join [file relative $repoRoot $filePath]]]
        
        # Prüfe ob Pfad übersprungen werden soll
        if {$skipRelativePath ne "" && [apply $skipRelativePath $relPath]} {
            continue
        }
        
        # Lese Dateiinhalt
        set fh [open $filePath r]
        set content [read $fh]
        close $fh
        
        # Finde Call-Lines
        set lines [apply $findCallLines $content $filePath]
        foreach line $lines {
            set callsite "$relPath:$line"
            
            # Prüfe ob Callsite erlaubt ist
            if {$allowCallsite ne "" && [apply $allowCallsite $callsite]} {
                continue
            }
            
            lappend violations $callsite
        }
    }
    
    # Beende wenn keine Verletzungen gefunden
    if {[llength $violations] == 0} {
        return
    }
    
    # Gebe Header aus
    puts stderr $header
    
    # Sortiere Verletzungen falls gewünscht
    if {$sortViolations eq "false"} {
        set output $violations
    } else {
        set output [lsort $violations]
    }
    
    # Gebe Verletzungen aus
    foreach violation $output {
        puts stderr "- $violation"
    }
    
    # Gebe Footer aus
    if {$footer ne ""} {
        puts stderr $footer
    }
    
    # Beende mit Fehlercode
    exit 1
}
