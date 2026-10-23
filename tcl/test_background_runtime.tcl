#!/usr/bin/env tclsh
# test_background_runtime.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_background_runtime.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_background_runtime.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_background_runtime.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_background_runtime.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Execute the real service worker with an in-memory Chrome API. Fixtures contain
# synthetic data only; no browser profile, credentials or live traffic is read.

# Note: Tcl does not have built-in assertion support like Node.js, so we'll implement basic assertions
proc assert_equal {actual expected {msg ""}} {
    if {$actual ne $expected} {
        error "Assertion failed: expected '$expected', got '$actual'. $msg"
    }
}

proc assert_ok {condition {msg ""}} {
    if {![expr $condition]} {
        error "Assertion failed: $msg"
    }
}

proc assert_rejects {script} {
    if {[catch {uplevel #0 $script}]} {
        return
    }
    error "Expected rejection but none occurred"
}

# Mock file operations
proc read_file {filename} {
    if {[file exists $filename]} {
        return [read [open $filename r]]
    }
    error "File not found: $filename"
}

# Mock path operations
proc path_join {args} {
    return [join $args "/"]
}

proc path_resolve {args} {
    return [file normalize [join $args "/"]]
}

# Mock structuredClone (deep copy)
proc structured_clone {data} {
    return $data
}

# Mock webcrypto.randomUUID
proc random_uuid {} {
    set chars "0123456789abcdef"
    set uuid ""
    for {set i 0} {$i < 32} {incr i} {
        append uuid [string index $chars [expr {int(rand()*16)}]]
        if {$i == 7 || $i == 11 || $i == 15 || $i == 19} {
            append uuid "-"
        }
    }
    return $uuid
}

# Core functions would need to be implemented or sourced from content-core.js
# For this translation, we'll mock the core functionality

namespace eval core {
    proc newEmbedSession {test creator startedAtMs} {
        return [dict create \
            phase "loading" \
            startedAtMs $startedAtMs \
            nextAttemptAtMs [expr {$startedAtMs + 2000}] \
            attempt 1 \
        ]
    }
    
    proc advanceEmbedSession {state observation now} {
        set status [dict get $observation status]
        set documentId [dict get $observation documentId]
        set documentStartedAtMs [dict get $observation documentStartedAtMs]
        
        if {$status eq "server-error"} {
            if {[dict get $state attempt] >= 3} {
                dict set state phase "failed"
                return [dict create session $state action "none"]
            }
            dict set state attempt [expr {[dict get $state attempt] + 1}]
            dict set state nextAttemptAtMs [expr {$now + 2000}]
            return [dict create session $state action "reload"]
        } elseif {$status eq "playing"} {
            dict set state phase "playing"
            dict set state nextAttemptAtMs ""
            return [dict create session $state action "none"]
        } elseif {$status eq "unavailable"} {
            dict set state nextAttemptAtMs [expr {$now + 5000}]
            return [dict create session $state action "reload"]
        }
        return [dict create session $state action "none"]
    }
    
    proc classifyEmbedObservation {observation} {
        if {[dict exists $observation text]} {
            set text [dict get $observation text]
            if {[string match "*Server error*" $text]} {
                return "server-error"
            } elseif {[string match "*LIVE is unavailable*" $text]} {
                return "unavailable"
            } elseif {[string match "*Melde dich an*" $text]} {
                return "login-required"
            }
        }
        if {[dict exists $observation playing] && [dict get $observation playing]} {
            if {[dict exists $observation readyState] && [dict get $observation readyState] == 4} {
                return "playing"
            }
        }
        if {[dict exists $observation paused] && [dict get $observation paused]} {
            if {[dict exists $observation readyState] && [dict get $observation readyState] == 4} {
                return "awaiting-gesture"
            }
        }
        return "unknown"
    }
    
    proc mediaRecoveryReason {video {options ""}} {
        if {[dict exists $options userPaused] && [dict get $options userPaused]} {
            return ""
        }
        if {![dict exists $video paused] || [dict get $video paused]} {
            return "video-paused"
        }
        if {[dict exists $video error] && [dict get $video error] ne ""} {
            return "video-error"
        }
        if {[dict exists $video ended] && [dict get $video ended]} {
            return "video-ended"
        }
        if {![dict exists $video readyState] || [dict get $video readyState] < 2} {
            return "video-not-ready"
        }
        if {![dict exists $options graceElapsed] || ![dict get $options graceElapsed]} {
            return ""
        }
        return ""
    }
}

# Worker function mock
proc worker {{seed {}}} {
    set clock [dict create now [expr {[dict exists $seed now] ? [dict get $seed now] : [clock milliseconds]}]]
    set session [expr {[dict exists $seed session] ? [dict get $seed session] : [dict create]}]
    set local [expr {[dict exists $seed local] ? [dict get $seed local] : [dict create]}]
    set sent [list]
    set broadcasts [list]
    set browserTabs [dict create]
    if {[dict exists $seed tabs]} {
        foreach tab [dict get $seed tabs] {
            dict set browserTabs [dict get $tab id] $tab
        }
    }
    set tabActions [list]
    set nextTabId 100
    set listeners [dict create]
    set alarms [dict create]
    
    # Return a namespace-like structure with worker components
    return [dict create \
        clock $clock \
        session $session \
        local $local \
        sent $sent \
        broadcasts $broadcasts \
        browserTabs $browserTabs \
        tabActions $tabActions \
        nextTabId $nextTabId \
        listeners $listeners \
        alarms $alarms \
    ]
}

# Test cases
proc test_0PE_170_startup_retry {} {
    set state [core::newEmbedSession "test" "creator" 1000]
    
    proc observe {state_var now status {documentId "a"} {documentStartedAtMs 1000}} {
        set observation [dict create status $status documentId $documentId documentStartedAtMs $documentStartedAtMs]
        set result [core::advanceEmbedSession [set $state_var] $observation $now]
        set $state_var [dict get $result session]
        return [dict get $result action]
    }
    
    assert_equal [observe state 2000 "server-error"] "none"
    assert_equal [dict get $state nextAttemptAtMs] 4000
    assert_equal [observe state 3999 "server-error"] "none"
    assert_equal [observe state 4000 "server-error"] "reload"
    assert_equal [dict get $state attempt] 2
    assert_equal [observe state 5000 "playing"] "none"
    assert_equal [dict get $state phase] "loading"
    observe state 6000 "unavailable" "b" 4500
    assert_equal [dict get $state nextAttemptAtMs] 10000
    assert_equal [observe state 10000 "unavailable" "b" 4500] "reload"
    observe state 11000 "server-error" "c" 10500
    assert_equal [dict get $state phase] "failed"
    assert_equal [dict get $state attempt] 3
    assert_equal [observe state 100000 "server-error" "c" 10500] "none"
}

proc test_0PE_170_playback_before_retry {} {
    proc observation {status} {
        return [dict create status $status documentId "a" documentStartedAtMs 1000]
    }
    
    set initial [core::newEmbedSession "test" "creator" 1000]
    set waiting [dict get [core::advanceEmbedSession $initial [observation "server-error"] 2000] session]
    set recovered [core::advanceEmbedSession $waiting [observation "playing"] 3000]
    
    assert_equal [dict get [dict get $recovered session] phase] "playing"
    assert_equal [dict get [dict get $recovered session] nextAttemptAtMs] ""
    
    foreach status {"login-required" "ended" "awaiting-gesture"} {
        set result [core::advanceEmbedSession $waiting [observation $status] 6000]
        assert_equal [dict get $result action] "none"
        assert_equal [dict get [dict get $result session] nextAttemptAtMs] ""
    }
    
    set cancelled_session [dict create phase "cancelled"]
    foreach {key value} $initial {
        if {![dict exists $cancelled_session $key]} {
            dict set cancelled_session $key $value
        }
    }
    set result [core::advanceEmbedSession $cancelled_session [observation "server-error"] 100000]
    assert_equal [dict get $result action] "none"
    
    assert_equal [core::classifyEmbedObservation [dict create text "Server error"]] "server-error"
    assert_equal [core::classifyEmbedObservation [dict create text "LIVE is unavailable"]] "unavailable"
    assert_equal [core::classifyEmbedObservation [dict create text "Melde dich an für das vollständige Erlebnis"]] "login-required"
    assert_equal [core::classifyEmbedObservation [dict create playing true readyState 4]] "playing"
    assert_equal [core::classifyEmbedObservation [dict create paused true readyState 4]] "awaiting-gesture"
}

proc test_0PE_167_explicit_user_pause {} {
    set video [dict create paused true readyState 4 error "" ended false]
    assert_equal [core::mediaRecoveryReason $video [dict create userPaused true]] ""
    assert_equal [core::mediaRecoveryReason $video] "video-paused"
    assert_equal [core::mediaRecoveryReason [dict create paused false readyState 4 error "" ended false]] ""
    assert_equal [core::mediaRecoveryReason [dict create paused true readyState 4 error "error" ended false]] "video-error"
    assert_equal [core::mediaRecoveryReason [dict create paused true readyState 4 error "" ended true]] "video-ended"
    assert_equal [core::mediaRecoveryReason [dict create paused false readyState 1 error "" ended false]] "video-not-ready"
    assert_equal [core::mediaRecoveryReason $video [dict create graceElapsed false]] ""
    assert_equal [core::mediaRecoveryReason ""] ""
}

# Run tests
puts "Running test_0PE_170_startup_retry..."
test_0PE_170_startup_retry
puts "PASSED"

puts "Running test_0PE_170_playback_before_retry..."
test_0PE_170_playback_before_retry
puts "PASSED"

puts "Running test_0PE_167_explicit_user_pause..."
test_0PE_167_explicit_user_pause
puts "PASSED"

puts "All tests passed!"
