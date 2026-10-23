#!/usr/bin/env tclsh
# test_peak_limiter.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of test_peak_limiter.cjs

# Load required packages
package require math::constants
package require math::statistics

# Define assertion procedures
proc assert_equal {actual expected msg} {
    if {$actual != $expected} {
        error "$msg: expected $expected but got $actual"
    }
}

proc assert_ok {condition msg} {
    if {!$condition} {
        error $msg
    }
}

proc assert_deep_equal {actual expected} {
    if {[llength $actual] != [llength $expected]} {
        error "Arrays have different lengths"
    }
    for {set i 0} {$i < [llength $actual]} {incr i} {
        if {[lindex $actual $i] != [lindex $expected $i]} {
            error "Arrays differ at index $i: [lindex $actual $i] vs [lindex $expected $i]"
        }
    }
}

# Mock the required functions from content-core.js
# These would need to be properly implemented based on the actual JS implementation
proc createPeakLimiter {rate} {
    # This is a simplified mock - actual implementation would be more complex
    set delaySamples [expr {int(0.005 * $rate)}]
    return [dict create rate $rate delaySamples $delaySamples]
}

proc limiterStrengthToDbfs {strength} {
    return [expr {-0.005 * $strength * $strength}]
}

proc process_kernel {kernel input output enabled strength} {
    # Simplified processing logic - this would need to match the actual algorithm
    set channels [llength $input]
    set length [llength [lindex $output 0]]
    
    for {set c 0} {$c < $channels} {incr c} {
        set in_chan [lindex $input $c]
        set out_chan [lindex $output $c]
        set in_len [llength $in_chan]
        
        for {set i 0} {$i < $length} {incr i} {
            set val 0
            if {$i < $in_len} {
                set val [lindex $in_chan $i]
            }
            # Apply some basic limiting logic
            if {$enabled && [expr {abs($val)} > 0.9]} {
                set val [expr {$val * 0.9 / abs($val)}]
            }
            lset output $c $i $val
        }
    }
    return $output
}

# Helper procedures
proc render {signal strength {rate 48000} {enabled true}} {
    set kernel [createPeakLimiter $rate]
    set delaySamples [dict get $kernel delaySamples]
    
    # Create output arrays with extra space for delay
    set output {}
    foreach channel $signal {
        set chan_length [llength $channel]
        set new_channel {}
        for {set i 0} {$i < [expr {$chan_length + $delaySamples}]} {incr i} {
            lappend new_channel 0.0
        }
        lappend output $new_channel
    }
    
    set total_length [llength [lindex $output 0]]
    for {set start 0} {$start < $total_length} {incr start 128} {
        set length [expr {min(128, $total_length - $start)}]
        
        # Create input block
        set input_block {}
        foreach channel $signal {
            set chan_block {}
            for {set i 0} {$i < $length} {incr i} {
                set idx [expr {$start + $i}]
                if {$idx < [llength $channel]} {
                    lappend chan_block [lindex $channel $idx]
                } else {
                    lappend chan_block 0.0
                }
            }
            lappend input_block $chan_block
        }
        
        # Create output subarray
        set output_sub {}
        foreach channel $output {
            set subarray [lrange $channel $start [expr {$start + $length - 1}]]
            lappend output_sub $subarray
        }
        
        # Process the block
        set processed [process_kernel $kernel $input_block $output_sub $enabled $strength]
        
        # Copy results back to output
        for {set c 0} {$c < [llength $output]} {incr c} {
            set proc_chan [lindex $processed $c]
            for {set i 0} {$i < [llength $proc_chan]} {incr i} {
                set global_idx [expr {$start + $i}]
                if {$global_idx < [llength [lindex $output $c]]} {
                    lset output $c $global_idx [lindex $proc_chan $i]
                }
            }
        }
    }
    
    return [list output $output delay $delaySamples]
}

proc peak {channel} {
    set max_val 0
    foreach value $channel {
        set abs_val [expr {abs($value)}]
        if {$abs_val > $max_val} {
            set max_val $abs_val
        }
    }
    return $max_val
}

proc sin_wave {length freq amplitude} {
    set result {}
    for {set i 0} {$i < $length} {incr i} {
        lappend result [expr {$amplitude * sin($i * 2 * 3.141592653589793 * $freq)}]
    }
    return $result
}

proc fill_array {length value} {
    set result {}
    for {set i 0} {$i < $length} {incr i} {
        lappend result $value
    }
    return $result
}

proc slice_array {array start end} {
    return [lrange $array $start [expr {$end - 1}]]
}

proc array_from_function {length func} {
    set result {}
    for {set i 0} {$i < $length} {incr i} {
        lappend result [eval $func $i]
    }
    return $result
}

# Test procedures
proc test_isolated_peaks {rate} {
    puts "Testing isolated and high-frequency peaks at $rate Hz"
    
    # Create signal array
    set signal [fill_array $rate 0.0]
    lset signal 1 1.0
    lset signal 127 -1.0
    
    for {set i 1000} {$i < 1100} {incr i} {
        lset signal $i [expr {sin(2 * 3.141592653589793 * 8000 * $i / $rate)}]
    }
    
    set previous 1.0
    foreach strength {25 75 100} {
        set result [render [list $signal] $strength $rate]
        set output [dict get $result output]
        set delay [dict get $result delay]
        
        set measured [peak [lindex $output 0]]
        set ceiling [expr {pow(10, [limiterStrengthToDbfs $strength] / 20)}]
        
        assert_ok [expr {$measured <= $ceiling + 1e-7}] "$measured exceeds $ceiling"
        assert_ok [expr {$measured < $previous}] "higher strength must attenuate more"
        assert_ok [expr {$delay / double($rate) <= 0.01}] ""
        
        set previous $measured
    }
}

proc test_bypass_preserves_samples {} {
    puts "Testing bypass preserves every sample"
    
    set signal {}
    for {set i 0} {$i < 10000} {incr i} {
        lappend signal [expr {sin($i * 0.7) * 0.8}]
    }
    
    set result [render [list $signal] 100 48000 false]
    set output [dict get $result output]
    set delay [dict get $result delay]
    
    set output_slice [slice_array [lindex $output 0] $delay [expr {$delay + [llength $signal]}]]
    assert_deep_equal $output_slice $signal
}

proc test_quiet_speech_band {} {
    puts "Testing quiet speech-band signal"
    
    set signal {}
    for {set i 0} {$i < 48000} {incr i} {
        lappend signal [expr {0.01 * sin($i * 2 * 3.141592653589793 * 200 / 48000)}]
    }
    
    set result [render [list $signal] 100]
    set output [dict get $result output]
    set delay [dict get $result delay]
    
    set output_slice [slice_array [lindex $output 0] $delay [expr {$delay + [llength $signal]}]]
    assert_deep_equal $output_slice $signal
}

proc test_linked_stereo_gain {} {
    puts "Testing linked stereo gain"
    
    set left [fill_array 1000 0.0]
    lset left 127 0.5
    set right [fill_array 1000 0.0]
    lset right 127 1.0
    
    set result [render [list $left $right] 100]
    set output [dict get $result output]
    set delay [dict get $result delay]
    
    set left_val [lindex [lindex $output 0] [expr {127 + $delay}]]
    set right_val [lindex [lindex $output 1] [expr {127 + $delay}]]
    
    assert_equal [expr {$left_val * 2}] $right_val "Stereo balance not preserved"
    assert_ok [expr {[peak [lindex $output 1]] <= pow(10, -30 / 20) + 1e-7}] "Channel not limited"
}

proc test_gain_recovery {} {
    puts "Testing gain recovery"
    
    set signal [fill_array 48000 0.0]
    lset signal 10 1.0
    lset signal 100 NaN
    lset signal 200 Inf
    
    for {set i 24000} {$i < [llength $signal]} {incr i} {
        lset signal $i 0.01
    }
    
    set result [render [list $signal] 100]
    set output [dict get $result output]
    
    # Check all values are finite
    foreach val [lindex $output 0] {
        if {$val != $val || $val == Inf || $val == -Inf} {  ;# NaN check and infinity check
            error "Invalid sample found: $val"
        }
    }
    
    set sample_40000 [lindex [lindex $output 0] 40000]
    assert_ok [expr {$sample_40000 > 0.00999}] "Gain did not recover"
}

proc test_empty_input_drains {} {
    puts "Testing empty input drains"
    
    set kernel [createPeakLimiter 48000]
    set block [fill_array 128 0.01]
    set out [fill_array 128 0.0]
    
    # Process initial block
    set out [process_kernel $kernel [list $block] [list $out] true 100]
    
    # Process empty blocks
    for {set n 0} {$n < 4} {incr n} {
        set out [process_kernel $kernel {} [list $out] true 100]
    }
    
    assert_equal [peak $out] 0 "Output not drained to silence"
}

# Run tests
foreach rate {44100 48000 96000} {
    test_isolated_peaks $rate
}

test_bypass_preserves_samples
test_quiet_speech_band
test_linked_stereo_gain
test_gain_recovery
test_empty_input_drains

puts "All tests passed!"
