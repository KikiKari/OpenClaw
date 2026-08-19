#!/usr/bin/env tclsh
# post-nodes-report.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Pfade
set DASHBOARD_PATH [file join [file dirname [file dirname [info script]]] dashboards nodes-overview.md]
set REPORT_LOG [file join [file dirname [file dirname [info script]]] logs nodes-report.log]

# Farbcodes
array set C [list \
  green \033\[32m \
  yellow \033\[33m \
  red \033\[31m \
  reset \033\[0m \
]

proc postReport {} {
  global DASHBOARD_PATH REPORT_LOG C

  # Inhalt lesen
  if {[catch {open $DASHBOARD_PATH r} fd]} {
    puts stderr "${C(red)}❌ Fehler beim Lesen der Dashboard-Datei:${C(reset)} $fd"
    return
  }
  set content [read $fd]
  close $fd

  # JSON escapen und Zeilenumbrüche maskieren
  set escaped_content [string map {"\n" "\\n" "\"" "\\\""} $content]
  set messageCmd "openclaw message send --target=main --message \"$escaped_content\""

  # Nachricht senden
  if {[catch {exec {*}$messageCmd} result]} {
    puts stderr "${C(red)}❌ Fehler beim Senden der Nachricht:${C(reset)} $result"
    set log_fd [open $REPORT_LOG a]
    puts $log_fd "\[[clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]\] Failed to post: $result"
    close $log_fd
  } else {
    puts "${C(green)}✅ Report erfolgreich im 'main'-Channel gepostet.${C(reset)}"
    set log_fd [open $REPORT_LOG a]
    puts $log_fd "\[[clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt true]\] Report posted."
    close $log_fd
  }
}

# Hauptausführung
puts "${C(yellow)}📤 Sende Nodes-Übersicht in 'main'...${C(reset)}"
postReport
