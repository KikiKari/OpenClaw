#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "ec0d6a15b686882bf0bde97668bda00c6be5c53e122181b1007a20c9af8b0e18", "source_sha256": "f01a1a7ac46054c631b27d8f3e127238ed7417a0fe38ecb59857573bd355603f", "target_language": "tcl"}
# guard-inventory-utils.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/guard-inventory-utils.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have native support for TypeScript parsing or module resolution like JavaScript/Node.js.
# This translation will simulate the structure and logic but cannot replicate full functionality without
# external tools or libraries for TypeScript AST parsing.

namespace eval GuardInventoryUtils {
    variable parsedTypeScriptSourceCache
    array set parsedTypeScriptSourceCache {}

    proc normalizeRepoPath {repoRoot filePath} {
        # Simulate path.relative and replace separators
        set relative [fileutil::stripPathPrefix $repoRoot $filePath]
        return [string map {\\ /} $relative]
    }

    proc resolveRepoSpecifier {repoRoot specifier importerFile} {
        if {[string match .* $specifier]} {
            set resolved [file join [file dirname $importerFile] $specifier]
            return [normalizeRepoPath $repoRoot $resolved]
        } elseif {[string match /* $specifier]} {
            return [normalizeRepoPath $repoRoot $specifier]
        }
        return ""
    }

    proc visitModuleSpecifiers {ts sourceFile visitCallback} {
        # Placeholder - Tcl can't parse TypeScript AST natively
        # This would require an external tool or library
        error "TypeScript AST parsing not supported in Tcl"
    }

    proc diffInventoryEntries {expected actual compareEntriesCmd} {
        set expectedKeys [dict create]
        set actualKeys [dict create]

        foreach entry $expected {
            dict set expectedKeys [::json::encode $entry] 1
        }

        foreach entry $actual {
            dict set actualKeys [::json::encode $entry] 1
        }

        set missing {}
        set unexpected {}

        foreach entry $expected {
            if {![dict exists $actualKeys [::json::encode $entry]]} {
                lappend missing $entry
            }
        }

        foreach entry $actual {
            if {![dict exists $expectedKeys [::json::encode $entry]]} {
                lappend unexpected $entry
            }
        }

        set missing [lsort -command $compareEntriesCmd $missing]
        set unexpected [lsort -command $compareEntriesCmd $unexpected]

        return [list missing $missing unexpected $unexpected]
    }

    proc writeLine {stream text} {
        puts $stream $text
    }

    proc collectTypeScriptInventory {params} {
        global parsedTypeScriptSourceCache

        set inventory {}
        set scriptKind [dict get $params scriptKind]
        if {$scriptKind eq ""} {
            set scriptKind "TS" ;# Default value
        }

        foreach filePath [dict get $params files] {
            set cacheKey "${scriptKind}:${filePath}"
            if {[info exists parsedTypeScriptSourceCache($cacheKey)]} {
                set sourceFile $parsedTypeScriptSourceCache($cacheKey)
            } else {
                set source [readFile $filePath]
                if {[dict exists $params shouldParseSource]} {
                    set shouldParseCmd [dict get $params shouldParseSource]
                    if {![{*}$shouldParseCmd $source $filePath]} {
                        continue
                    }
                }
                # Placeholder for creating source file object
                set sourceFile [createSourceFile $filePath $source]
                set parsedTypeScriptSourceCache($cacheKey) $sourceFile
            }
            set collectEntriesCmd [dict get $params collectEntries]
            set newEntries [{*}$collectEntriesCmd $sourceFile $filePath]
            set inventory [concat $inventory $newEntries]
        }

        set compareEntriesCmd [dict get $params compareEntries]
        return [lsort -command $compareEntriesCmd $inventory]
    }

    proc runBaselineInventoryCheck {params} {
        set streams [dict get $params io]
        if {$streams eq ""} {
            set streams [list stdout stdout stderr stderr]
        }

        set json [expr {"--json" in [dict get $params argv]}]
        set collectActualCmd [dict get $params collectActual]
        set actual [{*}$collectActualCmd]
        set readExpectedCmd [dict get $params readExpected]
        set expected [{*}$readExpectedCmd]
        set diffInventoryCmd [dict get $params diffInventory]
        set diffResult [{*}$diffInventoryCmd $expected $actual]
        set missing [dict get $diffResult missing]
        set unexpected [dict get $diffResult unexpected]
        set matchesBaseline [expr {[llength $missing] == 0 && [llength $unexpected] == 0}]

        if {$json} {
            set stdoutStream [dict get $streams stdout]
            writeLine $stdoutStream [::json::encodePretty $actual]
        } else {
            set stdoutStream [dict get $streams stdout]
            set formatInventoryHumanCmd [dict get $params formatInventoryHuman]
            writeLine $stdoutStream [{*}$formatInventoryHumanCmd $actual]
            set message [expr {$matchesBaseline ? 
                "Baseline matches ([llength $actual] entries)." :
                "Baseline mismatch ([llength $unexpected] unexpected, [llength $missing] missing)."}]
            writeLine $stdoutStream $message

            if {!$matchesBaseline} {
                set stderrStream [dict get $streams stderr]
                if {[llength $unexpected] > 0} {
                    writeLine $stderrStream "Unexpected entries:"
                    set formatEntryCmd [dict get $params formatEntry]
                    foreach entry $unexpected {
                        writeLine $stderrStream "- [{*}$formatEntryCmd $entry]"
                    }
                }
                if {[llength $missing] > 0} {
                    writeLine $stderrStream "Missing baseline entries:"
                    set formatEntryCmd [dict get $params formatEntry]
                    foreach entry $missing {
                        writeLine $stderrStream "- [{*}$formatEntryCmd $entry]"
                    }
                }
            }
        }

        return [expr {$matchesBaseline ? 0 : 1}]
    }

    # Helper procedures that need to be implemented based on specific needs
    proc readFile {filePath} {
        set fh [open $filePath r]
        set content [read $fh]
        close $fh
        return $content
    }

    proc createSourceFile {filePath source} {
        # Placeholder for source file creation
        return [list filePath $filePath sourceLength [string length $source]]
    }
}

# Package requirements
package require json
package require fileutil

# Exported functions would go here if needed, but Tcl doesn't have direct export mechanism like JS modules
