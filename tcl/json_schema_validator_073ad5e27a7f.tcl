#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "efd3295684d97205b2ca1684448517245277ec4e207f6df935ce10ecb3c164c3", "source_sha256": "f55ff3c9a1d0fb13ff0d5dd08f91e1c1a304c7d83f3d1bb93f165f2437d276b9", "target_language": "tcl"}
# json_schema_validator.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
# Erweitert Pydantic mit externen Schema-Dateien.

package require json
package require cmdline

# Globale Variablen für Module
set HAS_JSONSCHEMA 0

# Versuche jsonschema package zu laden
if {[catch {package require jsonschema}]} {
    puts stderr "Warning: jsonschema package not available"
} else {
    set HAS_JSONSCHEMA 1
}

# Hilfsfunktionen für Fehlerbehandlung
proc error {msg} {
    puts stderr $msg
    exit 1
}

proc SchemaValidationError {message} {
    return "SchemaValidationError: $message"
}

proc JSONProcessingError {message} {
    return "JSONProcessingError: $message"
}

proc JSONValidationError {message} {
    return "JSONValidationError: $message"
}

# Lädt ein JSON Schema aus verschiedenen Quellen
proc load_schema {schema_source} {
    # Wenn es bereits ein dict ist
    if {[string match "*{*}*" $schema_source] && [string match "*:*" $schema_source]} {
        if {[catch {::json::json2dict $schema_source} result]} {
            error [SchemaValidationError "Invalid JSON in schema: $result"]
        }
        return $result
    }
    
    # Prüfe ob es ein Dateipfad ist
    if {[file exists $schema_source]} {
        if {[catch {open $schema_source r} fd]} {
            error [SchemaValidationError "Cannot open schema file: $fd"]
        }
        set content [read $fd]
        close $fd
        
        if {[catch {::json::json2dict $content} result]} {
            error [SchemaValidationError "Invalid JSON in schema file: $result"]
        }
        return $result
    }
    
    # Versuche als JSON String zu parsen
    if {[catch {::json::json2dict $schema_source} result]} {
        error [SchemaValidationError "Schema not found or invalid: $schema_source"]
    }
    return $result
}

# Validiert Daten gegen ein JSON Schema
proc validate_with_jsonschema {data schema {draft "auto"}} {
    global HAS_JSONSCHEMA
    
    if {!$HAS_JSONSCHEMA} {
        error [SchemaValidationError "jsonschema not installed. Please install tcllib-jsonschema"]
    }
    
    # Lade das Schema
    if {[catch {load_schema $schema} schema_dict]} {
        error $schema_dict
    }
    
    # Konvertiere Daten zu JSON falls nötig
    set json_data $data
    if {![string match "*{*}*" $data] && ![string match "*\[*" $data]} {
        # Wahrscheinlich kein JSON - versuche zu konvertieren
        set json_data [::json::dict2json $data]
    }
    
    # Validiere
    if {[catch {::jsonschema::validate $json_data $schema_dict} result]} {
        error [SchemaValidationError "Schema validation failed: $result"]
    }
    
    return 1
}

# Parst, repariert und validiert JSON gegen Schema
proc validate_and_convert {raw_input schema {repair 1}} {
    # In Tcl verwenden wir einfach json::json2dict für das Parsen
    if {[catch {::json::json2dict $raw_input} data]} {
        if {$repair} {
            # Versuche einfache Reparaturen
            set repaired [string map {"'" "\"" "\"" "'"} $raw_input]
            if {[catch {::json::json2dict $repaired} data]} {
                error [JSONProcessingError "Could not parse JSON: $data"]
            }
        } else {
            error [JSONProcessingError "Could not parse JSON: $data"]
        }
    }
    
    # Validiere
    if {[catch {validate_with_jsonschema $raw_input $schema} result]} {
        error $result
    }
    
    return $data
}

# Hilfsklasse zum Erstellen von JSON Schemas (als Tcl-Procs)
namespace eval SchemaBuilder {
    # Erstellt ein Object-Schema
    proc object {properties {required ""}} {
        set schema [dict create type object properties $properties]
        if {$required ne ""} {
            dict set schema required $required
        }
        return $schema
    }
    
    # Erstellt ein String-Schema
    proc string {{enum ""} {pattern ""} {min_length ""}} {
        set schema [dict create type string]
        if {$enum ne ""} {
            dict set schema enum $enum
        }
        if {$pattern ne ""} {
            dict set schema pattern $pattern
        }
        if {$min_length ne ""} {
            dict set schema minLength $min_length
        }
        return $schema
    }
    
    # Erstellt ein Integer-Schema
    proc integer {{minimum ""} {maximum ""}} {
        set schema [dict create type integer]
        if {$minimum ne ""} {
            dict set schema minimum $minimum
        }
        if {$maximum ne ""} {
            dict set schema maximum $maximum
        }
        return $schema
    }
    
    # Erstellt ein Array-Schema
    proc array {items {min_items ""}} {
        set schema [dict create type array items $items]
        if {$min_items ne ""} {
            dict set schema minItems $min_items
        }
        return $schema
    }
}

# Hauptprogramm
proc main {} {
    global argv argc
    
    # Kommandozeilenoptionen parsen
    set options {
        {schema.arg "" "Schema file"}
        {file "Input is file"}
        {repair "Repair JSON if possible"}
    }
    
    if {[catch {cmdline::typedGetoptions argv $options} result]} {
        puts stderr "Error parsing options: $result"
        exit 1
    }
    
    array set opts $result
    
    if {$argc < 1} {
        puts stderr "Usage: $argv0 \[options\] <input>"
        puts stderr "Options:"
        puts stderr "  --schema,-s <file>  Schema file (required)"
        puts stderr "  --file,-f          Input is file"
        puts stderr "  --repair,-r        Repair JSON if possible"
        exit 1
    }
    
    set input [lindex $argv 0]
    
    if {$opts(schema) eq ""} {
        puts stderr "Schema file is required (--schema)"
        exit 1
    }
    
    # Lade Input (Auto-detect file vs string)
    set raw_input ""
    set input_path $input
    
    if {$opts(file) || ([file exists $input_path] && [file isfile $input_path])} {
        if {[catch {open $input_path r} fd]} {
            puts stderr "Cannot open input file: $fd"
            exit 1
        }
        set raw_input [read $fd]
        close $fd
    } else {
        set raw_input $input
    }
    
    # Validiere
    if {[catch {validate_and_convert $raw_input $opts(schema) $opts(repair)} result]} {
        puts stderr "✗ Validation failed: $result"
        exit 1
    }
    
    # Ausgabe
    puts [::json::dict2json $result]
    puts stderr "\n✓ Validation passed"
}

# Starte Hauptprogramm wenn direkt aufgerufen
if {[info script] eq $argv0} {
    main
}
