#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "1734877e9583d0737b6ba6442581bd381d6a3f66165f3f264a50a3faab808381", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "tcl"}
# changed-extensions.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Load required packages
package require Tcl 8.6
package require fileutil
package require cmdline

# Global variables
set repoRoot [file normalize [file join [file dirname [info script]] .. ..]]
set BUNDLED_PLUGIN_ROOT_DIR "extensions"
set BUNDLED_PLUGIN_PATH_PREFIX "extensions/"

# Helper procedure to execute git commands
proc runGit {args} {
    global repoRoot
    set cmd [list exec git {*}$args]
    if {[catch {eval $cmd} result]} {
        error $result
    }
    return $result
}

# Normalize path separators
proc normalizeRelative {inputPath} {
    return [string map {\\ /} $inputPath]
}

# Check if git commit exists
proc hasGitCommit {ref} {
    if {$ref eq "" || [regexp {^0+$} $ref]} {
        return false
    }
    
    if {[catch {runGit rev-parse --verify ${ref}^{commit}}]} {
        return false
    }
    return true
}

# Resolve base commit for change detection
proc resolveChangedPathsBase {params} {
    array set p $params
    
    set base [expr {[info exists p(base)] ? $p(base) : ""}]
    set head [expr {[info exists p(head)] ? $p(head) : "HEAD"}]
    set fallbackBaseRef [expr {[info exists p(fallbackBaseRef)] ? $p(fallbackBaseRef) : ""}]
    
    if {$base ne "" && [hasGitCommit $base]} {
        return $base
    }
    
    if {$fallbackBaseRef ne ""} {
        set remoteBaseRef $fallbackBaseRef
        if {![string match "origin/*" $fallbackBaseRef]} {
            set remoteBaseRef "origin/$fallbackBaseRef"
        }
        
        if {[hasGitCommit $remoteBaseRef]} {
            if {[catch {set mergeBase [string trim [runGit merge-base $remoteBaseRef $head]]}]} {
                # Error handling
            } else {
                if {[hasGitCommit $mergeBase]} {
                    return $mergeBase
                }
            }
        }
    }
    
    if {$base eq ""} {
        error "A git base revision is required to list changed extensions."
    }
    
    error "Git base revision is unavailable locally: $base"
}

# List paths that changed between commits
proc listChangedPaths {base {head "HEAD"}} {
    if {$base eq ""} {
        error "A git base revision is required to list changed extensions."
    }
    
    set output [runGit diff --name-only $base $head]
    set paths {}
    foreach line [split $output \n] {
        set trimmed [string trim $line]
        if {[string length $trimmed] > 0} {
            lappend paths $trimmed
        }
    }
    return $paths
}

# Check if extension has package.json
proc hasExtensionPackage {extensionId} {
    global repoRoot BUNDLED_PLUGIN_ROOT_DIR
    set packagePath [file join $repoRoot $BUNDLED_PLUGIN_ROOT_DIR $extensionId package.json]
    return [file exists $packagePath]
}

# List all available extension IDs
proc listAvailableExtensionIds {} {
    global repoRoot BUNDLED_PLUGIN_ROOT_DIR
    
    set extensionsDir [file join $repoRoot $BUNDLED_PLUGIN_ROOT_DIR]
    if {![file exists $extensionsDir] || ![file isdirectory $extensionsDir]} {
        return {}
    }
    
    set extensionIds {}
    set entries [glob -nocomplain -dir $extensionsDir *]
    foreach entry $entries {
        if {[file isdirectory $entry]} {
            set extensionId [file tail $entry]
            if {[hasExtensionPackage $extensionId]} {
                lappend extensionIds $extensionId
            }
        }
    }
    
    # Sort the list
    set sorted [lsort $extensionIds]
    return $sorted
}

# Detect changed extension IDs from changed paths
proc detectChangedExtensionIds {changedPaths} {
    global BUNDLED_PLUGIN_PATH_PREFIX
    set extensionIds {}
    
    foreach rawPath $changedPaths {
        set relativePath [normalizeRelative [string trim $rawPath]]
        if {$relativePath eq ""} {
            continue
        }
        
        # Match bundled plugin paths
        if {[regexp ^${BUNDLED_PLUGIN_PATH_PREFIX}([^/]+)(?:/|$) $relativePath match extensionId]} {
            if {[hasExtensionPackage $extensionId]} {
                lappend extensionIds $extensionId
            }
            continue
        }
        
        # Match src directory paths
        if {[regexp {^src/([^/]+)(?:/|$)} $relativePath match coreName]} {
            if {[hasExtensionPackage $coreName]} {
                lappend extensionIds $coreName
            }
        }
    }
    
    # Remove duplicates and sort
    set unique [lsort -unique $extensionIds]
    return $unique
}

# Main procedure to list changed extension IDs
proc listChangedExtensionIds {{params ""}} {
    array set p $params
    
    set head [expr {[info exists p(head)] ? $p(head) : "HEAD"}]
    set unavailableBaseBehavior [expr {[info exists p(unavailableBaseBehavior)] ? $p(unavailableBaseBehavior) : "error"}]
    
    if {[catch {
        set base [resolveChangedPathsBase $params]
        set changedPaths [listChangedPaths $base $head]
        return [detectChangedExtensionIds $changedPaths]
    } result]} {
        if {$unavailableBaseBehavior eq "all"} {
            return [listAvailableExtensionIds]
        }
        if {$unavailableBaseBehavior eq "empty"} {
            return {}
        }
        error $result
    }
}
