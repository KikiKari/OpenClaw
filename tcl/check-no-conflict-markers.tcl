#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "e1ca569690a0e035e774ffd21336ad56978a977ecfc6e82a3498dea330bffb17", "source_sha256": "c76d61da97f14736857987d3dd8234160c73b0a1b52ade5aac72de04cc61e7e6", "target_language": "tcl"}
# check-no-conflict-markers.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-conflict-markers.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

proc isBinaryBuffer {buffer} {
    # Check if buffer contains null byte
    return [string match "*\x00*" $buffer]
}

proc findConflictMarkerLines {content} {
    set lines [split $content "\n"]
    set matches {}
    set index 1
    
    foreach line $lines {
        if {[string match "<<<<<<< *" $line] || 
            [string match "||||||| *" $line] || 
            [string equal $line "======="] || 
            [string match ">>>>>>> *" $line]} {
            lappend matches $index
        }
        incr index
    }
    return $matches
}

proc listTrackedFiles {{cwd "."}} {
    if {[catch {exec git ls-files -z} output]} {
        error "Failed to execute git ls-files: $output"
    }
    
    set files {}
    set fileList [split $output "\x00"]
    
    foreach relativePath $fileList {
        if {$relativePath ne ""} {
            lappend files [file join $cwd $relativePath]
        }
    }
    return $files
}

proc findConflictMarkersInFiles {filePaths {readFile "readFile"}} {
    set violations {}
    
    foreach filePath $filePaths {
        if {[catch {set content [$readFile $filePath]}]} {
            continue
        }
        
        # Convert to string if needed
        if {[string is binary $content]} {
            # If it's already a proper string representation, keep it
            # Otherwise we assume it's the raw content
        }
        
        if {[isBinaryBuffer $content]} {
            continue
        }
        
        set lines [findConflictMarkerLines $content]
        if {[llength $lines] > 0} {
            lappend violations [list filePath $filePath lines $lines]
        }
    }
    return $violations
}

proc readFile {filePath} {
    if {[catch {open $filePath r} fh]} {
        error "Cannot open file: $fh"
    }
    
    fconfigure $fh -encoding binary
    set content [read $fh]
    close $fh
    
    # If it's text, convert from binary to string
    if {![string is binary $content] || [isBinaryBuffer $content]} {
        return $content
    }
    
    # Try to decode as UTF-8
    if {[catch {
        encoding convertfrom utf-8 $content
    } result]} {
        return $content
    } else {
        return $result
    }
}

proc main {} {
    set cwd [pwd]
    
    if {[catch {set filePaths [listTrackedFiles $cwd]} error]} {
        puts stderr "Error getting tracked files: $error"
        exit 1
    }
    
    set violations [findConflictMarkersInFiles $filePaths]
    
    if {[llength $violations] == 0} {
        return
    }
    
    puts stderr "Found unresolved merge conflict markers:"
    
    foreach violation $violations {
        array set vio $violation
        set relativePath [file normalize $vio(filePath)]
        if {[string first $cwd $relativePath] == 0} {
            set relativePath [string range $relativePath [string length $cwd] end]
            if {[string index $relativePath 0] eq "/"} {
                set relativePath [string range $relativePath 1 end]
            }
        }
        if {$relativePath eq ""} {
            set relativePath $vio(filePath)
        }
        puts stderr "- $relativePath:[join $vio(lines) ,]"
    }
    
    exit 1
}

# Check if script is being run directly
if {[info script] eq $argv0} {
    if {[catch {main} error]} {
        puts stderr $error
        exit 1
    }
}
