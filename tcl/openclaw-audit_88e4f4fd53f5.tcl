#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "af7d7924265eddc27da440fc840f5dc84042261dd24798ae707c4b0c303f93fc", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "tcl"}
# openclaw-audit.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# OpenClaw read-only audit/diagnostic sweep
# Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

# Bestimme das Verzeichnis des Skripts
set script_dir [file dirname [info script]]
set date_stamp [clock format [clock seconds] -format "%Y-%m-%d"]
set out [file join $script_dir "openclaw-audit-$date_stamp.log"]

set oc "openclaw --no-color"

# Hilfsfunktion zur Ausführung von Befehlen und Protokollierung
proc run_cmd {title args} {
    global out oc
    set timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S%z"]
    
    # Öffne die Logdatei im Anhang-Modus
    set fh [open $out a]
    
    puts $fh ""
    puts $fh "----------------------------------------------------------------"
    puts $fh "### $title"
    puts $fh "### \$ [join $args]"
    puts $fh "### $timestamp"
    puts $fh "----------------------------------------------------------------"
    
    # Führe den Befehl aus und erfasse stdout/stderr
    if {[catch {exec {*}$args 2>@1} result]} {
        set exit_code [lindex [split $result \n] end]
        set output [join [lrange [split $result \n] 0 end-1] \n]
        puts $fh $output
        puts $fh "\[exit: $exit_code\]"
    } else {
        puts $fh $result
        puts $fh "\[exit: 0\]"
    }
    
    close $fh
}

# Initialisiere die Logdatei mit Header-Informationen
set fh [open $out w]

puts $fh "================================================================"
puts $fh "OpenClaw audit run"
puts $fh "Started:  [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S%z"]"
if {[catch {exec hostname} hostname_result]} {
    set hostname_result "unknown"
}
puts $fh "Host:     $hostname_result"

if {[catch {exec whoami} whoami_result]} {
    set whoami_result "unknown"
}
puts $fh "User:     $whoami_result"

if {[catch {exec openclaw --version} version_result]} {
    set version_result "unknown"
}
puts $fh "Version:  $version_result"
puts $fh "Output:   $out"
puts $fh "================================================================"

close $fh

# Führe alle Audit-Befehle aus
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

# Füge Abschlussmeldung hinzu
set fh [open $out a]
puts $fh ""
puts $fh "================================================================"
puts $fh "Audit complete: [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S%z"]"
puts $fh "================================================================"
close $fh

puts "Audit complete. Output: $out"
