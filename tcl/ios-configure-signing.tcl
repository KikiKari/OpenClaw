#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "b778da45cbd99a5c71adb724e742f4dc5fb6efaacfe377b204d70bebd42d8411", "source_sha256": "7434e7c15cfe10e1fe7ca6ae3d5c90b97676c2406bffe4c136681d81534dc3f1", "target_language": "tcl"}
# ios-configure-signing.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-configure-signing.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Set global variables
set ROOT_DIR [file normalize [file join [file dirname [info script]] ..]]
set IOS_DIR [file join $ROOT_DIR apps ios]
set TEAM_ID_SCRIPT [file join $ROOT_DIR scripts ios-team-id.sh]
set LOCAL_SIGNING_FILE [file join $IOS_DIR .local-signing.xcconfig]

# Function to sanitize identifier segment
proc sanitize_identifier_segment {raw} {
    # Convert to lowercase
    set raw [string tolower $raw]
    # Replace non-alphanumeric characters with hyphens
    regsub -all {[^a-z0-9]+} $raw {-} raw
    # Remove leading hyphens
    regsub {^-+} $raw {} raw
    # Remove trailing hyphens
    regsub {-+$} $raw {} raw
    # Replace multiple hyphens with single hyphen
    regsub -all {--+} $raw {-} raw
    # If empty, set to "local"
    if {$raw eq ""} {
        set raw "local"
    }
    return $raw
}

# Function to normalize bundle ID
proc normalize_bundle_id {raw} {
    # Convert to lowercase
    set raw [string tolower $raw]
    # Replace invalid characters with hyphens
    regsub -all {[^a-z0-9.\-]+} $raw {-} raw
    # Replace multiple dots with single dot
    regsub -all {\.\.+} $raw {.} raw
    # Remove leading hyphens
    regsub {^-+} $raw {} raw
    # Remove trailing dots or hyphens
    regsub {[.\-]+$} $raw {} raw
    # If empty, set default
    if {$raw eq ""} {
        set raw "ai.openclaw.ios.test.local"
    }
    return $raw
}

# Check if team ID script exists and is executable
if {![file executable $TEAM_ID_SCRIPT]} {
    puts stderr "ERROR: Missing team detection helper: $TEAM_ID_SCRIPT"
    exit 1
}

# Try to get team ID
set team_id ""
if {[catch {exec $TEAM_ID_SCRIPT} team_id]} {
    # Check if signing is required
    if {[info exists ::env(IOS_SIGNING_REQUIRED)] && $::env(IOS_SIGNING_REQUIRED) eq "1"} {
        # Run the script again to show error output
        exec $TEAM_ID_SCRIPT
        exit 1
    } else {
        puts stderr "WARN: Unable to detect an Apple Team ID; keeping existing iOS signing override (if any)."
        exit 0
    }
}

# Trim whitespace from team_id
set team_id [string trim $team_id]

# Determine identity source
if {[info exists ::env(OPENCLAW_IOS_BUNDLE_SUFFIX)] && $::env(OPENCLAW_IOS_BUNDLE_SUFFIX) ne ""} {
    set identity_source $::env(OPENCLAW_IOS_BUNDLE_SUFFIX)
} else {
    set identity_source ""
    if {[info exists ::env(USER)]} {
        set identity_source $::env(USER)
    }
    if {$identity_source eq ""} {
        if {[catch {exec id -un} result]} {
            set identity_source ""
        } else {
            set identity_source [string trim $result]
        }
    }
    set team_segment [sanitize_identifier_segment $team_id]
    append identity_source "-$team_segment"
}
set bundle_suffix [sanitize_identifier_segment $identity_source]

# Determine bundle base
set bundle_base ""
if {[info exists ::env(OPENCLAW_IOS_APP_BUNDLE_ID)] && $::env(OPENCLAW_IOS_APP_BUNDLE_ID) ne ""} {
    set bundle_base $::env(OPENCLAW_IOS_APP_BUNDLE_ID)
} elseif {[info exists ::env(OPENCLAW_IOS_BUNDLE_ID_BASE)] && $::env(OPENCLAW_IOS_BUNDLE_ID_BASE) ne ""} {
    set bundle_base $::env(OPENCLAW_IOS_BUNDLE_ID_BASE)
}
if {$bundle_base eq ""} {
    set bundle_base "ai.openclaw.ios.test.$bundle_suffix"
}
set bundle_base [normalize_bundle_id $bundle_base]

# Determine other bundle IDs
set share_bundle_id ""
if {[info exists ::env(OPENCLAW_IOS_SHARE_BUNDLE_ID)] && $::env(OPENCLAW_IOS_SHARE_BUNDLE_ID) ne ""} {
    set share_bundle_id $::env(OPENCLAW_IOS_SHARE_BUNDLE_ID)
} else {
    set share_bundle_id "$bundle_base.share"
}

set activity_widget_bundle_id ""
if {[info exists ::env(OPENCLAW_IOS_ACTIVITY_WIDGET_BUNDLE_ID)] && $::env(OPENCLAW_IOS_ACTIVITY_WIDGET_BUNDLE_ID) ne ""} {
    set activity_widget_bundle_id $::env(OPENCLAW_IOS_ACTIVITY_WIDGET_BUNDLE_ID)
} else {
    set activity_widget_bundle_id "$bundle_base.activitywidget"
}

set watch_app_bundle_id ""
if {[info exists ::env(OPENCLAW_IOS_WATCH_APP_BUNDLE_ID)] && $::env(OPENCLAW_IOS_WATCH_APP_BUNDLE_ID) ne ""} {
    set watch_app_bundle_id $::env(OPENCLAW_IOS_WATCH_APP_BUNDLE_ID)
} else {
    set watch_app_bundle_id "$bundle_base.watchkitapp"
}

set watch_extension_bundle_id ""
if {[info exists ::env(OPENCLAW_IOS_WATCH_EXTENSION_BUNDLE_ID)] && $::env(OPENCLAW_IOS_WATCH_EXTENSION_BUNDLE_ID) ne ""} {
    set watch_extension_bundle_id $::env(OPENCLAW_IOS_WATCH_EXTENSION_BUNDLE_ID)
} else {
    set watch_extension_bundle_id "$watch_app_bundle_id.extension"
}

# Get code sign style and profiles
set code_sign_style "Automatic"
if {[info exists ::env(OPENCLAW_IOS_CODE_SIGN_STYLE)] && $::env(OPENCLAW_IOS_CODE_SIGN_STYLE) ne ""} {
    set code_sign_style $::env(OPENCLAW_IOS_CODE_SIGN_STYLE)
}

set app_profile ""
if {[info exists ::env(OPENCLAW_IOS_APP_PROFILE)]} {
    set app_profile $::env(OPENCLAW_IOS_APP_PROFILE)
}

set share_profile ""
if {[info exists ::env(OPENCLAW_IOS_SHARE_PROFILE)]} {
    set share_profile $::env(OPENCLAW_IOS_SHARE_PROFILE)
}

set watch_app_profile ""
if {[info exists ::env(OPENCLAW_IOS_WATCH_APP_PROFILE)]} {
    set watch_app_profile $::env(OPENCLAW_IOS_WATCH_APP_PROFILE)
}

set watch_extension_profile ""
if {[info exists ::env(OPENCLAW_IOS_WATCH_EXTENSION_PROFILE)]} {
    set watch_extension_profile $::env(OPENCLAW_IOS_WATCH_EXTENSION_PROFILE)
}

# Create temporary file content
set tmp_content "// Auto-generated by scripts/ios-configure-signing.sh.
// This file is local-only and should not be committed.
// Override values with env vars if needed:
// OPENCLAW_IOS_APP_BUNDLE_ID / OPENCLAW_IOS_BUNDLE_ID_BASE
// OPENCLAW_IOS_SHARE_BUNDLE_ID / OPENCLAW_IOS_ACTIVITY_WIDGET_BUNDLE_ID
// OPENCLAW_IOS_WATCH_APP_BUNDLE_ID / OPENCLAW_IOS_WATCH_EXTENSION_BUNDLE_ID
// OPENCLAW_IOS_CODE_SIGN_STYLE / OPENCLAW_IOS_APP_PROFILE / OPENCLAW_IOS_SHARE_PROFILE
// OPENCLAW_IOS_WATCH_APP_PROFILE / OPENCLAW_IOS_WATCH_EXTENSION_PROFILE
OPENCLAW_CODE_SIGN_STYLE = $code_sign_style
OPENCLAW_DEVELOPMENT_TEAM = $team_id
// Keep legacy key for compatibility with older signing config paths.
OPENCLAW_IOS_SELECTED_TEAM = $team_id
OPENCLAW_APP_BUNDLE_ID = $bundle_base
OPENCLAW_SHARE_BUNDLE_ID = $share_bundle_id
OPENCLAW_ACTIVITY_WIDGET_BUNDLE_ID = $activity_widget_bundle_id
OPENCLAW_WATCH_APP_BUNDLE_ID = $watch_app_bundle_id
OPENCLAW_WATCH_EXTENSION_BUNDLE_ID = $watch_extension_bundle_id
OPENCLAW_APP_PROFILE = $app_profile
OPENCLAW_SHARE_PROFILE = $share_profile
OPENCLAW_WATCH_APP_PROFILE = $watch_app_profile
OPENCLAW_WATCH_EXTENSION_PROFILE = $watch_extension_profile
"

# Create a temporary file
set tmp_file [exec mktemp "/tmp/openclaw-ios-signing.XXXXXX"]

# Write content to temporary file
set fh [open $tmp_file w]
puts -nonewline $fh $tmp_content
close $fh

# Check if local signing file exists and compare with temp file
if {[file exists $LOCAL_SIGNING_FILE]} {
    set files_equal 1
    if {[catch {exec cmp -s $tmp_file $LOCAL_SIGNING_FILE}]} {
        set files_equal 0
    }
    
    if {$files_equal} {
        file delete $tmp_file
        puts "iOS signing config already up to date: team=$team_id app=$bundle_base"
        exit 0
    }
}

# Move temporary file to local signing file
file rename -force $tmp_file $LOCAL_SIGNING_FILE
puts "Configured iOS signing: team=$team_id app=$bundle_base"
