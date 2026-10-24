#!/usr/bin/env tclsh8.6
# websearch-research.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/websearch-research.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

# Web Search Script: Deep Research für Incidents
# Verwendung: tclsh websearch-research.tcl "Beschreibung des Problems"

package require http
package require json
package require tls

# Hilfsfunktion zur URL-Kodierung
proc urlEncode {str} {
    return [string map {" " "%20" "\n" "%0A" "&" "%26" "=" "%3D" "?" "%3F" "/" "%2F"} $str]
}

# Hauptprogramm
set QUERY [lindex $argv 0]
set OUTPUT_DIR [expr {[llength $argv] > 1 ? [lindex $argv 1] : "./research"}]

if {$QUERY eq ""} {
    puts "Verwendung: [info script] \"Problem Beschreibung\" \[OUTPUT_DIR\]"
    exit 1
}

# TLS initialisieren
http::register https 443 [list ::tls::socket -autoservername true]

# Ausgabeverzeichnis erstellen
file mkdir $OUTPUT_DIR

# Zeitstempel für Dateinamen generieren
set timestamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
set OUTPUT_FILE "$OUTPUT_DIR/incident_$timestamp.md"

# Markdown-Header schreiben
set fh [open $OUTPUT_FILE w]
puts $fh "# Incident Research"
puts $fh "Datum: [clock format [clock seconds]]"
puts $fh "Query: $QUERY"
puts $fh ""
close $fh

# 1. EXA für schnelle Recherche
puts "## 1. Schnelle Recherche (EXA)" >> $OUTPUT_FILE

set postDataExa [::json::encode {
    model "openai/gpt-5.6-terra"
    messages [list [dict create role user content $QUERY]]
    plugins [list [dict create id web engine exa max_results 5]]
}]

set token [http::geturl https://openrouter.ai/api/v1/chat/completions \
    -headers [list Authorization "Bearer $::env(OPENROUTER_API_KEY)" Content-Type application/json] \
    -method POST \
    -query $postDataExa]

set responseExa [http::data $token]
http::cleanup $token

# Antwort parsen und in Datei schreiben
if {[dict exists $responseExa choices 0 message content]} {
    set contentExa [dict get $responseExa choices 0 message content]
    puts $contentExa >> $OUTPUT_FILE
} else {
    puts "Keine Ergebnisse" >> $OUTPUT_FILE
}

puts "" >> $OUTPUT_FILE
puts "---" >> $OUTPUT_FILE

# 2. Verifizierte Quellen (Perplexity)
puts "## 2. Verifizierte Fakten (Perplexity)" >> $OUTPUT_FILE

set postDataPerplexity [::json::encode {
    model "perplexity/sonar:online"
    messages [list [dict create role user content "$QUERY troubleshooting"]]
}]

set token2 [http::geturl https://openrouter.ai/api/v1/chat/completions \
    -headers [list Authorization "Bearer $::env(OPENROUTER_API_KEY)" Content-Type application/json] \
    -method POST \
    -query $postDataPerplexity]

set responsePerplexity [http::data $token2]
http::cleanup $token2

# Antwort parsen und in Datei schreiben
if {[dict exists $responsePerplexity choices 0 message content]} {
    set contentPerplexity [dict get $responsePerplexity choices 0 message content]
    puts $contentPerplexity >> $OUTPUT_FILE
} else {
    puts "Keine Ergebnisse" >> $OUTPUT_FILE
}

puts "" >> $OUTPUT_FILE
puts "Gespeichert in: $OUTPUT_FILE"
