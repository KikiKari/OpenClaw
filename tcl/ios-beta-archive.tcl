#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "3bce2d181221541e452238b86a808e27579f0e5c4d8b80822d54540927486c51", "source_sha256": "2cdcdc862375b173b06398d139b611f6f002e0435191f56d26d3e48a3cef02cf", "target_language": "tcl"}
# ios-beta-archive.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-archive.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts stderr {Usage:
  scripts/ios-beta-archive.sh [--build-number 7]

Archives and exports a beta-release IPA locally without uploading.}
}

# Helper to get the directory of the current script
proc get_script_dir {} {
    set script_path [info script]
    if {$script_path eq ""} {
        # Fallback for interactive mode
        return [pwd]
    }
    return [file dirname [file normalize $script_path]]
}

# Get root directory (parent of script directory)
set ROOT_DIR [file normalize [file join [get_script_dir] ..]]

# Initialize variables
set BUILD_NUMBER ""
array set env [array get ::env]

# Check if IOS_BETA_BUILD_NUMBER exists in environment
if {[info exists env(IOS_BETA_BUILD_NUMBER)]} {
    set BUILD_NUMBER $env(IOS_BETA_BUILD_NUMBER)
}

# Parse command line arguments
for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]
    switch -exact -- $arg {
        "--" {
            # Skip
        }
        "--build-number" {
            incr i
            if {$i < $argc} {
                set BUILD_NUMBER [lindex $argv $i]
            } else {
                puts stderr "Error: --build-number requires a value"
                usage
                exit 1
            }
        }
        "-h" - "--help" {
            usage
            exit 0
        }
        default {
            puts stderr "Unknown argument: $arg"
            usage
            exit 1
        }
    }
}

# Change to iOS app directory and execute fastlane command
set ios_dir [file join $ROOT_DIR apps ios]
if {![file isdirectory $ios_dir]} {
    puts stderr "Error: Directory $ios_dir does not exist"
    exit 1
}

# Set environment variable and execute fastlane
set env(IOS_BETA_BUILD_NUMBER) $BUILD_NUMBER

# Execute the fastlane command
if {[catch {
    exec fastlane ios beta_archive
} result options]} {
    # Command failed
    puts stderr "Error executing fastlane: $result"
    exit 1
} else {
    # Command succeeded
    puts $result
}
