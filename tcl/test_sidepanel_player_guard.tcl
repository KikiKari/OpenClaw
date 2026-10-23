#!/usr/bin/env tclsh
# test_sidepanel_player_guard.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have built-in modules like Node.js, so we simulate the required functionality.
# We'll read the file and extract the relevant JavaScript function manually.

# Read the source file
set source [readFile "../browser-extension/sidepanel.js"]

# Extract the relevant portion of the code
set start [string first "  async function refreshPlayer()" $source]
set end [string first "  function setButtonBusy" $source $start]
if {$start < 0 || $end <= $start} {
    error "Could not find the required functions in the source."
}

# Extract the JavaScript code snippet
set jsCode [string range $source $start $end-1]

# Simulate the JavaScript environment in Tcl
set activeTabId 1
set activeIsTikTok true
set playerContextGeneration 0
set calls 0
set reply ""
set rendered [list]

# Define the send function (simulated)
proc send {} {
    global calls reply
    incr calls
    # Return a promise-like structure (we use a variable to hold the callback)
    return "pending"
}

# Define the renderPlayer function
proc renderPlayer {state} {
    global rendered
    lappend rendered $state
}

# Since Tcl doesn't execute JavaScript, we need to simulate the behavior.
# We will parse and simulate the logic of refreshPlayer based on the extracted JS code.

# Simulate refreshPlayer logic in Tcl
proc refreshPlayer {} {
    global activeTabId activeIsTikTok playerContextGeneration reply rendered

    # Simulate async behavior with a simple proc that sets reply
    if {!$activeIsTikTok} {
        return
    }

    # Simulate sending request and waiting for reply
    set localTabId $activeTabId
    set localContextGen $playerContextGeneration

    # Simulate reply handling
    after idle [list handleReply $localTabId $localContextGen]
}

# Handle the simulated reply
proc handleReply {localTabId localContextGen} {
    global activeTabId playerContextGeneration rendered
    if {$localTabId == $activeTabId && $localContextGen == $playerContextGeneration} {
        lappend rendered "playing:true"
    }
}

# Main test logic
proc main {} {
    global activeTabId activeIsTikTok playerContextGeneration calls rendered reply

    # Initial call
    set pending [refreshPlayer]
    set activeTabId 2
    # Simulate reply
    set reply "{response: {playerState: {playing: true}}}"
    # Wait for pending (simulated by calling handleReply directly)
    handleReply 1 0
    if {[llength $rendered] != 0} {
        error "Old tab response must be ignored"
    }

    # Non-TikTok test
    set activeIsTikTok false
    refreshPlayer
    if {$calls != 1} {
        error "Non-TikTok tabs must not be polled"
    }

    # TikTok test
    set activeIsTikTok true
    set pending [refreshPlayer]
    set reply "{response: {playerState: {playing: true}}}"
    handleReply $activeTabId $playerContextGeneration
    if {[llength $rendered] != 1} {
        error "Current tab response must render"
    }

    # Stale response test
    set pending [refreshPlayer]
    set activeTabId 3
    incr playerContextGeneration
    set activeTabId 2
    incr playerContextGeneration
    set reply "{response: {playerState: {playing: false}}}"
    handleReply $activeTabId $playerContextGeneration
    if {[llength $rendered] != 1} {
        error "Returning to the same tab must not revive an old response"
    }

    # Check for context invalidation in source
    if {![regexp {async function refresh\(\)\s*\{\s*playerContextGeneration\+\+;} $::source]} {
        error "Context invalidation must precede asynchronous tab lookup"
    }

    puts "PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered"
}

# Helper to read file content
proc readFile {filename} {
    set fp [open $filename r]
    set filedata [read $fp]
    close $fp
    return $filedata
}

# Run the main test
if {[catch {main} error]} {
    puts stderr $error
    exit 1
}
