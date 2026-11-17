#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "bff6ac167cc2c372b1194e87cf4c60d73d28196d6ac01f5d961af8363b596138", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "tcl"}
# collect_ist_gateway_b.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Konfiguration
set BASE_DIR [file normalize "~/.openclaw"]
set OUT_DIR [file join $BASE_DIR workspace vscode]
set NOW_UTC [clock format [clock seconds] -gmt 1 -format "%Y-%m-%dT%H:%M:%SZ"]
set NOW_LOCAL [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %Z"]
set TS [clock format [clock seconds] -format "%Y%m%d-%H%M%S"]

# Sicherstellen, dass das Ausgabeverzeichnis existiert
file mkdir $OUT_DIR

# Dateipfade definieren
set IST_FILE [file join $OUT_DIR "IST-ZUSTAND_GATEWAY-B_NODE7.md"]
set INV_FILE [file join $OUT_DIR "ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md"]
set CFG_FILE [file join $OUT_DIR "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md"]
set ENV_FILE [file join $OUT_DIR "ENV-STATUS_GATEWAY-B_NODE7.md"]
set RUN_FILE [file join $OUT_DIR "RUN-$TS.md"]

set OPENCLAW_JSON [file join $BASE_DIR "openclaw.json"]
set ENV_DOT [file join $BASE_DIR ".env"]
set ENV_SYSTEMD [file join $BASE_DIR "gateway.systemd.env"]
set VSCODE_DIR [file join $BASE_DIR ".vscode"]

# Systeminformationen sammeln
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
            set OS_PRETTY [string trim [string range $line 12 end] "\""]
            break
        }
    }
    close $fd
}
set IPV4_ALL ""
if {[catch {exec hostname -I} result]} {
    set result ""
}
set PUBLIC_IP ""
if {[catch {exec curl -4 -s --max-time 4 ifconfig.me} result]} {
    set result ""
}
set TAILSCALE_IP ""
if {[catch {exec tailscale ip -4} result]} {
    set result ""
}
set OPENCLAW_VER ""
if {[catch {exec openclaw --version} result]} {
    set result ""
}
set NODE_VER ""
if {[catch {exec node -v} result]} {
    set result ""
}

# Leere Werte auffüllen
if {$PUBLIC_IP eq ""} {
    set PUBLIC_IP "(nicht ermittelt)"
}
if {$TAILSCALE_IP eq ""} {
    set TAILSCALE_IP "(nicht ermittelt)"
}
if {$OPENCLAW_VER eq ""} {
    set OPENCLAW_VER "(nicht ermittelt)"
}
if {$NODE_VER eq ""} {
    set NODE_VER "(nicht ermittelt)"
}

# IST-Zustand erstellen
set ist_fd [open $IST_FILE w]
puts $ist_fd "# IST-Zustand: Gateway B / Node 7"
puts $ist_fd ""
puts $ist_fd "Stand (lokal): $NOW_LOCAL  "
puts $ist_fd "Stand (UTC): $NOW_UTC"
puts $ist_fd ""
puts $ist_fd "## 1) Identität & System"
puts $ist_fd ""
puts $ist_fd "- Gateway: **B**"
puts $ist_fd "- Node: **7**"
puts $ist_fd "- Hostname (short): \\`$HOSTNAME_SHORT\\`"
puts $ist_fd "- Hostname (FQDN): \\`$HOSTNAME_FQDN\\`"
puts $ist_fd "- Architektur: \\`$ARCH\\`"
puts $ist_fd "- Kernel: \\`$KERNEL\\`"
puts $ist_fd "- OS: \\`$OS_PRETTY\\`"
puts $ist_fd "- IPv4 (lokal): \\`$IPV4_ALL\\`"
puts $ist_fd "- Public IPv4: \\`$PUBLIC_IP\\`"
puts $ist_fd "- Tailscale IPv4: \\`$TAILSCALE_IP\\`"
puts $ist_fd "- OpenClaw Version: \\`$OPENCLAW_VER\\`"
puts $ist_fd "- Node.js Version: \\`$NODE_VER\\`"
puts $ist_fd ""
puts $ist_fd "## 2) Arbeitsverzeichnisse"
puts $ist_fd ""
puts $ist_fd "- Basis: \\`$BASE_DIR\\`"
puts $ist_fd "- Funktionell VSCode: \\`$VSCODE_DIR\\`"
puts $ist_fd "- Workspace Doku: \\`$OUT_DIR\\`"
puts $ist_fd ""
puts $ist_fd "## 3) Kernartefakte (Existenz)"
puts $ist_fd ""

set openclaw_json_status "fehlt"
if {[file exists $OPENCLAW_JSON]} {
    set openclaw_json_status "vorhanden"
}
puts $ist_fd "- \\`$OPENCLAW_JSON\\`: $openclaw_json_status"

set env_dot_status "fehlt"
if {[file exists $ENV_DOT]} {
    set env_dot_status "vorhanden"
}
puts $ist_fd "- \\`$ENV_DOT\\`: $env_dot_status"

set env_systemd_status "fehlt"
if {[file exists $ENV_SYSTEMD]} {
    set env_systemd_status "vorhanden"
}
puts $ist_fd "- \\`$ENV_SYSTEMD\\`: $env_systemd_status"

set installs_json_status "fehlt"
if {[file exists [file join $BASE_DIR plugins installs.json]]} {
    set installs_json_status "vorhanden"
}
puts $ist_fd "- \\`[file join $BASE_DIR plugins installs.json]\\`: $installs_json_status"

set plugin_skills_status "fehlt"
if {[file isdirectory [file join $BASE_DIR plugin-skills]]} {
    set plugin_skills_status "vorhanden"
}
puts $ist_fd "- \\`[file join $BASE_DIR plugin-skills]\\`: $plugin_skills_status"

puts $ist_fd ""
puts $ist_fd "## 4) Hinweis"
puts $ist_fd ""
puts $ist_fd "Diese Datei wird bei jedem Lauf neu geschrieben."
puts $ist_fd "Zusätzlich wird ein Laufprotokoll als \\`RUN-*.md\\` erzeugt."
close $ist_fd

# Artefakt-Inventar erstellen
set inv_fd [open $INV_FILE w]
puts $inv_fd "# Artefakt-Inventar: Gateway B / Node 7"
puts $inv_fd ""
puts $inv_fd "Stand: $NOW_LOCAL"
puts $inv_fd ""
puts $inv_fd "## Top-Level in ~/.openclaw"
puts $inv_fd ""
puts $inv_fd "\\`\\`\\`text"
if {[file isdirectory $BASE_DIR]} {
    foreach item [glob -nocomplain -dir $BASE_DIR *] {
        puts $inv_fd [file tail $item]
    }
}
puts $inv_fd "\\`\\`\\`"
puts $inv_fd ""
puts $inv_fd "## ~/.openclaw/.vscode"
puts $inv_fd ""
puts $inv_fd "\\`\\`\\`text"
if {[file isdirectory $VSCODE_DIR]} {
    catch {exec ls -la $VSCODE_DIR} result
    puts $inv_fd $result
} else {
    puts $inv_fd "(nicht vorhanden)"
}
puts $inv_fd "\\`\\`\\`"
puts $inv_fd ""
puts $inv_fd "## plugin-skills/"
puts $inv_fd ""
puts $inv_fd "\\`\\`\\`text"
if {[file isdirectory [file join $BASE_DIR plugin-skills]]} {
    foreach item [glob -nocomplain -dir [file join $BASE_DIR plugin-skills] *] {
        puts $inv_fd [file tail $item]
    }
} else {
    puts $inv_fd "(nicht vorhanden)"
}
puts $inv_fd "\\`\\`\\`"
puts $inv_fd ""
puts $inv_fd "## openclaw.json Backups"
puts $inv_fd ""
puts $inv_fd "\\`\\`\\`text"
set backups_found 0
foreach file [glob -nocomplain [file join $BASE_DIR "openclaw.json.bak*"]] {
    puts $inv_fd [file tail $file]
    set backups_found 1
}
if {!$backups_found} {
    puts $inv_fd "(keine gefunden)"
}
puts $inv_fd "\\`\\`\\`"
close $inv_fd

# OpenClaw Config Snapshot erstellen
set cfg_fd [open $CFG_FILE w]
puts $cfg_fd "# OpenClaw Config Snapshot: Gateway B / Node 7"
puts $cfg_fd ""
puts $cfg_fd "Stand: $NOW_LOCAL"
puts $cfg_fd ""
puts $cfg_fd "## Schlüsselpositionen (grep)"
puts $cfg_fd ""
puts $cfg_fd "\\`\\`\\`text"
if {[file exists $OPENCLAW_JSON]} {
    set fd [open $OPENCLAW_JSON r]
    set line_num 1
    while {[gets $fd line] != -1} {
        if {[regexp {"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"} $line]} {
            puts $cfg_fd "$line_num:$line"
        }
        incr line_num
    }
    close $fd
} else {
    puts $cfg_fd "openclaw.json fehlt"
}
puts $cfg_fd "\\`\\`\\`"
puts $cfg_fd ""
puts $cfg_fd "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)"
puts $cfg_fd ""
puts $cfg_fd "\\`\\`\\`json"
if {[file exists $OPENCLAW_JSON]} {
    set fd [open $OPENCLAW_JSON r]
    set line_count 0
    while {[gets $fd line] != -1 && $line_count < 780} {
        if {$line_count >= 579} {
            puts $cfg_fd $line
        }
        incr line_count
    }
    close $fd
} else {
    puts $cfg_fd "{ \"error\": \"openclaw.json fehlt\" }"
}
puts $cfg_fd "\\`\\`\\`"
close $cfg_fd

# ENV-Status erstellen
set env_fd [open $ENV_FILE w]
puts $env_fd "# ENV-Status: Gateway B / Node 7"
puts $env_fd ""
puts $env_fd "Stand: $NOW_LOCAL"
puts $env_fd ""
puts $env_fd "## Dateien"
puts $env_fd ""
puts $env_fd "\\`\\`\\`text"
catch {exec ls -la $ENV_DOT $ENV_SYSTEMD} result
puts $env_fd $result
puts $env_fd "\\`\\`\\`"
puts $env_fd ""
puts $env_fd "## .env (vollständig, ungefiltert)"
puts $env_fd ""
puts $env_fd "\\`\\`\\`dotenv"
if {[file exists $ENV_DOT]} {
    set fd [open $ENV_DOT r]
    while {[gets $fd line] != -1} {
        puts $env_fd $line
    }
    close $fd
} else {
    puts $env_fd "# .env fehlt"
}
puts $env_fd "\\`\\`\\`"
puts $env_fd ""
puts $env_fd "## gateway.systemd.env (vollständig, ungefiltert)"
puts $env_fd ""
puts $env_fd "\\`\\`\\`dotenv"
if {[file exists $ENV_SYSTEMD]} {
    set fd [open $ENV_SYSTEMD r]
    while {[gets $fd line] != -1} {
        puts $env_fd $line
    }
    close $fd
} else {
    puts $env_fd "# gateway.systemd.env fehlt"
}
puts $env_fd "\\`\\`\\`"
close $env_fd

# Laufprotokoll erstellen
set run_fd [open $RUN_FILE w]
puts $run_fd "# Laufprotokoll Gateway B / Node 7"
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

# Erfolgsmeldung ausgeben
puts "OK: IST-Zustand erfasst."
puts "Ausgabeordner: $OUT_DIR"
puts "Dateien:"
foreach file [glob -nocomplain -dir $OUT_DIR *] {
    puts "- [file tail $file]"
}
