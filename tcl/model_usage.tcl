#!/usr/bin/env tclsh8.6
# model_usage.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
# auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Summarize CodexBar local cost usage by model.
#
# Defaults to current model (most recent daily entry), or list all models.

package require json
package require cmdline

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

    if {[dict size $data] > 0 && [dict exists $data provider]} {
        return $data
    }

    if {[llength $data] > 0} {
        foreach entry $data {
            if {[dict exists $entry provider] && [dict get $entry provider] eq $provider} {
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
    if {![dict size $daily] && ![llength $daily]} {
        return {}
    }
    set result {}
    foreach entry $daily {
        if {[dict size $entry]} {
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
    set cutoff [clock add [clock seconds] -$days days]
    set filtered {}
    foreach entry $entries {
        if {![dict exists $entry date]} {
            continue
        }
        set day [dict get $entry date]
        if {[set parsed [parse_date $day]] ne "" && $parsed >= $cutoff} {
            lappend filtered $entry
        }
    }
    return $filtered
}

proc aggregate_costs {entries} {
    set totals [dict create]
    foreach entry $entries {
        if {![dict exists $entry modelBreakdowns]} {
            continue
        }
        set breakdowns [dict get $entry modelBreakdowns]
        if {![llength $breakdowns]} {
            continue
        }
        foreach item $breakdowns {
            if {![dict size $item]} {
                continue
            }
            if {![dict exists $item modelName] || ![dict exists $item cost]} {
                continue
            }
            set model [dict get $item modelName]
            set cost [dict get $item cost]
            if {![string is double $cost]} {
                continue
            }
            set current_total [dict get $totals $model 0.0]
            dict set totals $model [expr {$current_total + $cost}]
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
        set date_val ""
        if {[dict exists $entry date]} {
            set date_val [dict get $entry date]
        }
        lappend sorted_entries [list $date_val $entry]
    }
    set sorted_entries [lsort -index 0 $sorted_entries]
    
    for {set i [expr {[llength $sorted_entries] - 1}]} {$i >= 0} {incr i -1} {
        set entry_data [lindex $sorted_entries $i]
        set entry [lindex $entry_data 1]
        
        if {[dict exists $entry modelBreakdowns]} {
            set breakdowns [dict get $entry modelBreakdowns]
            if {[llength $breakdowns]} {
                set scored {}
                foreach item $breakdowns {
                    if {![dict size $item]} {
                        continue
                    }
                    if {![dict exists $item modelName] || ![dict exists $item cost]} {
                        continue
                    }
                    set model [dict get $item modelName]
                    set cost [dict get $item cost]
                    if {[string is double $cost]} {
                        lappend scored [list $model $cost]
                    }
                }
                if {[llength $scored]} {
                    set scored [lsort -real -decreasing -index 1 $scored]
                    set best_model [lindex $scored 0 0]
                    set date_str ""
                    if {[dict exists $entry date]} {
                        set date_str [dict get $entry date]
                    }
                    return [list $best_model $date_str]
                }
            }
        }
        
        if {[dict exists $entry modelsUsed]} {
            set models_used [dict get $entry modelsUsed]
            if {[llength $models_used]} {
                set last [lindex $models_used end]
                if {[string length $last]} {
                    set date_str ""
                    if {[dict exists $entry date]} {
                        set date_str [dict get $entry date]
                    }
                    return [list $last $date_str]
                }
            }
        }
    }
    return [list "" ""]
}

proc usd {value} {
    if {$value eq "" || $value eq "null"} {
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
        set date_val ""
        if {[dict exists $entry date]} {
            set date_val [dict get $entry date]
        }
        lappend sorted_entries [list $date_val $entry]
    }
    set sorted_entries [lsort -index 0 $sorted_entries]
    
    for {set i [expr {[llength $sorted_entries] - 1}]} {$i >= 0} {incr i -1} {
        set entry_data [lindex $sorted_entries $i]
        set entry [lindex $entry_data 1]
        
        if {![dict exists $entry modelBreakdowns]} {
            continue
        }
        set breakdowns [dict get $entry modelBreakdowns]
        if {![llength $breakdowns]} {
            continue
        }
        foreach item $breakdowns {
            if {![dict size $item]} {
                continue
            }
            if {[dict exists $item modelName] && [dict get $item modelName] eq $model} {
                set cost ""
                if {[dict exists $item cost]} {
                    set cost_item [dict get $item cost]
                    if {[string is double $cost_item]} {
                        set cost $cost_item
                    }
                }
                set day ""
                if {[dict exists $entry date]} {
                    set day [dict get $entry date]
                }
                return [list $day $cost]
            }
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
    set sorted_totals {}
    dict for {model cost} $totals {
        lappend sorted_totals [list $model $cost]
    }
    set sorted_totals [lsort -real -decreasing -index 1 $sorted_totals]
    foreach item $sorted_totals {
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
    set sorted_totals {}
    dict for {model cost} $totals {
        lappend sorted_totals [list $model $cost]
    }
    set sorted_totals [lsort -real -decreasing -index 1 $sorted_totals]
    foreach item $sorted_totals {
        set model_dict [dict create]
        dict set model_dict model [lindex $item 0]
        dict set model_dict totalCostUSD [lindex $item 1]
        lappend models_list $model_dict
    }
    dict set result models $models_list
    return $result
}

proc main {} {
    set options {
        {provider.arg "codex" "Provider to analyze (codex|claude)"}
        {mode.arg "current" "Mode of operation (current|all)"}
        {model.arg "" "Explicit model name to report"}
        {input.arg "" "Path to codexbar cost JSON"}
        {days.arg "" "Limit to last N days"}
        {format.arg "text" "Output format (text|json)"}
        {pretty "Pretty-print JSON output"}
    }
    
    set usage "Usage: model_usage.tcl \[options\]"
    array set params [::cmdline::getoptions argv $options $usage]
    
    if {[catch {
        set payload [load_payload $params(input) $params(provider)]
    } err]} {
        eprint $err
        return 1
    }
    
    set entries [parse_daily_entries $payload]
    if {$params(days) ne ""} {
        set entries [filter_by_days $entries $params(days)]
    }
    
    if {$params(mode) eq "current"} {
        set model $params(model)
        set latest_date ""
        if {$model eq ""} {
            foreach {model latest_date} [pick_current_model $entries] break
        }
        if {$model eq ""} {
            eprint "No model data found in codexbar cost payload."
            return 2
        }
        set totals [aggregate_costs $entries]
        set total_cost [dict get $totals $model ""]
        foreach {latest_cost_date latest_cost} [latest_day_cost $entries $model] break
        
        if {$params(format) eq "json"} {
            set payload_out [build_json_current \
                $params(provider) \
                $model \
                $latest_date \
                $total_cost \
                $latest_cost \
                $latest_cost_date \
                [llength $entries]]
            if {$params(pretty)} {
                puts [::json::dict2json $payload_out 2]
            } else {
                puts [::json::dict2json $payload_out]
            }
        } else {
            puts [render_text_current \
                $params(provider) \
                $model \
                $latest_date \
                $total_cost \
                $latest_cost \
                $latest_cost_date \
                [llength $entries]]
        }
        return 0
    }
    
    set totals [aggregate_costs $entries]
    if {![dict size $totals]} {
        eprint "No model breakdowns found in codexbar cost payload."
        return 2
    }
    
    if {$params(format) eq "json"} {
        set payload_out [build_json_all $params(provider) $totals]
        if {$params(pretty)} {
            puts [::json::dict2json $payload_out 2]
        } else {
            puts [::json::dict2json $payload_out]
        }
    } else {
        puts [render_text_all $params(provider) $totals]
    }
    return 0
}

if {[info script] eq $argv0} {
    exit [main]
}
