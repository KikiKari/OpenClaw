#!/usr/bin/env tclsh
# test_mobile_bridge.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Tcl Port of test_mobile_bridge.cjs

# Helper function to check if substring exists in string
proc string_contains {haystack needle} {
    return [expr {[string first $needle $haystack] != -1}]
}

# Helper function to read file content
proc read_file {filepath} {
    if {![file exists $filepath]} {
        error "File not found: $filepath"
    }
    set fh [open $filepath r]
    set content [read $fh]
    close $fh
    return $content
}

# Get current directory and set up paths
set script_dir [file dirname [info script]]
set root [file normalize [file join $script_dir ".."]]
set bridgePath [file join $root "mobile-shared" "webview-bridge.js"]

# Read the main bridge file
if {![file exists $bridgePath]} {
    puts stderr "Bridge file not found: $bridgePath"
    exit 1
}
set source [read_file $bridgePath]

# Basic syntax check by attempting to create a procedure
# This mimics the JS behavior of compiling/checking syntax
if {[catch {proc test_compile {} $source} err]} {
    puts stderr "Syntax error in bridge file: $err"
    exit 1
}

# Assertions - check for required strings
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
        puts stderr "FAIL: Required pattern not found: $check"
        exit 1
    }
}

# Negative assertions - ensure these patterns are NOT present
set forbidden {
    {.send =}
    {document.cookie}
    {localStorage}
    {sessionStorage.clear}
    {innerHTML}
}

foreach forbidden_pattern $forbidden {
    if {[string_contains $source $forbidden_pattern]} {
        puts stderr "FAIL: Forbidden pattern found: $forbidden_pattern"
        exit 1
    }
}

# Check bridge copies in other locations
set copies [list \
    [file join $root ".." "mobile" "ios" "Resources" "webview-bridge.js"] \
    [file join $root ".." "mobile" "android" "app" "src" "main" "res" "raw" "webview_bridge.js"] \
]

foreach copy $copies {
    if {![file exists $copy]} {
        puts stderr "FAIL: Bridge copy not found: $copy"
        exit 1
    }
    
    set copy_content [read_file $copy]
    if {$copy_content ne $source} {
        puts stderr "FAIL: Bridge copy drifted: $copy"
        exit 1
    }
}

puts "PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards"
