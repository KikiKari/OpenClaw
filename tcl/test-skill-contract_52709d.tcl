#!/usr/bin/env tclsh8.6
# test-skill-contract.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/test-skill-contract.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Regression checks for /tiktok_live_mon routing and monitor actions.

package require fileutil

# Define constants
set SKILL [file normalize [file join [file dirname [info script]] ".." "SKILL.md"]]
set DISPATCHER "/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @name --quality auto --json"
set CONTROLLER "/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok-monitorctl.sh"

# Read the skill file content
set fh [open $SKILL r]
set text [read $fh]
close $fh
set normalized_text [string map {"\n" " " "\r" " " "\t" " "} $text]

# Test procedures
proc assert_in {text search_term} {
    if {![string match "*$search_term*" $text]} {
        error "Assertion failed: '$search_term' not found in text"
    }
}

proc run_tests {} {
    global text normalized_text DISPATCHER CONTROLLER
    
    # test_bare_handle_uses_dispatcher_as_first_tool_call
    assert_in $normalized_text "dispatcher exec must be the first tool call"
    assert_in $text $DISPATCHER
    assert_in $text "A bare handle never starts a daemon"
    
    # test_slash_command_bypasses_the_model
    foreach expected {
        "command-dispatch: tool"
        "command-tool: tiktok_live_mon_command"
        "command-arg-mode: raw"
    } {
        assert_in $text $expected
    }
    
    # test_no_preliminary_playwright_or_dependency_probe
    foreach expected {
        "Before this dispatcher call, do not invoke or inspect"
        "`tiktok-check-profile.js`"
        "Do not attempt to install or repair browser dependencies"
        "failed preliminary tool call"
    } {
        assert_in $normalized_text $expected
    }
    
    # test_direct_exec_without_shell_wrapper
    foreach expected {
        "Invoke that executable directly as the exec command"
        "Do not invoke `bash`"
        "`bash -lc`"
        "wrapper must not be attempted in the first place"
    } {
        assert_in $normalized_text $expected
    }
    
    # test_success_json_wins_over_trailing_diagnostics
    foreach expected {
        "display the final stdout JSON before trailing stderr diagnostics"
        "regardless of its visual position"
        "the tool execution succeeded"
        "Never replace such a result with a generic tool-failure message"
        "`node_available`"
    } {
        assert_in $normalized_text $expected
    }
    
    # test_running_dispatcher_is_polled_without_restart
    foreach expected {
        "Start exactly one dispatcher exec per request"
        "do not rerun exec"
        {sessionId: "NAME"}
        "Continue polling that same name until completion"
    } {
        assert_in $text $expected
    }
    
    # test_monitor_actions_remain_controller_backed
    foreach action {start status stop} {
        set cmd "$CONTROLLER $action @name"
        assert_in $text $cmd
    }
    assert_in $text "prevents duplicate active monitors"
    assert_in $text "Without the current word `start`"
    
    # test_one_shot_response_contract_covers_all_statuses
    set legacy "@<handle> is currently <OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.\nVLC/MPV: not available\nMethod: <method>"
    assert_in $text $legacy
    assert_in $text "@<handle> is currently LIVE on TikTok.\nTitel: <room.title>"
    
    foreach expected {
        "Stream-URLs:"
        "<label> (HLS):"
        "<label> (FLV):"
        "exactly one URL and nothing else"
        "No raw URL appears in plain text"
    } {
        assert_in $normalized_text $expected
    }
    
    foreach status {live offline restricted overloaded dependency_missing technical_error} {
        assert_in $text $status
    }
    
    # test_invalid_current_input_is_not_taken_from_history
    assert_in $text "Derive the action, handle, hours, and poll interval only"
    assert_in $text "Never take them from"
    
    puts "All tests passed."
}

# Run the tests
if {[info script] eq $argv0} {
    run_tests
}
