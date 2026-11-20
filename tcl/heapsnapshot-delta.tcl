#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "f763dfec033e498aea2dd0e8dc32f687cb87601249eaecf79a774019b05c51a1", "source_sha256": "d38a1b483644fdcb8d1b3d4826eb7c89f54ac769bf87debab3ab554e0544844f", "target_language": "tcl"}
# heapsnapshot-delta.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/.agents/skills/openclaw-test-heap-leaks/scripts/heapsnapshot-delta.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

proc printUsage {} {
    puts stderr "Usage: tclsh heapsnapshot-delta.tcl <before.heapsnapshot> <after.heapsnapshot> \[--top N\] \[--min-kb N\]"
    puts stderr "   or: tclsh heapsnapshot-delta.tcl --lane-dir <dir> \[--pid PID\] \[--top N\] \[--min-kb N\]"
}

proc fail {message} {
    puts stderr $message
    exit 1
}

proc parseArgs {argv} {
    set options [dict create \
        top 30 \
        minKb 64 \
        laneDir {} \
        pid {} \
        files {} \
    ]

    set index 0
    set argc [llength $argv]
    while {$index < $argc} {
        set arg [lindex $argv $index]
        if {$arg eq "--top"} {
            dict set options top [expr int([lindex $argv [incr index]])]
            incr index
            continue
        }
        if {$arg eq "--min-kb"} {
            dict set options minKb [expr int([lindex $argv [incr index]])]
            incr index
            continue
        }
        if {$arg eq "--lane-dir"} {
            dict set options laneDir [lindex $argv [incr index]]
            incr index
            continue
        }
        if {$arg eq "--pid"} {
            dict set options pid [expr int([lindex $argv [incr index]])]
            incr index
            continue
        }
        dict lappend options files $arg
        incr index
    }

    set top [dict get $options top]
    set minKb [dict get $options minKb]
    set pid [dict get $options pid]

    if {![string is integer -strict $top] || $top <= 0} {
        fail "--top must be a positive integer"
    }
    if {![string is integer -strict $minKb] || $minKb < 0} {
        fail "--min-kb must be a non-negative integer"
    }
    if {$pid ne {} && (![string is integer -strict $pid] || $pid <= 0)} {
        fail "--pid must be a positive integer"
    }

    return $options
}

oo::class create JsonStreamScanner {
    variable stream buffer offset done
    
    constructor {filePath} {
        set stream [open $filePath r]
        fconfigure $stream -encoding utf-8 -buffering full -buffersize 1048576
        set buffer ""
        set offset 0
        set done false
    }
    
    method destroy {} {
        if {[info exists stream]} {
            close $stream
        }
        next
    }
    
    method compactBuffer {} {
        if {$offset > 65536} {
            set buffer [string range $buffer $offset end]
            set offset 0
        }
    }
    
    method ensureAvailable {{count 1}} {
        while {!$done && [string length $buffer] - $offset < $count} {
            if {[catch {gets $stream line} result] || $result == -1} {
                set done true
                break
            }
            append buffer $line\n
        }
    }
    
    method peek {} {
        my ensureAvailable 1
        if {$offset >= [string length $buffer]} {
            return {}
        }
        return [string index $buffer $offset]
    }
    
    method next {} {
        my ensureAvailable 1
        if {$offset >= [string length $buffer]} {
            return {}
        }
        set char [string index $buffer $offset]
        incr offset
        my compactBuffer
        return $char
    }
    
    method skipWhitespace {} {
        while {true} {
            set char [my peek]
            if {$char eq {} || ![regexp {\s} $char]} {
                return
            }
            my next
        }
    }
    
    method expectChar {expected} {
        set char [my next]
        if {$char ne $expected} {
            fail "Expected $expected but found [expr {$char eq {} ? "<eof>" : $char}]"
        }
    }
    
    method find {sequence} {
        set matched 0
        while {true} {
            set char [my next]
            if {$char eq {}} {
                fail "Could not find $sequence"
            }
            if {$char eq [string index $sequence $matched]} {
                incr matched
                if {$matched == [string length $sequence]} {
                    return
                }
                continue
            }
            set matched [expr {$char eq [string index $sequence 0] ? 1 : 0}]
            if {$matched == [string length $sequence]} {
                return
            }
        }
    }
    
    method readBalancedObject {} {
        set start [my next]
        if {$start ne "\{"} {
            fail "Expected \{ but found [expr {$start eq {} ? "<eof>" : $start}]"
        }
        set text "\{"
        set depth 1
        set inString false
        set escaped false
        while {$depth > 0} {
            set char [my next]
            if {$char eq {}} {
                fail "Unexpected EOF while reading JSON object"
            }
            append text $char
            if {$inString} {
                if {$escaped} {
                    set escaped false
                } elseif {$char eq "\\"} {
                    set escaped true
                } elseif {$char eq "\""} {
                    set inString false
                }
                continue
            }
            if {$char eq "\""} {
                set inString true
            } elseif {$char eq "\{"} {
                incr depth
            } elseif {$char eq "\}"} {
                incr depth -1
            }
        }
        return $text
    }
    
    method parseNumberArray {onValue} {
        my skipWhitespace
        my expectChar "\["
        my skipWhitespace
        if {[my peek] eq "\]"} {
            my next
            return
        }

        set token ""
        set index 0
        set flushProc [list apply {{scanner token index onValue} {
            upvar 1 token token
            upvar 1 index index
            if {[string length $token] == 0} {
                fail "Unexpected empty number token"
            }
            set value [expr int($token)]
            if {![string is integer -strict $value]} {
                fail "Invalid numeric token: $token"
            }
            {*}$onValue $value $index
            incr index
            set token ""
        }} $this]
        
        while {true} {
            set char [my next]
            if {$char eq {}} {
                fail "Unexpected EOF while reading number array"
            }
            if {$char eq "\]"} {
                $flushProc $token $index $onValue
                return
            }
            if {$char eq ","} {
                $flushProc $token $index $onValue
                continue
            }
            if {[regexp {\s} $char]} {
                continue
            }
            append token $char
        }
    }
    
    method readJsonString {} {
        my expectChar "\""
        set value ""
        while {true} {
            set char [my next]
            if {$char eq {}} {
                fail "Unexpected EOF while reading JSON string"
            }
            if {$char eq "\""} {
                return $value
            }
            if {$char ne "\\"} {
                append value $char
                continue
            }
            set escaped [my next]
            if {$escaped eq {}} {
                fail "Unexpected EOF while reading JSON string escape"
            }
            if {$escaped eq "u"} {
                set hex ""
                for {set i 0} {$i < 4} {incr i} {
                    set hexChar [my next]
                    if {$hexChar eq {}} {
                        fail "Unexpected EOF while reading JSON unicode escape"
                    }
                    append hex $hexChar
                }
                append value [format %c [scan $hex %x]]
                continue
            }
            append value [expr {
                $escaped eq "b" ? "\b" :
                $escaped eq "f" ? "\f" :
                $escaped eq "n" ? "\n" :
                $escaped eq "r" ? "\r" :
                $escaped eq "t" ? "\t" :
                $escaped
            }]
        }
    }
    
    method parseStringArray {onValue} {
        my skipWhitespace
        my expectChar "\["
        my skipWhitespace
        if {[my peek] eq "\]"} {
            my next
            return
        }

        set index 0
        while {true} {
            set value [my readJsonString]
            {*}$onValue $value $index
            incr index
            my skipWhitespace
            set separator [my next]
            if {$separator eq "\]"} {
                return
            }
            if {$separator ne ","} {
                fail "Expected , or \] but found [expr {$separator eq {} ? "<eof>" : $separator}]"
            }
            my skipWhitespace
        }
    }
}

proc parseHeapFilename {filePath} {
    set base [file tail $filePath]
    if {![regexp {^Heap\.(\d{8}\.\d{6})\.(\d+)\.0\.(\d+)\.heapsnapshot$} $base -> stamp pid seq]} {
        return {}
    }
    return [dict create \
        filePath $filePath \
        pid [expr int($pid)] \
        stamp $stamp \
        sequence [expr int($seq)] \
    ]
}

proc resolvePair {options} {
    set laneDir [dict get $options laneDir]
    if {$laneDir ne {}} {
        set entries {}
        foreach name [glob -directory $laneDir -nocomplain *] {
            set entry [parseHeapFilename $name]
            if {$entry ne {}} {
                set pid [dict get $entry pid]
                set pidFilter [dict get $options pid]
                if {$pidFilter eq {} || $pid == $pidFilter} {
                    lappend entries $entry
                }
            }
        }
        
        set sortedEntries [lsort -command {
            apply {{left right} {
                set leftPid [dict get $left pid]
                set rightPid [dict get $right pid]
                if {$leftPid != $rightPid} {
                    return [expr {$leftPid - $rightPid}]
                }
                set leftStamp [dict get $left stamp]
                set rightStamp [dict get $right stamp]
                set stampCmp [string compare $leftStamp $rightStamp]
                if {$stampCmp != 0} {
                    return $stampCmp
                }
                set leftSeq [dict get $left sequence]
                set rightSeq [dict get $right sequence]
                return [expr {$leftSeq - $rightSeq}]
            }}
        } $entries]
        
        if {[llength $sortedEntries] == 0} {
            fail "No matching heap snapshots found in $laneDir"
        }
        
        set groups [dict create]
        foreach entry $sortedEntries {
            set pid [dict get $entry pid]
            if {![dict exists $groups $pid]} {
                dict set groups $pid {}
            }
            dict lappend groups $pid $entry
        }
        
        set candidates {}
        dict for {pid group} $groups {
            if {[llength $group] >= 2} {
                lappend candidates [dict create \
                    pid $pid \
                    before [lindex $group 0] \
                    after [lindex $group end] \
                    count [llength $group] \
                ]
            }
        }
        
        if {[llength $candidates] == 0} {
            fail "Need at least two snapshots for one PID in $laneDir"
        }
        
        set pidFilter [dict get $options pid]
        set chosen {}
        if {$pidFilter ne {}} {
            foreach candidate $candidates {
                if {[dict get $candidate pid] == $pidFilter} {
                    set chosen $candidate
                    break
                }
            }
        } else {
            set chosen [lindex [lsort -command {
                apply {{left right} {
                    set leftCount [dict get $left count]
                    set rightCount [dict get $right count]
                    set countDiff [expr {$rightCount - $leftCount}]
                    if {$countDiff != 0} {
                        return $countDiff
                    }
                    set leftPid [dict get $left pid]
                    set rightPid [dict get $right pid]
                    return [expr {$leftPid - $rightPid}]
                }}
            } $candidates] 0]
        }
        
        if {$chosen eq {}} {
            fail "No PID with at least two snapshots matched in $laneDir"
        }
        
        return [dict create \
            before [dict get [dict get $chosen before] filePath] \
            after [dict get [dict get $chosen after] filePath] \
            pid [dict get $chosen pid] \
            snapshotCount [dict get $chosen count] \
        ]
    }
    
    set files [dict get $options files]
    if {[llength $files] != 2} {
        printUsage
        exit 1
    }
    
    return [dict create \
        before [lindex $files 0] \
        after [lindex $files 1] \
        pid {} \
        snapshotCount 2 \
    ]
}

proc parseSnapshotMeta {scanner} {
    $scanner find {"snapshot":}
    $scanner skipWhitespace
    set metaObjectText [$scanner readBalancedObject]
    set parsed [dict get [json::json2dict $metaObjectText] snapshot {}]
    return [dict get $parsed meta {}]
}

proc buildSummary {filePath} {
    set scanner [JsonStreamScanner new $filePath]
    set meta [parseSnapshotMeta $scanner]
    if {$meta eq {}} {
        fail "Invalid heap snapshot: $filePath"
    }
    
    set node_fields [dict get $meta node_fields]
    set node_types [dict get $meta node_types]
    set typeNames [lindex $node_types 0]
    set typeIndex [lsearch -exact $node_fields type]
    set nameIndex [lsearch -exact $node_fields name]
    set selfSizeIndex [lsearch -exact $node_fields self_size]
    
    if {$typeIndex == -1 || $nameIndex == -1 || $selfSizeIndex == -1} {
        fail "Unsupported heap snapshot schema: $filePath"
    }
    
    set nodeFieldCount [llength $node_fields]
    set summaryByIndex [dict create]
    set nodeCount 0
    set currentTypeId 0
    set currentNameId 0
    set currentSelfSize 0
    
    $scanner find {"nodes":}
    $scanner parseNumberArray [list apply {{value index} {
        upvar 1 nodeFieldCount nodeFieldCount
        upvar 1 typeIndex typeIndex
        upvar 1 nameIndex nameIndex
        upvar 1 selfSizeIndex selfSizeIndex
        upvar 1 currentTypeId currentTypeId
        upvar 1 currentNameId currentNameId
        upvar 1 currentSelfSize currentSelfSize
        upvar 1 summaryByIndex summaryByIndex
        upvar 1 nodeCount nodeCount
        
        set fieldIndex [expr {$index % $nodeFieldCount}]
        if {$fieldIndex == $typeIndex} {
            set currentTypeId $value
            return
        }
        if {$fieldIndex == $nameIndex} {
            set currentNameId $value
            return
        }
        if {$fieldIndex == $selfSizeIndex} {
            set currentSelfSize $value
        }
        if {$fieldIndex != $nodeFieldCount - 1} {
            return
        }
        set key "$currentTypeId\t$currentNameId"
        if {![dict exists $summaryByIndex $key]} {
            dict set summaryByIndex $key [dict create \
                typeId $currentTypeId \
                nameId $currentNameId \
                selfSize 0 \
                count 0 \
            ]
        }
        set current [dict get $summaryByIndex $key]
        dict set current selfSize [expr {[dict get $current selfSize] + $currentSelfSize}]
        dict set current count [expr {[dict get $current count] + 1}]
        dict set summaryByIndex $key $current
        incr nodeCount
    }}]
    
    set requiredNameIds [dict create]
    dict for {key entry} $summaryByIndex {
        set nameId [dict get $entry nameId]
        if {$nameId >= 0} {
            dict set requiredNameIds $nameId 1
        }
    }
    
    set nameStrings [dict create]
    $scanner find {"strings":}
    $scanner parseStringArray [list apply {{value index} {
        upvar 1 requiredNameIds requiredNameIds
        upvar 1 nameStrings nameStrings
        if {[dict exists $requiredNameIds $index]} {
            dict set nameStrings $index $value
        }
    }}]
    
    set summary [dict create]
    dict for {key entry} $summaryByIndex {
        set typeId [dict get $entry typeId]
        set typeName [lindex $typeNames $typeId]
        if {$typeName eq {}} {
            set typeName "unknown"
        }
        set nameId [dict get $entry nameId]
        set nameString [dict get $nameStrings $nameId {}]
        set key "$typeName\t$nameString"
        dict set summary $key [dict create \
            type $typeName \
            name $nameString \
            selfSize [dict get $entry selfSize] \
            count [dict get $entry count] \
        ]
    }
    
    $scanner destroy
    return [dict create \
        nodeCount $nodeCount \
        summary $summary \
    ]
}

proc formatBytes {bytes} {
    if {abs($bytes) >= 1024 * 1024} {
        return [format "%.2f MiB" [expr {double($bytes) / (1024 * 1024)}]]
    }
    if {abs($bytes) >= 1024} {
        return [format "%.1f KiB" [expr {double($bytes) / 1024}]]
    }
    return "$bytes B"
}

proc formatDelta {bytes} {
    set sign [expr {$bytes >= 0 ? "+" : "-"}]
    return "$sign[formatBytes [expr {abs($bytes)}]]"
}

proc truncate {text maxLength} {
    if {[string length $text] <= $maxLength} {
        return $text
    }
    return "[string range $text 0 [expr {$maxLength - 2}]]…"
}

proc main {} {
    set options [parseArgs $::argv]
    set pair [resolvePair $options]
    set before [buildSummary [dict get $pair before]]
    set after [buildSummary [dict get $pair after]]
    set minBytes [expr {[dict get $options minKb] * 1024}]
    
    set rows {}
    dict for {key next} [dict get $after summary] {
        set previous [dict get $before summary $key [dict create selfSize 0 count 0]]
        set sizeDelta [expr {[dict get $next selfSize] - [dict get $previous selfSize]}]
        set countDelta [expr {[dict get $next count] - [dict get $previous count]}]
        if {$sizeDelta < $minBytes} {
            continue
        }
        lappend rows [dict create \
            type [dict get $next type] \
            name [dict get $next name] \
            sizeDelta $sizeDelta \
            countDelta $countDelta \
            afterSize [dict get $next selfSize] \
            afterCount [dict get $next count] \
        ]
    }
    
    set sortedRows [lsort -command {
        apply {{left right} {
            set leftSize [dict get $left sizeDelta]
            set rightSize [dict get $right sizeDelta]
            set sizeDiff [expr {$rightSize - $leftSize}]
            if {$sizeDiff != 0} {
                return $sizeDiff
            }
            set leftCount [dict get $left countDelta]
            set rightCount [dict get $right countDelta]
            return [expr {$rightCount - $leftCount}]
        }}
    } $rows]
    
    puts "before: [dict get $pair before]"
    puts "after:  [dict get $pair after]"
    set pid [dict get $pair pid]
    if {$pid ne {}} {
        puts "pid:    $pid ([dict get $pair snapshotCount] snapshots found)"
    }
    set beforeNodeCount [dict get $before nodeCount]
    set afterNodeCount [dict get $after nodeCount]
    set nodeDiff [expr {$afterNodeCount - $beforeNodeCount}]
    set nodeSign [expr {$nodeDiff >= 0 ? "+" : ""}]
    puts "nodes:   $beforeNodeCount -> $afterNodeCount ($nodeSign$nodeDiff)"
    set top [dict get $options top]
    set minKb [dict get $options minKb]
    puts "filter:  top=$top min=$minKb KiB"
    puts ""
    
    if {[llength $sortedRows] == 0} {
        puts "No entries exceeded the minimum delta."
        return
    }
    
    set slice [lrange $sortedRows 0 [expr {$top - 1}]]
    foreach row $slice {
        set sizeDelta [dict get $row sizeDelta]
        set countDelta [dict get $row countDelta]
        set type [dict get $row type]
        set name [dict get $row name]
        set formattedDelta [formatDelta $sizeDelta]
        set countSign [expr {$countDelta >= 0 ? "+" : ""}]
        set formattedCount "count $countSign$countDelta"
        set truncatedName [truncate [expr {$name eq {} ? "(empty)" : $name}] 96]
        puts [format "%11s  %10s  %-16s  %s" \
            [string range "           $formattedDelta" end-10 end] \
            [string range "          $formattedCount" end-9 end] \
            $type \
            $truncatedName]
    }
}

main
