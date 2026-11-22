#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "fcadfee5f92ab5e878286f2cd580f65491bd7249d8005e3a49ad26698c1e7827", "source_sha256": "93ecf5d3490bf6c88b3f288ec409b9375009242d467e26772ba3a10251e1d9b7", "target_language": "tcl"}
# profile-extension-memory.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/profile-extension-memory.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Tcl doesn't have native JSON support, so we'll implement basic JSON functions
proc json_escape {str} {
    regsub -all {(["\\\x00-\x1f])} $str {\\\1} str
    return "\"$str\""
}

proc json_object {dict} {
    set parts {}
    dict for {key value} $dict {
        lappend parts "[json_escape $key]: $value"
    }
    return "\{[join $parts ", "]\}"
}

proc json_array {list} {
    set parts {}
    foreach item $list {
        lappend parts $item
    }
    return "\[[join $parts ", "]\]"
}

proc format_error_message {error} {
    return $error
}

set DEFAULT_CONCURRENCY 6
set DEFAULT_TIMEOUT_MS 90000
set DEFAULT_COMBINED_TIMEOUT_MS 180000
set DEFAULT_TOP 10
set RSS_MARKER "__OPENCLAW_MAX_RSS_KB__="

proc print_help {} {
    global DEFAULT_CONCURRENCY DEFAULT_TIMEOUT_MS DEFAULT_COMBINED_TIMEOUT_MS DEFAULT_TOP
    puts "Usage: tclsh profile-extension-memory.tcl \[options\]

Profiles peak RSS for built bundled plugin entrypoints.
Run pnpm build first if you want stats for the latest source changes.

Options:
  --extension, -e <id>     Limit profiling to one or more extension ids (repeatable)
  --concurrency <n>        Number of per-extension workers (default: $DEFAULT_CONCURRENCY)
  --timeout-ms <ms>        Per-extension timeout in milliseconds (default: $DEFAULT_TIMEOUT_MS)
  --combined-timeout-ms <ms>
                           Combined-import timeout in milliseconds (default: $DEFAULT_COMBINED_TIMEOUT_MS)
  --top <n>                Show top N entries by delta from baseline (default: $DEFAULT_TOP)
  --json <path>            Write full JSON report to this path
  --skip-combined          Skip the combined all-imports measurement
  --help                   Show this help

Examples:
  pnpm test:extensions:memory
  pnpm test:extensions:memory -- --extension discord
  pnpm test:extensions:memory -- --extension discord --extension telegram --skip-combined"
}

proc parse_positive_int {raw flag_name} {
    if {![string is integer -strict $raw] || $raw <= 0} {
        error "$flag_name must be a positive integer"
    }
    return $raw
}

proc parse_args {argv} {
    global DEFAULT_CONCURRENCY DEFAULT_TIMEOUT_MS DEFAULT_COMBINED_TIMEOUT_MS DEFAULT_TOP
    
    array set options [list \
        extensions {} \
        concurrency $DEFAULT_CONCURRENCY \
        timeout_ms $DEFAULT_TIMEOUT_MS \
        combined_timeout_ms $DEFAULT_COMBINED_TIMEOUT_MS \
        top $DEFAULT_TOP \
        json_path "" \
        skip_combined false \
    ]
    
    set index 0
    set argc [llength $argv]
    
    while {$index < $argc} {
        set arg [lindex $argv $index]
        incr index
        
        switch $arg {
            "--" {
                # Ignore --
            }
            "--extension" -
            "-e" {
                if {$index >= $argc} {
                    error "$arg requires a value"
                }
                lappend options(extensions) [lindex $argv $index]
                incr index
            }
            "--concurrency" {
                if {$index >= $argc} {
                    error "$arg requires a value"
                }
                set options(concurrency) [parse_positive_int [lindex $argv $index] $arg]
                incr index
            }
            "--timeout-ms" {
                if {$index >= $argc} {
                    error "$arg requires a value"
                }
                set options(timeout_ms) [parse_positive_int [lindex $argv $index] $arg]
                incr index
            }
            "--combined-timeout-ms" {
                if {$index >= $argc} {
                    error "$arg requires a value"
                }
                set options(combined_timeout_ms) [parse_positive_int [lindex $argv $index] $arg]
                incr index
            }
            "--top" {
                if {$index >= $argc} {
                    error "$arg requires a value"
                }
                set options(top) [parse_positive_int [lindex $argv $index] $arg]
                incr index
            }
            "--json" {
                if {$index >= $argc} {
                    error "$arg requires a value"
                }
                set options(json_path) [file normalize [lindex $argv $index]]
                incr index
            }
            "--skip-combined" {
                set options(skip_combined) true
            }
            "--help" -
            "-h" {
                print_help
                exit 0
            }
            default {
                error "Unknown argument: $arg"
            }
        }
    }
    
    return [array get options]
}

proc parse_max_rss_mb {stderr} {
    global RSS_MARKER
    
    set pattern "^${RSS_MARKER}(\\d+)\$"
    set matches {}
    
    foreach line [split $stderr "\n"] {
        if {[regexp $pattern $line -> rss_kb]} {
            lappend matches $rss_kb
        }
    }
    
    if {[llength $matches] > 0} {
        set last [lindex $matches end]
        return [expr {double($last) / 1024}]
    }
    
    return ""
}

proc summarize_stderr {stderr {lines 8}} {
    set lines_list [split [string trim $stderr] "\n"]
    set filtered_lines {}
    
    foreach line $lines_list {
        if {[string length [string trim $line]] > 0} {
            lappend filtered_lines $line
        }
    }
    
    return [join [lrange $filtered_lines 0 [expr {$lines - 1}]] "\n"]
}

proc run_case {args_dict} {
    global tcl_platform
    
    array set args $args_dict
    array set options $args(options)
    
    # Create temporary directory for measurements
    set tmp_dir [exec mktemp -d]
    set hook_path [file join $tmp_dir measure-rss.mjs]
    
    # Write hook script
    set hook_content "process.on('exit', () => {
  const usage = typeof process.resourceUsage === 'function' ? process.resourceUsage() : null;
  if (usage && typeof usage.maxRSS === 'number') console.error('${::RSS_MARKER}' + String(usage.maxRSS));
});
"
    set fp [open $hook_path w]
    puts $fp $hook_content
    close $fp
    
    # Build command
    set cmd [list node --import $hook_path --input-type=module --eval $args(body)]
    
    # Set environment variables
    set env_vars [array get ::env]
    lappend env_vars HOME $tmp_dir
    lappend env_vars USERPROFILE $tmp_dir
    lappend env_vars XDG_CONFIG_HOME [file join $tmp_dir ".config"]
    lappend env_vars XDG_DATA_HOME [file join $tmp_dir ".local" "share"]
    lappend env_vars XDG_CACHE_HOME [file join $tmp_dir ".cache"]
    lappend env_vars NODE_DISABLE_COMPILE_CACHE 1
    lappend env_vars OPENCLAW_NO_RESPAWN 1
    lappend env_vars TERM [expr {[info exists ::env(TERM)] ? $::env(TERM) : "dumb"}]
    lappend env_vars LANG [expr {[info exists ::env(LANG)] ? $::env(LANG) : "C.UTF-8"}]
    
    # Execute command with timeout
    if {[catch {exec -keepnewline timeout $args(timeout_ms) {*}$cmd} output]} {
        set timed_out 1
        set code 1
        set signal ""
    } else {
        set timed_out 0
        set code 0
        set signal ""
    }
    
    # Parse results
    set max_rss_mb [parse_max_rss_mb $output]
    
    # Clean up
    file delete -force $tmp_dir
    
    return [list \
        name $args(name) \
        code $code \
        signal $signal \
        timed_out $timed_out \
        stdout "" \
        stderr $output \
        max_rss_mb $max_rss_mb \
    ]
}

proc build_import_body {entry_files label} {
    set imports ""
    foreach file_path $entry_files {
        append imports "await import([json_escape $file_path]);\n"
    }
    append imports "console.log([json_escape $label]);\nprocess.exit(0);\n"
    return $imports
}

proc find_extension_entries {repo_root} {
    set extensions_dir [file join $repo_root "dist" "extensions"]
    
    if {![file exists $extensions_dir]} {
        error "dist/extensions not found. Run pnpm build first."
    }
    
    set entries {}
    foreach dir [glob -nocomplain -directory $extensions_dir *] {
        if {[file isdirectory $dir]} {
            set file [file join $dir "index.js"]
            if {[file exists $file]} {
                lappend entries [list dir [file tail $dir] file $file]
            }
        }
    }
    
    if {[llength $entries] == 0} {
        error "No built bundled plugin entrypoints found in the dist plugin tree"
    }
    
    # Sort entries by directory name
    set sorted_entries {}
    foreach entry $entries {
        lappend sorted_entries [list [lindex $entry 1] $entry]
    }
    set sorted_entries [lsort -index 0 $sorted_entries]
    
    set result {}
    foreach item $sorted_entries {
        lappend result [lindex $item 1]
    }
    
    return $result
}

proc main {} {
    global argv DEFAULT_CONCURRENCY DEFAULT_TIMEOUT_MS DEFAULT_COMBINED_TIMEOUT_MS DEFAULT_TOP
    
    # Parse arguments
    array set options [parse_args $argv]
    
    # Get repository root
    set repo_root [pwd]
    
    # Find extension entries
    set all_entries [find_extension_entries $repo_root]
    
    # Filter selected entries
    set selected_entries {}
    if {[llength $options(extensions)] == 0} {
        set selected_entries $all_entries
    } else {
        foreach entry $all_entries {
            array set entry_dict $entry
            if {[lsearch -exact $options(extensions) $entry_dict(dir)] != -1} {
                lappend selected_entries $entry
            }
        }
    }
    
    # Check for missing extensions
    set missing {}
    foreach ext_id $options(extensions) {
        set found 0
        foreach entry $all_entries {
            array set entry_dict $entry
            if {$entry_dict(dir) eq $ext_id} {
                set found 1
                break
            }
        }
        if {!$found} {
            lappend missing $ext_id
        }
    }
    
    if {[llength $missing] > 0} {
        error "Unknown built extension ids: [join $missing ", "]"
    }
    
    if {[llength $selected_entries] == 0} {
        error "No extensions selected for profiling"
    }
    
    # Create temporary home directory
    set tmp_home [exec mktemp -d "/tmp/openclaw-extension-memory-XXXXXX"]
    set hook_path [file join $tmp_home "measure-rss.mjs"]
    set json_path [expr {$options(json_path) ne "" ? $options(json_path) : "/tmp/openclaw-extension-memory.json"}]
    
    # Write hook script
    set hook_content "process.on('exit', () => {
  const usage = typeof process.resourceUsage === 'function' ? process.resourceUsage() : null;
  if (usage && typeof usage.maxRSS === 'number') console.error('${::RSS_MARKER}' + String(usage.maxRSS));
});
"
    set fp [open $hook_path w]
    puts $fp $hook_content
    close $fp
    
    # Set environment variables
    set env(HOME) $tmp_home
    set env(USERPROFILE) $tmp_home
    set env(XDG_CONFIG_HOME) [file join $tmp_home ".config"]
    set env(XDG_DATA_HOME) [file join $tmp_home ".local" "share"]
    set env(XDG_CACHE_HOME) [file join $tmp_home ".cache"]
    set env(NODE_DISABLE_COMPILE_CACHE) 1
    set env(OPENCLAW_NO_RESPAWN) 1
    set env(TERM) [expr {[info exists ::env(TERM)] ? $::env(TERM) : "dumb"}]
    set env(LANG) [expr {[info exists ::env(LANG)] ? $::env(LANG) : "C.UTF-8"}]
    
    # Run baseline measurement
    array set baseline [run_case [list \
        options [array get options] \
        name "baseline" \
        body "process.exit(0)" \
        timeout_ms $options(timeout_ms) \
    ]]
    
    # Run combined measurement if not skipped
    set combined ""
    if {!$options(skip_combined)} {
        set files {}
        foreach entry $selected_entries {
            array set entry_dict $entry
            lappend files $entry_dict(file)
        }
        
        array set combined_result [run_case [list \
            options [array get options] \
            name "combined" \
            body [build_import_body $files "IMPORTED_ALL"] \
            timeout_ms $options(combined_timeout_ms) \
        ]]
        set combined [array get combined_result]
    }
    
    # Process individual extensions
    set pending [list {*}$selected_entries]
    set results {}
    
    # Worker function (simplified for single-threaded execution)
    while {[llength $pending] > 0} {
        set next [lindex $pending 0]
        set pending [lrange $pending 1 end]
        
        array set next_dict $next
        set body [build_import_body [list $next_dict(file)] "IMPORTED"]
        
        array set result [run_case [list \
            options [array get options] \
            name $next_dict(dir) \
            body $body \
            timeout_ms $options(timeout_ms) \
        ]]
        
        set status [expr {$result(timed_out) ? "timeout" : ($result(code) == 0 ? "ok" : "fail")}]
        set rss [expr {$result(max_rss_mb) eq "" ? "n/a" : [format "%.1f MB" $result(max_rss_mb)]}]
        puts "\[extension-memory\] $next_dict(dir): $status $rss"
        
        lappend results [list \
            dir $next_dict(dir) \
            file $next_dict(file) \
            status $status \
            max_rss_mb $result(max_rss_mb) \
            delta_from_baseline_mb [expr {($result(max_rss_mb) ne "" && $baseline(max_rss_mb) ne "") ? ($result(max_rss_mb) - $baseline(max_rss_mb)) : ""}] \
            stderr_preview [summarize_stderr $result(stderr)] \
        ]
    }
    
    # Sort results by directory name
    set sorted_results {}
    foreach result $results {
        array set result_dict $result
        lappend sorted_results [list $result_dict(dir) $result]
    }
    set sorted_results [lsort -index 0 $sorted_results]
    
    set results {}
    foreach item $sorted_results {
        lappend results [lindex $item 1]
    }
    
    # Calculate top entries
    set valid_results {}
    foreach result $results {
        array set result_dict $result
        if {$result_dict(status) eq "ok" && $result_dict(delta_from_baseline_mb) ne ""} {
            lappend valid_results $result
        }
    }
    
    # Sort by delta from baseline
    set sorted_valid {}
    foreach result $valid_results {
        array set result_dict $result
        lappend sorted_valid [list $result_dict(delta_from_baseline_mb) $result]
    }
    set sorted_valid [lsort -real -decreasing -index 0 $sorted_valid]
    
    set top {}
    set count 0
    foreach item $sorted_valid {
        if {$count >= $options(top)} break
        lappend top [lindex $item 1]
        incr count
    }
    
    # Count statuses
    set ok_count 0
    set fail_count 0
    set timeout_count 0
    
    foreach result $results {
        array set result_dict $result
        switch $result_dict(status) {
            "ok" { incr ok_count }
            "fail" { incr fail_count }
            "timeout" { incr timeout_count }
        }
    }
    
    # Build report
    set report_dict [list \
        generated_at [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"] \
        repo_root $repo_root \
        selected_extensions {} \
        baseline [list \
            status [expr {$baseline(timed_out) ? "timeout" : ($baseline(code) == 0 ? "ok" : "fail")}] \
            max_rss_mb $baseline(max_rss_mb) \
        ] \
        combined [expr {$combined eq "" ? "null" : [list \
            status [expr {[dict get $combined timed_out] ? "timeout" : ([dict get $combined code] == 0 ? "ok" : "fail")}] \
            max_rss_mb [dict get $combined max_rss_mb] \
            stderr_preview [summarize_stderr [dict get $combined stderr] 12] \
        ]}] \
        counts [list \
            total_entries [llength $selected_entries] \
            ok $ok_count \
            fail $fail_count \
            timeout $timeout_count \
        ] \
        options [list \
            concurrency $options(concurrency) \
            timeout_ms $options(timeout_ms) \
            combined_timeout_ms $options(combined_timeout_ms) \
            skip_combined $options(skip_combined) \
        ] \
        top_by_delta_mb $top \
        results $results \
    ]
    
    # Add selected extensions to report
    set selected_ext_names {}
    foreach entry $selected_entries {
        array set entry_dict $entry
        lappend selected_ext_names $entry_dict(dir)
    }
    dict set report_dict selected_extensions $selected_ext_names
    
    # Write JSON report
    set fp [open $json_path w]
    puts $fp [dict_to_json $report_dict]
    close $fp
    
    puts "\[extension-memory\] report: $json_path"
    
    # Print summary
    set summary_dict [list \
        baseline_mb $baseline(max_rss_mb) \
        combined_mb [expr {$combined eq "" ? "null" : [dict get $combined max_rss_mb]}] \
        counts [dict get $report_dict counts] \
        top_by_delta_mb $top \
    ]
    
    puts [dict_to_json $summary_dict]
    
    # Clean up
    file delete -force $tmp_home
}

proc dict_to_json {dict_val} {
    set json_parts {}
    
    dict for {key value} $dict_val {
        set json_key [json_escape $key]
        
        if {[string equal $value "null"]} {
            set json_value "null"
        } elseif {[string is double $value]} {
            set json_value $value
        } elseif {[string is integer $value]} {
            set json_value $value
        } elseif {[llength $value] > 1 && [llength [lindex $value 0]] == 2} {
            # This looks like a nested dictionary
            set json_value [dict_to_json $value]
        } elseif {[llength $value] > 0} {
            # This looks like a list/array
            set array_items {}
            foreach item $value {
                if {[string is double $item] || [string is integer $item]} {
                    lappend array_items $item
                } else {
                    lappend array_items [json_escape $item]
                }
            }
            set json_value "\[[join $array_items ", "]\]"
        } else {
            set json_value [json_escape $value]
        }
        
        lappend json_parts "$json_key: $json_value"
    }
    
    return "\{[join $json_parts ", "]\}"
}

# Error handling
if {[catch {main} error]} {
    puts stderr "\[extension-memory\] [format_error_message $error]"
    exit 1
}
