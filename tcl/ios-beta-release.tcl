#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "b7eb0f31fe3e22cc9f4a96e34ae4afe74038eb6b89575dcbd64e8f0aa3315173", "source_sha256": "74168ccc75bdca2481fb7bf1298fad30cea4e5fdd917205e7f1815e86948ca0c", "target_language": "tcl"}
# ios-beta-release.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-release.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts stdout "Usage:"
    puts stdout "  scripts/ios-beta-release.sh \[--build-number 7\]"
    puts stdout ""
    puts stdout "Archives and uploads a beta-release IPA to TestFlight locally."
}

# Get the directory where this script is located
set scriptDir [file dirname [info script]]
# Calculate ROOT_DIR as parent of script directory
set rootDir [file normalize [file join $scriptDir ".."]]

# Initialize variables
set buildNumber [expr {[info exists env(IOS_BETA_BUILD_NUMBER)] ? $env(IOS_BETA_BUILD_NUMBER) : ""}]
set args [lassign $argv scriptName]

# Parse command line arguments
while {[llength $args] > 0} {
    set arg [lindex $args 0]
    switch -exact -- $arg {
        "--" {
            set args [lassign $args arg]
        }
        "--build-number" {
            if {[llength $args] >= 2} {
                set buildNumber [lindex $args 1]
                set args [lassign $args arg value]
            } else {
                puts stderr "Missing value for --build-number"
                usage
                exit 1
            }
        }
        "-h" -
        "--help" {
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
set iosDir [file join $rootDir "apps" "ios"]
if {![file exists $iosDir]} {
    puts stderr "iOS directory not found: $iosDir"
    exit 1
}

# Set environment variable and execute fastlane
set env(IOS_BETA_BUILD_NUMBER) $buildNumber
if {[catch {exec fastlane ios beta} result]} {
    puts stderr "fastlane command failed: $result"
    exit 1
}
