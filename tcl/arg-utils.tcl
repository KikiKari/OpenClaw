#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "a36eccefece5629e3f3c69f6ae67d1c715d69126da57139e2d59f097b6853521", "source_sha256": "a1a384d35f3380f69c57a009348f8a076cc5e3fc09ba866cde4cf59a1c6ac88b", "target_language": "tcl"}
# arg-utils.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/arg-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Tcl does not have a direct equivalent to JavaScript modules with exports.
# We will define procedures that can be sourced into other scripts.
# The behavior and logic are preserved as closely as possible.

proc readEnvNumber {name {envDict ""}} {
    # In Tcl, we don't have process.env directly, so we expect an array or dict
    # If envDict is empty, we'll try to get from global environment
    if {$envDict eq ""} {
        if {[info exists ::env($name)]} {
            set raw [string trim $::env($name)]
        } else {
            return ""
        }
    } else {
        if {[dict exists $envDict $name]} {
            set raw [string trim [dict get $envDict $name]]
        } else {
            return ""
        }
    }

    if {$raw eq ""} {
        return ""
    }

    if {[string is double -strict $raw]} {
        set parsed [expr {double($raw)}]
        if {$parsed != "" && $parsed ne "Inf" && $parsed ne "-Inf"} {
            return $parsed
        } else {
            return ""
        }
    } else {
        return ""
    }
}

proc consumeStringFlag {argv index flag currentValue} {
    upvar $argv argvList
    if {$index >= [llength $argvList] || [lindex $argvList $index] ne $flag} {
        return ""
    }

    set nextIndex [expr {$index + 1}]
    set value $currentValue
    if {$nextIndex < [llength $argvList]} {
        set value [lindex $argvList $nextIndex]
    }

    # Return dict with keys: nextIndex, value
    return [list nextIndex $nextIndex value $value]
}

proc consumeStringListFlag {argv index flag} {
    upvar $argv argvList
    if {$index >= [llength $argvList] || [lindex $argvList $index] ne $flag} {
        return ""
    }

    set nextIndex [expr {$index + 1}]
    set value ""
    if {$nextIndex < [llength $argvList]} {
        set valCandidate [lindex $argvList $nextIndex]
        if {$valCandidate ne ""} {
            set value $valCandidate
        }
    }

    return [list nextIndex $nextIndex value $value]
}

proc consumeIntFlag {argv index flag currentValue {optionsDict ""}} {
    upvar $argv argvList
    if {$index >= [llength $argvList] || [lindex $argvList $index] ne $flag} {
        return ""
    }

    set nextIndex [expr {$index + 1}]
    set rawValue ""
    if {$nextIndex < [llength $argvList]} {
        set rawValue [lindex $argvList $nextIndex]
    }

    set min [expr {[dict exists $optionsDict min] ? [dict get $optionsDict min] : "-9223372036854775808"}]

    if {$rawValue eq "" || ![string is integer -strict $rawValue]} {
        return [list nextIndex $nextIndex value $currentValue]
    }

    set parsed [expr {wide($rawValue)}]
    if {$parsed >= $min} {
        return [list nextIndex $nextIndex value $parsed]
    } else {
        return [list nextIndex $nextIndex value $currentValue]
    }
}

proc consumeFloatFlag {argv index flag currentValue {optionsDict ""}} {
    upvar $argv argvList
    if {$index >= [llength $argvList] || [lindex $argvList $index] ne $flag} {
        return ""
    }

    set nextIndex [expr {$index + 1}]
    set rawValue ""
    if {$nextIndex < [llength $argvList]} {
        set rawValue [lindex $argvList $nextIndex]
    }

    set min [expr {[dict exists $optionsDict min] ? [dict get $optionsDict min] : "-Inf"}]
    set includeMin [expr {[dict exists $optionsDict includeMin] ? [dict get $optionsDict includeMin] : 1}]

    if {$rawValue eq "" || ![string is double -strict $rawValue]} {
        return [list nextIndex $nextIndex value $currentValue]
    }

    set parsed [expr {double($rawValue)}]
    set isValid 0

    if {$includeMin} {
        if {$parsed >= $min && $parsed ne "Inf" && $parsed ne "-Inf"} {
            set isValid 1
        }
    } else {
        if {$parsed > $min && $parsed ne "Inf" && $parsed ne "-Inf"} {
            set isValid 1
        }
    }

    if {$isValid} {
        return [list nextIndex $nextIndex value $parsed]
    } else {
        return [list nextIndex $nextIndex value $currentValue]
    }
}

proc stringFlag {flag key} {
    # Returns a dictionary representing the spec
    return [list type stringFlag flag $flag key $key]
}

proc stringListFlag {flag key} {
    return [list type stringListFlag flag $flag key $key]
}

proc createAssignedValueFlag {consumeProc} {
    return [list type customFlag consumeProc $consumeProc]
}

proc intFlag {flag key {optionsDict ""}} {
    set consumer "intFlagConsumer_$flag\[$key\]"
    proc $consumer {argv index currentValue optionsDict flag key} {
        upvar $argv argvList
        set result [consumeIntFlag argvList $index $flag $currentValue $optionsDict]
        if {$result ne ""} {
            dict set result key $key
        }
        return $result
    }
    return [list type assignedValueFlag consumer $consumer flag $flag key $key options $optionsDict]
}

proc floatFlag {flag key {optionsDict ""}} {
    set consumer "floatFlagConsumer_$flag\[$key\]"
    proc $consumer {argv index currentValue optionsDict flag key} {
        upvar $argv argvList
        set result [consumeFloatFlag argvList $index $flag $currentValue $optionsDict]
        if {$result ne ""} {
            dict set result key $key
        }
        return $result
    }
    return [list type assignedValueFlag consumer $consumer flag $flag key $key options $optionsDict]
}

proc booleanFlag {flag key {value 1}} {
    return [list type booleanFlag flag $flag key $key boolValue $value]
}

proc parseFlagArgs {argvVar argsVar specsList {optionsDict ""}} {
    upvar $argvVar argvList
    upvar $argsVar argsDict
    
    for {set i 0} {$i < [llength $argvList]} {incr i} {
        set arg [lindex $argvList $i]
        
        if {$arg eq "--" && [dict exists $optionsDict ignoreDoubleDash] && [dict get $optionsDict ignoreDoubleDash]} {
            continue
        }
        
        set handled 0
        foreach spec $specsList {
            set specType [dict get $spec type]
            
            switch -- $specType {
                stringFlag {
                    set flag [dict get $spec flag]
                    set key [dict get $spec key]
                    set currentValue [expr {[dict exists $argsDict $key] ? [dict get $argsDict $key] : ""}]
                    set option [consumeStringFlag argvList $i $flag $currentValue]
                    
                    if {$option ne ""} {
                        set newValue [dict get $option value]
                        dict set argsDict $key $newValue
                        set i [dict get $option nextIndex]
                        set handled 1
                        break
                    }
                }
                
                stringListFlag {
                    set flag [dict get $spec flag]
                    set key [dict get $spec key]
                    set option [consumeStringListFlag argvList $i $flag]
                    
                    if {$option ne ""} {
                        set newValue [dict get $option value]
                        if {$newValue ne ""} {
                            if {![dict exists $argsDict $key]} {
                                dict set argsDict $key {}
                            }
                            set currentList [dict get $argsDict $key]
                            lappend currentList $newValue
                            dict set argsDict $key $currentList
                        }
                        set i [dict get $option nextIndex]
                        set handled 1
                        break
                    }
                }
                
                assignedValueFlag {
                    set consumer [dict get $spec consumer]
                    set flag [dict get $spec flag]
                    set key [dict get $spec key]
                    set options [dict get $spec options]
                    set currentValue [expr {[dict exists $argsDict $key] ? [dict get $argsDict $key] : ""}]
                    
                    set option [$consumer argvList $i $currentValue $options $flag $key]
                    
                    if {$option ne ""} {
                        set newValue [dict get $option value]
                        dict set argsDict [dict get $option key] $newValue
                        set i [dict get $option nextIndex]
                        set handled 1
                        break
                    }
                }
                
                booleanFlag {
                    set flag [dict get $spec flag]
                    if {$arg eq $flag} {
                        set key [dict get $spec key]
                        set boolValue [dict get $spec boolValue]
                        dict set argsDict $key $boolValue
                        set handled 1
                        break
                    }
                }
                
                default {
                    error "Unknown spec type: $specType"
                }
            }
        }
        
        if {$handled} {
            continue
        }
        
        if {[dict exists $optionsDict onUnhandledArg]} {
            set callback [dict get $optionsDict onUnhandledArg]
            set fallbackResult [$callback $arg argsDict]
            if {$fallbackResult eq "handled"} {
                continue
            }
        }
        
        set allowUnknownOptions [expr {[dict exists $optionsDict allowUnknownOptions] ? [dict get $optionsDict allowUnknownOptions] : 0}]
        if {!$allowUnknownOptions && [string index $arg 0] eq "-" && $arg ne "--"} {
            error "Unknown option: $arg"
        }
    }
    
    return $argsDict
}
