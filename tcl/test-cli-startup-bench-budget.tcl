#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "793bdbf3a3b867a8db286ab5978d02c0b9538565d1ea208c452a78e2ced719c0", "source_sha256": "c6c7301dda8709e6c39c53f79a83f8f7938854384f4e21e1114095d876e51a6d", "target_language": "tcl"}
# test-cli-startup-bench-budget.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-cli-startup-bench-budget.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package require json
package require fileutil

# Constants
set CLI_STARTUP_BENCH_FIXTURE_PATH "test/fixtures/cli-startup-bench.json"

# Helper functions
proc formatMs {value} {
    return [format "%.1fms" $value]
}

proc formatMb {value} {
    return [format "%.1fMB" $value]
}

# Parse command line arguments
proc parseArgs {argv} {
    global CLI_STARTUP_BENCH_FIXTURE_PATH
    
    set opts [dict create \
        baseline $CLI_STARTUP_BENCH_FIXTURE_PATH \
        report "" \
        entry "openclaw.mjs" \
        preset "all" \
        runs 1 \
        warmup 0 \
        timeoutMs 30000 \
        maxDurationRegressionPct [expr {[info exists ::env(OPENCLAW_STARTUP_BENCH_MAX_DURATION_REGRESSION_PCT)] ? $::env(OPENCLAW_STARTUP_BENCH_MAX_DURATION_REGRESSION_PCT) : 20}] \
        maxRssRegressionPct [expr {[info exists ::env(OPENCLAW_STARTUP_BENCH_MAX_RSS_REGRESSION_PCT)] ? $::env(OPENCLAW_STARTUP_BENCH_MAX_RSS_REGRESSION_PCT) : 20}] \
    ]
    
    # Check for help flag first
    if {[lsearch -exact $argv "--help"] != -1} {
        puts [join {
            "Usage: tclsh test-cli-startup-bench-budget.tcl \[options\]"
            ""
            "Compare current CLI benchmark results against the checked-in fixture."
            ""
            "Options:"
            "  --baseline <path>             Baseline fixture path"
            "  --report <path>               Reuse an existing current benchmark report"
            "  --entry <path>                CLI entry to benchmark when report is omitted"
            "  --preset <name>               startup | real | all (default: all)"
            "  --runs <n>                    Measured runs per case (default: 1)"
            "  --warmup <n>                  Warmup runs per case (default: 0)"
            "  --timeout-ms <ms>             Per-run timeout (default: 30000)"
            "  --max-duration-regression-pct <n>"
            "                                Fail if avg duration regresses more than this percent"
            "  --max-rss-regression-pct <n>  Fail if avg RSS regresses more than this percent"
            "  --help                        Show this help text"
            ""
            "Example:"
            "  tclsh test-cli-startup-bench-budget.tcl --preset real --max-duration-regression-pct 15"
        } "\n"]
        exit 0
    }
    
    # Parse flags
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch $arg {
            "--baseline" {
                incr i
                dict set opts baseline [lindex $argv $i]
            }
            "--report" {
                incr i
                dict set opts report [lindex $argv $i]
            }
            "--entry" {
                incr i
                dict set opts entry [lindex $argv $i]
            }
            "--preset" {
                incr i
                dict set opts preset [lindex $argv $i]
            }
            "--runs" {
                incr i
                dict set opts runs [lindex $argv $i]
            }
            "--warmup" {
                incr i
                dict set opts warmup [lindex $argv $i]
            }
            "--timeout-ms" {
                incr i
                dict set opts timeoutMs [lindex $argv $i]
            }
            "--max-duration-regression-pct" {
                incr i
                dict set opts maxDurationRegressionPct [lindex $argv $i]
            }
            "--max-rss-regression-pct" {
                incr i
                dict set opts maxRssRegressionPct [lindex $argv $i]
            }
        }
    }
    
    return $opts
}

# Read JSON file
proc readJsonFile {path} {
    if {![file exists $path]} {
        error "File not found: $path"
    }
    set fd [open $path r]
    set data [read $fd]
    close $fd
    return [json::json2dict $data]
}

# Resolve current report path
proc resolveCurrentReportPath {opts} {
    if {[dict get $opts report] ne ""} {
        return [dict get $opts report]
    }
    
    set reportPath ".artifacts/cli-startup-bench.current.json"
    file mkdir ".artifacts"
    
    set args [list \
        "--import" "tsx" \
        "scripts/bench-cli-startup.ts" \
        "--entry" [dict get $opts entry] \
        "--preset" [dict get $opts preset] \
        "--runs" [dict get $opts runs] \
        "--warmup" [dict get $opts warmup] \
        "--timeout-ms" [dict get $opts timeoutMs] \
        "--output" $reportPath \
    ]
    
    # Execute node command
    set cmd [concat "node" $args]
    if {[catch {exec {*}$cmd} result]} {
        exit 1
    }
    
    return $reportPath
}

# Index cases from report
proc indexCases {report} {
    set cases [dict create]
    if {![dict exists $report primary cases]} {
        return $cases
    }
    
    set caseList [dict get $report primary cases]
    foreach case $caseList {
        set id [dict get $case id]
        dict set cases $id $case
    }
    
    return $cases
}

# Main execution
set opts [parseArgs $argv]
set baseline [readJsonFile [dict get $opts baseline]]
set current [readJsonFile [resolveCurrentReportPath $opts]]
set baselineCases [indexCases $baseline]
set currentCases [indexCases $current]

set failed false

dict for {id baselineCase} $baselineCases {
    if {![dict exists $currentCases $id]} {
        puts "\[test-cli-startup-bench-budget\] missing current case $id"
        set failed true
        continue
    }
    
    set currentCase [dict get $currentCases $id]
    
    # Duration check
    set baselineDuration ""
    set currentDuration ""
    
    if {[dict exists $baselineCase summary durationMs avg]} {
        set baselineDuration [dict get $baselineCase summary durationMs avg]
    }
    
    if {[dict exists $currentCase summary durationMs avg]} {
        set currentDuration [dict get $currentCase summary durationMs avg]
    }
    
    if {$baselineDuration ne "" && $currentDuration ne "" && 
        [string is double $baselineDuration] && [string is double $currentDuration] &&
        $baselineDuration > 0} {
        
        set allowedDuration [expr {$baselineDuration * (1 + [dict get $opts maxDurationRegressionPct] / 100.0)}]
        if {$currentDuration > $allowedDuration} {
            puts "\[test-cli-startup-bench-budget\] [dict get $baselineCase name] avg duration [formatMs $currentDuration] exceeded [formatMs $allowedDuration] (baseline [formatMs $baselineDuration], +[dict get $opts maxDurationRegressionPct]%)."
            set failed true
        }
    }
    
    # RSS check
    set baselineRss ""
    set currentRss ""
    
    if {[dict exists $baselineCase summary maxRssMb avg]} {
        set baselineRss [dict get $baselineCase summary maxRssMb avg]
    }
    
    if {[dict exists $currentCase summary maxRssMb avg]} {
        set currentRss [dict get $currentCase summary maxRssMb avg]
    }
    
    if {$baselineRss ne "" && $currentRss ne "" && 
        [string is double $baselineRss] && [string is double $currentRss] &&
        $baselineRss > 0} {
        
        set allowedRss [expr {$baselineRss * (1 + [dict get $opts maxRssRegressionPct] / 100.0)}]
        if {$currentRss > $allowedRss} {
            puts "\[test-cli-startup-bench-budget\] [dict get $baselineCase name] avg RSS [formatMb $currentRss] exceeded [formatMb $allowedRss] (baseline [formatMb $baselineRss], +[dict get $opts maxRssRegressionPct]%)."
            set failed true
        }
    }
    
    # Output results
    set durationStr "n/a"
    if {$currentDuration ne "" && [string is double $currentDuration]} {
        set durationStr [formatMs $currentDuration]
    }
    
    set baselineDurationStr "n/a"
    if {$baselineDuration ne "" && [string is double $baselineDuration]} {
        set baselineDurationStr [formatMs $baselineDuration]
    }
    
    set rssStr "n/a"
    if {$currentRss ne "" && [string is double $currentRss]} {
        set rssStr [formatMb $currentRss]
    }
    
    set baselineRssStr "n/a"
    if {$baselineRss ne "" && [string is double $baselineRss]} {
        set baselineRssStr [formatMb $baselineRss]
    }
    
    puts "\[test-cli-startup-bench-budget\] [dict get $baselineCase name] duration=$durationStr baseline=$baselineDurationStr rss=$rssStr baselineRss=$baselineRssStr"
}

if {$failed} {
    exit 1
}
