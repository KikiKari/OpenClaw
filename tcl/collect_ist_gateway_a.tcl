#!/usr/bin/env tclsh8.6
# collect_ist_gateway_a.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6
package require http 2.7

# Helper functions for shell-like operations
proc exec_with_fallback {cmd fallback} {
    if {[catch {exec {*}$cmd} result]} {
        return $fallback
    }
    return $result
}

proc file_exists {filename} {
    return [expr {[file exists $filename] ? "vorhanden" : "fehlt"}]
}

proc dir_exists {dirname} {
    return [expr {[file isdirectory $dirname] ? "vorhanden" : "fehlt"}]
}

proc read_file {filename} {
    if {[file exists $filename]} {
        set fh [open $filename r]
        set content [read $fh]
        close $fh
        return $content
    } else {
        return ""
    }
}

proc write_file {filename content} {
    set fh [open $filename w]
    puts -nonewline $fh $content
    close $fh
}

# Set variables similar to bash script
set BASE_DIR [file normalize "$env(HOME)/.openclaw"]
set OUT_DIR [file normalize "$BASE_DIR/workspace/vscode"]

# Get current time in different formats
set NOW_UTC [clock format [clock seconds] -gmt true -format "%Y-%m-%dT%H:%M:%SZ"]
set NOW_LOCAL [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %Z"]
set TS [clock format [clock seconds] -format "%Y%m%d-%H%M%S"]

# Create output directory
file mkdir $OUT_DIR

# Define output files
set IST_FILE [file join $OUT_DIR "IST-ZUSTAND_GATEWAY-A_NODE1.md"]
set INV_FILE [file join $OUT_DIR "ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md"]
set CFG_FILE [file join $OUT_DIR "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md"]
set ENV_FILE [file join $OUT_DIR "ENV-STATUS_GATEWAY-A_NODE1.md"]
set RUN_FILE [file join $OUT_DIR "RUN-$TS.md"]

# Define file paths
set OPENCLAW_JSON [file join $BASE_DIR "openclaw.json"]
set ENV_DOT [file join $BASE_DIR ".env"]
set ENV_SYSTEMD [file join $BASE_DIR "gateway.systemd.env"]
set VSCODE_DIR [file join $BASE_DIR ".vscode"]

# Get system information
set HOSTNAME_FQDN [exec_with_fallback {hostname -f} [exec hostname]]
set HOSTNAME_SHORT [exec hostname]
set ARCH [exec uname -m]
set KERNEL [exec uname -r]
set OS_PRETTY "(nicht ermittelt)"
if {[file exists "/etc/os-release"]} {
    set os_fh [open "/etc/os-release" r]
    while {[gets $os_fh line] != -1} {
        if {[string match "PRETTY_NAME=*" $line]} {
            set OS_PRETTY [string range $line 12 end]
            set OS_PRETTY [string trim $OS_PRETTY "\""]
            break
        }
    }
    close $os_fh
}
set IPV4_ALL [exec_with_fallback {hostname -I} ""]
set PUBLIC_IP [exec_with_fallback {curl -4 -s --max-time 4 ifconfig.me} "(nicht ermittelt)"]
set TAILSCALE_IP [exec_with_fallback {tailscale ip -4} "(nicht ermittelt)"]
set OPENCLAW_VER [exec_with_fallback {openclaw --version} "(nicht ermittelt)"]
set NODE_VER [exec_with_fallback {node -v} "(nicht ermittelt)"]

# Ensure variables have values
if {$PUBLIC_IP eq ""} {set PUBLIC_IP "(nicht ermittelt)"}
if {$TAILSCALE_IP eq ""} {set TAILSCALE_IP "(nicht ermittelt)"}
if {$OPENCLAW_VER eq ""} {set OPENCLAW_VER "(nicht ermittelt)"}
if {$NODE_VER eq ""} {set NODE_VER "(nicht ermittelt)"}

# Create IST-Zustand file
set ist_content "# IST-Zustand: Gateway A / Node 1

Stand (lokal): $NOW_LOCAL  
Stand (UTC): $NOW_UTC

## 1) Identitaet & System

- Gateway: **A**
- Node: **1**
- Hostname (short): `$HOSTNAME_SHORT`
- Hostname (FQDN): `$HOSTNAME_FQDN`
- Architektur: `$ARCH`
- Kernel: `$KERNEL`
- OS: `$OS_PRETTY`
- IPv4 (lokal): `$IPV4_ALL`
- Public IPv4: `$PUBLIC_IP`
- Tailscale IPv4: `$TAILSCALE_IP`
- OpenClaw Version: `$OPENCLAW_VER`
- Node.js Version: `$NODE_VER`

## 2) Arbeitsverzeichnisse

- Basis: `$BASE_DIR`
- Funktionell VSCode: `$VSCODE_DIR`
- Workspace Doku: `$OUT_DIR`

## 3) Kernartefakte (Existenz)

- `$OPENCLAW_JSON`: [expr {[file exists $OPENCLAW_JSON] ? "vorhanden" : "fehlt"}]
- `$ENV_DOT`: [expr {[file exists $ENV_DOT] ? "vorhanden" : "fehlt"}]
- `$ENV_SYSTEMD`: [expr {[file exists $ENV_SYSTEMD] ? "vorhanden" : "fehlt"}]
- `[file join $BASE_DIR plugins installs.json]`: [expr {[file exists [file join $BASE_DIR plugins installs.json]] ? "vorhanden" : "fehlt"}]
- `[file join $BASE_DIR plugin-skills]`: [expr {[file isdirectory [file join $BASE_DIR plugin-skills]] ? "vorhanden" : "fehlt"}]
"

write_file $IST_FILE $ist_content

# Create Artefakt-Inventar file
set inv_content "# Artefakt-Inventar: Gateway A / Node 1

Stand: $NOW_LOCAL

## Top-Level in ~/.openclaw

```text
"
if {[file isdirectory $BASE_DIR]} {
    foreach item [lsort [glob -nocomplain -directory $BASE_DIR *]] {
        append inv_content [file tail $item]\n
    }
} else {
    append inv_content "(nicht vorhanden)\n"
}
append inv_content "```

## ~/.openclaw/.vscode

```text
"
if {[file isdirectory $VSCODE_DIR]} {
    if {[catch {exec ls -la $VSCODE_DIR} result]} {
        append inv_content "(Fehler beim Lesen)\n"
    } else {
        append inv_content $result\n
    }
} else {
    append inv_content "(nicht vorhanden)\n"
}
append inv_content "```

## plugin-skills/

```text
"
if {[file isdirectory [file join $BASE_DIR plugin-skills]]} {
    foreach item [lsort [glob -nocomplain -directory [file join $BASE_DIR plugin-skills] *]] {
        append inv_content [file tail $item]\n
    }
} else {
    append inv_content "(nicht vorhanden)\n"
}
append inv_content "```

## openclaw.json Backups

```text
"
set backup_files [glob -nocomplain -directory $BASE_DIR openclaw.json.bak*]
if {[llength $backup_files] > 0} {
    foreach file $backup_files {
        append inv_content [file tail $file]\n
    }
} else {
    append inv_content "(keine gefunden)\n"
}
append inv_content "```
"

write_file $INV_FILE $inv_content

# Create OpenClaw Config Snapshot file
set cfg_content "# OpenClaw Config Snapshot: Gateway A / Node 1

Stand: $NOW_LOCAL

## Schluesselpositionen (grep)

```text
"
if {[file exists $OPENCLAW_JSON]} {
    set json_content [read_file $OPENCLAW_JSON]
    foreach pattern {"gateway" "session" "dmScope" "auth" "secrets" "tools" "plugins" "profile" "alsoAllow" "denyCommands"} {
        foreach line [split $json_content \n] {
            if {[string match "*\"$pattern\"*" $line]} {
                append cfg_content $line\n
            }
        }
    }
} else {
    append cfg_content "openclaw.json fehlt\n"
}
append cfg_content "```

## Ausschnitt gateway/session/auth

```json
"
if {[file exists $OPENCLAW_JSON]} {
    set json_lines [split [read_file $OPENCLAW_JSON] \n]
    set start_line 579
    set end_line 779
    set line_count [llength $json_lines]
    if {$start_line < $line_count} {
        set end_idx [expr {$end_line < $line_count ? $end_line : $line_count - 1}]
        for {set i $start_line} {$i <= $end_idx} {incr i} {
            append cfg_content [lindex $json_lines $i]\n
        }
    }
} else {
    append cfg_content "{ \"error\": \"openclaw.json fehlt\" }\n"
}
append cfg_content "```
"

write_file $CFG_FILE $cfg_content

# Create ENV-Status file
set env_content "# ENV-Status: Gateway A / Node 1

Stand: $NOW_LOCAL

## Dateien

```text
"
if {[file exists $ENV_DOT] || [file exists $ENV_SYSTEMD]} {
    if {[file exists $ENV_DOT]} {
        append env_content "-rwxr-xr-x 1 user user [file size $ENV_DOT] [clock format [file mtime $ENV_DOT] -format "%b %d %H:%M"] [file tail $ENV_DOT]\n"
    }
    if {[file exists $ENV_SYSTEMD]} {
        append env_content "-rwxr-xr-x 1 user user [file size $ENV_SYSTEMD] [clock format [file mtime $ENV_SYSTEMD] -format "%b %d %H:%M"] [file tail $ENV_SYSTEMD]\n"
    }
}
append env_content "```

## .env (vollstaendig)

```dotenv
"
if {[file exists $ENV_DOT]} {
    append env_content [read_file $ENV_DOT]
} else {
    append env_content "# .env fehlt\n"
}
append env_content "```

## gateway.systemd.env (vollstaendig)

```dotenv
"
if {[file exists $ENV_SYSTEMD]} {
    append env_content [read_file $ENV_SYSTEMD]
} else {
    append env_content "# gateway.systemd.env fehlt\n"
}
append env_content "```
"

write_file $ENV_FILE $env_content

# Create Laufprotokoll file
set run_content "# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): $NOW_LOCAL
- Zeit (UTC): $NOW_UTC
- Script: [file normalize $argv0]

## Erzeugte Dateien

- [file tail $IST_FILE]
- [file tail $INV_FILE]
- [file tail $CFG_FILE]
- [file tail $ENV_FILE]
"

write_file $RUN_FILE $run_content

# Print success message
puts "OK: IST-Zustand erfasst."
if {[file isdirectory $OUT_DIR]} {
    foreach file [lsort [glob -nocomplain -directory $OUT_DIR *]] {
        puts "- [file tail $file]"
    }
}
