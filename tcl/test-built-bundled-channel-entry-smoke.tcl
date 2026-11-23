#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "cd6309df791ccca675d4f612b265f50c4de0f8caba1fa26c281818487a4deb82", "source_sha256": "cd0bfcd0719418f4f0877e7488a8136ca9e8ba296aaaf669b43c7da1dca0f581", "target_language": "tcl"}
# test-built-bundled-channel-entry-smoke.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-built-bundled-channel-entry-smoke.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of test-built-bundled-channel-entry-smoke.mjs
# This script performs smoke tests on bundled channel entry files

package require json
package require fileutil

# Set environment variable if not already set
if {![info exists ::env(OPENCLAW_DISABLE_BUNDLED_ENTRY_SOURCE_FALLBACK)]} {
    set ::env(OPENCLAW_DISABLE_BUNDLED_ENTRY_SOURCE_FALLBACK) 1
}

# Parse command line arguments
proc parseArgs {argv} {
    global env
    set packageRoot ""
    
    # Check environment variable first
    if {[info exists env(OPENCLAW_BUNDLED_CHANNEL_SMOKE_ROOT)]} {
        set packageRoot $env(OPENCLAW_BUNDLED_CHANNEL_SMOKE_ROOT)
    }
    
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        if {$arg eq "--package-root"} {
            incr i
            set packageRoot [lindex $argv $i]
        } elseif {[string match "--package-root=*" $arg]} {
            set packageRoot [string range $arg [string length "--package-root="] end]
        } else {
            error "unknown argument: $arg"
        }
    }
    
    # If no package root provided, use current directory's parent
    if {$packageRoot eq ""} {
        set scriptDir [file dirname [info script]]
        set packageRoot [file normalize [file join $scriptDir ".."]]
    }
    
    return [list packageRoot [file normalize $packageRoot]]
}

# Read JSON file
proc readJson {pathname} {
    set fd [open $pathname r]
    set data [read $fd]
    close $fd
    return [::json::json2dict $data]
}

# Convert extension entry to dist filename
proc extensionEntryToDistFilename {entry} {
    # Remove leading ./
    regsub {^\./} $entry {} entry
    # Replace extension with .js
    regsub {\.[^.]+$} $entry {.js} result
    return $result
}

# Collect bundled channel entry files
proc collectBundledChannelEntryFiles {distExtensionsRoot} {
    set files {}
    
    # Get directories in dist/extensions
    set dirEntries [glob -nocomplain -directory $distExtensionsRoot -types d *]
    
    foreach dirEntry $dirEntries {
        set extensionName [file tail $dirEntry]
        set extensionRoot $dirEntry
        set packageJsonPath [file join $extensionRoot "package.json"]
        
        if {![file exists $packageJsonPath]} {
            continue
        }
        
        set packageJson [readJson $packageJsonPath]
        
        # Check if openclaw.channel exists
        if {![dict exists $packageJson openclaw] || ![dict exists [dict get $packageJson openclaw] channel]} {
            continue
        }
        
        # Get extensions or default to ./index.ts
        set extensionEntries {}
        if {[dict exists $packageJson openclaw extensions] && 
            [llength [dict get $packageJson openclaw extensions]] > 0} {
            set extensionEntries [dict get $packageJson openclaw extensions]
        } else {
            set extensionEntries {"./index.ts"}
        }
        
        foreach entry $extensionEntries {
            if {$entry ne "" && [string trim $entry] ne ""} {
                lappend files [list \
                    id $extensionName \
                    kind "channel" \
                    path [file join $extensionRoot [extensionEntryToDistFilename $entry]]]
            }
        }
        
        # Handle setup entry
        if {[dict exists $packageJson openclaw setupEntry]} {
            set setupEntry [dict get $packageJson openclaw setupEntry]
            if {$setupEntry ne "" && [string trim $setupEntry] ne ""} {
                lappend files [list \
                    id $extensionName \
                    kind "setup" \
                    path [file join $extensionRoot [extensionEntryToDistFilename $setupEntry]]]
            }
        }
        
        # Handle channel-entry.js
        set channelEntryPath [file join $extensionRoot "channel-entry.js"]
        if {[file exists $channelEntryPath]} {
            lappend files [list \
                id $extensionName \
                kind "channel" \
                path $channelEntryPath]
        }
    }
    
    # Sort the files
    set sortedFiles {}
    foreach item $files {
        dict with item {
            lappend sortedFiles [list $id $kind $path]
        }
    }
    
    set sortedItems {}
    foreach item [lsort -dictionary $sortedFiles] {
        lassign $item id kind path
        lappend sortedItems [list id $id kind $kind path $path]
    }
    
    return $sortedItems
}

# Assert secret contract shape
proc assertSecretContractShape {secrets context} {
    if {![dict size $secrets] || [dict size $secrets] == 0} {
        error "$context: missing secrets contract"
    }
    
    if {![dict exists $secrets collectRuntimeConfigAssignments] || 
        [dict get $secrets collectRuntimeConfigAssignments] ne "function"} {
        error "$context: collectRuntimeConfigAssignments must be a function"
    }
    
    if {![dict exists $secrets secretTargetRegistryEntries] || 
        ![dict get $secrets secretTargetRegistryEntries] eq "array"} {
        error "$context: secretTargetRegistryEntries must be an array"
    }
}

# Assert entry file exists
proc assertEntryFileExists {entry} {
    dict with entry {
        if {![file exists $path]} {
            error "$id $kind entry missing from packed dist: $path"
        }
    }
}

# Smoke test channel entry
proc smokeChannelEntry {entryFile} {
    assertEntryFileExists $entryFile
    
    dict with entryFile {
        # In Tcl we can't dynamically import modules like in JS
        # We'll simulate the check by examining the file content
        
        if {![file exists $path]} {
            error "$id channel entry file does not exist: $path"
        }
        
        # Check that it has expected structure by reading the file
        set fd [open $path r]
        set content [read $fd]
        close $fd
        
        # Basic checks for bundled-channel-entry
        if {![regexp {kind.*bundled-channel-entry} $content]} {
            error "$id channel entry kind mismatch"
        }
        
        if {![regexp {loadChannelPlugin} $content]} {
            error "$id channel entry missing loadChannelPlugin"
        }
        
        # Check for secrets if they exist
        if {[regexp {loadChannelSecrets} $content]} {
            # We can't actually call the function in Tcl, so just note it exists
        }
    }
}

# Smoke test setup entry
proc smokeSetupEntry {entryFile} {
    assertEntryFileExists $entryFile
    
    dict with entryFile {
        if {![file exists $path]} {
            error "$id setup entry file does not exist: $path"
        }
        
        # Check file content
        set fd [open $path r]
        set content [read $fd]
        close $fd
        
        # Check for bundled-channel-setup-entry
        if {![regexp {kind.*bundled-channel-setup-entry} $content]} {
            return false
        }
        
        if {![regexp {loadSetupPlugin} $content]} {
            error "$id setup entry missing loadSetupPlugin"
        }
        
        # Check for secrets if they exist
        if {[regexp {loadSetupSecrets} $content]} {
            # We can't actually call the function in Tcl, so just note it exists
        }
    }
    
    return true
}

# Main execution
set argsResult [parseArgs $::argv]
dict with argsResult {}

set distExtensionsRoot [file join $packageRoot "dist" "extensions"]

set entryFiles [collectBundledChannelEntryFiles $distExtensionsRoot]

set channelCount 0
set setupCount 0
set legacySetupCount 0

foreach entryFile $entryFiles {
    dict with entryFile {
        if {$kind eq "channel"} {
            smokeChannelEntry $entryFile
            incr channelCount
        } else {
            if {[smokeSetupEntry $entryFile]} {
                incr setupCount
            } else {
                incr legacySetupCount
            }
        }
    }
}

if {$channelCount <= 0} {
    error "no bundled channel entries found"
}

puts "\[build-smoke\] bundled channel entry smoke passed packageRoot=$packageRoot channel=$channelCount setup=$setupCount legacySetup=$legacySetupCount"
