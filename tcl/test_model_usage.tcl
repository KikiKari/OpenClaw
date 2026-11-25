#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "f03c807e3f9ad84fd750dc17ae089cad33a9c4530e54453bc9966b53c4e34a53", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "tcl"}
# test_model_usage.py — portiert nach tcl
# Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Tests for model_usage helpers.

# Load the model_usage.tcl file
source [file join [file dirname [info script]] model_usage.tcl]

# Simple test framework
proc assertEqual {actual expected msg} {
    if {$actual != $expected} {
        error "Assertion failed: $msg\nExpected: $expected\nActual: $actual"
    }
}

proc assertRaises {func args} {
    if {[catch {eval $func $args} result]} {
        return $result
    } else {
        error "Assertion failed: Expected exception was not raised"
    }
}

# Test functions
proc test_positive_int_accepts_valid_numbers {} {
    set result [positive_int "1"]
    assertEqual $result 1 "positive_int should return 1 for input '1'"
    
    set result [positive_int "7"]
    assertEqual $result 7 "positive_int should return 7 for input '7'"
}

proc test_positive_int_rejects_zero_and_negative {} {
    # Test zero
    if {![catch {positive_int "0"} result]} {
        error "Assertion failed: positive_int should raise error for input '0'"
    }
    
    # Test negative
    if {![catch {positive_int "-3"} result]} {
        error "Assertion failed: positive_int should raise error for input '-3'"
    }
}

proc test_filter_by_days_keeps_recent_entries {} {
    # Calculate dates
    set today [clock seconds]
    set date_5_days_ago [clock format [clock add $today -5 days] -format "%Y-%m-%d"]
    set date_1_day_ago [clock format [clock add $today -1 days] -format "%Y-%m-%d"]
    set today_str [clock format $today -format "%Y-%m-%d"]
    
    # Create test entries
    set entries [list \
        [dict create date $date_5_days_ago modelBreakdowns [list]] \
        [dict create date $date_1_day_ago modelBreakdowns [list]] \
        [dict create date $today_str modelBreakdowns [list]] \
    ]
    
    # Filter entries
    set filtered [filter_by_days $entries 2]
    
    # Check results
    if {[llength $filtered] != 2} {
        error "Assertion failed: Expected 2 entries, got [llength $filtered]"
    }
    
    set first_date [dict get [lindex $filtered 0] date]
    set second_date [dict get [lindex $filtered 1] date]
    
    set expected_first_date $date_1_day_ago
    set expected_second_date $today_str
    
    if {$first_date ne $expected_first_date} {
        error "Assertion failed: First entry date mismatch\nExpected: $expected_first_date\nActual: $first_date"
    }
    
    if {$second_date ne $expected_second_date} {
        error "Assertion failed: Second entry date mismatch\nExpected: $expected_second_date\nActual: $second_date"
    }
}

# Run tests
if {[info script] eq $argv0} {
    puts "Running tests..."
    
    test_positive_int_accepts_valid_numbers
    puts "test_positive_int_accepts_valid_numbers passed"
    
    test_positive_int_rejects_zero_and_negative
    puts "test_positive_int_rejects_zero_and_negative passed"
    
    test_filter_by_days_keeps_recent_entries
    puts "test_filter_by_days_keeps_recent_entries passed"
    
    puts "All tests passed!"
}
