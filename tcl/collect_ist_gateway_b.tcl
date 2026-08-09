#!/usr/bin/env tclsh8.6
# collect_ist_gateway_b.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

package require http
package require json

# Hilfsfunktion für Kommandoausführung mit Fehlerbehandlung
proc exec_safe {cmd} {
    if {[catch {exec {*}$cmd} result]} {
        return ""
    }
    return [string trim $result]
}

# Hilfsfunktion für Dateiinhalt mit Fehlerbehandlung
proc read_file_safe {filename} {
    if {[file exists $filename]} {
        set fp [open $filename r]
        set content [read $fp]
        close $fp
        return [string trim $content]
    }
    return ""
}

# Hilfsfunktion für Dateiprüfung
proc file_status {filepath} {
    if {[file exists $filepath]} {
        if {[file isdirectory $filepath]} {
            return "vorhanden"
        } elseif {[file isfile $filepath]} {
            return "vorhanden"
        }
    }
    return "fehlt"
}

# Datum und Zeit bestimmen
set now_utc [clock format [clock seconds] -gmt true -format "%Y-%m-%dT%H:%M:%SZ"]
set now_local [clock format [clock seconds] -gmt false -format "%Y-%m-%d %H:%M:%S %Z"]
set ts [clock format [clock seconds] -gmt false -format "%Y%m%d-%H%M%S"]

# Pfade definieren
set base_dir [file normalize "$env(HOME)/.openclaw"]
set out_dir [file normalize "$base_dir/workspace/vscode"]
file mkdir $out_dir

set ist_file [file join $out_dir "IST-ZUSTAND_GATEWAY-B_NODE7.md"]
set inv_file [file join $out_dir "ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md"]
set cfg_file [file join $out_dir "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md"]
set env_file [file join $out_dir "ENV-STATUS_GATEWAY-B_NODE7.md"]
set run_file [file join $out_dir "RUN-$ts.md"]

set openclaw_json [file join $base_dir "openclaw.json"]
set env_dot [file join $base_dir ".env"]
set env_systemd [file join $base_dir "gateway.systemd.env"]
set vscode_dir [file join $base_dir ".vscode"]

# Systeminformationen sammeln
set hostname_fqdn [exec_safe [list hostname -f]]
if {$hostname_fqdn eq ""} {
    set hostname_fqdn [exec_safe [list hostname]]
}
set hostname_short [exec_safe [list hostname]]
set arch [exec_safe [list uname -m]]
set kernel [exec_safe [list uname -r]]

set os_pretty ""
if {[file exists "/etc/os-release"]} {
    set os_content [read_file_safe "/etc/os-release"]
    foreach line [split $os_content "\n"] {
        if {[string match "PRETTY_NAME=*" $line]} {
            set os_pretty [string range $line 12 end]
            set os_pretty [string trim $os_pretty "\""]
            break
        }
    }
}

set ipv4_all [exec_safe [list hostname -I]]
set public_ip [exec_safe [list curl -4 -s --max-time 4 ifconfig.me]]
set tailscale_ip [exec_safe [list tailscale ip -4]]

set openclaw_ver [exec_safe [list openclaw --version]]
set node_ver [exec_safe [list node -v]]

# Fallback-Werte setzen
if {$public_ip eq ""} {set public_ip "(nicht ermittelt)"}
if {$tailscale_ip eq ""} {set tailscale_ip "(nicht ermittelt)"}
if {$openclaw_ver eq ""} {set openclaw_ver "(nicht ermittelt)"}
if {$node_ver eq ""} {set node_ver "(nicht ermittelt)"}

# IST-Zustand schreiben
set fp [open $ist_file w]
puts $fp "# IST-Zustand: Gateway B / Node 7"
puts $fp ""
puts $fp "Stand (lokal): $now_local  "
puts $fp "Stand (UTC): $now_utc"
puts $fp ""
puts $fp "## 1) Identität & System"
puts $fp ""
puts $fp "- Gateway: **B**"
puts $fp "- Node: **7**"
puts $fp "- Hostname (short): \`$hostname_short\`"
puts $fp "- Hostname (FQDN): \`$hostname_fqdn\`"
puts $fp "- Architektur: \`$arch\`"
puts $fp "- Kernel: \`$kernel\`"
puts $fp "- OS: \`$os_pretty\`"
puts $fp "- IPv4 (lokal): \`$ipv4_all\`"
puts $fp "- Public IPv4: \`$public_ip\`"
puts $fp "- Tailscale IPv4: \`$tailscale_ip\`"
puts $fp "- OpenClaw Version: \`$openclaw_ver\`"
puts $fp "- Node.js Version: \`$node_ver\`"
puts $fp ""
puts $fp "## 2) Arbeitsverzeichnisse"
puts $fp ""
puts $fp "- Basis: \`$base_dir\`"
puts $fp "- Funktionell VSCode: \`$vscode_dir\`"
puts $fp "- Workspace Doku: \`$out_dir\`"
puts $fp ""
puts $fp "## 3) Kernartefakte (Existenz)"
puts $fp ""
puts $fp "- \`$openclaw_json\`: [file_status $openclaw_json]"
puts $fp "- \`$env_dot\`: [file_status $env_dot]"
puts $fp "- \`$env_systemd\`: [file_status $env_systemd]"
puts $fp "- \`${base_dir}/plugins/installs.json\`: [file_status ${base_dir}/plugins/installs.json]"
puts $fp "- \`${base_dir}/plugin-skills\`: [file_status ${base_dir}/plugin-skills]"
puts $fp ""
puts $fp "## 4) Hinweis"
puts $fp ""
puts $fp "Diese Datei wird bei jedem Lauf neu geschrieben."
puts $fp "Zusätzlich wird ein Laufprotokoll als \`RUN-*.md\` erzeugt."
close $fp

# Artefakt-Inventar schreiben
set fp [open $inv_file w]
puts $fp "# Artefakt-Inventar: Gateway B / Node 7"
puts $fp ""
puts $fp "Stand: $now_local"
puts $fp ""
puts $fp "## Top-Level in ~/.openclaw"
puts $fp ""
puts $fp "\`\`\`text"
if {[file exists $base_dir] && [file isdirectory $base_dir]} {
    set files [lsort [glob -nocomplain -dir $base_dir *]]
    foreach f $files {
        puts $fp [file tail $f]
    }
}
puts $fp "\`\`\`"
puts $fp ""
puts $fp "## ~/.openclaw/.vscode"
puts $fp ""
puts $fp "\`\`\`text"
if {[file exists $vscode_dir] && [file isdirectory $vscode_dir]} {
    catch {
        set dir_content [exec ls -la $vscode_dir]
        puts $fp $dir_content
    }
} else {
    puts $fp "(nicht vorhanden)"
}
puts $fp "\`\`\`"
puts $fp ""
puts $fp "## plugin-skills/"
puts $fp ""
puts $fp "\`\`\`text"
if {[file exists ${base_dir}/plugin-skills] && [file isdirectory ${base_dir}/plugin-skills]} {
    set skill_files [lsort [glob -nocomplain -dir ${base_dir}/plugin-skills *]]
    foreach f $skill_files {
        puts $fp [file tail $f]
    }
} else {
    puts $fp "(nicht vorhanden)"
}
puts $fp "\`\`\`"
puts $fp ""
puts $fp "## openclaw.json Backups"
puts $fp ""
puts $fp "\`\`\`text"
set backup_files [lsort [glob -nocomplain ${base_dir}/openclaw.json.bak*]]
if {[llength $backup_files] > 0} {
    foreach f $backup_files {
        puts $fp [file tail $f]
    }
} else {
    puts $fp "(keine gefunden)"
}
puts $fp "\`\`\`"
close $fp

# Config Snapshot schreiben
set fp [open $cfg_file w]
puts $fp "# OpenClaw Config Snapshot: Gateway B / Node 7"
puts $fp ""
puts $fp "Stand: $now_local"
puts $fp ""
puts $fp "## Schlüsselpositionen (grep)"
puts $fp ""
puts $fp "\`\`\`text"
if {[file exists $openclaw_json]} {
    set content [read_file_safe $openclaw_json]
    set lines [split $content "\n"]
    set line_num 1
    foreach line $lines {
        if {[regexp {"gateway"|"session"|"dmScope"|"auth"|"secrets"|"tools"|"plugins"|"profile"|"alsoAllow"|"denyCommands"} $line]} {
            puts $fp "$line_num:$line"
        }
        incr line_num
    }
} else {
    puts $fp "openclaw.json fehlt"
}
puts $fp "\`\`\`"
puts $fp ""
puts $fp "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)"
puts $fp ""
puts $fp "\`\`\`json"
if {[file exists $openclaw_json]} {
    set fp_json [open $openclaw_json r]
    set line_count 0
    while {[gets $fp_json line] >= 0 && $line_count < 780} {
        incr line_count
        if {$line_count >= 580} {
            puts $fp $line
        }
    }
    close $fp_json
} else {
    puts $fp "{ \"error\": \"openclaw.json fehlt\" }"
}
puts $fp "\`\`\`"
close $fp

# ENV-Status schreiben
set fp [open $env_file w]
puts $fp "# ENV-Status: Gateway B / Node 7"
puts $fp ""
puts $fp "Stand: $now_local"
puts $fp ""
puts $fp "## Dateien"
puts $fp ""
puts $fp "\`\`\`text"
catch {
    set stat_result [exec ls -la $env_dot $env_systemd]
    puts $fp $stat_result
}
puts $fp "\`\`\`"
puts $fp ""
puts $fp "## .env (vollständig, ungefiltert)"
puts $fp ""
puts $fp "\`\`\`dotenv"
if {[file exists $env_dot]} {
    set env_content [read_file_safe $env_dot]
    puts $fp $env_content
} else {
    puts $fp "# .env fehlt"
}
puts $fp "\`\`\`"
puts $fp ""
puts $fp "## gateway.systemd.env (vollständig, ungefiltert)"
puts $fp ""
puts $fp "\`\`\`dotenv"
if {[file exists $env_systemd]} {
    set systemd_content [read_file_safe $env_systemd]
    puts $fp $systemd_content
} else {
    puts $fp "# gateway.systemd.env fehlt"
}
puts $fp "\`\`\`"
close $fp

# Laufprotokoll schreiben
set fp [open $run_file w]
puts $fp "# Laufprotokoll Gateway B / Node 7"
puts $fp ""
puts $fp "- Zeit (lokal): $now_local"
puts $fp "- Zeit (UTC): $now_utc"
puts $fp "- Script: [info script]"
puts $fp ""
puts $fp "## Erzeugte Dateien"
puts $fp ""
puts $fp "- [file tail $ist_file]"
puts $fp "- [file tail $inv_file]"
puts $fp "- [file tail $cfg_file]"
puts $fp "- [file tail $env_file]"
close $fp

# Erfolgsmeldung ausgeben
puts "OK: IST-Zustand erfasst."
puts "Ausgabeordner: $out_dir"
puts "Dateien:"
set output_files [lsort [glob -nocomplain -dir $out_dir *]]
foreach f $output_files {
    puts "- [file tail $f]"
}
