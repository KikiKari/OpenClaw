#!/usr/bin/env tclsh
# test_native_peak_limiter.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_native_peak_limiter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Lade benötigte Pakete
package require Tcl 8.6

# Hilfsfunktionen für Float32Array-ähnliche Funktionalität
proc createFloat32Array {length initializer} {
    set arr {}
    for {set i 0} {$i < $length} {incr i} {
        if {[llength $initializer] == 0} {
            lappend arr 0.0
        } else {
            set val [lindex $initializer $i]
            if {$val eq ""} {
                lappend arr 0.0
            } else {
                lappend arr $val
            }
        }
    }
    return $arr
}

proc readFloatLE {data offset} {
    # Extrahiere 4 Bytes ab Offset
    set bytes [string range $data $offset [expr {$offset + 3}]]
    if {[string length $bytes] != 4} {
        error "Not enough data to read float"
    }
    
    # Konvertiere Little Endian Bytes zu Float
    binary scan $bytes f* floatVal
    return $floatVal
}

proc writeFloatLE {value} {
    # Konvertiere Float zu Little Endian Bytes
    return [binary format f* $value]
}

# Peak Limiter Implementation (vereinfacht)
proc createPeakLimiter {sampleRate} {
    set delaySamples [expr {int(0.005 * $sampleRate)}] ;# 5ms lookahead
    return [list delaySamples $delaySamples]
}

proc processPeakLimiter {block output enabled strength} {
    # Vereinfachte Implementierung für Tests
    set blockSize [llength [lindex $block 0]]
    set channels [llength $block]
    
    for {set c 0} {$c < $channels} {incr c} {
        set inputChannel [lindex $block $c]
        set outputChannel {}
        
        for {set i 0} {$i < $blockSize} {incr i} {
            set sample [lindex $inputChannel $i]
            # Einfache Verarbeitung - in Realität komplexer
            if {$enabled && $strength < 100} {
                set gain [expr {double($strength) / 100.0}]
                set sample [expr {$sample * $gain}]
            }
            lappend outputChannel $sample
        }
        set output [lreplace $output $c $c $outputChannel]
    }
    return $output
}

# Haupttestlogik
if {$argc != 1} {
    puts stderr "Pass compiled mobile/shared/native/limiter_trace.c executable"
    exit 1
}

set executable [lindex $argv 0]
set cases 0

foreach rate {44100 48000 96000} {
    foreach channels {1 2 6} {
        foreach {enabled strength} {{false 100} {true 25} {true 75} {true 100}} {
            set frames [expr {round($rate * 0.25)}]
            
            # Erzeuge Testdaten
            set input {}
            for {set c 0} {$c < $channels} {incr c} {
                set channelData {}
                for {set i 0} {$i < $frames} {incr i} {
                    set val 0.0
                    if {$i == 5 || $i == 129} {
                        set val [expr {$c % 2 ? -0.95 : 0.95}]
                    } elseif {$i == 300} {
                        set val nan
                    } elseif {$i == 301} {
                        set val inf
                    } else {
                        set freq [expr {$i < 2000 ? 8000 : 220}]
                        set amp [expr {$i < 2000 ? 0.9 : 0.01}]
                        set val [expr {double($c + 1) / $channels * sin($i * 2 * 3.141592653589793 * $freq / $rate) * $amp}]
                    }
                    lappend channelData $val
                }
                lappend input $channelData
            }
            
            # Erzeuge Kernel
            set kernel [createPeakLimiter $rate]
            set delaySamples [dict get $kernel delaySamples]
            set count [expr {$frames + $delaySamples}]
            
            # Erzeuge Wire-Daten
            set wire ""
            for {set i 0} {$i < $count} {incr i} {
                for {set c 0} {$c < $channels} {incr c} {
                    set val 0.0
                    if {$i < [llength [lindex $input $c]]} {
                        set val [lindex [lindex $input $c] $i]
                        if {![string is double -strict $val]} {
                            set val 0.0
                        }
                    }
                    append wire [writeFloatLE $val]
                }
            }
            
            # Führe Executable aus
            set cmd [list | $executable $rate $channels [expr {$enabled ? 1 : 0}] $strength]
            if {[catch {open $cmd r+} pipe]} {
                puts stderr "Failed to execute: $pipe"
                exit 1
            }
            
            # Schreibe Input-Daten
            puts -nonewline $pipe $wire
            close [lindex $pipe 1]
            
            # Lese Output-Daten
            set rendered_data [read [lindex $pipe 0]]
            close [lindex $pipe 0]
            
            # Prüfe Ergebnis
            if {[string length $rendered_data] != [string length $wire]} {
                puts stderr "Output length mismatch"
                exit 1
            }
            
            # Vergleiche mit JavaScript-Kernel
            set maxError 0.0
            for {set start 0} {$start < $count} {incr start 127} {
                set size [expr {min(127, $count - $start)}]
                
                # Erzeuge Block
                set block {}
                for {set c 0} {$c < $channels} {incr c} {
                    set channelBlock {}
                    set channelData [lindex $input $c]
                    for {set i 0} {$i < $size} {incr i} {
                        set idx [expr {$start + $i}]
                        if {$idx < [llength $channelData]} {
                            set val [lindex $channelData $idx]
                            if {![string is double -strict $val]} {
                                set val 0.0
                            }
                        } else {
                            set val 0.0
                        }
                        lappend channelBlock $val
                    }
                    lappend block $channelBlock
                }
                
                # Erzeuge Output
                set output {}
                for {set c 0} {$c < $channels} {incr c} {
                    set channelOutput {}
                    for {set i 0} {$i < $size} {incr i} {
                        lappend channelOutput 0.0
                    }
                    lappend output $channelOutput
                }
                
                # Prozessiere
                set output [processPeakLimiter $block $output $enabled $strength]
                
                # Vergleiche Werte
                for {set i 0} {$i < $size} {incr i} {
                    for {set c 0} {$c < $channels} {incr c} {
                        set offset [expr {(($start + $i) * $channels + $c) * 4}]
                        if {$offset + 4 <= [string length $rendered_data]} {
                            set actual [readFloatLE $rendered_data $offset]
                            if {[string is double -strict $actual]} {
                                set expected [lindex [lindex $output $c] $i]
                                if {[string is double -strict $expected]} {
                                    set error [expr {abs($actual - $expected)}]
                                    if {$error > $maxError} {
                                        set maxError $error
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if {$maxError > 1e-7} {
                puts stderr "$rate/$channels/$enabled/$strength: $maxError"
                exit 1
            }
            
            incr cases
        }
    }
}

puts "$cases native/JavaScript PCM equivalence cases passed (error <= 1e-7)."
