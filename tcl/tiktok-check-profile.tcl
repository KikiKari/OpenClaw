#!/usr/bin/env tclsh
# tiktok-check-profile.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# TikTok Live Status Checker
# Prüft ausschließlich profilgebundene Live-Indikatoren.
# Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
# Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
# via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).

package require http
package require tls
package require json
package require fileutil

# TLS für HTTPS aktivieren
http::register https 443 [list ::tls::socket]

# Hilfsfunktion zur CPU-Auslastungsprüfung
proc rejectBusyNode {} {
    set limit [getenv TIKTOK_MAX_LOAD_PER_CPU]
    if {![string is double -strict $limit] || $limit <= 0} {
        return
    }
    
    # Anzahl CPUs ermitteln
    set cpuCount [expr {[auto_cpu_count] > 0 ? [auto_cpu_count] : 1}]
    
    # Load Average ermitteln (Unix-spezifisch)
    if {[catch {exec uptime} result]} {
        return
    }
    
    # Extrahiere Load Average aus "load averages: 0.23, 0.19, 0.18"
    if {[regexp {load averages?: ([0-9.]+)(, [0-9.]+)*} $result -> loadAvg]} {
        set normalizedLoad [expr {$loadAvg / $cpuCount}]
        if {$normalizedLoad > $limit} {
            puts stderr "NODE_BUSY normalizedLoad=[format "%.2f" $normalizedLoad] limit=$limit"
            exit 75
        }
    }
}

# Anzahl der CPUs ermitteln
proc auto_cpu_count {} {
    if {[info exists ::tcl_platform(nativeCpuCount)]} {
        return $::tcl_platform(nativeCpuCount)
    } elseif {[info exists ::tcl_platform(cpuCount)]} {
        return $::tcl_platform(cpuCount)
    } else {
        return 1
    }
}

# Umgebungsvariable abrufen
proc getenv {name} {
    if {[info exists ::env($name)]} {
        return $::env($name)
    } else {
        return ""
    }
}

# Hauptfunktion zur Live-Statusprüfung
proc checkLiveStatus {username} {
    # Da Tcl kein Playwright hat, simulieren wir das Verhalten mit HTTP-Anfragen
    
    set url "https://www.tiktok.com/@$username"
    
    # Header setzen
    array set headers {
        User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    
    # HTTP-Anfrage senden
    if {[catch {
        set token [http::geturl $url -headers [array get headers] -timeout 30000]
        set status [http::status $token]
        set code [http::ncode $token]
        set data [http::data $token]
        http::cleanup $token
    } error]} {
        puts [json::encode {
            error true
            message "HTTP request failed"
            details $error
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"]
        }]
        exit 1
    }
    
    # Prüfen ob Anfrage erfolgreich war
    if {$status != "ok" || $code != 200} {
        puts [json::encode {
            error true
            message "Failed to fetch profile page"
            status $status
            code $code
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"]
        }]
        exit 1
    }
    
    # Speichere HTML-Daten für Debugging falls nötig
    if {[getenv DEBUG] eq "1"} {
        set fd [open "/tmp/tiktok-$username.html" w]
        puts $fd $data
        close $fd
    }
    
    # Indikatoren suchen
    set liveIconVisible [expr {[string first {data-e2e="live-icon"} $data] != -1}]
    set liveBadgeVisible [expr {[regexp {(?i)LIVE} $data]}]
    set hasLiveBorder false
    set hasLiveLink [expr {[string first "/@$username/live" $data] != -1}]
    set liveIndicatorVisible [expr {[regexp {(?i)live-indicator|LiveBadge} $data]}]
    
    # Weitere Prüfung auf Live-Farben im CSS
    if {[regexp {border.*?(255|red|rgb\(254|fe2c55|#fe2c)} $data]} {
        set hasLiveBorder true
    }
    if {[regexp {box-shadow.*?(255|254)} $data]} {
        set hasLiveBorder true
    }
    
    # Kombinierte Live-Erkennung
    set isLive [expr {$liveIconVisible || $liveBadgeVisible || $hasLiveBorder || $hasLiveLink || $liveIndicatorVisible}]
    
    # Ergebnis als JSON ausgeben
    puts [json::encode [dict create \
        username $username \
        isLive $isLive \
        timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"] \
        indicators [dict create \
            liveIcon $liveIconVisible \
            liveBadge $liveBadgeVisible \
            liveBorder $hasLiveBorder \
            liveLink $hasLiveLink \
            liveIndicator $liveIndicatorVisible \
        ] \
    ]]
    
    return $isLive
}

# Hauptprogramm
proc main {} {
    global argv
    
    # Prüfe Kommandozeilenargumente
    if {[llength $argv] < 1} {
        puts stderr "Usage: tclsh tiktok-check-profile.tcl <username>"
        exit 1
    }
    
    set rawUsername [lindex $argv 0]
    if {$rawUsername eq ""} {
        puts stderr "Username must not be empty"
        exit 1
    }
    
    # Entferne führende @-Zeichen
    regsub {^@+} $rawUsername {} username
    if {$username eq ""} {
        puts stderr "Username must not be empty"
        exit 1
    }
    
    # Lastprüfung durchführen
    rejectBusyNode
    
    # Live-Status prüfen
    if {[catch {
        set isLive [checkLiveStatus $username]
        if {$isLive} {
            exit 0
        } else {
            exit 1
        }
    } error]} {
        puts [json::encode [dict create \
            error true \
            message $error \
            timestamp [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ"] \
        ]]
        exit 1
    }
}

# Starte Hauptprogramm
main
