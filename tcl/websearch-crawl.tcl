#!/usr/bin/env tclsh
# websearch-crawl.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/websearch-crawl.sh
# auch in: OpenClaw@gateway2:scripts/websearch-crawl.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

# Web Search Script: Website Crawling mit Firecrawl
# Verwendung: tclsh websearch-crawl.tcl <URL> [OUTPUT_DIR]

package require http
package require json
package require fileutil

# Hilfsfunktion für JSON-Parsing
proc get_json_value {json key} {
    if {[dict exists $json $key]} {
        return [dict get $json $key]
    } else {
        return ""
    }
}

# Kommandozeilenargumente verarbeiten
if {$argc < 1} {
    puts "Verwendung: [info script] <URL> \[OUTPUT_DIR\]"
    exit 1
}

set WEBSITE_URL [lindex $argv 0]
set OUTPUT_DIR [expr {$argc > 1 ? [lindex $argv 1] : "./crawled"}]

# API-Key aus Umgebung oder Datei lesen
set FIRECRAWL_API_KEY ""
if {[info exists ::env(FIRECRAWL_API_KEY)] && $::env(FIRECRAWL_API_KEY) ne ""} {
    set FIRECRAWL_API_KEY $::env(FIRECRAWL_API_KEY)
} else {
    # Versuche aus Datei zu lesen
    set env_file "$::env(HOME)/.openclaw/openclaw.env"
    if {[file exists $env_file]} {
        set fp [open $env_file r]
        while {[gets $fp line] >= 0} {
            if {[regexp {OPENROUTER="([^"]+)"} $line match key]} {
                set FIRECRAWL_API_KEY $key
                break
            }
        }
        close $fp
    }
}

if {$FIRECRAWL_API_KEY eq ""} {
    puts "FEHLER: FIRECRAWL_API_KEY nicht gefunden"
    exit 1
}

# Ausgabeverzeichnis erstellen
file mkdir $OUTPUT_DIR
puts "Crawling $WEBSITE_URL..."

# HTTP-Header vorbereiten
set headers [list Authorization "Bearer $FIRECRAWL_API_KEY" Content-Type "application/json"]

# Crawl starten
set post_data [subst -nocommands {
    {
        "url": "$WEBSITE_URL",
        "limit": 100,
        "scrapeOptions": {"formats": ["markdown"]}
    }
}]

set token [http::geturl "https://api.firecrawl.dev/v1/crawl" \
    -method POST \
    -headers $headers \
    -query $post_data]

set response_code [http::status $token]
set response_data [http::data $token]
http::cleanup $token

if {$response_code ne "ok"} {
    puts "Fehler bei der Anfrage: $response_code"
    exit 1
}

# Antwort parsen
if {[catch {::json::json2dict $response_data} crawl_response]} {
    puts "Fehler beim Parsen der JSON-Antwort:"
    puts $response_data
    exit 1
}

set CRAWL_ID [get_json_value $crawl_response "id"]
if {$CRAWL_ID eq ""} {
    puts "Fehler: Crawl konnte nicht gestartet werden"
    puts [::json::dict2json $crawl_response]
    exit 1
}

puts "Crawl ID: $CRAWL_ID"

# Status prüfen
while {true} {
    set token [http::geturl "https://api.firecrawl.dev/v1/crawl/$CRAWL_ID" \
        -headers [list Authorization "Bearer $FIRECRAWL_API_KEY"]]
    
    set status_code [http::status $token]
    set status_data [http::data $token]
    http::cleanup $token
    
    if {$status_code ne "ok"} {
        puts "Fehler bei der Statusanfrage: $status_code"
        exit 1
    }
    
    if {[catch {::json::json2dict $status_data} status_response]} {
        puts "Fehler beim Parsen der Statusantwort:"
        puts $status_data
        exit 1
    }
    
    set STATUS [get_json_value $status_response "status"]
    if {$STATUS eq ""} {
        set STATUS "unknown"
    }
    
    puts "Status: $STATUS"
    
    if {$STATUS eq "completed"} {
        # Aktuelles Datum für Dateinamen
        set timestamp [clock format [clock seconds] -format "%Y%m%d"]
        set output_file "$OUTPUT_DIR/${timestamp}_crawl.json"
        
        set fp [open $output_file w]
        puts $fp $status_data
        close $fp
        
        puts "Gespeichert in $OUTPUT_DIR"
        break
    } elseif {$STATUS eq "failed"} {
        puts "Crawl fehlgeschlagen"
        exit 1
    }
    
    # 5 Sekunden warten
    after 5000
}
