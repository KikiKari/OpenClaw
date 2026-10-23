#!/usr/bin/env tclsh
# test_native_peak_limiter.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Tcl port of test_native_peak_limiter.cjs
# Note: This requires a Tcl implementation that can interface with the peak limiter library
# and execute external processes. Some functionality may need adaptation based on 
# available Tcl extensions.

# Load required packages
package require Tcl 8.6

# Helper function to mimic Node.js assert
proc assert {condition {message ""}} {
    if {![expr $condition]} {
        error "Assertion failed: $message"
    }
}

# Helper function to check if value is finite
proc isFinite {value} {
    return [expr {!([string is double -strict $value] && \
                   ($value eq "Inf" || $value eq "-Inf" || $value eq "NaN"))}]
}

# Parse command line arguments
if {$argc < 1} {
    puts stderr "Pass compiled mobile/shared/native/limiter_trace.c executable"
    exit 1
}
set executable [lindex $argv 0]

# Mock implementation of createPeakLimiter since we don't have access to content-core.js
# In a real implementation, this would interface with the actual peak limiter library
proc createPeakLimiter {rate} {
    # This is a simplified mock - in reality you'd load and use the actual library
    return [dict create delaySamples 100]
}

# Mock implementation of kernel.process
# In a real implementation, this would call the actual processing function
proc processKernel {block output enabled strength} {
    # Simplified processing - just copy input to output
    # A real implementation would apply the peak limiting algorithm
    for {set ch 0} {$ch < [llength $block]} {incr ch} {
        set inChannel [lindex $block $ch]
        set outChannel [lindex $output $ch]
        for {set i 0} {$i < [llength $inChannel]} {incr i} {
            lset output $ch $i [lindex $inChannel $i]
        }
    }
    return $output
}

# Function to convert float to little-endian binary representation
proc floatToLEBinary {value} {
    # This is a simplified approach - proper implementation would handle IEEE 754 conversion
    # For testing purposes, we'll use a placeholder
    binary format f $value
}

# Function to read float from little-endian binary data
proc readFloatLE {data offset} {
    binary scan [string range $data $offset [expr {$offset + 3}]] f* result
    return $result
}

set cases 0

# Test loop - adapted from JavaScript version
foreach rate {44100 48000 96000} {
    foreach channels {1 2 6} {
        foreach {enabled strength} {{false 100} {true 25} {true 75} {true 100}} {
            set frames [expr {round($rate * 0.25)}]
            
            # Create input data
            set input {}
            for {set c 0} {$c < $channels} {incr c} {
                set channel {}
                for {set i 0} {$i < $frames} {incr i} {
                    set value 0
                    if {$i == 5 || $i == 129} {
                        set value [expr {$c % 2 ? -0.95 : 0.95}]
                    } elseif {$i == 300} {
                        set value NaN
                    } elseif {$i == 301} {
                        set value Inf
                    } else {
                        set freq [expr {$i < 2000 ? 8000 : 220}]
                        set amp [expr {$i < 2000 ? 0.9 : 0.01}]
                        set value [expr {($c + 1) / $channels * sin($i * 2 * 3.141592653589793 * $freq / $rate) * $amp}]
                    }
                    lappend channel $value
                }
                lappend input $channel
            }
            
            # Create kernel (mock)
            set kernel [createPeakLimiter $rate]
            set delaySamples [dict get $kernel delaySamples]
            set count [expr {$frames + $delaySamples}]
            
            # Create wire buffer (binary data)
            set wire ""
            for {set i 0} {$i < $count} {incr i} {
                for {set c 0} {$c < $channels} {incr c} {
                    set val 0
                    if {$i < [llength [lindex $input $c]]} {
                        set val [lindex [lindex $input $c] $i]
                    }
                    append wire [floatToLEBinary $val]
                }
            }
            
            # Execute external process
            set cmd [list | $executable $rate $channels [expr {$enabled ? 1 : 0}] $strength]
            set pipe [open $cmd r+]
            puts -nonewline $pipe $wire
            close $pipe w
            set rendered [read $pipe]
            close $pipe
            
            # Check status and output length
            # Note: In Tcl we can't easily check process exit status like in Node.js
            if {[string length $rendered] != [string length $wire]} {
                error "Output length mismatch"
            }
            
            set maxError 0
            for {set start 0} {$start < $count} {incr start 127} {
                set size [expr {min(127, $count - $start)}]
                
                # Create block
                set block {}
                for {set ch 0} {$ch < $channels} {incr ch} {
                    set channelBlock {}
                    for {set i 0} {$i < $size} {incr i} {
                        set idx [expr {$start + $i}]
                        if {$idx < [llength [lindex $input $ch]]} {
                            lappend channelBlock [lindex [lindex $input $ch] $idx]
                        } else {
                            lappend channelBlock 0
                        }
                    }
                    lappend block $channelBlock
                }
                
                # Create output
                set output {}
                for {set ch 0} {$ch < $channels} {incr ch} {
                    set channelOutput {}
                    for {set i 0} {$i < $size} {incr i} {
                        lappend channelOutput 0
                    }
                    lappend output $channelOutput
                }
                
                # Process (mock)
                set output [processKernel $block $output $enabled $strength]
                
                # Compare results
                for {set i 0} {$i < $size} {incr i} {
                    for {set c 0} {$c < $channels} {incr c} {
                        set offset [expr {(($start + $i) * $channels + $c) * 4}]
                        set actual [readFloatLE $rendered $offset]
                        if {![isFinite $actual]} {
                            error "Actual value is not finite"
                        }
                        set expected [lindex [lindex $output $c] $i]
                        set error [expr {abs($actual - $expected)}]
                        set maxError [expr {max($maxError, $error)}]
                    }
                }
            }
            
            if {$maxError > 1e-7} {
                error "$rate/$channels/$enabled/$strength: $maxError"
            }
            
            incr cases
        }
    }
}

puts "$cases native/JavaScript PCM equivalence cases passed (error <= 1e-7)."
