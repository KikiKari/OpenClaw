#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "974dfd734a312383cb67921d7cbd824dd555bc23d839b6c3f205022fa9142655", "source_sha256": "290dec5062f0c8675bc7304f9c93475a3e9667ed53e93894c5bc66f40e5ae5df", "target_language": "tcl"}
# check-no-random-messaging-tmp.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-random-messaging-tmp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of check-no-random-messaging-tmp.mjs

# Helper functions to mimic JavaScript behavior
proc endsWith {str suffix} {
    set len [string length $suffix]
    if {$len == 0} {return 1}
    set end [string range $str end-[expr {$len-1}] end]
    return [string equal $end $suffix]
}

proc includes {list item} {
    return [expr {[lsearch -exact $list $item] != -1}]
}

proc some {list predicate} {
    foreach item $list {
        if {[{*}$predicate $item]} {
            return 1
        }
    }
    return 0
}

proc filter {list predicate} {
    set result {}
    foreach item $list {
        if {[{*}$predicate $item]} {
            lappend result $item
        }
    }
    return $result
}

proc map {list func} {
    set result {}
    foreach item $list {
        lappend result [{*}$func $item]
    }
    return $result
}

proc find {list predicate} {
    foreach item $list {
        if {[{*}$predicate $item]} {
            return $item
        }
    }
    return {}
}

proc every {list predicate} {
    foreach item $list {
        if {![{*}$predicate $item]} {
            return 0
        }
    }
    return 1
}

# Load required modules
if {[catch {package require fileutil}]} {
    puts stderr "Error: Tcllib fileutil package is required"
    exit 1
}

# Configuration constants
set messagingTmpdirGuardSourceRoots [list \
    "src/channels" \
    "src/infra/outbound" \
    "src/line" \
    "src/media" \
    "src/media-understanding" \
    "extensions"]

# Placeholder for bundledPluginFile - adjust path as needed
proc bundledPluginFile {plugin path} {
    # This should match the actual implementation
    return "plugins/$plugin/$path"
}

set allowedRelativePaths [dict create]
dict set allowedRelativePaths [bundledPluginFile "feishu" "src/dedup.ts"] 1

# Simple AST-like parsing functions for tmpdir detection
proc collectOsTmpdirImports {content} {
    global allowedRelativePaths
    
    set osModuleSpecifiers [list "node:os" "os"]
    set osNamespaceOrDefault [dict create]
    set namedTmpdir [dict create]
    
    # Very basic parsing - this is a simplified version
    # In reality, proper AST parsing would be needed
    set lines [split $content "\n"]
    
    foreach line $lines {
        # Match import statements like: import os from 'os'
        if {[regexp {^import\s+(\w+)\s+from\s+['"](node:os|os)['"]} $line -> varName moduleSpec]} {
            if {[includes $osModuleSpecifiers $moduleSpec]} {
                dict set osNamespaceOrDefault $varName 1
            }
        }
        
        # Match import statements like: import { tmpdir } from 'os'
        if {[regexp {^import\s+\{([^}]+)\}\s+from\s+['"](node:os|os)['"]} $line -> bindings moduleSpec]} {
            if {[includes $osModuleSpecifiers $moduleSpec]} {
                set bindingList [split [string trim $bindings] ","]
                foreach binding $bindingList {
                    set binding [string trim $binding]
                    if {[regexp {^tmpdir(?:\s+as\s+(\w+))?$} $binding -> alias]} {
                        set tmpdirVar [expr {$alias ne "" ? $alias : "tmpdir"}]
                        dict set namedTmpdir $tmpdirVar 1
                    }
                }
            }
        }
        
        # Match import statements like: import * as os from 'os'
        if {[regexp {^import\s+\*\s+as\s+(\w+)\s+from\s+['"](node:os|os)['"]} $line -> namespace moduleSpec]} {
            if {[includes $osModuleSpecifiers $moduleSpec]} {
                dict set osNamespaceOrDefault $namespace 1
            }
        }
    }
    
    return [list $osNamespaceOrDefault $namedTmpdir]
}

proc unwrapExpression {expression} {
    # Simplified unwrapping - remove parentheses, etc.
    return [string trim $expression]
}

proc isPropertyAccessExpression {callee} {
    # Check if it's a property access like os.tmpdir()
    return [regexp {\w+\.\w+} $callee]
}

proc getPropertyName {callee} {
    # Extract property name from expression like os.tmpdir
    if {[regexp {\.(\w+)$} $callee -> prop]} {
        return $prop
    }
    return ""
}

proc getObjectName {callee} {
    # Extract object name from expression like os.tmpdir
    if {[regexp {^(\w+)\.} $callee -> obj]} {
        return $obj
    }
    return ""
}

proc isIdentifier {expression} {
    # Check if it's a simple identifier
    return [regexp {^[a-zA-Z_$][a-zA-Z0-9_$]*$} $expression]
}

proc findMessagingTmpdirCallLines {content {fileName "source.ts"}} {
    global allowedRelativePaths
    
    # Parse imports first
    lassign [collectOsTmpdirImports $content] osNamespaceOrDefault namedTmpdir
    
    set violations {}
    set lines [split $content "\n"]
    set lineNumber 1
    
    foreach line $lines {
        # Look for calls to tmpdir()
        if {[regexp {\b([a-zA-Z_]\w*)\.tmpdir\(\)} $line -> objName]} {
            if {[dict exists $osNamespaceOrDefault $objName]} {
                lappend violations $lineNumber
            }
        }
        
        # Look for direct calls to tmpdir()
        if {[regexp {\b([a-zA-Z_]\w*)\(\)} $line -> funcName]} {
            if {[dict exists $namedTmpdir $funcName]} {
                lappend violations $lineNumber
            }
        }
        
        incr lineNumber
    }
    
    return $violations
}

proc readFile {filepath} {
    if {[catch {open $filepath r} fh]} {
        error "Cannot open file $filepath: $::errorInfo"
    }
    set content [read $fh]
    close $fh
    return $content
}

proc checkDirectory {directory sourceRoots} {
    set violations {}
    
    # Get all .ts files recursively
    set files [::fileutil::findByPattern $directory *.ts]
    
    foreach filepath $files {
        # Check if file is in one of our source roots
        set relativePath [::fileutil::relative $directory $filepath]
        set isInSourceRoot 0
        
        foreach root $sourceRoots {
            if {[string match "${root}*" $relativePath]} {
                set isInSourceRoot 1
                break
            }
        }
        
        if {!$isInSourceRoot} {
            continue
        }
        
        # Skip allowed paths
        if {[dict exists $allowedRelativePaths $relativePath]} {
            continue
        }
        
        # Read and check file
        if {[catch {readFile $filepath} content]} {
            puts stderr "Warning: Could not read $filepath"
            continue
        }
        
        set lines [findMessagingTmpdirCallLines $content $filepath]
        if {[llength $lines] > 0} {
            foreach lineNum $lines {
                lappend violations [list $filepath $lineNum]
            }
        }
    }
    
    return $violations
}

proc main {} {
    global messagingTmpdirGuardSourceRoots argv
    
    set directory [pwd]
    if {[llength $argv] > 0} {
        set directory [lindex $argv 0]
    }
    
    set violations [checkDirectory $directory $messagingTmpdirGuardSourceRoots]
    
    if {[llength $violations] > 0} {
        puts "Found os.tmpdir()/tmpdir() usage in messaging/channel runtime sources:"
        foreach violation $violations {
            lassign $violation filepath lineNum
            puts "$filepath:$lineNum"
        }
        puts "Use resolvePreferredOpenClawTmpDir() or plugin-sdk temp helpers instead of host tmp defaults."
        exit 1
    }
}

# Run main if script is executed directly
if {[info script] eq $argv0} {
    main
}
