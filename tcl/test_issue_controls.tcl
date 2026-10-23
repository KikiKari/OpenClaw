#!/usr/bin/env tclsh
# test_issue_controls.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_issue_controls.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Tcl doesn't have native testing framework like node:test
# We'll implement basic testing functionality

proc test {description script} {
    puts "Running test: $description"
    if {[catch {uplevel #0 $script} error]} {
        puts "FAIL: $description - $error"
        exit 1
    } else {
        puts "PASS: $description"
    }
}

proc assert_equal {actual expected} {
    if {$actual ne $expected} {
        error "Assertion failed: expected '$expected', got '$actual'"
    }
}

proc assert_match {text pattern} {
    if {![regexp $pattern $text]} {
        error "Assertion failed: '$text' does not match pattern '$pattern'"
    }
}

proc assert_fail {message} {
    error "Assertion failed: $message"
}

# Mock file reading
proc read_file {filename} {
    set fp [open $filename r]
    set content [read $fp]
    close $fp
    return $content
}

# Get directory of this script
set script_dir [file dirname [info script]]

# Read source files
set source [read_file [file join $script_dir ../browser-extension/sidepanel.js]]
# Note: content-core.js is referenced but not loaded as it's not used directly in tests

# Helper function to extract code fragments
proc fragment {start end} {
    global source
    set a [string first $start $source]
    if {$a == -1} {
        error "Start string '$start' not found"
    }
    set b [string first $end $source [expr {$a + [string length $start]}]]
    if {$b <= $a} {
        error "End string '$end' not found after start"
    }
    return [string range $source $a [expr {$b - 1}]]
}

# Create controls mock
proc controls {} {
    # In Tcl we'll use arrays and dicts to simulate the JS objects
    set elements [dict create]
    set document [dict create activeElement ""]
    
    # Return a dict containing our mock objects
    return [list elements $elements document $document]
}

# Test 175
test "175 manual and automatic speech reject raw point triggers before author prefixes" {
    foreach enabled [list false true] {
        set spoken [list]
        
        # Build context dictionary (like JS object)
        array set s [list \
            core "" \
            filterExternalSpeechTriggers $enabled \
            externalSpeechTriggerCharacters "." \
            speechEnabled true \
            speechQueue [list] \
            elements [dict create speech-status [dict create]] \
            pumpSpeech {} \
            speechText "Autor sagt %s" \
            speechLang "de" \
            serviceSpeech [list service_speech_callback spoken] \
            browserSpeech "fail" \
        ]
        
        proc service_speech_callback {var text} {
            upvar $var spoken_list
            lappend spoken_list $text
        }
        
        # Extract and execute relevant functions
        set func1 [fragment "  async function speakItem(" "  async function pumpSpeech("]
        set func2 [fragment "  function enqueueSpeech(" "  function "]
        
        # Evaluate functions in global scope
        eval $func1
        eval $func2
        
        # Test data
        set contents [list ".Text" ". Text" "  .Text" "Normal" "Ein Satz. Noch einer"]
        foreach content $contents {
            # Call speakItem and enqueueSpeech
            speakItem [list content $content]
            enqueueSpeech [list content $content]
        }
        
        # Check results
        set expected_count [expr {$enabled ? 2 : 5}]
        assert_equal [llength $spoken] $expected_count
        assert_equal [llength [array get s speechQueue]] $expected_count
    }
}

# Test 187 input truncates pasted values
test "187 input truncates pasted values and checkbox preserves selection" {
    set calls [list]
    
    # Create controls
    array set control_data [controls]
    set elements [dict get $control_data elements]
    set document [dict get $control_data document]
    
    # Add event handling capabilities to elements
    proc add_element_event_handlers {element_dict} {
        dict set element_dict handlers [dict create]
        dict set element_dict addEventListener [list add_event_listener element_dict]
        dict set element_dict click [list click_element element_dict]
        dict set element_dict focus [list focus_element element_dict]
        return $element_dict
    }
    
    proc add_event_listener {element_var name fn} {
        upvar $element_var element
        dict set element handlers $name $fn
    }
    
    proc click_element {element_var} {
        upvar $element_var element
        set handler [dict get $element handlers click]
        if {$handler ne ""} {
            # Call handler with mock event
            eval $handler [list target $element]
        }
    }
    
    proc focus_element {element_var} {
        upvar $element_var element
        # Focus implementation would go here
    }
    
    # Build context
    array set s [list \
        elements $elements \
        document $document \
        core "" \
        filterExternalSpeechTriggers false \
        externalSpeechTriggerCharacters ".,-" \
        send [list send_callback calls] \
    ]
    
    proc send_callback {var type payload} {
        upvar $var call_list
        lappend call_list [dict merge [list type $type] $payload]
    }
    
    # Extract and run event listeners
    set event_code [fragment {  elements["filter-external-speech-triggers"].addEventListener} {  elements["game-mode"].addEventListener}]
    eval $event_code
    
    # Test input value truncation
    set input_element [dict get $s(elements) external-speech-trigger-characters]
    dict set input_element value ".,-;:!"
    
    # Trigger input event
    set input_handler [dict get $input_element handlers input]
    if {$input_handler ne ""} {
        eval $input_handler
    }
    
    assert_equal [dict get $input_element value] ".,-;:"
    assert_equal [dict get [lindex $calls end] externalSpeechTriggerCharacters] ".,-;:"
    
    # Test checkbox toggle
    set toggle_element [dict get $s(elements) filter-external-speech-triggers]
    dict set toggle_element checked true
    
    set change_handler [dict get $toggle_element handlers change]
    if {$change_handler ne ""} {
        eval $change_handler
    }
    
    dict set toggle_element checked false
    if {$change_handler ne ""} {
        eval $change_handler
    }
    
    assert_equal [dict get $input_element value] ".,-;:"
    assert_equal [dict get $input_element disabled] false
    assert_equal [dict get [lindex $calls end] filterExternalSpeechTriggers] false
    
    # Test emoji truncation
    dict set input_element value "😀😁😂😃😄😅"
    if {$input_handler ne ""} {
        eval $input_handler
    }
    assert_equal [dict get $input_element value] "😀😁😂😃😄"
    
    # Test empty value
    dict set input_element value ""
    if {$input_handler ne ""} {
        eval $input_handler
    }
    assert_equal [dict get [lindex $calls end] externalSpeechTriggerCharacters] ""
}

# Test 187 custom prefixes
test "187 custom prefixes apply to manual and automatic speech before author prefixes" {
    foreach enabled [list false true] {
        set spoken [list]
        
        # Build context
        array set s [list \
            core "" \
            filterExternalSpeechTriggers $enabled \
            externalSpeechTriggerCharacters ".,-" \
            speechEnabled true \
            speechQueue [list] \
            elements [dict create speech-status [dict create]] \
            pumpSpeech {} \
            speechText "Autor sagt %s" \
            speechLang "de" \
            serviceSpeech [list service_speech_callback spoken] \
            browserSpeech "fail" \
        ]
        
        # Extract and execute relevant functions
        set func1 [fragment "  async function speakItem(" "  async function pumpSpeech("]
        set func2 [fragment "  function enqueueSpeech(" "  function "]
        
        eval $func1
        eval $func2
        
        # Test data
        set contents [list ".Hallo" ",Hallo" "- Hallo" "Hallo, zusammen."]
        foreach content $contents {
            speakItem [list content $content]
            enqueueSpeech [list content $content]
        }
        
        # Check results
        set expected_count [expr {$enabled ? 1 : 4}]
        assert_equal [llength $spoken] $expected_count
        assert_equal [llength [array get s speechQueue]] $expected_count
    }
}

# Test 176 speech switch
test "176 speech switch commits On/Off only after a successful request" {
    # Create controls
    array set control_data [controls]
    set elements [dict get $control_data elements]
    set document [dict get $control_data document]
    
    # Build context
    array set s [list \
        elements $elements \
        document $document \
        speechEnabled false \
        send {} \
        refresh {} \
        activateSpeech {set s(speechEnabled) true} \
        stopSpeech {set s(speechEnabled) false} \
    ]
    
    # Add methods to manipulate speechEnabled
    proc activateSpeech {} {
        global s
        set s(speechEnabled) true
    }
    
    proc stopSpeech {} {
        global s
        set s(speechEnabled) false
    }
    
    # Extract and run event listeners
    set event_code [fragment {  elements["toggle-speech"].addEventListener} {  elements["speech-volume"].addEventListener}]
    eval $event_code
    
    # Test successful toggle
    proc set_send_success {} {
        global s
        set s(send) "success_send"
    }
    
    proc success_send {} {
        # Do nothing - success
    }
    
    set_send_success
    set toggle_element [dict get $s(elements) toggle-speech]
    click_element toggle_element
    assert_equal $s(speechEnabled) true
    
    # Test failed toggle
    proc set_send_failure {} {
        global s
        set s(send) "fail_send"
    }
    
    proc fail_send {} {
        error "failed"
    }
    
    set_send_failure
    click_element toggle_element
    assert_equal $s(speechEnabled) true
    assert_match [dict get [dict get $s(elements) speech-status] textContent] "failed"
    
    # Test successful disable
    set_send_success
    click_element toggle_element
    assert_equal $s(speechEnabled) false
}

# Test 176 Connection
test "176 Connection selects both commands and preserves state on rejection" {
    # Create controls
    array set control_data [controls]
    set elements [dict get $control_data elements]
    
    # Build context
    set calls [list]
    array set s [list \
        elements $elements \
        currentState [dict create hook [dict create armed false]] \
        send [list connection_send calls] \
        refresh [list connection_refresh] \
    ]
    
    proc connection_send {var cmd} {
        upvar $var call_list
        lappend call_list $cmd
        # Simulate state change
        global s
        dict set s(currentState) hook armed [expr {![dict get $s(currentState) hook armed]}]
    }
    
    proc connection_refresh {} {
        global s
        dict set s(currentState) hook armed [expr {![dict get $s(currentState) hook armed]}]
    }
    
    # Extract and run event listeners
    set event_code [fragment {  elements["toggle-hook"].addEventListener} {  elements["reset-tab"].addEventListener}]
    eval $event_code
    
    # Test toggling
    set toggle_element [dict get $s(elements) toggle-hook]
    click_element toggle_element
    click_element toggle_element
    assert_equal $calls [list "TLC_ENABLE_HOOK" "TLC_DISABLE_HOOK"]
    
    # Test failure case
    proc failing_send {} {
        error "failed"
    }
    
    set s(send) failing_send
    click_element toggle_element
    assert_equal [dict get $s(currentState) hook armed] false
    assert_match [dict get $s(elements) notice textContent] "failed"
}

# Test 176 Connection dialog focus
test "176 Connection dialog returns focus and traps Tab in both directions" {
    # Create controls
    array set control_data [controls]
    set elements [dict get $control_data elements]
    set document [dict get $control_data document]
    
    # Build context
    array set s [list \
        elements $elements \
        document $document \
    ]
    
    # Extract and run event listeners
    set event_code1 [fragment {  elements["open-connection-settings"].addEventListener} {  elements["open-speech-settings"].addEventListener}]
    eval $event_code1
    
    set key_handler ""
    proc add_document_event_listener {var name fn} {
        upvar $var handler_var
        set handler_var $fn
    }
    
    dict set s(document) addEventListener [list add_document_event_listener key_handler]
    
    set event_code2 [fragment {  document.addEventListener("keydown"} {  elements["keep-speech-active"].addEventListener}]
    eval $event_code2
    
    # Simulate opening connection settings
    set open_element [dict get $s(elements) open-connection-settings]
    click_element open_element
    
    assert_equal [dict get [dict get $s(elements) connection-settings-modal] hidden] false
    assert_equal [dict get $s(document) activeElement] [dict get $s(elements) close-connection-settings]
    
    # Set up first and last elements
    set first [dict get $s(elements) close-connection-settings]
    set last [dict get $s(elements) quick-recover-seconds]
    
    # Mock querySelectorAll
    proc mock_query_selector_all {modal} {
        global first last
        return [list $first $last]
    }
    
    dict set s(elements) connection-settings-modal [dict create querySelectorAll mock_query_selector_all]
    
    set prevented 0
    proc prevent_default {var} {
        upvar $var count
        incr count
    }
    
    # Test shift+tab
    $key_handler [dict create key "Tab" shiftKey true preventDefault [list prevent_default prevented]]
    assert_equal [dict get $s(document) activeElement] $last
    
    # Test tab
    $key_handler [dict create key "Tab" shiftKey false preventDefault [list prevent_default prevented]]
    assert_equal [dict get $s(document) activeElement] $first
    assert_equal $prevented 2
    
    # Test escape
    $key_handler [dict create key "Escape"]
    assert_equal [dict get [dict get $s(elements) connection-settings-modal] hidden] true
    assert_equal [dict get $s(document) activeElement] [dict get $s(elements) open-connection-settings]
}

puts "All tests completed successfully!"
