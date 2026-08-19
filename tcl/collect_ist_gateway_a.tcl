#!/usr/bin/env tclsh
# collect_ist_gateway_a.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Configuration and setup
set BASE_DIR [file normalize "~/.openclaw"]
set OUT_DIR [file join $BASE_DIR workspace vscode]
set NOW_UTC [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]
set NOW_LOCAL [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %Z"]
set TS [clock format [clock seconds] -format "%Y%m%d-%H%M%S"]

file mkdir $OUT_DIR

set IST_FILE [file join $OUT_DIR "IST-ZUSTAND_GATEWAY-A_NODE1.md"]
set INV_FILE [file join $OUT_DIR "ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md"]
set CFG_FILE [file join $OUT_DIR "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md"]
set ENV_FILE [file join $OUT_DIR "ENV-STATUS_GATEWAY-A_NODE1.md"]
set RUN_FILE [file join $OUT_DIR "RUN-$TS.md"]

set OPENCLAW_JSON [file join $BASE_DIR "openclaw.json"]
set ENV_DOT [file join $BASE_DIR ".env"]
set ENV_SYSTEMD [file join $BASE_DIR "gateway.systemd.env"]
set VSCODE_DIR [file join $BASE_DIR ".vscode"]

# System information gathering
set HOSTNAME_FQDN [exec hostname -f]
if {[catch {exec hostname -f} result]} {
    set HOSTNAME_FQDN [exec hostname]
}
set HOSTNAME_SHORT [exec hostname]
set ARCH [exec uname -m]
set KERNEL [exec uname -r]
set OS_PRETTY ""
if {[file exists "/etc/os-release"]} {
    set fd [open "/etc/os-release" r]
    while {[gets $fd line] != -1} {
        if {[string match "PRETTY_NAME=*" $line]} {
            set OS_PRETTY [string range $line 13 end]
            set OS_PRETTY [string trim $OS_PRETTY "\""]
            break
        }
    }
    close $fd
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

# Create IST file
set ist_fd [open $IST_FILE w]
puts $ist_fd "# IST-Zustand: Gateway A / Node 1"
puts $ist_fd ""
puts $ist_fd "Stand (lokal): $NOW_LOCAL  "
puts $ist_fd "Stand (UTC): $NOW_UTC"
puts $ist_fd ""
puts $ist_fd "## 1) Identitaet & System"
puts $ist_fd ""
puts $ist_fd "- Gateway: **A**"
puts $ist_fd "- Node: **1**"
puts $ist_fd "- Hostname (short): \\`${HOSTNAME_SHORT}\\`"
puts $ist_fd "- Hostname (FQDN): \\`${HOSTNAME_FQDN}\\`"
puts $ist_fd "- Architektur: \\`${ARCH}\\`"
puts $ist_fd "- Kernel: \\`${KERNEL}\\`"
puts $ist_fd "- OS: \\`${OS_PRETTY}\\`"
puts $ist_fd "- IPv4 (lokal): \\`${IPV4_ALL}\\`"
puts $ist_fd "- Public IPv4: \\`${PUBLIC_IP}\\`"
puts $ist_fd "- Tailscale IPv4: \\`${TAILSCALE_IP}\\`"
puts $ist_fd "- OpenClaw Version: \\`${OPENCLAW_VER}\\`"
puts $ist_fd "- Node.js Version: \\`${NODE_VER}\\`"
puts $ist_fd ""
puts $ist_fd "## 2) Arbeitsverzeichnisse"
puts $ist_fd ""
puts $ist_fd "- Basis: \\`${BASE_DIR}\\`"
puts $ist_fd "- Funktionell VSCode: \\`${VSCODE_DIR}\\`"
puts $ist_fd "- Workspace Doku: \\`${OUT_DIR}\\`"
puts $ist_fd ""
puts $ist_fd "## 3) Kernartefakte (Existenz)"
puts $ist_fd ""

set openclaw_json_status "fehlt"
if {[file exists $OPENCLAW_JSON]} {
    set openclaw_json_status "vorhanden"
}
puts $ist_fd "- \\`${OPENCLAW_JSON}\\`: $openclaw_json_status"

set env_dot_status "fehlt"
if {[file exists $ENV_DOT]} {
    set env_dot_status "vorhanden"
}
puts $ist_fd "- \\`${ENV_DOT}\\`: $env_dot_status"

set env_systemd_status "fehlt"
if {[file exists $ENV_SYSTEMD]} {
    set env_systemd_status "vorhanden"
}
puts $ist_fd "- \\`${ENV_SYSTEMD}\\`: $env_systemd_status"

set installs_json_status "fehlt"
if {[file exists [file join $BASE_DIR plugins installs.json]]} {
    set installs_json_status "vorhanden"
}
puts $ist_fd "- \\`${BASE_DIR}/plugins/installs.json\\`: $installs_json_status"

set plugin_skills_status "fehlt"
if {[file isdirectory [file join $BASE_DIR plugin-skills]]} {
    set plugin_skills_status "vorhanden"
}
puts $ist_fd "- \\`${BASE_DIR}/plugin-skills\\`: $plugin_skills_status"

close $ist_fd

# Create inventory file
set inv_fd [open $INV_FILE w]
puts $inv_fd "# Artefakt-Inventar: Gateway A / Node 1"
puts $inv_fd ""
puts $inv_fd "Stand: $NOW_LOCAL"
puts $inv_fd ""
puts $inv_fd "## Top-Level in ~/.openclaw"
puts $inv_fd ""
puts $inv_fd "\\`\\`\\`text"
if {[file isdirectory $BASE_DIR]} {
    set files [glob -nocomplain -dir $BASE_DIR *]
    foreach f $files {
        puts $inv_fd [file tail $f]
    }
}
puts $inv_fd "\\`\\`\\`"
puts $inv_fd ""
puts $inv_fd "## ~/.openclaw/.vscode"
puts $inv_fd ""
puts $inv_fd "\\`\\`\\`text"
if {[file isdirectory $VSCODE_DIR]} {
    exec ls -la $VSCODE_DIR | while {[gets stdin line] != -1} {
        puts $inv_fd $line
    }
} else {
    puts $inv_fd "(nicht vorhanden)"
}
puts $inv_fd "\\`\\`\\`"
puts $inv_fd ""
puts $inv_fd "## plugin-skills/"
puts $inv_fd ""
puts $inv_fd "\\`\\`\\`text"
if {[file isdirectory [file join $BASE_DIR plugin-skills]]} {
    set skill_files [glob -nocomplain -dir [file join $BASE_DIR plugin-skills] *]
    foreach sf $skill_files {
        puts $inv_fd [file tail $sf]
    }
} else {
    puts $inv_fd "(nicht vorhanden)"
}
puts $inv_fd "\\`\\`\\`"
puts $inv_fd ""
puts $inv_fd "## openclaw.json Backups"
puts $inv_fd ""
puts $inv_fd "\\`\\`\\`text"
set backup_files [glob -nocomplain $BASE_DIR/openclaw.json.bak*]
if {[llength $backup_files] > 0} {
    foreach bf $backup_files {
        puts $inv_fd [file tail $bf]
    }
} else {
    puts $inv_fd "(keine gefunden)"
}
puts $inv_fd "\\`\\`\\`"
close $inv_fd

# Create config snapshot file
set cfg_fd [open $CFG_FILE w]
puts $cfg_fd "# OpenClaw Config Snapshot: Gateway A / Node 1"
puts $cfg_fd ""
puts $cfg_fd "Stand: $NOW_LOCAL"
puts $cfg_fd ""
puts $cfg_fd "## Schluesselpositionen (grep)"
puts $cfg_fd ""
puts $cfg_fd "\\`\\`\\`text"
if {[file exists $OPENCLAW_JSON]} {
    if {[catch {exec grep -nE {"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"} $OPENCLAW_JSON} result]} {
        # Ignore errors in grep
    } else {
        puts $cfg_fd $result
    }
} else {
    puts $cfg_fd "openclaw.json fehlt"
}
puts $cfg_fd "\\`\\`\\`"
puts $cfg_fd ""
puts $cfg_fd "## Ausschnitt gateway/session/auth"
puts $cfg_fd ""
puts $cfg_fd "\\`\\`\\`json"
if {[file exists $OPENCLAW_JSON]} {
    set json_fd [open $OPENCLAW_JSON r]
    set lines [split [read $json_fd] "\n"]
    close $json_fd
    set start_line 579
    set end_line 779
    for {set i $start_line} {$i <= $end_line && $i < [llength $lines]} {incr i} {
        puts $cfg_fd [lindex $lines $i]
    }
} else {
    puts $cfg_fd "{ \"error\": \"openclaw.json fehlt\" }"
}
puts $cfg_fd "\\`\\`\\`"
close $cfg_fd

# Create environment status file
set env_fd [open $ENV_FILE w]
puts $env_fd "# ENV-Status: Gateway A / Node 1"
puts $env_fd ""
puts $env_fd "Stand: $NOW_LOCAL"
puts $env_fd ""
puts $env_fd "## Dateien"
puts $env_fd ""
puts $env_fd "\\`\\`\\`text"
if {[file exists $ENV_DOT] || [file exists $ENV_SYSTEMD]} {
    if {[file exists $ENV_DOT]} {
        exec ls -la $ENV_DOT | while {[gets stdin line] != -1} {
            puts $env_fd $line
        }
    }
    if {[file exists $ENV_SYSTEMD]} {
        exec ls -la $ENV_SYSTEMD | while {[gets stdin line] != -1} {
            puts $env_fd $line
        }
    }
}
puts $env_fd "\\`\\`\\`"
puts $env_fd ""
puts $env_fd "## .env (vollstaendig)"
puts $env_fd ""
puts $env_fd "\\`\\`\\`dotenv"
if {[file exists $ENV_DOT]} {
    set dot_fd [open $ENV_DOT r]
    puts $env_fd [read $dot_fd]
    close $dot_fd
} else {
    puts $env_fd "# .env fehlt"
}
puts $env_fd "\\`\\`\\`"
puts $env_fd ""
puts $env_fd "## gateway.systemd.env (vollstaendig)"
puts $env_fd ""
puts $env_fd "\\`\\`\\`dotenv"
if {[file exists $ENV_SYSTEMD]} {
    set systemd_fd [open $ENV_SYSTEMD r]
    puts $env_fd [read $systemd_fd]
    close $systemd_fd
} else {
    puts $env_fd "# gateway.systemd.env fehlt"
}
puts $env_fd "\\`\\`\\`"
close $env_fd

# Create run file
set run_fd [open $RUN_FILE w]
puts $run_fd "# Laufprotokoll Gateway A / Node 1"
puts $run_fd ""
puts $run_fd "- Zeit (lokal): $NOW_LOCAL"
puts $run_fd "- Zeit (UTC): $NOW_UTC"
puts $run_fd "- Script: [info script]"
puts $run_fd ""
puts $run_fd "## Erzeugte Dateien"
puts $run_fd ""
puts $run_fd "- [file tail $IST_FILE]"
puts $run_fd "- [file tail $INV_FILE]"
puts $run_fd "- [file tail $CFG_FILE]"
puts $run_fd "- [file tail $ENV_FILE]"
close $run_fd

# Output completion message
puts "OK: IST-Zustand erfasst."
if {[file isdirectory $OUT_DIR]} {
    set files [glob -nocomplain -dir $OUT_DIR *]
    foreach f $files {
        puts "- [file tail $f]"
    }
}
