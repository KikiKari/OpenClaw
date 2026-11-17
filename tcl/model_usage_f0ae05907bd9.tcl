#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "e4aa492e6c02e389527693c31917a69812133aaef496fa4277723f8478f3a386", "source_sha256": "502dcda47466a4ab74da59badbe4b12c4782ed031c43d5038f8bd8534373cd35", "target_language": "tcl"}
# model_usage.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
# auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Summarize CodexBar local cost usage by model.
#
# Defaults to current model (most recent daily entry), or list all models.

package require json
package require json::write

proc eprint {msg} {
    puts stderr $msg
}

proc run_codexbar_cost {provider} {
    set cmd [list codexbar cost --format json --provider $provider]
    if {[catch {exec {*}$cmd} output]} {
        error "codexbar cost failed: $output"
    }
    if {[catch {::json::json2dict $output} data]} {
        error "Failed to parse codexbar JSON output: $data"
    }
    if {![dict exists $data]} {
        error "Expected codexbar cost JSON array."
    }
    return $data
}

proc load_payload {input_path provider} {
    if {$input_path ne ""} {
        if {$input_path eq "-"} {
            set raw [read stdin]
        } else {
            set fd [open $input_path r]
            set raw [read $fd]
            close $fd
        }
        set data [::json::json2dict $raw]
    } else {
        set data [run_codexbar_cost $provider]
    }

    if {[dict size $data] > 0 && [dict get $data provider] eq $provider} {
        return $data
    }

    if {[llength $data] > 0} {
        foreach entry $data {
            if {[dict get $entry provider] eq $provider} {
                return $entry
            }
        }
        error "Provider '$provider' not found in codexbar payload."
    }

    error "Unsupported JSON input format."
}

proc parse_daily_entries {payload} {
    if {![dict exists $payload daily]} {
        return {}
    }
    set daily [dict get $payload daily]
    if {![llength $daily]} {
        return {}
    }
    set result {}
    foreach entry $daily {
        if {[dict size $entry] > 0} {
            lappend result $entry
        }
    }
    return $result
}

proc parse_date {value} {
    if {[catch {clock scan $value -format "%Y-%m-%d"} result]} {
        return ""
    }
    return $result
}

proc filter_by_days {entries days} {
    if {$days eq "" || $days <= 0} {
        return $entries
    }
    set cutoff [expr {[clock seconds] - ($days - 1) * 86400}]
    set filtered {}
    foreach entry $entries {
        if {![dict exists $entry date]} continue
        set day [dict get $entry date]
        if {![string is string $day]} continue
        set parsed [parse_date $day]
        if {$parsed ne "" && $parsed >= $cutoff} {
            lappend filtered $entry
        }
    }
    return $filtered
}

proc aggregate_costs {entries} {
    set totals [dict create]
    foreach entry $entries {
        if {![dict exists $entry modelBreakdowns]} continue
        set breakdowns [dict get $entry modelBreakdowns]
        if {![llength $breakdowns]} continue
        foreach item $breakdowns {
            if {![dict size $item]} continue
            if {![dict exists $item modelName] || ![dict exists $item cost]} continue
            set model [dict get $item modelName]
            set cost [dict get $item cost]
            if {![string is string $model] || ![string is double $cost]} continue
            if {[dict exists $totals $model]} {
                set current [dict get $totals $model]
                dict set totals $model [expr {$current + $cost}]
            } else {
                dict set totals $model $cost
            }
        }
    }
    return $totals
}

proc pick_current_model {entries} {
    if {![llength $entries]} {
        return [list "" ""]
    }
    set sorted_entries {}
    foreach entry $entries {
        if {[dict exists $entry date]} {
            lappend sorted_entries [list [dict get $entry date] $entry]
        } else {
            lappend sorted_entries [list "" $entry]
        }
    }
    set sorted_entries [lsort -decreasing -index 0 $sorted_entries]
    
    foreach item $sorted_entries {
        set entry [lindex $item 1]
        if {[dict exists $entry modelBreakdowns]} {
            set breakdowns [dict get $entry modelBreakdowns]
            if {[llength $breakdowns]} {
                set scored {}
                foreach item $breakdowns {
                    if {![dict size $item]} continue
                    if {![dict exists $item modelName] || ![dict exists $item cost]} continue
                    set model [dict get $item modelName]
                    set cost [dict get $item cost]
                    if {[string is string $model] && [string is double $cost]} {
                        lappend scored [list $model $cost]
                    }
                }
                if {[llength $scored]} {
                    set scored [lsort -real -decreasing -index 1 $scored]
                    set best_model [lindex $scored 0 0]
                    set date_val ""
                    if {[dict exists $entry date] && [string is string [dict get $entry date]]} {
                        set date_val [dict get $entry date]
                    }
                    return [list $best_model $date_val]
                }
            }
        }
        if {[dict exists $entry modelsUsed]} {
            set models_used [dict get $entry modelsUsed]
            if {[llength $models_used]} {
                set last [lindex $models_used end]
                if {[string is string $last]} {
                    set date_val ""
                    if {[dict exists $entry date] && [string is string [dict get $entry date]]} {
                        set date_val [dict get $entry date]
                    }
                    return [list $last $date_val]
                }
            }
        }
    }
    return [list "" ""]
}

proc usd {value} {
    if {$value eq ""} {
        return "—"
    }
    return [format "$%.2f" $value]
}

proc latest_day_cost {entries model} {
    if {![llength $entries]} {
        return [list "" ""]
    }
    set sorted_entries {}
    foreach entry $entries {
        if {[dict exists $entry date]} {
            lappend sorted_entries [list [dict get $entry date] $entry]
        } else {
            lappend sorted_entries [list "" $entry]
        }
    }
    set sorted_entries [lsort -decreasing -index 0 $sorted_entries]
    
    foreach item $sorted_entries {
        set entry [lindex $item 1]
        if {![dict exists $entry modelBreakdowns]} continue
        set breakdowns [dict get $entry modelBreakdowns]
        if {![llength $breakdowns]} continue
        foreach item $breakdowns {
            if {![dict size $item]} continue
            if {![dict exists $item modelName] || [dict get $item modelName] ne $model} continue
            set cost ""
            if {[dict exists $item cost] && [string is double [dict get $item cost]]} {
                set cost [dict get $item cost]
            }
            set day ""
            if {[dict exists $entry date] && [string is string [dict get $entry date]]} {
                set day [dict get $entry date]
            }
            return [list $day $cost]
        }
    }
    return [list "" ""]
}

proc render_text_current {provider model latest_date total_cost latest_cost latest_cost_date entry_count} {
    set lines [list "Provider: $provider" "Current model: $model"]
    if {$latest_date ne ""} {
        lappend lines "Latest model date: $latest_date"
    }
    lappend lines "Total cost (rows): [usd $total_cost]"
    if {$latest_cost_date ne ""} {
        lappend lines "Latest day cost: [usd $latest_cost] ($latest_cost_date)"
    }
    lappend lines "Daily rows: $entry_count"
    return [join $lines "\n"]
}

proc render_text_all {provider totals} {
    set lines [list "Provider: $provider" "Models:"]
    set sorted_items {}
    dict for {model cost} $totals {
        lappend sorted_items [list $model $cost]
    }
    set sorted_items [lsort -real -decreasing -index 1 $sorted_items]
    foreach item $sorted_items {
        set model [lindex $item 0]
        set cost [lindex $item 1]
        lappend lines "- $model: [usd $cost]"
    }
    return [join $lines "\n"]
}

proc build_json_current {provider model latest_date total_cost latest_cost latest_cost_date entry_count} {
    set result [dict create]
    dict set result provider $provider
    dict set result mode "current"
    dict set result model $model
    dict set result latestModelDate $latest_date
    dict set result totalCostUSD $total_cost
    dict set result latestDayCostUSD $latest_cost
    dict set result latestDayCostDate $latest_cost_date
    dict set result dailyRowCount $entry_count
    return $result
}

proc build_json_all {provider totals} {
    set result [dict create]
    dict set result provider $provider
    dict set result mode "all"
    set models_list {}
    set sorted_items {}
    dict for {model cost} $totals {
        lappend sorted_items [list $model $cost]
    }
    set sorted_items [lsort -real -decreasing -index 1 $sorted_items]
    foreach item $sorted_items {
        set model_dict [dict create]
        dict set model_dict model [lindex $item 0]
        dict set model_dict totalCostUSD [lindex $item 1]
        lappend models_list $model_dict
    }
    dict set result models $models_list
    return $result
}

proc main {} {
    global argv
    set provider "codex"
    set mode "current"
    set model ""
    set input ""
    set days ""
    set format "text"
    set pretty 0
    
    # Simple argument parsing
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        incr i
        switch -- $arg {
            "--provider" {
                if {$i < [llength $argv]} {
                    set provider [lindex $argv $i]
                    incr i
                }
            }
            "--mode" {
                if {$i < [llength $argv]} {
                    set mode [lindex $argv $i]
                    incr i
                }
            }
            "--model" {
                if {$i < [llength $argv]} {
                    set model [lindex $argv $i]
                    incr i
                }
            }
            "--input" {
                if {$i < [llength $argv]} {
                    set input [lindex $argv $i]
                    incr i
                }
            }
            "--days" {
                if {$i < [llength $argv]} {
                    set days [lindex $argv $i]
                    incr i
                }
            }
            "--format" {
                if {$i < [llength $argv]} {
                    set format [lindex $argv $i]
                    incr i
                }
            }
            "--pretty" {
                set pretty 1
            }
        }
    }
    
    if {$provider ne "codex" && $provider ne "claude"} {
        eprint "Invalid provider: $provider"
        return 1
    }
    
    if {$mode ne "current" && $mode ne "all"} {
        eprint "Invalid mode: $mode"
        return 1
    }
    
    if {$format ne "text" && $format ne "json"} {
        eprint "Invalid format: $format"
        return 1
    }
    
    if {$days ne "" && ![string is integer $days]} {
        eprint "Invalid days value: $days"
        return 1
    }
    
    if {[catch {load_payload $input $provider} payload]} {
        eprint $payload
        return 1
    }
    
    set entries [parse_daily_entries $payload]
    set entries [filter_by_days $entries $days]
    
    if {$mode eq "current"} {
        if {$model eq ""} {
            set result [pick_current_model $entries]
            set model [lindex $result 0]
            set latest_date [lindex $result 1]
        } else {
            set latest_date ""
        }
        
        if {$model eq ""} {
            eprint "No model data found in codexbar cost payload."
            return 2
        }
        
        set totals [aggregate_costs $entries]
        set total_cost ""
        if {[dict exists $totals $model]} {
            set total_cost [dict get $totals $model]
        }
        
        set latest_result [latest_day_cost $entries $model]
        set latest_cost_date [lindex $latest_result 0]
        set latest_cost [lindex $latest_result 1]
        
        if {$format eq "json"} {
            set payload_out [build_json_current $provider $model $latest_date $total_cost $latest_cost $latest_cost_date [llength $entries]]
            if {$pretty} {
                puts [::json::write indented $payload_out]
            } else {
                puts [::json::write unquoted $payload_out]
            }
        } else {
            puts [render_text_current $provider $model $latest_date $total_cost $latest_cost $latest_cost_date [llength $entries]]
        }
        return 0
    }
    
    set totals [aggregate_costs $entries]
    if {[dict size $totals] == 0} {
        eprint "No model breakdowns found in codexbar cost payload."
        return 2
    }
    
    if {$format eq "json"} {
        set payload_out [build_json_all $provider $totals]
        if {$pretty} {
            puts [::json::write indented $payload_out]
        } else {
            puts [::json::write unquoted $payload_out]
        }
    } else {
        puts [render_text_all $provider $totals]
    }
    return 0
}

exit [main]
