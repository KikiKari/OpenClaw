#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "c4f57407e874ddba2278f22f5790021cb5e121755173af5e59425a1b3194a1f5", "source_sha256": "12dffdae6f3576ff268694787ca9415cbb1e307cb0b7cb39a0784412c35e1318", "target_language": "tcl"}
# run-extension-oxlint.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/run-extension-oxlint.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package require fileutil
package require json
package require cmdline

# Globale Variablen für Prozessinformationen
set ::env(HOME) $::tcl_platform(userHome)
set ::argv0 [info script]

proc runExtensionOxlint {params} {
    set repoRoot [pwd]
    set oxlintPath [file normalize "node_modules/.bin/oxlint"]
    
    # Acquire lock - simplified implementation
    set lockName [dict get $params lockName]
    set toolName [dict get $params toolName]
    set tempDirPrefix [dict get $params tempDirPrefix]
    
    # Create temporary directory
    set tempDir [exec mktemp -d "/tmp/${tempDirPrefix}XXXXXX"]
    set tempConfigPath [file join $tempDir "oxlint.json"]
    
    set exitCode 0
    
    # Try-finally equivalent
    if {[catch {
        prepareExtensionPackageBoundaryArtifacts $repoRoot
        
        set extensionFiles {}
        foreach root [dict get $params roots] {
            set fullPath [file normalize [file join $repoRoot $root]]
            lappend extensionFiles {*}[collectTypeScriptFiles $fullPath]
        }
        
        if {[llength $extensionFiles] == 0} {
            puts stderr [dict get $params emptyMessage]
            exit 1
        }
        
        writeTempOxlintConfig $repoRoot $tempConfigPath
        
        # Build arguments
        set baseArgs [list "-c" $tempConfigPath]
        # Add remaining arguments from command line (simplified)
        foreach arg $::argv {
            if {$arg ne [lindex $::argv 0]} {
                lappend baseArgs $arg
            }
        }
        set baseArgs [concat $baseArgs $extensionFiles]
        
        # Apply policy (simplified)
        set finalArgs $baseArgs
        set envVars [array get ::env]
        
        # Execute oxlint
        if {[catch {
            set cmd [list exec $oxlintPath {*}$finalArgs]
            eval $cmd
        } result]} {
            if {[string match "*Child process exited*" $result]} {
                # Extract exit code from error message
                regexp {exit status (\d+)} $result -> exitCode
                set exitCode $exitCode
            } else {
                error $result
            }
        }
    } error]} {
        set exitCode 1
        puts stderr "Error: $error"
    }
    
    # Cleanup
    catch {file delete -force $tempDir}
    
    # Release lock - simplified
    return $exitCode
}

proc prepareExtensionPackageBoundaryArtifacts {repoRoot} {
    # Acquire lock - simplified
    set scriptPath [file normalize [file join $repoRoot "scripts" "prepare-extension-package-boundary-artifacts.mjs"]]
    
    if {[catch {
        exec node $scriptPath
    } result]} {
        if {[string match "*Child process exited*" $result]} {
            regexp {exit status (\d+)} $result -> exitCode
            if {$exitCode != 0} {
                exit $exitCode
            }
        } else {
            error $result
        }
    }
}

proc writeTempOxlintConfig {repoRoot configPath} {
    set configFile [file normalize [file join $repoRoot ".oxlintrc.json"]]
    set fp [open $configFile r]
    set content [read $fp]
    close $fp
    
    set config [::json::json2dict $content]
    
    # Remove $schema key if exists
    if {[dict exists $config \$schema]} {
        dict unset config \$schema
    }
    
    # Check ignore patterns
    if {[dict exists $config ignorePatterns]} {
        set ignorePatterns [dict get $config ignorePatterns]
        if {[llength $ignorePatterns] > 0} {
            foreach pattern $ignorePatterns {
                if {[isTopLevelExtensionsIgnorePattern $pattern]} {
                    error "Refusing to run extension oxlint with .oxlintrc.json ignore pattern \"$pattern\". Remove the top-level extensions ignore so root and focused lint agree."
                }
            }
        }
    }
    
    # Write config
    set fp [open $configPath w]
    puts $fp [::json::dict2json $config]
    close $fp
}

proc isTopLevelExtensionsIgnorePattern {pattern} {
    # Normalize pattern
    set normalized [string trim $pattern]
    regsub -all {\\} $normalized "/" normalized
    regsub {^\.?/} $normalized "" normalized
    
    return [expr {$normalized eq "extensions" || $normalized eq "extensions/" || $normalized eq "extensions/**"}]
}

proc collectTypeScriptFiles {directoryPath} {
    set files {}
    
    if {![file isdirectory $directoryPath]} {
        return $files
    }
    
    # Get directory contents and sort them
    set entries [lsort [glob -nocomplain -directory $directoryPath *]]
    
    foreach entryPath $entries {
        if {[file isdirectory $entryPath]} {
            lappend files {*}[collectTypeScriptFiles $entryPath]
        } elseif {[file isfile $entryPath]} {
            set ext [file extension $entryPath]
            if {$ext eq ".ts" || $ext eq ".tsx"} {
                # Convert to relative path with forward slashes
                set relPath [file relativize [pwd] $entryPath]
                regsub -all {\\} $relPath "/" relPath
                lappend files $relPath
            }
        }
    }
    
    return $files
}

# Helper proc to mimic file relativize (not built-in in Tcl 8.6)
proc file {args} {
    switch [lindex $args 0] {
        "relativize" {
            set base [lindex $args 1]
            set path [lindex $args 2]
            # Simplified relative path calculation
            return [string range $path [string length $base]+1 end]
        }
        default {
            # Pass through to built-in file command
            return [eval builtin::file $args]
        }
    }
}

# Main execution
if {[info script] eq $::argv0} {
    # Parse command line arguments into params dict
    set params [dict create]
    dict set params toolName "oxlint"
    dict set params lockName "oxlint-lock"
    dict set params tempDirPrefix "oxlint-"
    dict set params emptyMessage "No TypeScript files found to lint"
    dict set params roots [list "src" "lib"]
    
    set exitCode [runExtensionOxlint $params]
    exit $exitCode
}
