#!/usr/bin/env tclsh
# test_mobile_bridge.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Tcl equivalent of the JavaScript test file for mobile bridge

# Load required packages
package require Tcl 8.6

# Function to check if substring exists in string
proc string_contains {str substr} {
    return [expr {[string first $substr $str] != -1}]
}

# Function to read file content
proc read_file {filepath} {
    if {![file exists $filepath]} {
        error "File not found: $filepath"
    }
    
    set fh [open $filepath r]
    set content [read $fh]
    close $fh
    return $content
}

# Get current directory and determine paths
set script_dir [file dirname [info script]]
set root [file normalize "$script_dir/.."]
set bridge_path [file join $root "mobile-shared" "webview-bridge.js"]

# Read the main bridge file
set source [read_file $bridge_path]

# Perform assertions - check that specific strings exist in source
set checks {
    {location.hostname !== \"www.tiktok.com\"}
    {root.top === root}
    {if (!isTop) return}
    {MAX_MESSAGE_BYTES = 64 * 1024}
    {MAX_AUDIO_SECONDS = 12}
    {QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400}
    {ALLOWED_COMMANDS}
    {\"set-auto-reconnect\"}
    {\"set-limiter\"}
    {\"scan-recommendations\"}
    {\"cancel-recommendation-scan\"}
    {MAX_MEDIA_URLS = 12}
    {const mediaUrls = new Map()}
    {emit(\"media-url\"}
    {addEventListener(\"message\"}
    {FORCE_RETURN_KEY = \"tlc-force-return\"}
    {sessionStorage.getItem(FORCE_RETURN_KEY)}
}

foreach check $checks {
    if {![string_contains $source $check]} {
        error "Assertion failed: '$check' not found in source"
    }
}

# Check that certain forbidden strings do NOT exist
set forbidden {
    {.send =}
    {document.cookie}
    {localStorage}
    {sessionStorage.clear}
    {innerHTML}
}

foreach forbid $forbidden {
    if {[string_contains $source $forbid]} {
        error "Forbidden pattern found: '$forbid'"
    }
}

# Check bridge copies in other locations
set copies [list \
    [file join $root ".." "mobile" "ios" "Resources" "webview-bridge.js"] \
    [file join $root ".." "mobile" "android" "app" "src" "main" "res" "raw" "webview_bridge.js"] \
]

foreach copy $copies {
    set copy_content [read_file $copy]
    if {$copy_content ne $source} {
        error "Bridge copy drifted: $copy"
    }
}

puts "PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards"
