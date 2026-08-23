#!/usr/bin/env tclsh
# test-skill-contract.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:skills/tiktok-live/scripts/test-skill-contract.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Regression checks for the documented /tiktok_live normal flow.

package require fileutil
package require cmdline

# Define constants
set SKILL [file normalize [file join [file dirname $argv0] ".." "SKILL.md"]]
set CANONICAL_COMMAND "/home/openclaw/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py url @handle --quality auto --json"
set NODE_COMMAND $CANONICAL_COMMAND

# Test class equivalent
namespace eval SkillContractTests {
    variable text
    variable normalized_text
    
    # Setup method
    proc setUpClass {} {
        variable text
        variable normalized_text
        
        if {[catch {set fd [open $::SKILL r]}]} {
            error "Could not open $::SKILL"
        }
        set text [read $fd]
        close $fd
        
        # Normalize whitespace like Python's " ".join(text.split())
        regsub -all {\s+} $text " " normalized_text
    }
    
    # Assertion procedures
    proc assertIn {expected actual msg} {
        if {![string match "*$expected*" $actual]} {
            error "$msg: '$expected' not found in text"
        }
    }
    
    proc assertNotIn {expected actual msg} {
        if {[string match "*$expected*" $actual]} {
            error "$msg: '$expected' should not be found in text"
        }
    }
    
    proc assertEquals {expected actual msg} {
        if {$expected != $actual} {
            error "$msg: expected $expected, got $actual"
        }
    }
    
    # Test methods
    proc test_dispatcher_is_the_documented_first_action {} {
        variable text
        variable normalized_text
        
        assertIn "Make the existing dispatcher the first action" $text "First assertion failed"
        assertIn "first tool call of the request" $normalized_text "Second assertion failed"
        assertEquals [regexp -all $::CANONICAL_COMMAND $text] 2 "Command count assertion failed"
    }
    
    proc test_slash_command_bypasses_the_model {} {
        variable text
        
        foreach expected {
            "command-dispatch: tool"
            "command-tool: tiktok_live_command"
            "command-arg-mode: raw"
        } {
            assertIn $expected $text "Slash command bypass test failed for: $expected"
        }
    }
    
    proc test_no_preliminary_playwright_or_dependency_probe {} {
        variable normalized_text
        
        foreach expected {
            "Before this dispatcher call, do not invoke or inspect"
            "`tiktok-check-profile.js`"
            "Do not attempt to install or repair browser dependencies"
            "failed preliminary tool call"
        } {
            assertIn $expected $normalized_text "Preliminary probe test failed for: $expected"
        }
    }
    
    proc test_direct_exec_without_shell_wrapper {} {
        variable normalized_text
        
        foreach expected {
            "Invoke that executable directly as the exec command"
            "Do not invoke `bash`"
            "`bash -lc`"
            "wrapper must not be attempted in the first place"
        } {
            assertIn $expected $normalized_text "Direct exec test failed for: $expected"
        }
    }
    
    proc test_success_json_wins_over_trailing_diagnostics {} {
        variable normalized_text
        
        foreach expected {
            "display the final stdout JSON before trailing stderr diagnostics"
            "regardless of its visual position"
            "the tool execution succeeded"
            "Never replace such a result with a generic tool-failure message"
            "`node_available`"
        } {
            assertIn $expected $normalized_text "Success JSON test failed for: $expected"
        }
    }
    
    proc test_auto_host_and_bounded_node_fallback {} {
        variable text
        variable normalized_text
        
        foreach expected {
            "tools.exec.host=auto"
            "omit both the `host` and `node` fields"
            "retry exactly once"
            "least-loaded connected paired node"
            "host=node"
            "Never replace it with"
        } {
            assertIn $expected $text "Auto host fallback test failed for: $expected"
        }
        
        assertIn "`technical_error`, `dependency_missing`, or `overloaded`" $normalized_text "Error types test failed"
        assertNotIn "host=gateway" $text "Host gateway check failed"
        assertIn "Never start a second node retry" $text "Second retry check failed"
        assertIn "never\nchange the global exec host" $text "Global exec host check failed"
        assertIn "runtime block occurs before the Node allowlist" $text "Runtime block check failed"
        assertEquals [regexp -all $::CANONICAL_COMMAND $text] 2 "Command count assertion failed"
    }
    
    proc test_public_contract_covers_legacy_and_rich_formats {} {
        variable text
        variable normalized_text
        
        set legacy "@<handle> is currently <OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.\nVLC/MPV: not available\nMethod: <validated method>"
        assertIn $legacy $text "Legacy format test failed"
        
        set live_format "@<handle> is currently LIVE on TikTok.\nTitel: <room.title>"
        assertIn $live_format $text "Live format test failed"
        
        foreach expected {
            "Stream-URLs:"
            "<label> (HLS):"
            "<label> (FLV):"
            "Live seit: <HH:MM UTC> (<Xh Ym>)"
            "exactly one URL and nothing else"
            "degrades to the legacy three lines including the `VLC/MPV:` URL"
            "No raw URL appears in plain text"
        } {
            assertIn $expected $normalized_text "Rich formats test failed for: $expected"
        }
    }
    
    proc test_existing_capabilities_are_preserved {} {
        variable text
        
        foreach capability {
            "Node" "browser" "file" "directory" "configuration"
            "dependency" "diagnostic tools remain available"
        } {
            assertIn $capability $text "Capabilities preservation test failed for: $capability"
        }
    }
    
    proc test_no_response_flag_is_documented {} {
        variable text
        
        assertNotIn "--response" $text "Response flag should not be documented"
    }
    
    proc test_atomic_output_and_synchronized_audio {} {
        variable normalized_text
        
        foreach expected {
            "send it atomically"
            "Preserve every returned URL byte-for-byte"
            "channel voice output set to `always`"
            "Do not invoke the `tts` tool"
            "do not emit `[[tts:text]]` wrappers"
            "visible text remains the authoritative source"
        } {
            assertIn $expected $normalized_text "Atomic output test failed for: $expected"
        }
    }
}

# Main execution
proc main {} {
    # Initialize test class
    SkillContractTests::setUpClass
    
    # Run all test methods
    set test_methods [info procs SkillContractTests::test_*]
    
    set passed 0
    set failed 0
    
    foreach method $test_methods {
        if {[catch {$method} error]} {
            puts "FAIL: $method - $error"
            incr failed
        } else {
            puts "PASS: $method"
            incr passed
        }
    }
    
    puts "\nTests run: [expr {$passed + $failed}], Passed: $passed, Failed: $failed"
    
    if {$failed > 0} {
        exit 1
    }
}

# Execute main if script is run directly
if {[info script] eq $argv0} {
    main
}
