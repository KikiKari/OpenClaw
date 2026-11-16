#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "3f8f056e4889ca13fbeab472fd2934f75de34e2ca7fdfe7f05d23d6716600cbd", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "tcl"}
# bundle-a2ui.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require sha256

# Globale Variablen
set scriptDir [file dirname [info script]]
set rootDir [file normalize [file join $scriptDir ..]]
set hashFile [file join $rootDir src canvas-host a2ui .bundle.hash]
set outputFile [file join $rootDir src canvas-host a2ui a2ui.bundle.js]
set a2uiRendererDir [file join $rootDir vendor a2ui renderers lit]
set a2uiAppDir [file join $rootDir apps shared OpenClawKit Tools CanvasA2UI]
set inputPaths [list \
    [file join $rootDir package.json] \
    [file join $rootDir pnpm-lock.yaml] \
    $a2uiRendererDir \
    $a2uiAppDir \
]
set ignoredBundleHashInputPrefixes [list "vendor/a2ui/renderers/lit/dist"]

proc fail {message} {
    puts stderr $message
    puts stderr "A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle"
    puts stderr "If this persists, verify pnpm deps and try again."
    exit 1
}

proc pathExists {targetPath} {
    return [expr {[file exists $targetPath]}]
}

proc normalizePath {filePath} {
    # In Tcl verwenden wir native Pfade, aber für Vergleiche normalisieren wir sie
    return [string map {\\ /} $filePath]
}

proc isBundleHashInputPath {filePath {repoRoot ""}} {
    global rootDir ignoredBundleHashInputPrefixes
    if {$repoRoot eq ""} {
        set repoRoot $rootDir
    }
    set relativePath [normalizePath [file relative $repoRoot $filePath]]
    
    foreach ignoredPath $ignoredBundleHashInputPrefixes {
        if {$relativePath eq $ignoredPath || [string match "${ignoredPath}/*" $relativePath]} {
            return 0
        }
    }
    return 1
}

proc getLocalRolldownCliCandidates {{repoRoot ""}} {
    global rootDir
    if {$repoRoot eq ""} {
        set repoRoot $rootDir
    }
    
    set candidates [list]
    lappend candidates [file join $repoRoot node_modules rolldown bin cli.mjs]
    lappend candidates [file join $repoRoot node_modules .pnpm node_modules rolldown bin cli.mjs]
    lappend candidates [file join $repoRoot node_modules .pnpm rolldown@1.0.0-rc.12 node_modules rolldown bin cli.mjs]
    
    return $candidates
}

proc walkFiles {entryPath filesVar} {
    upvar $filesVar files
    
    if {![isBundleHashInputPath $entryPath]} {
        return
    }
    
    if {![file isdirectory $entryPath]} {
        lappend files $entryPath
        return
    }
    
    set entries [glob -nocomplain -dir $entryPath *]
    foreach entry $entries {
        walkFiles $entry files
    }
}

proc listTrackedInputFiles {} {
    global rootDir inputPaths
    
    set relativeInputPaths [list]
    foreach inputPath $inputPaths {
        lappend relativeInputPaths [normalizePath [file relative $rootDir $inputPath]]
    }
    
    if {[catch {exec git ls-files -- {*}$relativeInputPaths} result]} {
        return {}
    }
    
    set files [list]
    foreach line [split $result \n] {
        if {$line ne ""} {
            set fullPath [file join $rootDir $line]
            if {[isBundleHashInputPath $fullPath]} {
                lappend files $fullPath
            }
        }
    }
    
    return $files
}

proc computeHash {} {
    global rootDir inputPaths
    
    set files [listTrackedInputFiles]
    if {[llength $files] == 0} {
        set files [list]
        foreach inputPath $inputPaths {
            walkFiles $inputPath files
        }
    }
    
    set sortedFiles [lsort -command comparePaths $files]
    
    set hash [sha256::init]
    foreach filePath $sortedFiles {
        set relativePath [normalizePath [file relative $rootDir $filePath]]
        sha256::update $hash $relativePath\0
        if {[file exists $filePath]} {
            set content [readFile $filePath]
            sha256::update $hash $content\0
        }
    }
    
    return [sha256::final $hash]
}

proc comparePaths {left right} {
    global rootDir
    set leftNorm [normalizePath [file relative $rootDir $left]]
    set rightNorm [normalizePath [file relative $rootDir $right]]
    return [string compare $leftNorm $rightNorm]
}

proc readFile {filePath} {
    if {[catch {open $filePath r} fh]} {
        return ""
    }
    set content [read $fh]
    close $fh
    return $content
}

proc writeFile {filePath content} {
    if {[catch {open $filePath w} fh]} {
        error "Cannot write file: $filePath"
    }
    puts -nonewline $fh $content
    close $fh
}

proc runStep {command args} {
    global env
    
    set options [dict create]
    if {[llength $args] > 0 && [dict exists [lindex $args end] options]} {
        set optionsDict [dict get [lindex $args end] options]
        set args [lrange $args 0 end-1]
        array set optionsArr $optionsDict
        if {[info exists optionsArr(shell)]} {
            # Shell-Option wird ignoriert in Tcl
        }
    }
    
    if {[catch {exec $command {*}$args} result]} {
        if {[info exists ::errorCode]} {
            exit [lindex $::errorCode 2]
        } else {
            exit 1
        }
    }
}

proc runPnpm {pnpmArgs} {
    global env
    
    # Vereinfachte Implementierung des pnpm runners
    set command "pnpm"
    set fullArgs $pnpmArgs
    
    # Prüfen ob npm_execpath existiert
    if {[info exists env(npm_execpath)] && $env(npm_execpath) ne ""} {
        set command $env(npm_execpath)
        # Füge pnpmArgs als Argumente hinzu
        set fullArgs [concat $pnpmArgs]
    }
    
    runStep $command {*}$fullArgs
}

proc main {} {
    global rootDir a2uiRendererDir a2uiAppDir outputFile env
    
    set hasRendererDir [pathExists $a2uiRendererDir]
    set hasAppDir [pathExists $a2uiAppDir]
    set hasOutputFile [pathExists $outputFile]
    
    if {!$hasRendererDir || !$hasAppDir} {
        if {$hasOutputFile} {
            puts "A2UI sources missing; keeping prebuilt bundle."
            return
        }
        if {[info exists env(OPENCLAW_SPARSE_PROFILE)] || 
            ([info exists env(OPENCLAW_A2UI_SKIP_MISSING)] && $env(OPENCLAW_A2UI_SKIP_MISSING) eq "1")} {
            puts stderr "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set."
            return
        }
        fail "A2UI sources missing and no prebuilt bundle found at: $outputFile"
    }
    
    set currentHash [computeHash]
    set previousHash ""
    set hashFileExists [pathExists $hashFile]
    
    if {$hashFileExists} {
        set previousHash [string trim [readFile $hashFile]]
    }
    
    if {$hashFileExists && $previousHash eq $currentHash && $hasOutputFile} {
        puts "A2UI bundle up to date; skipping."
        return
    }
    
    runPnpm [list "-s" "exec" "tsc" "-p" [file join $a2uiRendererDir "tsconfig.json"]]
    
    set localRolldownCliCandidates [getLocalRolldownCliCandidates]
    set localRolldownCli ""
    
    foreach candidate $localRolldownCliCandidates {
        if {[pathExists $candidate]} {
            set localRolldownCli $candidate
            break
        }
    }
    
    if {$localRolldownCli ne ""} {
        runStep [info nameofexecutable] $localRolldownCli -c [file join $a2uiAppDir "rolldown.config.mjs"]
    } else {
        runPnpm [list "-s" "exec" "rolldown" "-c" [file join $a2uiAppDir "rolldown.config.mjs"]]
    }
    
    writeFile $hashFile "$currentHash\n"
}

# Fehlerbehandlung
if {[catch {main} error]} {
    fail [expr {[info exists error] ? $error : "Unknown error"}]
}
