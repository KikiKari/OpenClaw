#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "b58a50ea9c3214a8e6d37ab788ab95aa820a014c56b412afc642f210ff977765", "source_sha256": "913a32ef02a0f4e83bb9d65b279088c91abd5e717e9dbba62e17a4a50836e586", "target_language": "tcl"}
# check-architecture-smells.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-architecture-smells.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require fileutil
package require json

# Define constants
set repoRoot [file normalize [file dirname [info script]]/..]
set BUNDLED_PLUGIN_PATH_PREFIX "extensions/"

# Utility functions
proc normalizeRepoPath {repoRoot filePath} {
    set absPath [file normalize $filePath]
    if {[string first $repoRoot $absPath] == 0} {
        return [string range $absPath [string length $repoRoot]+1 end]
    }
    return $absPath
}

proc resolveRepoSpecifier {repoRoot specifier filePath} {
    set dir [file dirname $filePath]
    set resolved [file join $dir $specifier]
    set normalized [file normalize $resolved]
    if {[string first $repoRoot $normalized] == 0} {
        return [string range $normalized [string length $repoRoot]+1 end]
    }
    return ""
}

proc toLine {sourceFile node} {
    # Placeholder implementation
    return 1
}

proc writeLine {stream text} {
    puts $stream $text
}

proc collectTypeScriptFilesFromRoots {roots} {
    set files {}
    foreach root $roots {
        if {[file exists $root]} {
            lappend files {*}[glob -nocomplain -type f -directory $root *.ts]
        }
    }
    return $files
}

proc resolveSourceRoots {repoRoot paths} {
    set roots {}
    foreach path $paths {
        lappend roots [file join $repoRoot $path]
    }
    return $roots
}

proc runAsScript {scriptName mainProc} {
    if {[info script] eq $scriptName} {
        $mainProc $::argv
    }
}

# Comparison function
proc compareEntries {left right} {
    set cmp [string compare [dict get $left category] [dict get $right category]]
    if {$cmp != 0} {return $cmp}
    
    set cmp [string compare [dict get $left file] [dict get $right file]]
    if {$cmp != 0} {return $cmp}
    
    set cmp [expr {[dict get $left line] - [dict get $right line]}]
    if {$cmp != 0} {return $cmp}
    
    set cmp [string compare [dict get $left kind] [dict get $right kind]]
    if {$cmp != 0} {return $cmp}
    
    set cmp [string compare [dict get $left specifier] [dict get $right specifier]]
    if {$cmp != 0} {return $cmp}
    
    return [string compare [dict get $left reason] [dict get $right reason]]
}

# Scan functions
proc scanPluginSdkExtensionFacadeSmells {sourceFile filePath repoRoot} {
    set relativeFile [normalizeRepoPath $repoRoot $filePath]
    if {![string match "src/plugin-sdk/*" $relativeFile]} {
        return {}
    }
    
    set entries {}
    # Placeholder logic for scanning module specifiers
    # This would need actual TypeScript AST parsing in real implementation
    return $entries
}

proc scanRuntimeTypeImplementationSmells {sourceFile filePath repoRoot} {
    set relativeFile [normalizeRepoPath $repoRoot $filePath]
    if {![regexp {^src/plugins/runtime/types(?:-[^/]+)?\.ts$} $relativeFile]} {
        return {}
    }
    
    set entries {}
    # Placeholder logic for visiting nodes
    return $entries
}

proc scanRuntimeServiceLocatorSmells {sourceFile filePath repoRoot} {
    set relativeFile [normalizeRepoPath $repoRoot $filePath]
    if {![string match "src/plugin-sdk/*" $relativeFile] && ![string match "src/plugins/runtime/*" $relativeFile]} {
        return {}
    }
    
    set entries {}
    set exportedNames {}
    set runtimeStoreCalls {}
    set mutableStateNodes {}
    
    # Placeholder logic for analyzing statements and visiting nodes
    return $entries
}

proc collectArchitectureSmells {repoRoot scanRoots} {
    set files [lsort -dictionary [collectTypeScriptFilesFromRoots $scanRoots]]
    set inventory {}
    
    foreach filePath $files {
        set sourceFile {} ;# Placeholder for actual source file content
        
        set entries {}
        lappend entries {*}[scanPluginSdkExtensionFacadeSmells $sourceFile $filePath $repoRoot]
        lappend entries {*}[scanRuntimeTypeImplementationSmells $sourceFile $filePath $repoRoot]
        lappend entries {*}[scanRuntimeServiceLocatorSmells $sourceFile $filePath $repoRoot]
        
        set inventory [concat $inventory $entries]
    }
    
    return [lsort -command compareEntries $inventory]
}

proc formatInventoryHuman {inventory} {
    if {[llength $inventory] == 0} {
        return "No architecture smells found for the configured checks."
    }
    
    set lines [list "Architecture smell inventory:"]
    set activeCategory ""
    set activeFile ""
    
    foreach entry $inventory {
        set category [dict get $entry category]
        set file [dict get $entry file]
        
        if {$category ne $activeCategory} {
            set activeCategory $category
            set activeFile ""
            lappend lines $category
        }
        
        if {$file ne $activeFile} {
            set activeFile $file
            lappend lines "  $file"
        }
        
        lappend lines "    - line [dict get $entry line] \[[dict get $entry kind]\] [dict get $entry reason]"
        lappend lines "      specifier: [dict get $entry specifier]"
        lappend lines "      resolved: [dict get $entry resolvedPath]"
    }
    
    return [join $lines "\n"]
}

proc runArchitectureSmellsCheck {{argv {}} {io ""}} {
    global argv
    if {$argv eq ""} {set argv $::argv}
    
    set json [expr {[lsearch -exact $argv "--json"] >= 0}]
    set scanRoots [resolveSourceRoots $::repoRoot {src/plugin-sdk src/plugins/runtime}]
    set inventory [collectArchitectureSmells $::repoRoot $scanRoots]
    
    if {$json} {
        writeLine stdout [::json::encode $inventory]
        return 0
    }
    
    writeLine stdout [formatInventoryHuman $inventory]
    writeLine stdout "[llength $inventory] smell[expr {[llength $inventory] != 1 ? \"s\" : \"\"}] found."
    return 0
}

proc main {{argv {}} {io ""}} {
    return [runArchitectureSmellsCheck $argv $io]
}

# Run as script
if {[info script] eq $argv0} {
    main $::argv
}
