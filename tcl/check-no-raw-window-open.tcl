#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "cda0bf18441d40221422034fd67c3952e2709fe9df1bab1b7d700169950771c2", "source_sha256": "b77d7ac77e305afea60b0aa9579426471649732bc9d7cb3bce3f14575d0d0bb6", "target_language": "tcl"}
# check-no-raw-window-open.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-window-open.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Emulate Node.js path and fs modules functionality in Tcl
namespace eval path {
    proc join {args} {
        return [file join {*}$args]
    }

    proc relative {from to} {
        return [file relative $to $from]
    }
}

namespace eval fs {
    proc readFile {filePath encoding} {
        set fh [open $filePath r]
        fconfigure $fh -encoding $encoding
        set content [read $fh]
        close $fh
        return $content
    }
}

# Dummy TypeScript AST functions - these would need a real TypeScript parser in Tcl
# For now we simulate the behavior with string matching since full AST parsing is complex

proc unwrapExpression {expr} {
    # Simplified: just return the expression itself
    return $expr
}

proc isPropertyAccess {expression} {
    # Simulate checking if it's a property access like window.open or globalThis.open
    if {[regexp {^(window|globalThis)\.open} $expression]} {
        return $expression
    }
    return {}
}

proc isRawWindowOpenCall {expression} {
    set propertyAccess [isPropertyAccess [unwrapExpression $expression]]
    if {$propertyAccess ne ""} {
        return 1
    }
    return 0
}

proc toLine {sourceFile node} {
    # Simplified line number extraction - in reality this would come from the AST
    # Here we just return a placeholder or extract line from source
    return 1
}

proc findRawWindowOpenLines {content fileName} {
    set lines {}
    set lineNumber 0
    foreach line [split $content \n] {
        incr lineNumber
        # Check for patterns like window.open or globalThis.open not followed by safe wrapper
        if {[regexp {\b(window|globalThis)\.open\s*\([^)]*\)} $line match target] && 
            ![regexp {openExternalUrlSafe} $line]} {
            lappend lines $lineNumber
        }
    }
    return $lines
}

proc resolveRepoRoot {} {
    # Get the directory of this script as the repo root
    return [file dirname [file dirname [info script]]]
}

proc collectTypeScriptFiles {dir {extraTestSuffixes {".browser.test.ts" ".node.test.ts"}} {ignoreMissing true}} {
    set files {}
    if {![file exists $dir]} {
        if {!$ignoreMissing} {
            error "Directory does not exist: $dir"
        }
        return $files
    }

    # Recursively find all .ts files excluding test files unless specified
    proc scanDir {d} {
        upvar files fl extraTestSuffixes ext ignoreMissing im
        if {![file isdirectory $d]} return
        foreach item [glob -nocomplain -directory $d *] {
            if {[file isdirectory $item]} {
                scanDir $item
            } elseif {[file extension $item] eq ".ts" && [file extension $item] ne ".d.ts"} {
                set isTest 0
                foreach suffix $ext {
                    if {[string match "*$suffix" $item]} {
                        set isTest 1
                        break
                    }
                }
                if {!$isTest} {
                    lappend fl $item
                }
            }
        }
    }

    scanDir $dir
    return $files
}

proc main {} {
    set repoRoot [resolveRepoRoot]
    set uiSourceDir [path::join $repoRoot "ui" "src" "ui"]
    set allowedCallsites [dict create [path::join $uiSourceDir "open-external-url.ts"] 1]

    set files [collectTypeScriptFiles $uiSourceDir]
    set violations {}

    foreach filePath $files {
        if {[dict exists $allowedCallsites $filePath]} {
            continue
        }

        if {![file exists $filePath]} {
            continue
        }

        set content [fs::readFile $filePath utf8]
        set lines [findRawWindowOpenLines $content $filePath]
        foreach line $lines {
            set relPath [path::relative $repoRoot $filePath]
            lappend violations "$relPath:$line"
        }
    }

    if {[llength $violations] == 0} {
        return
    }

    puts stderr "Found raw window.open usage outside safe helper:"
    foreach violation $violations {
        puts stderr "- $violation"
    }
    puts stderr "Use openExternalUrlSafe(...) from ui/src/ui/open-external-url.ts instead."
    exit 1
}

# Run main if script is executed directly
if {[info script] eq $argv0} {
    main
}
