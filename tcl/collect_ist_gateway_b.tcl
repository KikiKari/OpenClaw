#!/usr/bin/env tclsh
# collect_ist_gateway_b.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Setzen der Umgebungsvariablen und Zeitstempel
set BASE_DIR [file normalize "~/.openclaw"]
set OUT_DIR [file join $BASE_DIR workspace vscode]
set NOW_UTC [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]
set NOW_LOCAL [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %Z"]
set TS [clock format [clock seconds] -format "%Y%m%d-%H%M%S"]

# Erstellen des Ausgabeverzeichnisses
file mkdir $OUT_DIR

# Dateipfade definieren
set IST_FILE [file join $OUT_DIR "IST-ZUSTAND_GATEWAY-B_NODE7.md"]
set INV_FILE [file join $OUT_DIR "ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md"]
set CFG_FILE [file join $OUT_DIR "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md"]
set ENV_FILE [file join $OUT_DIR "ENV-STATUS_GATEWAY-B_NODE7.md"]
set RUN_FILE [file join $OUT_DIR "RUN-$TS.md"]

# Weitere Dateipfade
set OPENCLAW_JSON [file join $BASE_DIR "openclaw.json"]
set ENV_DOT [file join $BASE_DIR ".env"]
set ENV_SYSTEMD [file join $BASE_DIR "gateway.systemd.env"]
set VSCODE_DIR [file join $BASE_DIR ".vscode"]

# Hostinformationen sammeln
set HOSTNAME_FQDN [exec hostname -f]
if {[catch {exec hostname -f} result]} {
    set HOSTNAME_FQDN [exec hostname]
}
set HOSTNAME_SHORT [exec hostname]
set ARCH [exec uname -m]
set KERNEL [exec uname -r]
set OS_PRETTY ""
if {[file exists "/etc/os-release"]} {
    set os_release [exec cat "/etc/os-release"]
    foreach line [split $os_release "\n"] {
        if {[string match "PRETTY_NAME=*" $line]} {
            set OS_PRETTY [string range $line 12 end]
            set OS_PRETTY [string trim $OS_PRETTY "\""]
            break
        }
    }
}

set IPV4_ALL ""
if {[catch {exec hostname -I} result]} {
    set IPV4_ALL $result
} else {
    set IPV4_ALL "(nicht ermittelt)"
}

set PUBLIC_IP ""
if {[catch {exec curl -4 -s --max-time 4 ifconfig.me} result]} {
    set PUBLIC_IP $result
} else {
    set PUBLIC_IP "(nicht ermittelt)"
}

set TAILSCALE_IP ""
if {[catch {exec tailscale ip -4} result]} {
    set TAILSCALE_IP [lindex [split $result "\n"] 0]
} else {
    set TAILSCALE_IP "(nicht ermittelt)"
}

set OPENCLAW_VER ""
if {[catch {exec openclaw --version} result]} {
    set OPENCLAW_VER $result
} else {
    set OPENCLAW_VER "(nicht ermittelt)"
}

set NODE_VER ""
if {[catch {exec node -v} result]} {
    set NODE_VER $result
} else {
    set NODE_VER "(nicht ermittelt)"
}

# IST-Datei erstellen
set ist_fh [open $IST_FILE w]
puts $ist_fh "# IST-Zustand: Gateway B / Node 7"
puts $ist_fh ""
puts $ist_fh "Stand (lokal): $NOW_LOCAL  "
puts $ist_fh "Stand (UTC): $NOW_UTC"
puts $ist_fh ""
puts $ist_fh "## 1) Identität & System"
puts $ist_fh ""
puts $ist_fh "- Gateway: **B**"
puts $ist_fh "- Node: **7**"
puts $ist_fh "- Hostname (short): \\`$HOSTNAME_SHORT\\`"
puts $ist_fh "- Hostname (FQDN): \\`$HOSTNAME_FQDN\\`"
puts $ist_fh "- Architektur: \\`$ARCH\\`"
puts $ist_fh "- Kernel: \\`$KERNEL\\`"
puts $ist_fh "- OS: \\`$OS_PRETTY\\`"
puts $ist_fh "- IPv4 (lokal): \\`$IPV4_ALL\\`"
puts $ist_fh "- Public IPv4: \\`$PUBLIC_IP\\`"
puts $ist_fh "- Tailscale IPv4: \\`$TAILSCALE_IP\\`"
puts $ist_fh "- OpenClaw Version: \\`$OPENCLAW_VER\\`"
puts $ist_fh "- Node.js Version: \\`$NODE_VER\\`"
puts $ist_fh ""
puts $ist_fh "## 2) Arbeitsverzeichnisse"
puts $ist_fh ""
puts $ist_fh "- Basis: \\`$BASE_DIR\\`"
puts $ist_fh "- Funktionell VSCode: \\`$VSCODE_DIR\\`"
puts $ist_fh "- Workspace Doku: \\`$OUT_DIR\\`"
puts $ist_fh ""
puts $ist_fh "## 3) Kernartefakte (Existenz)"
puts $ist_fh ""

set openclaw_json_status "fehlt"
if {[file exists $OPENCLAW_JSON]} {
    set openclaw_json_status "vorhanden"
}
puts $ist_fh "- \\`$OPENCLAW_JSON\\`: $openclaw_json_status"

set env_dot_status "fehlt"
if {[file exists $ENV_DOT]} {
    set env_dot_status "vorhanden"
}
puts $ist_fh "- \\`$ENV_DOT\\`: $env_dot_status"

set env_systemd_status "fehlt"
if {[file exists $ENV_SYSTEMD]} {
    set env_systemd_status "vorhanden"
}
puts $ist_fh "- \\`$ENV_SYSTEMD\\`: $env_systemd_status"

set installs_json_status "fehlt"
if {[file exists [file join $BASE_DIR plugins installs.json]]} {
    set installs_json_status "vorhanden"
}
puts $ist_fh "- \\`$BASE_DIR/plugins/installs.json\\`: $installs_json_status"

set plugin_skills_status "fehlt"
if {[file isdirectory [file join $BASE_DIR plugin-skills]]} {
    set plugin_skills_status "vorhanden"
}
puts $ist_fh "- \\`$BASE_DIR/plugin-skills\\`: $plugin_skills_status"

puts $ist_fh ""
puts $ist_fh "## 4) Hinweis"
puts $ist_fh ""
puts $ist_fh "Diese Datei wird bei jedem Lauf neu geschrieben."
puts $ist_fh "Zusätzlich wird ein Laufprotokoll als \\`RUN-*.md\\` erzeugt."
close $ist_fh

# Inventar-Datei erstellen
set inv_fh [open $INV_FILE w]
puts $inv_fh "# Artefakt-Inventar: Gateway B / Node 7"
puts $inv_fh ""
puts $inv_fh "Stand: $NOW_LOCAL"
puts $inv_fh ""
puts $inv_fh "## Top-Level in ~/.openclaw"
puts $inv_fh ""
puts $inv_fh "\\`\\`\\`text"
if {[file exists $BASE_DIR]} {
    set files [glob -nocomplain -dir $BASE_DIR *]
    foreach f $files {
        puts $inv_fh [file tail $f]
    }
}
puts $inv_fh "\\`\\`\\`"
puts $inv_fh ""
puts $inv_fh "## ~/.openclaw/.vscode"
puts $inv_fh ""
puts $inv_fh "\\`\\`\\`text"
if {[file isdirectory $VSCODE_DIR]} {
    set dir_content [exec ls -la $VSCODE_DIR]
    puts $inv_fh $dir_content
} else {
    puts $inv_fh "(nicht vorhanden)"
}
puts $inv_fh "\\`\\`\\`"
puts $inv_fh ""
puts $inv_fh "## plugin-skills/"
puts $inv_fh ""
puts $inv_fh "\\`\\`\\`text"
if {[file isdirectory [file join $BASE_DIR plugin-skills]]} {
    set skill_files [glob -nocomplain -dir [file join $BASE_DIR plugin-skills] *]
    foreach sf $skill_files {
        puts $inv_fh [file tail $sf]
    }
} else {
    puts $inv_fh "(nicht vorhanden)"
}
puts $inv_fh "\\`\\`\\`"
puts $inv_fh ""
puts $inv_fh "## openclaw.json Backups"
puts $inv_fh ""
puts $inv_fh "\\`\\`\\`text"
set backup_files [glob -nocomplain $BASE_DIR/openclaw.json.bak*]
if {[llength $backup_files] > 0} {
    foreach bf $backup_files {
        puts $inv_fh [file tail $bf]
    }
} else {
    puts $inv_fh "(keine gefunden)"
}
puts $inv_fh "\\`\\`\\`"
close $inv_fh

# Konfigurations-Snapshot erstellen
set cfg_fh [open $CFG_FILE w]
puts $cfg_fh "# OpenClaw Config Snapshot: Gateway B / Node 7"
puts $cfg_fh ""
puts $cfg_fh "Stand: $NOW_LOCAL"
puts $cfg_fh ""
puts $cfg_fh "## Schlüsselpositionen (grep)"
puts $cfg_fh ""
puts $cfg_fh "\\`\\`\\`text"
if {[file exists $OPENCLAW_JSON]} {
    set grep_result ""
    if {[catch {exec grep -nE {"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"} $OPENCLAW_JSON} result]} {
        # Keine Treffer, leer lassen
    } else {
        puts $cfg_fh $result
    }
} else {
    puts $cfg_fh "openclaw.json fehlt"
}
puts $cfg_fh "\\`\\`\\`"
puts $cfg_fh ""
puts $cfg_fh "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)"
puts $cfg_fh ""
puts $cfg_fh "\\`\\`\\`json"
if {[file exists $OPENCLAW_JSON]} {
    set lines [split [exec cat $OPENCLAW_JSON] "\n"]
    set start_line 580
    set end_line 780
    set total_lines [llength $lines]
    
    for {set i [expr {$start_line - 1}]} {$i < $end_line && $i < $total_lines} {incr i} {
        if {$i >= 0} {
            puts $cfg_fh [lindex $lines $i]
        }
    }
} else {
    puts $cfg_fh "{ \"error\": \"openclaw.json fehlt\" }"
}
puts $cfg_fh "\\`\\`\\`"
close $cfg_fh

# ENV-Status erstellen
set env_fh [open $ENV_FILE w]
puts $env_fh "# ENV-Status: Gateway B / Node 7"
puts $env_fh ""
puts $env_fh "Stand: $NOW_LOCAL"
puts $env_fh ""
puts $env_fh "## Dateien"
puts $env_fh ""
puts $env_fh "\\`\\`\\`text"
set file_list [list $ENV_DOT $ENV_SYSTEMD]
foreach ef $file_list {
    if {[file exists $ef]} {
        set stat_info [file mtime $ef]
        puts $env_fh [format "%-30s %s" [file tail $ef] [clock format $stat_info]]
    }
}
puts $env_fh "\\`\\`\\`"
puts $env_fh ""
puts $env_fh "## .env (vollständig, ungefiltert)"
puts $env_fh ""
puts $env_fh "\\`\\`\\`dotenv"
if {[file exists $ENV_DOT]} {
    set env_content [exec cat $ENV_DOT]
    puts $env_fh $env_content
} else {
    puts $env_fh "# .env fehlt"
}
puts $env_fh "\\`\\`\\`"
puts $env_fh ""
puts $env_fh "## gateway.systemd.env (vollständig, ungefiltert)"
puts $env_fh ""
puts $env_fh "\\`\\`\\`dotenv"
if {[file exists $ENV_SYSTEMD]} {
    set systemd_content [exec cat $ENV_SYSTEMD]
    puts $env_fh $systemd_content
} else {
    puts $env_fh "# gateway.systemd.env fehlt"
}
puts $env_fh "\\`\\`\\`"
close $env_fh

# Run-Datei erstellen
set run_fh [open $RUN_FILE w]
puts $run_fh "# Laufprotokoll Gateway B / Node 7"
puts $run_fh ""
puts $run_fh "- Zeit (lokal): $NOW_LOCAL"
puts $run_fh "- Zeit (UTC): $NOW_UTC"
puts $run_fh "- Script: [info script]"
puts $run_fh ""
puts $run_fh "## Erzeugte Dateien"
puts $run_fh ""
puts $run_fh "- [file tail $IST_FILE]"
puts $run_fh "- [file tail $INV_FILE]"
puts $run_fh "- [file tail $CFG_FILE]"
puts $run_fh "- [file tail $ENV_FILE]"
close $run_fh

# Ausgabe auf Konsole
puts "OK: IST-Zustand erfasst."
puts "Ausgabeordner: $OUT_DIR"
puts "Dateien:"
set output_files [glob -nocomplain -dir $OUT_DIR *]
foreach of $output_files {
    puts "- [file tail $of]"
}
