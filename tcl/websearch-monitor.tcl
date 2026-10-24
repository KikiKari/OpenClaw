#!/usr/bin/env tclsh
# websearch-monitor.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/websearch-monitor.sh
# auch in: OpenClaw@gateway2:scripts/websearch-monitor.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

# Web Search Script: Server-Monitoring mit Tavily
# Verwendung: ./websearch-monitor.tcl [TOPIC]

package require http
package require json

# Hilfsfunktion zur Prüfung ob ein Kommando existiert
proc command_exists {cmd} {
    set result [auto_execok $cmd]
    return [expr {$result ne ""}]
}

# Hilfsfunktion für String-Ersetzung (Leerzeichen durch + ersetzen)
proc url_encode {str} {
    return [regsub -all { } $str +]
}

# Hauptlogik
proc main {} {
    global argv
    
    # Topic setzen mit Standardwert
    if {[llength $argv] > 0} {
        set TOPIC [lindex $argv 0]
    } else {
        set TOPIC "Linux kernel security updates"
    }
    
    puts "Prüfe: $TOPIC"
    
    # Versuche zuerst Tavily CLI
    if {[command_exists "tvly"]} {
        if {[catch {
            set cmd [list tvly search $TOPIC --topic news --time-arg week --max-results 5 --include-answer advanced]
            set result [exec {*}$cmd 2>@1]
            
            # JSON parsen und Antwort extrahieren
            if {[catch {set json_data [::json::json2dict $result]}]} {
                puts "Keine Zusammenfassung verfügbar"
            } else {
                # Suche nach 'answer' Feld im JSON
                array set data $json_data
                if {[info exists data(answer)] && $data(answer) ne ""} {
                    puts $data(answer)
                } else {
                    puts "Keine Zusammenfassung verfügbar"
                }
            }
        } err]} {
            puts "Keine Zusammenfassung verfügbar"
        }
    } else {
        # Fallback zu einfacher Web-Suche
        if {[catch {
            set encoded_topic [url_encode $TOPIC]
            set url "http://localhost:8888/search?q=${encoded_topic}&format=json"
            
            set token [::http::geturl $url -timeout 5000]
            set status [::http::status $token]
            
            if {$status eq "ok"} {
                set data [::http::data $token]
                
                # JSON parsen
                if {[catch {set json_result [::json::json2dict $data]}]} {
                    error "Invalid JSON"
                }
                
                # Extrahiere results Array
                array set response $json_result
                if {[info exists response(results)]} {
                    set results $response(results)
                    
                    # Begrenze auf erste 3 Ergebnisse
                    set count 0
                    foreach item $results {
                        if {$count >= 3} break
                        
                        array set entry $item
                        if {[info exists entry(title)] && [info exists entry(url)]} {
                            puts $entry(title)
                            puts $entry(url)
                            incr count
                        }
                    }
                }
            } else {
                error "HTTP request failed"
            }
            
            ::http::cleanup $token
        } err]} {
            puts "SearXNG nicht verfügbar"
        }
    }
}

# Skript starten
main
