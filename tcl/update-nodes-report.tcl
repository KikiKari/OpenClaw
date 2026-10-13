#!/usr/bin/env tclsh
# update-nodes-report.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway1:scripts/update-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/update-nodes-report.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

package require json
package require fileutil

# Pfade
set DASHBOARD_PATH [file normalize [file join [file dirname $argv0] ../dashboards/nodes-overview.md]]

# Farbcodes fuer Konsole
array set C {
    green  \033\[32m
    yellow \033\[33m
    red    \033\[31m
    blue   \033\[34m
    reset  \033\[0m
}

proc getNodeStatus {} {
    global C
    if {[catch {exec openclaw nodes status --json} output]} {
        puts stderr "${C(red)}❌ Fehler beim Abrufen des Node-Status:${C(reset)} $output"
        return {}
    }
    if {[catch {::json::json2dict $output} result]} {
        puts stderr "${C(red)}❌ Fehler beim Parsen des JSON:$C(reset) $result"
        return {}
    }
    return $result
}

proc updateDashboard {nodes} {
    global DASHBOARD_PATH C
    
    # Aktuelles Datum im deutschen Format
    set now [clock format [clock seconds] -format "%d.%m.%Y, %H:%M:%S" -timezone Europe/Berlin]
    
    # Manuelle Ergaenzung statischer Konfigurationen (da nicht alle Infos ueber CLI)
    array set nodeConfig {
        1 {name "Gateway" os "Ubuntu 22.04" ip "152.53.145.65" wg "10.10.0.1" tunnel "–" mode "Gateway"}
        2 {name "Netcup Server" os "Ubuntu 22.04" ip "78.46.123.10" wg "10.10.0.2" tunnel "–" mode "Node"}
        3 {name "xNetX VPS" os "Debian 11" ip "5.45.105.20" wg "–" tunnel "Port 18794" mode "Node"}
        4 {name "Webhosting" os "Shared Linux" ip "–" wg "–" tunnel "–" mode "–"}
        5 {name "Redmi Note 11" os "Android" ip "–" wg "10.10.0.5" tunnel "–" mode "Node"}
        6 {name "Lenovo (Win)" os "Windows 11" ip "–" wg "–" tunnel "–" mode "Node"}
    }
    
    set rows {}
    foreach nodeId [lsort -integer [array names nodeConfig]] {
        set cfg $nodeConfig($nodeId)
        
        # Suche nach passendem Knoten in der Liste
        set node {}
        foreach n $nodes {
            dict with n {
                if {$nodeId eq $nodeId || ([info exists name] && [string first [lindex [split [dict get $cfg name] " "] 0] $name] != -1)} {
                    set node $n
                    break
                }
            }
        }
        
        # Bestimme Statussymbole
        set statusVPN ⚠️
        if {[llength $node] > 0} {
            dict with node {
                if {[info exists status]} {
                    set statusVPN [expr {$status eq "paired" ? "✅" : "🔴"}]
                }
            }
        }
        
        set statusSSH ❌
        if {[dict get $cfg tunnel] ne "–"} {
            set statusSSH ✅
        }
        
        set sshKey ❌
        if {$nodeId in {2 3}} {
            set sshKey "❌ (Pending)"
        } elseif {$nodeId eq "1"} {
            set sshKey "Local (id_ed25519)"
        }
        
        # Letzter Check Zeitpunkt
        set lastCheck "–"
        if {[llength $node] > 0 && [dict exists $node lastSeen]} {
            set timestamp [dict get $node lastSeen]
            set lastCheck [clock format $timestamp -format "%d.%m.%Y, %H:%M:%S" -timezone Europe/Berlin]
        }
        
        lappend rows "| $nodeId    | [dict get $cfg name] | [dict get $cfg os] | [dict get $cfg ip] | [dict get $cfg mode]       | [dict get $cfg wg]             | [dict get $cfg tunnel] | $statusVPN | $statusSSH | $sshKey | $lastCheck |"
    }
    
    set content "# Nodes Overview (Network Status)

| Node | Name          | OS           | IP             | Mode       | Primär WG IP       | Sekundär/SSH Tunnel | StatusVPN | StatusSSH | SSH Key (Deployed) | Letzter Check       |
|------|---------------|--------------|----------------|------------|--------------------|---------------------|-----------|-----------|---------------------|---------------------|
[join $rows \n]

> 💡 **Legende:** 
> - **Primär WG IP**: Die WireGuard-VPN-IP des Nodes
> - **Sekundär/SSH Tunnel**: Fallback-Mechanismus (z. B. Reverse-Tunnel)
> - **StatusVPN**: Verbunden über OpenClaw/WireGuard
> - **StatusSSH**: SSH-Zugriff via Reverse-Tunnel aktiv
> - **SSH Key (Deployed)**: Zeigt an, ob der Gateway-Schlüssel (\`id_ed25519\`) auf dem Ziel bereitgestellt ist
> - Letzter Stand: **$now CET**

*Größe: ~1.8 KB | Automatisch aktualisiert via \`update-nodes-report.js\`*"
    
    if {[catch {::fileutil::writeFile $DASHBOARD_PATH $content} error]} {
        puts stderr "${C(red)}❌ Fehler beim Schreiben der Datei:${C(reset)} $error"
    } else {
        puts "${C(green)}✅ Dashboard aktualisiert:${C(reset)} $DASHBOARD_PATH"
    }
}

# Hauptausfuehrung
puts "${C(blue)}🔄 Aktualisiere Nodes-Übersicht...${C(reset)}"
set nodes [getNodeStatus]
updateDashboard $nodes]
