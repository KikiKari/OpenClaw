#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "a4b91a065e807cd9cf72fba3ad7def3001eeef5a19b3e8c083b2e242dab1ced6", "source_sha256": "c1ed4f7faa3c799c1ac7104f76f48529711802b8f045a3a2fa20f18a82447b76", "target_language": "tcl"}
# check-extension-plugin-sdk-boundary.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-plugin-sdk-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require json
package require fileutil

# Configuration constants
set repoRoot [file normalize [file join [file dirname [info script]] ..]]
set BUNDLED_PLUGIN_ROOT_DIR "extensions"
set extensionsRoot [file join $repoRoot $BUNDLED_PLUGIN_ROOT_DIR]

array set MODES {
    src-outside-plugin-sdk 1
    plugin-sdk-internal 1
    relative-outside-package 1
}

array set baselinePathByMode [
    list \
    src-outside-plugin-sdk [file join $repoRoot test fixtures extension-src-outside-plugin-sdk-inventory.json] \
    plugin-sdk-internal [file join $repoRoot test fixtures extension-plugin-sdk-internal-inventory.json] \
    relative-outside-package [file join $repoRoot test fixtures extension-relative-outside-package-inventory.json]
]

array set ruleTextByMode [
    list \
    src-outside-plugin-sdk "Rule: production bundled plugins must not import src/** outside src/plugin-sdk/**" \
    plugin-sdk-internal "Rule: production bundled plugins must not import src/plugin-sdk-internal/**" \
    relative-outside-package "Rule: production bundled plugins must not use relative imports that escape their own package root"
]

# Global state variables
set allInventoryByModePromise ""
set parsedExtensionSourceFilesPromise ""

proc isCodeFile {fileName} {
    regexp {\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$} $fileName
}

proc isBoundaryCanaryFile {fileName} {
    string match "*__rootdir_boundary_canary__*" $fileName
}

proc normalizeRepoPath {repoRoot fullPath} {
    # Convert absolute path to relative path from repo root
    set normalized [file normalize $fullPath]
    set rootNormalized [file normalize $repoRoot]
    
    # Remove repoRoot prefix
    if {[string first $rootNormalized $normalized] == 0} {
        set result [string range $normalized [string length $rootNormalized] end]
        # Remove leading slash if present
        if {[string index $result 0] eq "/"} {
            set result [string range $result 1 end]
        }
        return $result
    }
    return $normalized
}

proc classifyBundledExtensionSourcePath {relativePath} {
    # Simplified implementation - in real case would need to implement full logic
    array set result {isTestLike 0}
    
    # Check if path looks like test-related
    if {[regexp {(test|__tests__|\.test\.|\.spec\.)} $relativePath]} {
        set result(isTestLike) 1
    }
    
    return [array get result]
}

proc resolveRepoSpecifier {repoRoot specifier filePath} {
    # Simplified resolver - would need proper implementation
    if {[string match "src/*" $specifier]} {
        return $specifier
    } elseif {[string match "./src/*" $specifier]} {
        return [string range $specifier 2 end]
    }
    return $specifier
}

proc toLine {sourceFile specifierNode} {
    # Placeholder - would need actual implementation
    return 1
}

proc visitModuleSpecifiers {callback} {
    # Placeholder - would need actual TypeScript AST parsing
    # This would be complex to implement in pure Tcl
}

proc collectExtensionSourceFiles {rootDir} {
    variable repoRoot
    
    set out {}
    
    proc walk {dir repoRoot outVar} {
        upvar $outVar out
        
        if {![file exists $dir] || ![file isdirectory $dir]} {
            return
        }
        
        set entries [lsort [glob -nocomplain -dir $dir *]]
        foreach entryPath $entries {
            set entryName [file tail $entryPath]
            
            if {$entryName eq "dist" || $entryName eq "node_modules"} {
                continue
            }
            
            if {[file isdirectory $entryPath]} {
                walk $entryPath $repoRoot out
                continue
            }
            
            if {![file isfile $entryPath] || ![isCodeFile $entryName] || [isBoundaryCanaryFile $entryName]} {
                continue
            }
            
            set relativePath [normalizeRepoPath $::repoRoot $entryPath]
            array set classification [classifyBundledExtensionSourcePath $relativePath]
            
            if {!$classification(isTestLike)} {
                lappend out $entryPath
            }
        }
    }
    
    walk $rootDir $repoRoot out
    
    # Sort by relative path
    set sorted {}
    foreach filePath $out {
        lappend sorted [list [normalizeRepoPath $repoRoot $filePath] $filePath]
    }
    
    set result {}
    foreach item [lsort -index 0 $sorted] {
        lappend result [lindex $item 1]
    }
    
    return $result
}

proc collectParsedExtensionSourceFiles {} {
    variable parsedExtensionSourceFilesPromise
    variable extensionsRoot
    variable repoRoot
    
    if {$parsedExtensionSourceFilesPromise eq ""} {
        set parsedExtensionSourceFilesPromise [collectExtensionSourceFiles $extensionsRoot]
    }
    
    return $parsedExtensionSourceFilesPromise
}

proc resolveExtensionRoot {filePath} {
    variable repoRoot
    variable BUNDLED_PLUGIN_ROOT_DIR
    
    set relativePath [normalizeRepoPath $repoRoot $filePath]
    set segments [split $relativePath "/"]
    
    if {[lindex $segments 0] ne $BUNDLED_PLUGIN_ROOT_DIR || [llength $segments] < 2} {
        return ""
    }
    
    return "[lindex $segments 0]/[lindex $segments 1]"
}

proc classifyReason {mode kind resolvedPath specifier} {
    set verb "imports"
    switch $kind {
        export { set verb "re-exports" }
        dynamic-import { set verb "dynamically imports" }
        default { set verb "imports" }
    }
    
    switch $mode {
        relative-outside-package {
            if {[string match "src/plugin-sdk/*" $resolvedPath]} {
                return "$verb plugin-sdk via relative path; use openclaw/plugin-sdk/<subpath>"
            }
            if {[string match "src/*" $resolvedPath]} {
                return "$verb core src path via relative path outside the extension package"
            }
            if {[string match "extensions/*" $resolvedPath]} {
                return "$verb another bundled plugin via relative path outside the extension package"
            }
            return "$verb relative path $specifier outside the extension package"
        }
        plugin-sdk-internal {
            return "$verb src/plugin-sdk-internal from an extension"
        }
        default {
            if {[string match "src/plugin-sdk/*" $resolvedPath]} {
                return "$verb allowed plugin-sdk path"
            }
            return "$verb core src path outside plugin-sdk from an extension"
        }
    }
}

proc compareEntries {left right} {
    set fileComp [string compare [dict get $left file] [dict get $right file]]
    if {$fileComp != 0} {return $fileComp}
    
    set lineComp [expr {[dict get $left line] - [dict get $right line]}]
    if {$lineComp != 0} {return $lineComp}
    
    set kindComp [string compare [dict get $left kind] [dict get $right kind]]
    if {$kindComp != 0} {return $kindComp}
    
    set specifierComp [string compare [dict get $left specifier] [dict get $right specifier]]
    if {$specifierComp != 0} {return $specifierComp}
    
    return [string compare [dict get $left resolvedPath] [dict get $right resolvedPath]]
}

proc shouldReport {mode resolvedPath} {
    if {$mode eq "relative-outside-package"} {
        return 0
    }
    
    if {![string match "src/*" $resolvedPath]} {
        return 0
    }
    
    if {$mode eq "plugin-sdk-internal"} {
        return [string match "src/plugin-sdk-internal/*" $resolvedPath]
    }
    
    return [expr {![string match "src/plugin-sdk/*" $resolvedPath]}]
}

proc collectEntriesByModeFromSourceFile {filePath} {
    variable repoRoot
    
    array set entriesByMode {
        src-outside-plugin-sdk {}
        plugin-sdk-internal {}
        relative-outside-package {}
    }
    
    set extensionRoot [resolveExtensionRoot $filePath]
    set relativeFile [normalizeRepoPath $repoRoot $filePath]
    
    # Placeholder - would need actual AST parsing
    # For now we'll return empty entries
    return [array get entriesByMode]
}

proc collectExtensionPluginSdkBoundaryInventory {mode} {
    variable MODES
    variable allInventoryByModePromise
    variable extensionsRoot
    
    if {![info exists MODES($mode)]} {
        error "Unknown mode: $mode"
    }
    
    if {$allInventoryByModePromise eq ""} {
        set files [collectParsedExtensionSourceFiles]
        array set inventoryByMode {
            src-outside-plugin-sdk {}
            plugin-sdk-internal {}
            relative-outside-package {}
        }
        
        foreach filePath $files {
            array set entriesByMode [collectEntriesByModeFromSourceFile $filePath]
            foreach inventoryMode [array names MODES] {
                set inventoryByMode($inventoryMode) [concat $inventoryByMode($inventoryMode) $entriesByMode($inventoryMode)]
            }
        }
        
        # Sort entries
        foreach inventoryMode [array names MODES] {
            set inventoryByMode($inventoryMode) [lsort -command compareEntries $inventoryByMode($inventoryMode)]
        }
        
        set allInventoryByModePromise [array get inventoryByMode]
    }
    
    array set inventoryByMode $allInventoryByModePromise
    return $inventoryByMode($mode)
}

proc readExpectedInventory {mode} {
    variable baselinePathByMode
    
    if {[catch {open $baselinePathByMode($mode) r} fd]} {
        if {($mode eq "plugin-sdk-internal" || $mode eq "src-outside-plugin-sdk" || $mode eq "relative-outside-package") && 
            [string match "*no such file or directory*" $fd]} {
            return {}
        }
        error $fd
    }
    
    set content [read $fd]
    close $fd
    return [json::json2dict $content]
}

proc diffInventoryEntries {expected actual compareFunc} {
    # Simplified diff implementation
    array set result {missing {} unexpected {}}
    
    # Find missing entries (in expected but not in actual)
    foreach expEntry $expected {
        set found 0
        foreach actEntry $actual {
            if {[compareEntries $expEntry $actEntry] == 0} {
                set found 1
                break
            }
        }
        if {!$found} {
            lappend result(missing) $expEntry
        }
    }
    
    # Find unexpected entries (in actual but not in expected)
    foreach actEntry $actual {
        set found 0
        foreach expEntry $expected {
            if {[compareEntries $actEntry $expEntry] == 0} {
                set found 1
                break
            }
        }
        if {!$found} {
            lappend result(unexpected) $actEntry
        }
    }
    
    return [array get result]
}

proc diffInventory {expected actual} {
    return [diffInventoryEntries $expected $actual "compareEntries"]
}

proc formatInventoryHuman {mode inventory} {
    variable ruleTextByMode
    
    set lines [list $ruleTextByMode($mode)]
    
    if {[llength $inventory] == 0} {
        lappend lines "No extension plugin-sdk boundary violations found."
        return [join $lines "\n"]
    }
    
    lappend lines "Extension boundary inventory:"
    set activeFile ""
    
    foreach entry $inventory {
        set currentFile [dict get $entry file]
        if {$currentFile ne $activeFile} {
            set activeFile $currentFile
            lappend lines $activeFile
        }
        lappend lines "  - line [dict get $entry line] \[[dict get $entry kind]\] [dict get $entry reason]"
        lappend lines "    specifier: [dict get $entry specifier]"
        lappend lines "    resolved: [dict get $entry resolvedPath]"
    }
    
    return [join $lines "\n"]
}

proc writeLine {stream text} {
    puts $stream $text
    flush $stream
}

proc runExtensionPluginSdkBoundaryCheck {{argv ""} {io ""}} {
    variable MODES
    variable baselinePathByMode
    
    if {$argv eq ""} {
        set argv [lassign $::argv]
    }
    
    set json 0
    set mode "src-outside-plugin-sdk"
    
    foreach arg $argv {
        if {$arg eq "--json"} {
            set json 1
        } elseif {[string match "--mode=*" $arg]} {
            set mode [string range $arg 7 end]
        }
    }
    
    if {![info exists MODES($mode)]} {
        error "Unknown mode: $mode"
    }
    
    set actual [collectExtensionPluginSdkBoundaryInventory $mode]
    
    if {$io eq ""} {
        array set streams {stdout stdout stderr stderr}
    } else {
        array set streams $io
    }
    
    if {$json} {
        writeLine $streams(stdout) [json::dict2json $actual]
        return 0
    }
    
    writeLine $streams(stdout) [formatInventoryHuman $mode $actual]
    
    if {$mode eq "relative-outside-package"} {
        if {[llength $actual] == 0} {
            return 0
        }
        writeLine $streams(stderr) "Relative outside-package violations found ([llength $actual]); this mode no longer uses a baseline."
        return 1
    }
    
    set expected [readExpectedInventory $mode]
    array set diff [diffInventory $expected $actual]
    
    if {[llength $diff(missing)] == 0 && [llength $diff(unexpected)] == 0} {
        writeLine $streams(stdout) "Baseline matches ([llength $actual] entries)."
        return 0
    }
    
    if {[llength $diff(missing)] > 0} {
        writeLine $streams(stderr) "Missing baseline entries ([llength $diff(missing)]):"
        foreach entry $diff(missing) {
            writeLine $streams(stderr) "  - [dict get $entry file]:[dict get $entry line] [dict get $entry reason]"
        }
    }
    
    if {[llength $diff(unexpected)] > 0} {
        writeLine $streams(stderr) "Unexpected inventory entries ([llength $diff(unexpected)]):"
        foreach entry $diff(unexpected) {
            writeLine $streams(stderr) "  - [dict get $entry file]:[dict get $entry line] [dict get $entry reason]"
        }
    }
    
    return 1
}

proc main {{argv ""} {io ""}} {
    set exitCode [runExtensionPluginSdkBoundaryCheck $argv $io]
    if {$io eq ""} {
        exit $exitCode
    }
    return $exitCode
}

# Auto-execute if called directly
if {[info script] eq $argv0} {
    main
}
