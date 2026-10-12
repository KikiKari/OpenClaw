#!/usr/bin/env tclsh
# test_peak_limiter.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_peak_limiter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Load required packages
package require mathfunc
package require math

# Define helper functions
proc assert_equal {a b} {
    if {$a != $b} {
        error "Assertion failed: $a != $b"
    }
}

proc assert_ok {condition msg} {
    if {![expr $condition]} {
        error "Assertion failed: $msg"
    }
}

proc assert_deep_equal {a b} {
    if {$a ne $b} {
        error "Assertion failed: arrays not equal"
    }
}

proc max {args} {
    set max_val [lindex $args 0]
    foreach val $args {
        if {$val > $max_val} {
            set max_val $val
        }
    }
    return $max_val
}

proc abs {x} {
    return [expr {abs($x)}]
}

proc sin {x} {
    return [expr {sin($x)}]
}

proc pi {} {
    return [expr {acos(-1)}]
}

proc float32_array {size} {
    set arr {}
    for {set i 0} {$i < $size} {incr i} {
        lappend arr 0.0
    }
    return $arr
}

proc float32_array_from_length {len func} {
    set arr {}
    for {set i 0} {$i < $len} {incr i} {
        lappend arr [eval $func $i]
    }
    return $arr
}

proc subarray {arr start end} {
    return [lrange $arr $start [expr {$end - 1}]]
}

proc array_reduce {arr func initial} {
    set result $initial
    foreach item $arr {
        set result [eval $func $result $item]
    }
    return $result
}

proc peak {channel} {
    return [array_reduce $channel {expr {max($arg1, abs($arg2))}} 0]
}

proc dbfs {strength} {
    return [expr {-0.005 * $strength * $strength}]
}

proc create_peak_limiter {rate} {
    set attackTime 0.001
    set releaseTime 0.1
    set delaySamples [expr {int(0.001 * $rate)}]
    
    # Initialize state variables
    set state [dict create]
    dict set state attackCoeff [expr {exp(-1.0 / ($rate * $attackTime))}]
    dict set state releaseCoeff [expr {exp(-1.0 / ($rate * $releaseTime))}]
    dict set state envelope 0.0
    dict set state delayBuffer {}
    dict set state delaySamples $delaySamples
    dict set state sampleRate $rate
    
    # Initialize delay buffer
    for {set i 0} {$i < $delaySamples} {incr i} {
        dict lappend state delayBuffer 0.0
    }
    
    return $state
}

proc process_kernel {kernel_ref input output enabled strength} {
    upvar $kernel_ref kernel
    
    set attackCoeff [dict get $kernel attackCoeff]
    set releaseCoeff [dict get $kernel releaseCoeff]
    set envelope [dict get $kernel envelope]
    set delayBuffer [dict get $kernel delayBuffer]
    
    set inputLength [llength [lindex $input 0]]
    set numChannels [llength $input]
    
    # Calculate target ceiling from strength
    set dbfsValue [dbfs $strength]
    set ceiling [expr {pow(10, $dbfsValue / 20)}]
    
    # Process each sample
    for {set i 0} {$i < $inputLength} {incr i} {
        # Get maximum absolute value across all channels
        set maxValue 0.0
        for {set ch 0} {$ch < $numChannels} {incr ch} {
            set val [expr {abs([lindex [lindex $input $ch] $i])}]
            if {$val > $maxValue} {
                set maxValue $val
            }
        }
        
        # Update envelope
        if {$maxValue > $envelope} {
            set envelope [expr {$attackCoeff * $envelope + (1 - $attackCoeff) * $maxValue}]
        } else {
            set envelope [expr {$releaseCoeff * $envelope + (1 - $releaseCoeff) * $maxValue}]
        }
        
        # Calculate gain
        set gain 1.0
        if {$enabled && $envelope > $ceiling} {
            set gain [expr {$ceiling / $envelope}]
        }
        
        # Apply delay and gain to each channel
        for {set ch 0} {$ch < $numChannels} {incr ch} {
            # Add input to delay buffer
            dict lappend delayBuffer [lindex [lindex $input $ch] $i]
            
            # Get delayed sample
            set delayedSample [lindex $delayBuffer 0]
            set delayBuffer [lrange $delayBuffer 1 end]
            
            # Apply gain
            set outputSample [expr {$delayedSample * $gain}]
            
            # Store in output
            set outputChannel [lindex $output $ch]
            lset outputChannel $i $outputSample
            set output [lreplace $output $ch $ch $outputChannel]
        }
    }
    
    # Update kernel state
    dict set kernel envelope $envelope
    dict set kernel delayBuffer $delayBuffer
    
    return $kernel
}

proc render {signal strength {rate 48000} {enabled true}} {
    set kernel [create_peak_limiter $rate]
    set delaySamples [dict get $kernel delaySamples]
    
    # Create output arrays with padding for delay
    set output {}
    foreach channel $signal {
        set paddedChannel {}
        for {set i 0} {$i < [expr {[llength $channel] + $delaySamples}]} {incr i} {
            lappend paddedChannel 0.0
        }
        lappend output $paddedChannel
    }
    
    # Process in blocks of 128 samples
    set totalLength [llength [lindex $output 0]]
    for {set start 0} {$start < $totalLength} {incr start 128} {
        set length [expr {min(128, $totalLength - $start)}]
        
        # Prepare input block
        set inputBlock {}
        foreach channel $signal {
            set block {}
            for {set i 0} {$i < $length} {incr i} {
                set idx [expr {$start + $i}]
                if {$idx < [llength $channel]} {
                    lappend block [lindex $channel $idx]
                } else {
                    lappend block 0.0
                }
            }
            lappend inputBlock $block
        }
        
        # Prepare output block
        set outputBlock {}
        foreach channel $output {
            lappend outputBlock [subarray $channel $start [expr {$start + $length}]]
        }
        
        # Process block
        set kernel [process_kernel kernel $inputBlock $outputBlock $enabled $strength]
        
        # Copy processed block back to output
        set chIdx 0
        foreach channel $outputBlock {
            set outputChannel [lindex $output $chIdx]
            set i 0
            foreach sample $channel {
                set fullIdx [expr {$start + $i}]
                if {$fullIdx < [llength $outputChannel]} {
                    lset outputChannel $fullIdx $sample
                }
                incr i
            }
            set output [lreplace $output $chIdx $chIdx $outputChannel]
            incr chIdx
        }
    }
    
    return [list output $output delay $delaySamples]
}

# Test cases
proc run_tests {} {
    # Test isolated and high-frequency peaks are bounded
    foreach rate {44100 48000 96000} {
        puts "Testing peaks bounded at $rate Hz"
        
        # Create test signal
        set signal {}
        for {set i 0} {$i < $rate} {incr i} {
            lappend signal 0.0
        }
        lset signal 1 1.0
        lset signal 127 -1.0
        
        for {set i 1000} {$i < 1100} {incr i} {
            set val [expr {sin(2 * [pi] * 8000 * $i / $rate)}]
            lset signal $i $val
        }
        
        set previous 1.0
        foreach strength {25 75 100} {
            set result [render [list $signal] $strength $rate]
            set output [dict get $result output]
            set delay [dict get $result delay]
            
            set measured [peak [lindex $output 0]]
            set dbfsValue [dbfs $strength]
            set ceiling [expr {pow(10, $dbfsValue / 20)}]
            
            assert_ok {$measured <= $ceiling + 1e-7} "$measured exceeds $ceiling"
            assert_ok {$measured < $previous} "higher strength must attenuate more"
            assert_ok {[expr {$delay / double($rate)}] <= 0.01} ""
            
            set previous $measured
        }
    }
    
    # Test bypass preserves every sample
    puts "Testing bypass preserves samples"
    set signal {}
    for {set i 0} {$i < 10000} {incr i} {
        lappend signal [expr {sin($i * 0.7) * 0.8}]
    }
    
    set result [render [list $signal] 100 48000 false]
    set output [dict get $result output]
    set delay [dict get $result delay]
    
    set delayedSignal [subarray [lindex $output 0] $delay [expr {$delay + [llength $signal]}]]
    assert_deep_equal $delayedSignal $signal
    
    # Test quiet speech-band signal is not permanently attenuated
    puts "Testing quiet speech preservation"
    set signal {}
    for {set i 0} {$i < 48000} {incr i} {
        lappend signal [expr {0.01 * sin($i * 2 * [pi] * 200 / 48000)}]
    }
    
    set result [render [list $signal] 100]
    set output [dict get $result output]
    set delay [dict get $result delay]
    
    set delayedSignal [subarray [lindex $output 0] $delay [expr {$delay + [llength $signal]}]]
    assert_deep_equal $delayedSignal $signal
    
    # Test linked stereo gain preserves balance
    puts "Testing stereo gain balance"
    set left {}
    set right {}
    for {set i 0} {$i < 1000} {incr i} {
        lappend left 0.0
        lappend right 0.0
    }
    lset left 127 0.5
    lset right 127 1.0
    
    set result [render [list $left $right] 100]
    set output [dict get $result output]
    set delay [dict get $result delay]
    
    set leftVal [lindex [lindex $output 0] [expr {127 + $delay}]]
    set rightVal [lindex [lindex $output 1] [expr {127 + $delay}]]
    
    assert_equal [expr {$leftVal * 2}] $rightVal
    
    set rightPeak [peak [lindex $output 1]]
    set threshold [expr {pow(10, -30 / 20) + 1e-7}]
    assert_ok {$rightPeak <= $threshold} ""
    
    # Test gain recovery and NaN handling
    puts "Testing gain recovery and NaN handling"
    set signal {}
    for {set i 0} {$i < 48000} {incr i} {
        lappend signal 0.0
    }
    lset signal 10 1.0
    lset signal 100 nan
    lset signal 200 inf
    for {set i 24000} {$i < [llength $signal]} {incr i} {
        lset signal $i 0.01
    }
    
    set result [render [list $signal] 100]
    set output [dict get $result output]
    
    # Check no infinite values
    set hasInf false
    foreach sample [lindex $output 0] {
        if {[expr {!isfinite($sample)}]} {
            set hasInf true
            break
        }
    }
    assert_equal $hasInf false
    
    # Check recovery at end
    set lastSample [lindex [lindex $output 0] 40000]
    assert_ok {$lastSample > 0.00999} ""
    
    # Test empty input drains delay
    puts "Testing empty input drain"
    set kernel [create_peak_limiter 48000]
    set block {}
    for {set i 0} {$i < 128} {incr i} {
        lappend block 0.01
    }
    set out {}
    for {set i 0} {$i < 128} {incr i} {
        lappend out 0.0
    }
    
    set kernel [process_kernel kernel [list $block] [list $out] true 100]
    
    for {set n 0} {$n < 4} {incr n} {
        set kernel [process_kernel kernel {} [list $out] true 100]
    }
    
    set outPeak [peak $out]
    assert_equal $outPeak 0.0
    
    puts "All tests passed!"
}

# Run the tests
run_tests
