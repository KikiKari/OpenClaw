#!/usr/bin/env tclsh8.6
# openclaw-audit.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# OpenClaw read-only audit/diagnostic sweep
# Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

package require Tcl 8.6

# Get script directory
set script_dir [file dirname [info script]]
set date_stamp [clock format [clock seconds] -format "%Y-%m-%d"]
set out [file join $script_dir "openclaw-audit-$date_stamp.log"]

set oc [list openclaw --no-color]

# Write header to log file
set fh [open $out w]
puts $fh "================================================================"
puts $fh "OpenClaw audit run"
puts $fh "Started:  [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]"
if {[catch {exec hostname} hostname_result]} {
    set hostname "unknown"
} else {
    set hostname $hostname_result
}
puts $fh "Host:     $hostname"
if {[catch {exec whoami} whoami_result]} {
    set user "unknown"
} else {
    set user $whoami_result
}
puts $fh "User:     $user"
if {[catch {exec openclaw --version} version_result]} {
    set version "unknown"
} else {
    set version $version_result
}
puts $fh "Version:  $version"
puts $fh "Output:   $out"
puts $fh "================================================================"
close $fh

# Function to run command and append output to log
proc run_cmd {title args} {
    global out oc
    set fh [open $out a]
    puts $fh ""
    puts $fh "----------------------------------------------------------------"
    puts $fh "### $title"
    puts $fh "### \$ [join $args " "]"
    puts $fh "### [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]"
    puts $fh "----------------------------------------------------------------"
    
    if {[catch {exec {*}$args} result]} {
        puts $fh $result
        set rc 1
    } else {
        puts $fh $result
        set rc 0
    }
    puts $fh "\[exit: $rc\]"
    close $fh
}

# Run all commands
run_cmd "tasks audit --severity error" {*}$oc tasks audit --severity error
run_cmd "secrets audit" {*}$oc secrets audit
run_cmd "security audit" {*}$oc security audit
run_cmd "plugins doctor" {*}$oc plugins doctor
run_cmd "plugins deps" {*}$oc plugins deps
run_cmd "plugins registry" {*}$oc plugins registry
run_cmd "skills check" {*}$oc skills check
run_cmd "hooks check" {*}$oc hooks check
run_cmd "gateway status --deep" {*}$oc gateway status --deep
run_cmd "channels status --probe" {*}$oc channels status --probe
run_cmd "memory status --deep" {*}$oc memory status --deep
run_cmd "sessions --all-agents" {*}$oc sessions --all-agents
run_cmd "tasks list" {*}$oc tasks list
run_cmd "cron list" {*}$oc cron list

# Write footer to log file
set fh [open $out a]
puts $fh ""
puts $fh "================================================================"
puts $fh "Audit complete: [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]"
puts $fh "================================================================"
close $fh

puts "Audit complete. Output: $out"
