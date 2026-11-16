#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "593980bce33b6d51fa1cd4450b86d40793f44954cc7226811b069ae8020f2ca7", "source_sha256": "04f0268dc494793e85c15189558b4768a3e49a147b113ecc0fe3456b05d0eb20", "target_language": "tcl"}
# check-cli-startup-memory.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-cli-startup-memory.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Check if we're on Linux or macOS
set isLinux [string equal $::tcl_platform(platform) "unix"]
set isMac [string equal $::tcl_platform(os) "Darwin"]

if {!$isLinux && !$isMac} {
    puts "\[startup-memory\] Skipping on unsupported platform: $::tcl_platform(os)"
    exit 0
}

# Get current working directory (repo root)
set repoRoot [pwd]

# Create temporary directory
set tmpHome [exec mktemp -d openclaw-startup-memory-XXXXXX]
set tmpDir [expr {[info exists ::env(TMPDIR)] ? $::env(TMPDIR) : 
                 [info exists ::env(TEMP)] ? $::env(TEMP) : 
                 [info exists ::env(TMP)] ? $::env(TMP) : "/tmp"}]

set rssHookPath [file join $tmpHome measure-rss.tcl]
set MAX_RSS_MARKER "__OPENCLAW_MAX_RSS_KB__="

# Write RSS monitoring script
set rssHookFile [open $rssHookPath w]
puts $rssHookFile {
# This is a placeholder - Tcl doesn't have direct equivalent to Node's resourceUsage
# We'll use external tools like ps or /proc/status to monitor memory
}
close $rssHookFile

# Default limits in MB
array set DEFAULT_LIMITS_MB {
    help 100
    statusJson 400
    gatewayStatus 500
}

# Test cases
set cases [list]

# Help case
dict set case_help id "help"
dict set case_help label "--help"
dict set case_help args [list "openclaw.tcl" "--help"]
set help_limit [expr {[info exists ::env(OPENCLAW_STARTUP_MEMORY_HELP_MB)] ? 
                      $::env(OPENCLAW_STARTUP_MEMORY_HELP_MB) : $DEFAULT_LIMITS_MB(help)}]
dict set case_help limitMb $help_limit
lappend cases $case_help

# Status JSON case
dict set case_statusJson id "statusJson"
dict set case_statusJson label "status --json"
dict set case_statusJson args [list "openclaw.tcl" "status" "--json"]
set status_json_limit [expr {[info exists ::env(OPENCLAW_STARTUP_MEMORY_STATUS_JSON_MB)] ? 
                             $::env(OPENCLAW_STARTUP_MEMORY_STATUS_JSON_MB) : $DEFAULT_LIMITS_MB(statusJson)}]
dict set case_statusJson limitMb $status_json_limit
lappend cases $case_statusJson

# Gateway status case
dict set case_gatewayStatus id "gatewayStatus"
dict set case_gatewayStatus label "gateway status"
dict set case_gatewayStatus args [list "openclaw.tcl" "gateway" "status"]
set gateway_status_limit [expr {[info exists ::env(OPENCLAW_STARTUP_MEMORY_GATEWAY_STATUS_MB)] ? 
                                $::env(OPENCLAW_STARTUP_MEMORY_GATEWAY_STATUS_MB) : $DEFAULT_LIMITS_MB(gatewayStatus)}]
dict set case_gatewayStatus limitMb $gateway_status_limit
lappend cases $case_gatewayStatus

proc formatFixGuidance {testCase details} {
    global repoRoot
    set argsList [dict get $testCase args]
    set command "tclsh [join $argsList " "]"
    
    set guidance "\[startup-memory\] Fix guidance"
    append guidance "\nCase: [dict get $testCase label]"
    append guidance "\nCommand: $command"
    append guidance "\nNext steps:"
    append guidance "\n1. Run \`$command\` locally on the built tree."
    append guidance "\n2. If this is a memory overage, compare the startup import graph against the last passing commit and look for newly eager imports, bootstrap side effects, or plugin loading on the command path."
    append guidance "\n3. If this is a non-zero exit, inspect the first transitive import/config error in stderr and fix that root cause before re-checking memory."
    append guidance "\nLLM prompt:"
    append guidance "\n\"OpenClaw startup-memory CI failed for '[dict get $testCase label]'. Analyze this failure, identify the first runtime/import side effect that makes startup heavier or broken, and propose the smallest safe patch. Failure output:\n$details\""
    
    return "$guidance\n"
}

proc formatFailure {testCase message {details ""}} {
    set trimmedDetails [string trim $details]
    set sections [list $message]
    
    if {$trimmedDetails ne ""} {
        lappend sections $trimmedDetails
    }
    
    lappend sections [formatFixGuidance $testCase [expr {$trimmedDetails eq "" ? $message : $trimmedDetails}]]
    
    return [join $sections "\n\n"]
}

proc parseMaxRssMb {stderr} {
    global MAX_RSS_MARKER
    
    # Try to extract RSS from stderr using pattern matching
    # This is a simplified approach since Tcl doesn't have native resource usage tracking
    if {[regexp "${MAX_RSS_MARKER}(\\d+)" $stderr match rssKb]} {
        return [expr {$rssKb / 1024.0}]
    }
    
    # Alternative: try to parse from system tools output
    if {[regexp {VmRSS:[[:space:]]+(\d+)[[:space:]]+kB} $stderr match rssKb]} {
        return [expr {$rssKb / 1024.0}]
    }
    
    return ""
}

proc buildBenchEnv {} {
    global tmpHome tmpDir
    
    array set envVars {
        HOME ""
        USERPROFILE ""
        XDG_CONFIG_HOME ""
        XDG_DATA_HOME ""
        XDG_CACHE_HOME ""
        PATH ""
        TMPDIR ""
        TEMP ""
        TMP ""
        LANG ""
        TERM ""
        LC_ALL ""
        CI ""
        NODE_DISABLE_COMPILE_CACHE ""
        OPENCLAW_NO_RESPAWN ""
    }
    
    set envVars(HOME) $tmpHome
    set envVars(USERPROFILE) $tmpHome
    set envVars(XDG_CONFIG_HOME) [file join $tmpHome .config]
    set envVars(XDG_DATA_HOME) [file join $tmpHome .local share]
    set envVars(XDG_CACHE_HOME) [file join $tmpHome .cache]
    set envVars(PATH) [expr {[info exists ::env(PATH)] ? $::env(PATH) : ""}]
    set envVars(TMPDIR) $tmpDir
    set envVars(TEMP) $tmpDir
    set envVars(TMP) $tmpDir
    set envVars(LANG) [expr {[info exists ::env(LANG)] ? $::env(LANG) : "C.UTF-8"}]
    set envVars(TERM) [expr {[info exists ::env(TERM)] ? $::env(TERM) : "dumb"}]
    
    if {[info exists ::env(LC_ALL)]} {
        set envVars(LC_ALL) $::env(LC_ALL)
    }
    if {[info exists ::env(CI)]} {
        set envVars(CI) $::env(CI)
    }
    
    # Keep the benchmark on a single process
    set envVars(OPENCLAW_NO_RESPAWN) "1"
    
    return [array get envVars]
}

proc runCase {testCase} {
    global repoRoot rssHookPath MAX_RSS_MARKER
    
    set envVars [buildBenchEnv]
    set argsList [dict get $testCase args]
    
    # Prepare environment variables for execution
    set envCmd ""
    foreach {key value} $envVars {
        if {$value ne ""} {
            append envCmd "$key='$value' "
        }
    }
    
    # For memory measurement, we'll use ps or /proc/status
    set cmd "$envCmd tclsh"
    foreach arg $argsList {
        append cmd " [list $arg]"
    }
    
    # Execute command and capture output
    if {[catch {exec /bin/sh -c "$cmd 2>&1"} output]} {
        set stderr $output
        set status 1
    } else {
        set stderr $output
        set status 0
    }
    
    # Try to get memory usage - this is platform specific
    set maxRssMb [parseMaxRssMb $stderr]
    set matrixBootstrapWarning [regexp -nocase {matrix: crypto runtime bootstrap failed} $stderr]
    
    if {$status != 0} {
        error [formatFailure $testCase "$testCase(label) exited with $status" [string trim $stderr]]
    }
    
    if {$maxRssMb eq ""} {
        error [formatFailure $testCase "$testCase(label) did not report max RSS" $stderr]
    }
    
    if {$matrixBootstrapWarning} {
        error [formatFailure $testCase "$testCase(label) triggered Matrix crypto bootstrap during startup"]
    }
    
    if {$maxRssMb > [dict get $testCase limitMb]} {
        error [formatFailure $testCase "$testCase(label) used [format %.1f $maxRssMb] MB RSS (limit [dict get $testCase limitMb] MB)"]
    }
    
    puts "\[startup-memory\] [dict get $testCase label]: [format %.1f $maxRssMb] MB RSS (limit [dict get $testCase limitMb] MB)"
}

# Main execution loop
set success 1
foreach testCase $cases {
    if {[catch {runCase $testCase} errorMsg]} {
        puts stderr $errorMsg
        set success 0
        break
    }
}

# Cleanup temporary directory
catch {exec rm -rf $tmpHome}

if {!$success} {
    exit 1
}
