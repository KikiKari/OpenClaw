#!/usr/bin/env tclsh8.6
# websearch-research.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/websearch-research.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

# Web Search Script: Deep Research für Incidents
# Verwendung: tclsh websearch-research.tcl "Beschreibung des Problems"

package require http
package require json
package require tls

# TLS-Support aktivieren
http::register https 443 [list ::tls::socket]

# Hilfsfunktion zur JSON-Erstellung
proc createJson {dict} {
    set result "{"
    set first 1
    dict for {key value} $dict {
        if {!$first} {append result ","}
        append result "\"$key\":"
        if {[string is list $value] && [llength $value] > 0 && [string index [lindex $value 0] 0] eq "\{"} {
            append result "\[" 
            set innerFirst 1
            foreach item $value {
                if {!$innerFirst} {append result ","}
                append result $item
                set innerFirst 0
            }
            append result "\]"
        } elseif {[string is list $value]} {
            append result "\[" 
            set innerFirst 1
            foreach item $value {
                if {!$innerFirst} {append result ","}
                append result "\"$item\""
                set innerFirst 0
            }
            append result "\]"
        } else {
            append result "\"$value\""
        }
        set first 0
    }
    append result "}"
    return $result
}

# Hauptlogik
set argc [llength $argv]
if {$argc < 1} {
    puts "Verwendung: [info script] \"Problem Beschreibung\" \[OUTPUT_DIR\]"
    exit 1
}

set QUERY [lindex $argv 0]
set OUTPUT_DIR [expr {$argc > 1 ? [lindex $argv 1] : "./research"}]

file mkdir $OUTPUT_DIR
set timestamp [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
set OUTPUT_FILE "${OUTPUT_DIR}/incident_${timestamp}.md"

set fh [open $OUTPUT_FILE w]
puts $fh "# Incident Research"
puts $fh "Datum: [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]"
puts $fh "Query: $QUERY"
puts $fh ""
close $fh

# Funktion zum API-Aufruf
proc callAPI {model messages {plugins ""}} {
    global env
    
    set url "https://openrouter.ai/api/v1/chat/completions"
    set headers [list Authorization "Bearer $env(OPENROUTER_API_KEY)" Content-Type "application/json"]
    
    set dataDict [list model $model messages $messages]
    if {$plugins ne ""} {
        lappend dataDict plugins $plugins
    }
    
    set jsonData [createJson $dataDict]
    
    set token [http::geturl $url -headers $headers -query $jsonData -method POST]
    set response [http::data $token]
    http::cleanup $token
    
    if {[catch {set jsonResponse [json::json2dict $response]}]} {
        return "Keine Ergebnisse"
    }
    
    if {[dict exists $jsonResponse choices 0 message content]} {
        return [dict get $jsonResponse choices 0 message content]
    } else {
        return "Keine Ergebnisse"
    }
}

# 1. EXA für schnelle Recherche
set fh [open $OUTPUT_FILE a]
puts $fh "## 1. Schnelle Recherche (EXA)"
close $fh

set messages [list [dict create role user content $QUERY]]
set plugins [list [dict create id web engine exa max_results 5]]

set result [callAPI "openai/gpt-5.4-mini" $messages $plugins]

set fh [open $OUTPUT_FILE a]
puts $fh $result
puts $fh ""
puts $fh "---"
close $fh

# 2. Verifizierte Quellen (Perplexity) falls verfügbar
set fh [open $OUTPUT_FILE a]
puts $fh "## 2. Verifizierte Fakten (Perplexity)"
close $fh

set messages2 [list [dict create role user content "$QUERY troubleshooting"]]
set result2 [callAPI "perplexity/sonar:online" $messages2]

set fh [open $OUTPUT_FILE a]
puts $fh $result2
puts $fh ""
puts $fh "Gespeichert in: $OUTPUT_FILE"
close $fh
