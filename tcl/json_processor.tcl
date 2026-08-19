#!/usr/bin/env tclsh8.6
# json_processor.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# JSON Processor mit Tcl 8.6
# Für robuste Verarbeitung von LLM-Outputs.

package require json
package require cmdline

# Globale Variablen
set HAS_JSON_REPAIR false

# Hilfsfunktionen für Fehlerbehandlung
proc throw {exceptionType message} {
    error "$exceptionType: $message"
}

proc JSONProcessingError {msg} {
    throw "JSONProcessingError" $msg
}

proc JSONValidationError {msg} {
    throw "JSONValidationError" $msg
}

proc JSONRepairError {msg} {
    throw "JSONRepairError" $msg
}

# Repariert häufige JSON-Fehler aus LLM-Outputs
proc repair_json_string {raw_json} {
    global HAS_JSON_REPAIR
    
    if {$HAS_JSON_REPAIR} {
        # In Tcl gibt es kein json_repair, daher immer Fallback
        set HAS_JSON_REPAIR false
    }
    
    if {!$HAS_JSON_REPAIR} {
        # Fallback: Manuelle Reparaturen
        set cleaned [string trim $raw_json]
        
        # Entferne JavaScript-Kommentare
        regsub -all {//[^\n]*\n} $cleaned "\n" cleaned
        regsub -all {/\*.*?\*/} $cleaned "" cleaned
        
        # Entferne trailing commas vor ] oder }
        regsub -all {,(\s*[\}\]])} $cleaned {\1} cleaned
        
        return $cleaned
    }
}

# Parst JSON-String mit optionaler automatischer Reparatur
proc parse_json {raw_input {repair true}} {
    set raw_input [string trim $raw_input]
    
    # Versuche zuerst direktes Parsing
    if {[catch {::json::json2dict $raw_input} result]} {
        # Direktes Parsing fehlgeschlagen
    } else {
        return $result
    }
    
    # Extrahiere JSON aus Markdown-Code-Blöcken
    if {[string match "*```*" $raw_input]} {
        # Suche nach JSON in ```json ... ``` oder ``` ... ```
        foreach pattern {{```json\s*(.*?)\s*```} {```\s*(\{.*?\})\s*```} {```\s*(\[.*?\])\s*```}} {
            if {[regexp -indices $pattern $raw_input match]} {
                set start [lindex $match 0]
                set end [lindex $match 1]
                set extracted [string range $raw_input [expr {$start + 3}] [expr {$end - 3}]]
                set extracted [string trim $extracted]
                
                if {[catch {::json::json2dict $extracted} result]} {
                    continue
                } else {
                    return $result
                }
            }
        }
    }
    
    # Versuche Reparatur
    if {$repair} {
        if {[catch {repair_json_string $raw_input} repaired]} {
            JSONProcessingError "Could not parse JSON even after repair: $repaired"
        }
        
        if {[catch {::json::json2dict $repaired} result]} {
            JSONProcessingError "Could not parse JSON even after repair: $result"
        } else {
            return $result
        }
    }
    
    JSONProcessingError "Could not parse JSON"
}

# Sicheres JSON-Parsing mit Fallback auf Default-Wert
proc safe_json_loads {raw_input {default ""} {repair true}} {
    if {[catch {parse_json $raw_input $repair} result]} {
        return $default
    } else {
        return $result
    }
}

# Extrahiert alle JSON-Objekte aus einem Text
proc extract_json_from_text {text} {
    set results {}
    
    # Pattern für JSON-Objekte und Arrays
    set patterns [list {\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}} {\[[^\[\]]*(?:\[[^\[\]*\][^\[\]]*)*\]}]
    
    foreach pattern $patterns {
        set matches [regexp -inline -all $pattern $text]
        foreach match $matches {
            if {[catch {parse_json $match true} parsed]} {
                continue
            } else {
                lappend results $parsed
            }
        }
    }
    
    return $results
}

# Hauptprogramm
proc main {} {
    global argv
    
    # Kommandozeilenargumente parsen
    set options {
        {file.f "Input is a file path"}
        {repair.r "Enable JSON repair" true}
        {no-repair.R "Disable JSON repair"}
        {pretty.p "Pretty print output"}
    }
    
    if {[catch {cmdline::typedGetoptions argv $options} optlist]} {
        puts stderr "Error parsing command line: $optlist"
        exit 1
    }
    
    array set opts $optlist
    
    if {[llength $argv] < 1} {
        puts stderr "Usage: json_processor.tcl \[-f\] \[-r|-R\] \[-p\] <input>"
        exit 1
    }
    
    set input [lindex $argv 0]
    
    # Eingabe verarbeiten
    if {$opts(file)} {
        if {[catch {open $input r} fh]} {
            puts stderr "Error opening file '$input': $fh"
            exit 1
        }
        set content [read $fh]
        close $fh
    } else {
        set content $input
    }
    
    # Reparatur-Einstellung übernehmen
    set repair_enabled $opts(repair)
    if {[info exists opts(no-repair)] && $opts(no-repair)} {
        set repair_enabled false
    }
    
    # JSON parsen
    if {[catch {parse_json $content $repair_enabled} result]} {
        puts stderr "Error: $result"
        exit 1
    }
    
    # Ausgabe formatieren
    if {$opts(pretty)} {
        # Pretty-printing in Tcl ist nicht direkt verfügbar
        # Wir geben einfach das Dictionary formatiert aus
        puts [format_dict $result 0]
    } else {
        puts [dict_to_json $result]
    }
}

# Hilfsfunktion zur Formatierung von Dictionaries
proc format_dict {dict_val {indent_level 0}} {
    set indent [string repeat "  " $indent_level]
    set output ""
    
    dict for {key value} $dict_val {
        append output "$indent$key: "
        if {[dict exists $value]} {
            append output "\n"
            append output [format_dict $value [expr {$indent_level + 1}]]
        } else {
            append output "$value\n"
        }
    }
    
    return $output
}

# Einfache Konvertierung von dict zu JSON-ähnlichem String
proc dict_to_json {dict_val} {
    set json "{"
    set first true
    
    dict for {key value} $dict_val {
        if {!$first} {
            append json ","
        }
        set first false
        
        append json "\"$key\":"
        if {[dict exists $value]} {
            append json [dict_to_json $value]
        } elseif {[string is integer $value] || [string is double $value]} {
            append json "$value"
        } else {
            append json "\"$value\""
        }
    }
    
    append json "}"
    return $json
}

# Programmstart
if {[info script] eq $argv0} {
    main
}
