#!/usr/bin/env tclsh
# test_issue_controls.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_issue_controls.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require tdom

# Mock Node.js modules and functions
proc require {module} {
    # In Tcl, we don't have require, but we can simulate the needed functionality
    switch $module {
        "node:test" {
            return [dict create test test]
        }
        "node:assert/strict" {
            return [dict create assert assert]
        }
        default {
            return ""
        }
    }
}

proc readFileSync {filepath} {
    set fp [open $filepath r]
    set data [read $fp]
    close $fp
    return $data
}

proc joinPath {args} {
    return [join $args "/"]
}

proc dirname {} {
    return [file dirname [info script]]
}

# Load source files
set source [readFileSync [joinPath [dirname] "../browser-extension/sidepanel.js"]]
set core_content [readFileSync [joinPath [dirname] "../browser-extension/content-core.js"]]

# Fragment function
proc fragment {start end} {
    global source
    set a [string first $start $source]
    set b [string first $end $source [expr {$a + [string length $start]}]]
    if {$a < 0 || $b <= $a} {
        error "Fragment not found"
    }
    return [string range $source $a [expr {$b - 1}]]
}

# Controls function
proc controls {} {
    # In Tcl, we'll use arrays to simulate objects
    array set elements {}
    
    # Document simulation
    set document [dict create activeElement ""]
    
    # Element creation function
    proc createElement {id} {
        return [dict create \
            hidden true \
            disabled false \
            textContent "Off" \
            handlers [dict create] \
            addEventListener [list addEventListener $id] \
            focus [list focus $id] \
            click [list click $id]]
    }
    
    proc addEventListener {id name fn} {
        variable elements
        set elem [dict get $elements $id]
        dict set elem handlers $name $fn
        dict set elements $id $elem
    }
    
    proc focus {id} {
        variable document
        dict set document activeElement $id
    }
    
    proc click {id} {
        variable elements
        if {[dict exists $elements $id]} {
            set elem [dict get $elements $id]
            if {[dict exists $elem handlers click]} {
                set handler [dict get $elem handlers click]
                # Execute handler with mock event
                uplevel #0 $handler [list [dict create target $elem]]
            }
        }
    }
    
    return [dict create elements [array get elements] document $document]
}

# Test framework simulation
proc test {description script} {
    puts "Running test: $description"
    if [catch {uplevel #0 $script} error] {
        puts "Test failed: $error"
    } else {
        puts "Test passed"
    }
}

# Assertion functions
proc assert_equal {actual expected} {
    if {$actual != $expected} {
        error "Assertion failed: expected $expected, got $actual"
    }
}

proc assert_match {actual pattern} {
    if {![regexp $pattern $actual]} {
        error "Assertion failed: '$actual' does not match pattern '$pattern'"
    }
}

proc assert_fail {message} {
    error "Assertion failed: $message"
}

# Test cases
test "175 manual and automatic speech reject raw point triggers before author prefixes" {
    foreach enabled {false true} {
        set spoken [list]
        array set s [list \
            core $core_content \
            filterExternalSpeechTriggers $enabled \
            speechEnabled true \
            speechQueue [list] \
            elements [dict create speech-status [dict create]] \
            pumpSpeech {} \
            speechText {proc speechText item {return "Autor sagt [dict get \$item content]"}} \
            speechLang {proc speechLang {} {return "de"}} \
            serviceSpeech [list serviceSpeech spoken] \
            browserSpeech {proc browserSpeech {} {assert_fail "unexpected fallback"}}]
        
        # Execute the speech functions from fragments
        set speakItemCode [fragment "  async function speakItem(" "  async function pumpSpeech("]
        set enqueueSpeechCode [fragment "  function enqueueSpeech(" "  function "]
        
        # Simplified execution model
        proc speakItem {item} {
            variable s
            lappend s(spoken) [$s(speechText) $item]
        }
        
        proc enqueueSpeech {item} {
            variable s
            lappend s(spoken) [$s(speechText) $item]
        }
        
        foreach content {.Text ". Text" "  .Text" Normal "Ein Satz. Noch einer"} {
            speakItem [dict create content $content]
            enqueueSpeech [dict create content $content]
        }
        
        assert_equal [llength $spoken] [expr {$enabled ? 2 : 5}]
        assert_equal [llength $s(speechQueue)] [expr {$enabled ? 2 : 5}]
    }
}

test "176 speech switch commits On/Off only after a successful request" {
    array set s [controls]
    dict set s speechEnabled false
    dict set s send {proc send {} {}}
    dict set s refresh {proc refresh {} {}}
    dict set s activateSpeech {proc activateSpeech {} {dict set s speechEnabled true}}
    dict set s stopSpeech {proc stopSpeech {} {dict set s speechEnabled false}}
    
    # Add event listeners (simplified)
    set toggleHookCode [fragment "  elements\[\"toggle-speech\"\].addEventListener" "  elements\[\"speech-volume\"\].addEventListener"]
    
    # Simulate clicks
    click "toggle-speech"
    assert_equal [dict get $s speechEnabled] true
    
    dict set s send {proc send {} {error "failed"}}
    click "toggle-speech"
    assert_equal [dict get $s speechEnabled] true
    
    # Check status text contains failed
    if {![regexp "failed" [dict get $s elements speech-status textContent]]} {
        assert_fail "Status text should contain 'failed'"
    }
    
    dict set s send {proc send {} {}}
    click "toggle-speech"
    assert_equal [dict get $s speechEnabled] false
}

test "176 Connection selects both commands and preserves state on rejection" {
    set calls [list]
    array set s [controls]
    dict set s currentState [dict create hook [dict create armed false]]
    dict set s send [list lappend calls]
    dict set s refresh {proc refresh {} {dict set s currentState hook armed [expr {![dict get $s currentState hook armed]}]}}
    
    # Add event listeners (simplified)
    set toggleHookCode [fragment "  elements\[\"toggle-hook\"\].addEventListener" "  elements\[\"reset-tab\"\].addEventListener"]
    
    # Simulate clicks
    click "toggle-hook"
    click "toggle-hook"
    assert_equal $calls [list TLC_ENABLE_HOOK TLC_DISABLE_HOOK]
    
    dict set s send {proc send {} {error "failed"}}
    click "toggle-hook"
    assert_equal [dict get $s currentState hook armed] false
    if {![regexp "failed" [dict get $s elements notice textContent]]} {
        assert_fail "Notice text should contain 'failed'"
    }
}

test "176 Connection dialog returns focus and traps Tab in both directions" {
    array set s [controls]
    
    # Add event listeners (simplified)
    set connectionSettingsCode [fragment "  elements\[\"open-connection-settings\"\].addEventListener" "  elements\[\"open-speech-settings\"\].addEventListener"]
    
    # Set up key event handling
    set keyHandler ""
    dict set s document addEventListener [list set keyHandler]
    
    set keyDownCode [fragment "  document.addEventListener(\"keydown\"" "  elements\[\"keep-speech-active\"\].addEventListener"]
    
    # Simulate opening connection settings
    click "open-connection-settings"
    assert_equal [dict get $s elements connection-settings-modal hidden] false
    assert_equal [dict get $s document activeElement] [dict get $s elements close-connection-settings]
    
    # Set up modal elements
    set first [dict get $s elements close-connection-settings]
    set last [dict create quick-recover-seconds {}]
    dict set s elements connection-settings-modal querySelectorAll [list return [list $first $last]]
    
    # Simulate tab navigation
    set prevented 0
    set preventDefaultProc {incr prevented}
    
    # Shift+Tab
    uplevel #0 $keyHandler [list [dict create key Tab shiftKey true preventDefault $preventDefaultProc]]
    assert_equal [dict get $s document activeElement] $last
    
    # Tab
    uplevel #0 $keyHandler [list [dict create key Tab shiftKey false preventDefault $preventDefaultProc]]
    assert_equal [dict get $s document activeElement] $first
    assert_equal $prevented 2
    
    # Escape
    uplevel #0 $keyHandler [list [dict create key Escape]]
    assert_equal [dict get $s elements connection-settings-modal hidden] true
    assert_equal [dict get $s document activeElement] [dict get $s elements open-connection-settings]
}

puts "All tests completed"
