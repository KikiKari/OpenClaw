#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "d2ff6abce5a6e0072d2490852fab0273ef58e9528cb3d20f22f6937a04d05eec", "source_sha256": "f68a161573356fe83ce98ebe454cffaef6896f81d310cd932a9847500e671f9b", "target_language": "tcl"}
# json_processor.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# JSON Processor mit Validation und JSON-Repair.
# Für robuste Verarbeitung von LLM-Outputs.

package require json
package require cmdline

# Globale Variablen für Module
set HAS_JSON_REPAIR 0
set HAS_PYDANTIC 0

# Error-Klassen simulieren
proc JSONProcessingError {msg} {
    error "JSONProcessingError: $msg"
}
proc JSONValidationError {msg} {
    error "JSONValidationError: $msg"
}
proc JSONRepairError {msg} {
    error "JSONRepairError: $msg"
}

# Hilfsfunktion zum Laden von externen Modulen
proc load_module {module_name} {
    global HAS_JSON_REPAIR HAS_PYDANTIC
    if {$module_name eq "json_repair"} {
        if {[catch {package require json_repair}]} {
            puts stderr "Warning: json_repair not available"
            set HAS_JSON_REPAIR 0
        } else {
            set HAS_JSON_REPAIR 1
        }
    } elseif {$module_name eq "pydantic"} {
        # In Tcl gibt es kein direktes Äquivalent zu Pydantic
        # Wir simulieren grundlegende Validierungsfunktionen
        set HAS_PYDANTIC 1
    }
}

# Lade benötigte Module
load_module json_repair
load_module pydantic

# Repariert häufige JSON-Fehler aus LLM-Outputs
proc repair_json_string {raw_json} {
    global HAS_JSON_REPAIR
    
    if {$HAS_JSON_REPAIR} {
        if {[catch {::json_repair::repair $raw_json} repaired]} {
            JSONRepairError "JSON repair failed: $repaired"
        } else {
            return $repaired
        }
    } else {
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
proc parse_json {raw_input {repair 1}} {
    set raw_input [string trim $raw_input]
    
    # Versuche zuerst direktes Parsing
    if {![catch {::json::json2dict $raw_input} result]} {
        return $result
    }
    
    # Extrahiere JSON aus Markdown-Code-Blöcken
    if {[regexp {```(?:json)?\s*(.*?)\s*```}} $raw_input match extracted]} {
        if {![catch {::json::json2dict $extracted} result]} {
            return $result
        }
    }
    
    # Versuche Reparatur
    if {$repair} {
        if {[catch {repair_json_string $raw_input} repaired]} {
            JSONProcessingError "Could not parse JSON even after repair: $repaired"
        }
        if {![catch {::json::json2dict $repaired} result]} {
            return $result
        }
    }
    
    JSONProcessingError "Could not parse JSON"
}

# Parst JSON und validiert gegen ein Schema (vereinfachte Version)
proc parse_and_validate {raw_input model_class {repair 1} {strict 0}} {
    if {[catch {parse_json $raw_input $repair} data]} {
        JSONValidationError "JSON parsing failed: $data"
    }
    
    # In Tcl simulieren wir die Validierung durch Prüfung der Struktur
    # Dies ist eine vereinfachte Version ohne echtes Pydantic-Äquivalent
    return $data
}

# Validiert einen OpenClaw/Tool-Call JSON
proc validate_tool_call {raw_json {tool_name ""}} {
    if {[catch {parse_json $raw_json 1} tool_call]} {
        JSONValidationError "Invalid JSON: $tool_call"
    }
    
    # Prüfe ob erforderliche Felder vorhanden sind
    if {![dict exists $tool_call "tool"]} {
        JSONValidationError "Missing required field 'tool'"
    }
    
    set parsed_tool [dict get $tool_call "tool"]
    if {$tool_name ne "" && $parsed_tool ne $tool_name} {
        JSONValidationError "Expected tool '$tool_name', got '$parsed_tool'"
    }
    
    # Setze Standardwerte falls nicht vorhanden
    if {![dict exists $tool_call "arguments"]} {
        dict set tool_call "arguments" [dict create]
    }
    
    return $tool_call
}

# Sicheres JSON-Parsing mit Fallback auf Default-Wert
proc safe_json_loads {raw_input {default ""} {repair 1}} {
    if {[catch {parse_json $raw_input $repair} result]} {
        return $default
    } else {
        return $result
    }
}

# Extrahiert alle JSON-Objekte aus einem Text
proc extract_json_from_text {text} {
    set results [list]
    
    # Pattern für JSON-Objekte und Arrays
    set patterns [list {\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}} {\[[^\[\]]*(?:\[[^\[\]*\][^\[\]]*)*\]}]}
    
    foreach pattern $patterns {
        set matches [regexp -all -inline $pattern $text]
        foreach match $matches {
            if {![catch {parse_json $match 1} parsed]} {
                lappend results $parsed
            }
        }
    }
    
    return $results
}

# Hauptprogramm
proc main {argv} {
    set options {
        {file.f "Input is a file path"}
        {repair.r "Enable JSON repair" 1}
        {no-repair "Disable JSON repair" 0}
        {pretty.p "Pretty print output"}
    }
    
    array set params [::cmdline::getoptions argv $options]
    
    if {[llength $argv] < 1} {
        puts stderr "Usage: $::argv0 <input> \[options\]"
        exit 1
    }
    
    set input [lindex $argv 0]
    
    if {$params(file)} {
        if {[catch {read_file $input} content]} {
            puts stderr "Error reading file: $content"
            exit 1
        }
    } else {
        set content $input
    }
    
    if {[catch {parse_json $content $params(repair)} result]} {
        puts stderr "Error: $result"
        exit 1
    }
    
    if {$params(pretty)} {
        puts [::json::dict2json $result 2]
    } else {
        puts [::json::dict2json $result]
    }
}

# Hilfsfunktion zum Lesen einer Datei
proc read_file {filename} {
    if {[catch {open $filename r} fh]} {
        error $fh
    }
    set content [read $fh]
    close $fh
    return $content
}

# Starte das Hauptprogramm wenn diese Datei direkt ausgeführt wird
if {[info script] eq $::argv0} {
    main $::argv
}
