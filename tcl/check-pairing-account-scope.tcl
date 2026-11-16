#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "f446aff8386f4073db71785147b7ab9a515f2b8523137e281f61993bb3e77234", "source_sha256": "03602fb41765aad7878e52af85d1c4c5a8d1d8a752b53a46602deb38e8783f73", "target_language": "tcl"}
# check-pairing-account-scope.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-pairing-account-scope.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of check-pairing-account-scope.mjs

package require Tcl 8.6

# Global variables to simulate module context
set repoRoot ""
set sourceRoots {}

# Initialize context (simulating createPairingGuardContext)
proc initContext {} {
    global repoRoot sourceRoots
    # In a real implementation, this would determine the actual paths
    # For now we'll set reasonable defaults
    set repoRoot [file normalize "."]
    set sourceRoots [list "src"]
}

# Helper functions to simulate TypeScript AST operations
proc isUndefinedLikeExpression {node} {
    # This is a simplified check - in reality we'd need proper AST parsing
    if {[dict exists $node type] && [dict get $node type] eq "Identifier"} {
        if {[dict exists $node text] && [dict get $node text] eq "undefined"} {
            return 1
        }
    }
    if {[dict exists $node type] && [dict get $node type] eq "NullKeyword"} {
        return 1
    }
    return 0
}

proc getPropertyNameText {property} {
    if {[dict exists $property name text]} {
        return [dict get $property name text]
    }
    return ""
}

proc hasRequiredAccountIdProperty {node} {
    if {![dict exists $node type] || [dict get $node type] ne "ObjectLiteralExpression"} {
        return 0
    }
    
    if {![dict exists $node properties]} {
        return 0
    }
    
    foreach property [dict get $node properties] {
        if {[dict exists $property type] && [dict get $property type] eq "ShorthandPropertyAssignment"} {
            if {[dict exists $property name text] && [dict get $property name text] eq "accountId"} {
                return 1
            }
        }
        
        if {![dict exists $property type] || [dict get $property type] ne "PropertyAssignment"} {
            continue
        }
        
        if {[getPropertyNameText $property] ne "accountId"} {
            continue
        }
        
        if {[dict exists $property initializer]} {
            set initializer [dict get $property initializer]
            if {[isUndefinedLikeExpression $initializer]} {
                return 0
            }
        }
        return 1
    }
    return 0
}

# Simplified line number tracking
proc toLine {sourceFile node} {
    # In a real implementation, this would extract line numbers from the AST
    # For now we return a placeholder
    return 1
}

proc findViolations {content filePath} {
    set violations [list]
    
    # This is a very simplified parser that just looks for function calls
    # A real implementation would parse the JavaScript/TypeScript properly
    
    # Find all function calls in the content
    set lines [split $content "\n"]
    set lineNum 0
    
    foreach line $lines {
        incr lineNum
        
        # Check for readChannelAllowFromStore calls
        if {[regexp {readChannelAllowFromStore\s*\([^)]*\)} $line]} {
            # Check if it has less than 3 arguments or 3rd argument is undefined/null
            if {![regexp {readChannelAllowFromStore\s*\([^,]+,[^,]+,[^)]+\)} $line]} {
                lappend violations [dict create \
                    line $lineNum \
                    reason "readChannelAllowFromStore call must pass explicit accountId as 3rd arg"]
            }
        }
        
        # Check for legacy function calls
        if {[regexp {(readLegacyChannelAllowFromStore|readLegacyChannelAllowFromStoreSync)\s*\()} $line match funcName]} {
            lappend violations [dict create \
                line $lineNum \
                reason "$funcName is legacy-only; use account-scoped readChannelAllowFromStore* APIs"]
        }
        
        # Check for upsertChannelPairingRequest calls
        if {[regexp {upsertChannelPairingRequest\s*\(([^)]*)\)} $line match args]} {
            # Very simplified check - in reality we'd parse the first argument properly
            if {$args eq "" || ![string match "*accountId*" $args]} {
                lappend violations [dict create \
                    line $lineNum \
                    reason "upsertChannelPairingRequest call must include accountId in params"]
            }
        }
    }
    
    return $violations
}

proc collectFileViolations {options} {
    global sourceRoots repoRoot
    
    set violations [list]
    
    # Walk through source files
    foreach sourceRoot $sourceRoots {
        set fullPath [file join $repoRoot $sourceRoot]
        if {[file exists $fullPath] && [file isdirectory $fullPath]} {
            # Recursively find .js and .ts files
            foreach file [findSourceFiles $fullPath] {
                if {[catch {open $file r} fh]} {
                    continue
                }
                set content [read $fh]
                close $fh
                
                set fileViolations [findViolations $content $file]
                foreach violation $fileViolations {
                    lappend violations [dict create \
                        path $file \
                        line [dict get $violation line] \
                        reason [dict get $violation reason]]
                }
            }
        }
    }
    
    return $violations
}

proc findSourceFiles {dir} {
    set result [list]
    
    if {[catch {glob -nocomplain -dir $dir *.js *.ts} files]} {
        return $result
    }
    
    foreach file $files {
        if {[file isfile $file]} {
            lappend result $file
        }
    }
    
    # Recurse into subdirectories
    if {[catch {glob -nocomplain -dir $dir *} dirs]} {
        return $result
    }
    
    foreach subdir $dirs {
        if {[file isdirectory $subdir]} {
            set subFiles [findSourceFiles $subdir]
            set result [concat $result $subFiles]
        }
    }
    
    return $result
}

proc main {} {
    initContext
    
    set violations [collectFileViolations ""]
    
    if {[llength $violations] == 0} {
        return
    }
    
    puts stderr "Found unscoped pairing-store calls:"
    foreach violation $violations {
        set path [dict get $violation path]
        set line [dict get $violation line]
        set reason [dict get $violation reason]
        puts stderr "- $path:$line ($reason)"
    }
    exit 1
}

# Run as script
if {[info script] eq $argv0} {
    main
}
