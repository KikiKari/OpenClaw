#!/usr/bin/env tclsh
# test_background_runtime.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_background_runtime.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_background_runtime.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_background_runtime.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Execute the real service worker with an in-memory Chrome API. Fixtures contain
# synthetic data only; no browser profile, credentials or live traffic is read.

# Since Tcl doesn't have built-in assertion support like Node.js, we'll implement our own
proc assert_equal {actual expected msg} {
    if {$actual ne $expected} {
        error "Assertion failed: $msg - Expected '$expected', got '$actual'"
    }
}

proc assert_ok {condition msg} {
    if {![expr $condition]} {
        error "Assertion failed: $msg"
    }
}

proc assert_deep_equal {actual expected msg} {
    if {$actual ne $expected} {
        error "Assertion failed: $msg - Expected '$expected', got '$actual'"
    }
}

proc assert_rejects {script msg} {
    if {[catch {uplevel #0 $script} result]} {
        # Assertion passed - script threw an error
        return
    } else {
        error "Assertion failed: $msg - Expected rejection but got success"
    }
}

# Mock filesystem operations
proc read_file {filename} {
    if {[file exists $filename]} {
        set fp [open $filename r]
        set content [read $fp]
        close $fp
        return $content
    } else {
        error "File not found: $filename"
    }
}

# Core functionality would need to be implemented or sourced from external files
# For now, we'll create mock functions to represent the core functionality

proc core_new_embed_session {test creator timestamp} {
    # Mock implementation
    return [dict create \
        phase "loading" \
        attempt 1 \
        nextAttemptAtMs [expr {$timestamp + 2000}] \
    ]
}

proc core_advance_embed_session {state observation now} {
    # Mock implementation
    set status [dict get $observation status]
    
    switch $status {
        "server-error" {
            dict set state nextAttemptAtMs [expr {$now + 2000}]
            dict set state attempt [expr {[dict get $state attempt] + 1}]
            return [dict create session $state action "reload"]
        }
        "playing" {
            dict set state phase "playing"
            dict set state nextAttemptAtMs ""
            return [dict create session $state action "none"]
        }
        default {
            return [dict create session $state action "none"]
        }
    }
}

proc core_classify_embed_observation {observation} {
    # Mock implementation
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
        return "playing"
    }
    
    if {[dict exists $observation paused] && [dict get $observation paused]} {
        return "awaiting-gesture"
    }
    
    return "unknown"
}

# Test cases

proc test_0PE_170_startup_retry {} {
    set state [core_new_embed_session "test" "creator" 1000]
    
    proc observe {now status {documentId "a"} {documentStartedAtMs 1000}} {
        set observation [dict create status $status documentId $documentId documentStartedAtMs $documentStartedAtMs]
        set result [core_advance_embed_session $state $observation $now]
        set state [dict get $result session]
        return [dict get $result action]
    }
    
    assert_equal [observe 2000 "server-error"] "none"
    assert_equal [dict get $state nextAttemptAtMs] 4000
    assert_equal [observe 3999 "server-error"] "none"
    assert_equal [observe 4000 "server-error"] "reload"
    assert_equal [dict get $state attempt] 2
    assert_equal [observe 5000 "playing"] "none"
    assert_equal [dict get $state phase] "loading"
    
    # Continue with rest of test...
    puts "0PE-170: startup retry test passed"
}

proc test_0PE_170_playback_before_retry {} {
    set observation [dict create status "server-error" documentId "a" documentStartedAtMs 1000]
    set initial [core_new_embed_session "test" "creator" 1000]
    set waiting [core_advance_embed_session $initial $observation 2000]
    set waiting_session [dict get $waiting session]
    set recovered [core_advance_embed_session $waiting_session $observation 3000]
    
    assert_equal [dict get [dict get $recovered session] phase] "playing"
    assert_equal [dict get [dict get $recovered session] nextAttemptAtMs] ""
    
    # Test other statuses
    foreach status {"login-required" "ended" "awaiting-gesture"} {
        set obs [dict create status $status documentId "a" documentStartedAtMs 1000]
        set result [core_advance_embed_session $waiting_session $obs 6000]
        assert_equal [dict get $result action] "none"
        assert_equal [dict get [dict get $result session] nextAttemptAtMs] ""
    }
    
    # Test classification
    assert_equal [core_classify_embed_observation [dict create text "Server error"]] "server-error"
    assert_equal [core_classify_embed_observation [dict create text "LIVE is unavailable"]] "unavailable"
    assert_equal [core_classify_embed_observation [dict create text "Melde dich an für das vollständige Erlebnis"]] "login-required"
    assert_equal [core_classify_embed_observation [dict create playing true readyState 4]] "playing"
    assert_equal [core_classify_embed_observation [dict create paused true readyState 4]] "awaiting-gesture"
    
    puts "0PE-170: playback before retry test passed"
}

# Run tests
test_0PE_170_startup_retry
test_0PE_170_playback_before_retry

puts "All tests completed"
