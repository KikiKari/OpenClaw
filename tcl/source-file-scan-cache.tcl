#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "64318ef625df26ced8b889a2f92b921647c771d37a23219416994739d649d03b", "source_sha256": "44f04cb59342c4d1b0965cd87195e903f79fc80231b0f537dba10313bc29aa00", "target_language": "tcl"}
# source-file-scan-cache.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/source-file-scan-cache.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

namespace eval source_file_scan_cache {
    variable scanCache

    # Initialize the cache
    array set scanCache {}

    # Normalize repository path
    proc normalizeRepoPath {repoRoot filePath} {
        # Get relative path and replace backslashes with forward slashes
        set relative [file normalize [file join $repoRoot]]
        set filePath [file normalize $filePath]
        
        # Compute relative path
        set relPath [string range $filePath [string length $relative] end]
        if {[string index $relPath 0] eq "/"} {
            set relPath [string range $relPath 1 end]
        }
        
        # Replace backslashes with forward slashes
        return [string map {\\ /} $relPath]
    }

    # Walk files recursively
    proc walkFiles {params rootDir} {
        upvar $params p
        
        set out {}
        
        # Try to read directory entries
        if {![file exists $rootDir]} {
            return $out
        }
        
        set entries {}
        catch {
            set entries [lsort [glob -directory $rootDir -nocomplain *]]
        }
        
        foreach entry $entries {
            set entryName [file tail $entry]
            
            if {[file isdirectory $entry]} {
                # Check if directory should be ignored
                set ignored 0
                foreach ignoredDir $p(ignoredDirNames) {
                    if {$entryName eq $ignoredDir} {
                        set ignored 1
                        break
                    }
                }
                
                if {!$ignored} {
                    set subEntries [walkFiles p $entry]
                    foreach subEntry $subEntries {
                        lappend out $subEntry
                    }
                }
            } elseif {[file isfile $entry]} {
                # Check file extension
                set ext [string tolower [file extension $entry]]
                if {[lsearch -exact $p(scanExtensions) $ext] != -1} {
                    lappend out $entry
                }
            }
        }
        
        return $out
    }

    # Collect source file contents
    proc collectSourceFileContents {params} {
        variable scanCache
        
        # Create cache key
        set sortedScanRoots [lsort $params(scanRoots)]
        set sortedScanExtensions [lsort $params(scanExtensions)]
        set sortedIgnoredDirs [lsort $params(ignoredDirNames)]
        
        set cacheKey "$params(repoRoot)|$sortedScanRoots|$sortedScanExtensions|$sortedIgnoredDirs"
        
        # Check if already cached
        if {[info exists scanCache($cacheKey)]} {
            return $scanCache($cacheKey)
        }
        
        # Process files
        set allFiles {}
        foreach root $params(scanRoots) {
            set fullPath [file join $params(repoRoot) $root]
            set files [walkFiles params $fullPath]
            foreach f $files {
                lappend allFiles $f
            }
        }
        
        # Sort files by normalized path
        set sortedFiles {}
        foreach f $allFiles {
            lappend sortedFiles [list $f [normalizeRepoPath $params(repoRoot) $f]]
        }
        
        set sortedFiles [lsort -index 1 $sortedFiles]
        
        # Read file contents
        set result {}
        foreach item $sortedFiles {
            set filePath [lindex $item 0]
            set relativeFile [lindex $item 1]
            
            if {[catch {open $filePath r} fh]} {
                error "Could not open file: $filePath"
            }
            
            set content [read $fh]
            close $fh
            
            lappend result [dict create \
                filePath $filePath \
                relativeFile $relativeFile \
                content $content]
        }
        
        # Cache the result
        set scanCache($cacheKey) $result
        
        return $result
    }
    
    # Export the main procedure
    namespace export collectSourceFileContents
}

# Example usage:
# set params [dict create \
#     repoRoot "/path/to/repo" \
#     scanRoots {src lib} \
#     scanExtensions {.js .ts .jsx .tsx} \
#     ignoredDirNames {node_modules .git}]
# 
# set files [source_file_scan_cache::collectSourceFileContents $params]
