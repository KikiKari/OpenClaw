#!/usr/bin/env tclsh
# test_hook_recovery.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_hook_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_hook_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_hook_recovery.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_hook_recovery.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Mocking Node.js modules and functions
proc node_test_run {tests} {
    foreach test $tests {
        {*}$test
    }
}

proc node_assert_equal {actual expected} {
    if {$actual != $expected} {
        error "Assertion failed: expected $expected, got $actual"
    }
}

proc node_assert_ok {condition} {
    if {![expr $condition]} {
        error "Assertion failed: condition not met"
    }
}

proc node_assert_throws {script} {
    if {[catch {uplevel #0 $script}]} {
        return
    }
    error "Expected exception was not thrown"
}

# Load required modules (mocked)
source [file join [file dirname $argv0] .. browser-extension hook-recovery.tcl]
source [file join [file dirname $argv0] .. browser-extension proto-main.tcl]

# Harness function
proc harness {} {
    set now 1000
    set serial 0
    set identity "stream-a"
    set timers [dict create]
    set events [list]
    set sockets [list]

    proc now_fn {} {
        variable now
        return $now
    }

    proc uuid_fn {} {
        variable serial
        incr serial
        return $serial
    }

    proc identity_fn {} {
        variable identity
        return $identity
    }

    proc emit_fn {e} {
        variable events
        lappend events $e
        set events $events
    }

    proc later_fn {fn ms} {
        variable timers
        variable serial
        variable now
        incr serial
        set id $serial
        dict set timers $id [dict create at [expr {$now + $ms}] fn $fn]
        return $id
    }

    proc cancel_fn {id} {
        variable timers
        dict unset timers $id
    }

    proc connect_fn {template token} {
        variable sockets
        set s [dict create token $token closed false]
        lappend sockets $s
        set sockets $sockets
        return $s
    }

    set controller [create [dict create \
        now now_fn \
        uuid uuid_fn \
        identity identity_fn \
        emit emit_fn \
        later later_fn \
        cancel cancel_fn \
        connect connect_fn]]

    proc tick_fn {ms} {
        variable now
        variable timers
        set target [expr {$now + $ms}]
        while {true} {
            set candidates [list]
            dict for {id t} $timers {
                if {[dict get $t at] <= $target} {
                    lappend candidates [list $id $t]
                }
            }
            if {[llength $candidates] == 0} break
            set next [lindex [lsort -integer -index 1 $candidates] 0]
            set now [dict get [lindex $next 1] at]
            dict unset timers [lindex $next 0]
            {*}[dict get [lindex $next 1] fn]
        }
        set now $target
    }

    proc stream_fn {v} {
        variable identity
        variable controller
        set identity $v
        $controller checkStream
    }

    proc prime_fn {} {
        variable controller
        $controller nativeConnected [dict create supported true]
        $controller configure [dict create enabled true seconds 3]
        $controller nativeDisconnected
    }

    return [dict create \
        controller $controller \
        tick tick_fn \
        events events \
        sockets sockets \
        timers timers \
        stream stream_fn \
        prime prime_fn]
}

# Test cases
proc test_hook_default_disabled_and_unverified_protocol_cannot_create_sockets {} {
    set h [harness]
    dict get $h controller nativeDisconnected
    {*}[dict get $h tick] 60000
    node_assert_equal [llength [dict get $h sockets]] 0
    dict get $h controller configure [dict create enabled true]
    {*}[dict get $h tick] 60000
    node_assert_equal [llength [dict get $h sockets]] 0
    node_assert_equal [dict get [lindex [dict get $h events] end] phase] "unavailable"
}

proc test_five_synthetic_hook_failures_recover_without_any_media_navigation_capability {} {
    set h [harness]
    {*}[dict get $h prime]
    for {set i 0} {$i < 5} {incr i} {
        {*}[dict get $h tick] 2999
        node_assert_equal [llength [dict get $h sockets]] $i
        {*}[dict get $h tick] 1
        set token [dict get [lindex [dict get $h sockets] end] token]
        dict get $h controller stage $token "socket-open"
        {*}[dict get $h tick] 200
        dict get $h controller stage $token "first-frame"
        {*}[dict get $h tick] 100
        dict get $h controller stage $token "first-decoded-message"
        node_assert_equal [dict get $h controller connected $token] true
        node_assert_equal [dict get [lindex [dict get $h events] end] disconnectToDecodedMs] 3300
        dict get $h controller nativeConnected [dict create supported true]
        node_assert_equal [dict get [lindex [dict get $h sockets] end] closed] true
        dict get $h controller nativeDisconnected
    }
}

proc test_open_alone_times_out_after_ten_seconds_one_socket_backoff_capped_at_30_seconds {} {
    set h [harness]
    {*}[dict get $h prime]
    {*}[dict get $h tick] 3000
    for {set i 0} {$i < 6} {incr i} {
        set s [lindex [dict get $h sockets] end]
        dict get $h controller stage [dict get $s token] "socket-open"
        {*}[dict get $h tick] 9999
        node_assert_equal [dict get $s closed] false
        {*}[dict get $h tick] 1
        node_assert_equal [dict get $s closed] true
        set delay [dict get [lindex [dict get $h events] end] effectiveDelayMs]
        node_assert_ok {$delay <= 30000}
        {*}[dict get $h tick] $delay
        node_assert_equal [llength [lsearch -all -inline [dict get $h sockets] {!closed}]] 1
    }
}

proc test_native_takeover_cancels_deadline_and_ignores_stale_socket_callbacks {} {
    set h [harness]
    {*}[dict get $h prime]
    {*}[dict get $h tick] 3000
    set token [dict get [lindex [dict get $h sockets] 0] token]
    dict get $h controller nativeConnected [dict create supported true]
    node_assert_equal [dict get $h controller connected $token] false
    dict get $h controller failed $token "socket-close"
    {*}[dict get $h tick] 60000
    node_assert_equal [llength [dict get $h sockets]] 1
    node_assert_equal [dict get [lindex [dict get $h events] end] phase] "native"
}

proc test_stream_switch_discards_template_and_cancels_scheduled_attempt {} {
    set h [harness]
    {*}[dict get $h prime]
    {*}[dict get $h stream] "stream-b"
    {*}[dict get $h tick] 60000
    node_assert_equal [llength [dict get $h sockets]] 0
    dict get $h controller nativeDisconnected
    node_assert_equal [dict get [lindex [dict get $h events] end] phase] "unavailable"
}

proc test_disable_closes_owned_socket_and_policy_rejection_forbids_retries {} {
    set h [harness]
    {*}[dict get $h prime]
    {*}[dict get $h tick] 3000
    dict get $h controller configure [dict create enabled false]
    node_assert_equal [dict get [lindex [dict get $h sockets] 0] closed] true
    {*}[dict get $h tick] 60000
    node_assert_equal [llength [dict get $h sockets]] 1
    set p [harness]
    {*}[dict get $p prime]
    {*}[dict get $p tick] 3000
    dict get $p controller failed [dict get [lindex [dict get $p sockets] 0] token] "policy-rejected"
    {*}[dict get $p tick] 60000
    node_assert_equal [llength [dict get $p sockets]] 1
    node_assert_equal [dict get [lindex [dict get $p events] end] phase] "unavailable"
}

proc test_disposed_document_never_reconnects_after_new_configuration {} {
    set h [harness]
    {*}[dict get $h prime]
    dict get $h controller dispose
    dict get $h controller configure [dict create enabled true]
    {*}[dict get $h tick] 60000
    node_assert_equal [llength [dict get $h sockets]] 0
}

proc test_ACK_and_heartbeat_encoder_round_trips_supported_dialect_and_rejects_malformed_controls {} {
    node_assert_equal [proto inspectTransportControl [proto encodeTransport hb]] type "hb"
    set ack [proto inspectTransportControl [proto encodeTransport ack 18446744073709551615 opaque]]
    node_assert_equal [dict get $ack id] "18446744073709551615"
    node_assert_equal [dict get $ack payload] "opaque"
    node_assert_equal [proto inspectTransportControl [proto encodeTransport ack 0]] null
    node_assert_equal [proto inspectTransportControl [proto encodeTransport hb 1]] null
    node_assert_equal [proto inspectTransportControl [binary format c 255]] null
    node_assert_throws {proto encodeTransport ack -1}
}

# Run tests
node_test_run {
    test_hook_default_disabled_and_unverified_protocol_cannot_create_sockets
    test_five_synthetic_hook_failures_recover_without_any_media_navigation_capability
    test_open_alone_times_out_after_ten_seconds_one_socket_backoff_capped_at_30_seconds
    test_native_takeover_cancels_deadline_and_ignores_stale_socket_callbacks
    test_stream_switch_discards_template_and_cancels_scheduled_attempt
    test_disable_closes_owned_socket_and_policy_rejection_forbids_retries
    test_disposed_document_never_reconnects_after_new_configuration
    test_ACK_and_heartbeat_encoder_round_trips_supported_dialect_and_rejects_malformed_controls
}
