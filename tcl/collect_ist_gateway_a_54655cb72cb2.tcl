#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "f30fa2de3822452162ad95dc3bcb2adb844668431e839716aa3b4440f5e92323", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "tcl"}
# collect_ist_gateway_a.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

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
set IST_FILE [file join $OUT_DIR "IST-ZUSTAND_GATEWAY-A_NODE1.md"]
set INV_FILE [file join $OUT_DIR "ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md"]
set CFG_FILE [file join $OUT_DIR "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md"]
set ENV_FILE [file join $OUT_DIR "ENV-STATUS_GATEWAY-A_NODE1.md"]
set RUN_FILE [file join $OUT_DIR "RUN-$TS.md"]

set OPENCLAW_JSON [file join $BASE_DIR "openclaw.json"]
set ENV_DOT [file join $BASE_DIR ".env"]
set ENV_SYSTEMD [file join $BASE_DIR "gateway.systemd.env"]
set VSCODE_DIR [file join $BASE_DIR ".vscode"]

# Systeminformationen sammeln
set HOSTNAME_FQDN [exec hostname -f]
set HOSTNAME_SHORT [exec hostname]
set ARCH [exec uname -m]
set KERNEL [exec uname -r]
set OS_PRETTY ""
catch {
    set os_release [exec grep {^PRETTY_NAME=} /etc/os-release]
    set OS_PRETTY [string trim [lindex [split $os_release =] 1] {"}]
} errmsg
set IPV4_ALL ""
catch {
    set IPV4_ALL [exec hostname -I]
} errmsg
set PUBLIC_IP ""
catch {
    set PUBLIC_IP [exec curl -4 -s --max-time 4 ifconfig.me]
} errmsg
set TAILSCALE_IP ""
catch {
    set TAILSCALE_IP [lindex [split [exec tailscale ip -4] "\n"] 0]
} errmsg
set OPENCLAW_VER ""
catch {
    set OPENCLAW_VER [exec openclaw --version]
} errmsg
set NODE_VER ""
catch {
    set NODE_VER [exec node -v]
} errmsg

# Fallback-Werte setzen
if {$PUBLIC_IP eq ""} {set PUBLIC_IP "(nicht ermittelt)"}
if {$TAILSCALE_IP eq ""} {set TAILSCALE_IP "(nicht ermittelt)"}
if {$OPENCLAW_VER eq ""} {set OPENCLAW_VER "(nicht ermittelt)"}
if {$NODE_VER eq ""} {set NODE_VER "(nicht ermittelt)"}

# IST-Zustand erstellen
set ist_fd [open $IST_FILE w]
puts $ist_fd "# IST-Zustand: Gateway A / Node 1\n"
puts $ist_fd "Stand (lokal): $NOW_LOCAL  "
puts $ist_fd "Stand (UTC): $NOW_UTC\n"
puts $ist_fd "## 1) Identitaet & System\n"
puts $ist_fd "- Gateway: **A**"
puts $ist_fd "- Node: **1**"
puts $ist_fd "- Hostname (short): \`$HOSTNAME_SHORT\`"
puts $ist_fd "- Hostname (FQDN): \`$HOSTNAME_FQDN\`"
puts $ist_fd "- Architektur: \`$ARCH\`"
puts $ist_fd "- Kernel: \`$KERNEL\`"
puts $ist_fd "- OS: \`$OS_PRETTY\`"
puts $ist_fd "- IPv4 (lokal): \`$IPV4_ALL\`"
puts $ist_fd "- Public IPv4: \`$PUBLIC_IP\`"
puts $ist_fd "- Tailscale IPv4: \`$TAILSCALE_IP\`"
puts $ist_fd "- OpenClaw Version: \`$OPENCLAW_VER\`"
puts $ist_fd "- Node.js Version: \`$NODE_VER\`\n"
puts $ist_fd "## 2) Arbeitsverzeichnisse\n"
puts $ist_fd "- Basis: \`$BASE_DIR\`"
puts $ist_fd "- Funktionell VSCode: \`$VSCODE_DIR\`"
puts $ist_fd "- Workspace Doku: \`$OUT_DIR\`\n"
puts $ist_fd "## 3) Kernartefakte (Existenz)\n"

set openclaw_json_status "fehlt"
if {[file exists $OPENCLAW_JSON]} {set openclaw_json_status "vorhanden"}
puts $ist_fd "- \`$OPENCLAW_JSON\`: $openclaw_json_status"

set env_dot_status "fehlt"
if {[file exists $ENV_DOT]} {set env_dot_status "vorhanden"}
puts $ist_fd "- \`$ENV_DOT\`: $env_dot_status"

set env_systemd_status "fehlt"
if {[file exists $ENV_SYSTEMD]} {set env_systemd_status "vorhanden"}
puts $ist_fd "- \`$ENV_SYSTEMD\`: $env_systemd_status"

set installs_json_status "fehlt"
if {[file exists [file join $BASE_DIR plugins installs.json]]} {set installs_json_status "vorhanden"}
puts $ist_fd "- \`[file join $BASE_DIR plugins installs.json]\`: $installs_json_status"

set plugin_skills_status "fehlt"
if {[file isdirectory [file join $BASE_DIR plugin-skills]]} {set plugin_skills_status "vorhanden"}
puts $ist_fd "- \`[file join $BASE_DIR plugin-skills]\`: $plugin_skills_status"

close $ist_fd

# Artefakt-Inventar erstellen
set inv_fd [open $INV_FILE w]
puts $inv_fd "# Artefakt-Inventar: Gateway A / Node 1\n"
puts $inv_fd "Stand: $NOW_LOCAL\n"
puts $inv_fd "## Top-Level in ~/.openclaw\n"
puts $inv_fd "\`\`\`text"
if {[catch {exec ls -1 $BASE_DIR} result]} {
    puts $inv_fd ""
} else {
    puts $inv_fd $result
}
puts $inv_fd "\`\`\`\n"
puts $inv_fd "## ~/.openclaw/.vscode\n"
puts $inv_fd "\`\`\`text"
if {[file isdirectory $VSCODE_DIR]} {
    catch {exec ls -la $VSCODE_DIR} result
    puts $inv_fd $result
} else {
    puts $inv_fd "(nicht vorhanden)"
}
puts $inv_fd "\`\`\`\n"
puts $inv_fd "## plugin-skills/\n"
puts $inv_fd "\`\`\`text"
if {[file isdirectory [file join $BASE_DIR plugin-skills]]} {
    if {[catch {exec ls -1 [file join $BASE_DIR plugin-skills]} result]} {
        puts $inv_fd ""
    } else {
        puts $inv_fd $result
    }
} else {
    puts $inv_fd "(nicht vorhanden)"
}
puts $inv_fd "\`\`\`\n"
puts $inv_fd "## openclaw.json Backups\n"
puts $inv_fd "\`\`\`text"
if {[catch {exec ls -1 [glob -nocomplain [file join $BASE_DIR openclaw.json.bak*]]} result]} {
    puts $inv_fd "(keine gefunden)"
} else {
    puts $inv_fd $result
}
puts $inv_fd "\`\`\`"
close $inv_fd

# OpenClaw Config Snapshot erstellen
set cfg_fd [open $CFG_FILE w]
puts $cfg_fd "# OpenClaw Config Snapshot: Gateway A / Node 1\n"
puts $cfg_fd "Stand: $NOW_LOCAL\n"
puts $cfg_fd "## Schluesselpositionen (grep)\n"
puts $cfg_fd "\`\`\`text"
if {[file exists $OPENCLAW_JSON]} {
    if {[catch {exec grep -nE {"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"} $OPENCLAW_JSON} result]} {
        puts $cfg_fd ""
    } else {
        puts $cfg_fd $result
    }
} else {
    puts $cfg_fd "openclaw.json fehlt"
}
puts $cfg_fd "\`\`\`\n"
puts $cfg_fd "## Ausschnitt gateway/session/auth\n"
puts $cfg_fd "\`\`\`json"
if {[file exists $OPENCLAW_JSON]} {
    if {[catch {exec sed -n {580,780p} $OPENCLAW_JSON} result]} {
        puts $cfg_fd ""
    } else {
        puts $cfg_fd $result
    }
} else {
    puts $cfg_fd "{ \"error\": \"openclaw.json fehlt\" }"
}
puts $cfg_fd "\`\`\`"
close $cfg_fd

# ENV-Status erstellen
set env_fd [open $ENV_FILE w]
puts $env_fd "# ENV-Status: Gateway A / Node 1\n"
puts $env_fd "Stand: $NOW_LOCAL\n"
puts $env_fd "## Dateien\n"
puts $env_fd "\`\`\`text"
if {[catch {exec ls -la $ENV_DOT $ENV_SYSTEMD} result]} {
    puts $env_fd ""
} else {
    puts $env_fd $result
}
puts $env_fd "\`\`\`\n"
puts $env_fd "## .env (vollstaendig)\n"
puts $env_fd "\`\`\`dotenv"
if {[file exists $ENV_DOT]} {
    set dot_env_fd [open $ENV_DOT r]
    puts $env_fd [read $dot_env_fd]
    close $dot_env_fd
} else {
    puts $env_fd "# .env fehlt"
}
puts $env_fd "\`\`\`\n"
puts $env_fd "## gateway.systemd.env (vollstaendig)\n"
puts $env_fd "\`\`\`dotenv"
if {[file exists $ENV_SYSTEMD]} {
    set systemd_env_fd [open $ENV_SYSTEMD r]
    puts $env_fd [read $systemd_env_fd]
    close $systemd_env_fd
} else {
    puts $env_fd "# gateway.systemd.env fehlt"
}
puts $env_fd "\`\`\`"
close $env_fd

# Laufprotokoll erstellen
set run_fd [open $RUN_FILE w]
puts $run_fd "# Laufprotokoll Gateway A / Node 1\n"
puts $run_fd "- Zeit (lokal): $NOW_LOCAL"
puts $run_fd "- Zeit (UTC): $NOW_UTC"
puts $run_fd "- Script: [info script]\n"
puts $run_fd "## Erzeugte Dateien\n"
puts $run_fd "- [file tail $IST_FILE]"
puts $run_fd "- [file tail $INV_FILE]"
puts $run_fd "- [file tail $CFG_FILE]"
puts $run_fd "- [file tail $ENV_FILE]"
close $run_fd

# Erfolgsmeldung ausgeben
puts "OK: IST-Zustand erfasst."
if {[catch {exec ls -1 $OUT_DIR} result]} {
    puts ""
} else {
    foreach line [split $result "\n"] {
        if {$line ne ""} {
            puts "- $line"
        }
    }
}
