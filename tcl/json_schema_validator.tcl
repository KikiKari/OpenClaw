#!/usr/bin/env tclsh8.6
# json_schema_validator.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
# Erweitert Pydantic mit externen Schema-Dateien.

package require json
package require json::schema

# Globale Variablen für Verfügbarkeit
set HAS_JSONSCHEMA 1

# Fehlerklassen definieren
proc SchemaValidationError {msg} {
    error "SchemaValidationError: $msg"
}

# Lädt ein JSON Schema aus verschiedenen Quellen
proc load_schema {schema_source} {
    # Prüfe ob es ein Dictionary ist (als JSON-String)
    if {[string index $schema_source 0] eq "\{"} {
        if {[catch {::json::json2dict $schema_source} result]} {
            SchemaValidationError "Invalid JSON in schema: $result"
        }
        return $result
    }
    
    # Prüfe ob es eine Datei ist
    if {[file exists $schema_source]} {
        if {[catch {read_file $schema_source} content]} {
            SchemaValidationError "Cannot read schema file: $content"
        }
        if {[catch {::json::json2dict $content} result]} {
            SchemaValidationError "Invalid JSON in schema file: $result"
        }
        return $result
    }
    
    # Versuche als JSON String zu parsen
    if {[catch {::json::json2dict $schema_source} result]} {
        SchemaValidationError "Schema not found or invalid: $schema_source"
    }
    return $result
}

# Liest eine Datei und gibt den Inhalt zurück
proc read_file {filepath} {
    if {[catch {open $filepath r} fh]} {
        error "Cannot open file $filepath: $fh"
    }
    set content [read $fh]
    close $fh
    return $content
}

# Validiert Daten gegen ein JSON Schema
proc validate_with_jsonschema {data schema {draft "auto"}} {
    global HAS_JSONSCHEMA
    
    if {!$HAS_JSONSCHEMA} {
        SchemaValidationError "jsonschema not installed"
    }
    
    if {[catch {load_schema $schema} schema_dict]} {
        SchemaValidationError "Failed to load schema: $schema_dict"
    }
    
    # Konvertiere Daten zu JSON falls nötig
    if {[llength $data] > 1 || [string index $data 0] ne "\{"} {
        set data_json [::json::dict2json $data]
    } else {
        set data_json $data
    }
    
    if {[catch {::json::schema::validate $data_json $schema_dict} result]} {
        SchemaValidationError "Schema validation failed: $result"
    }
    
    if {$result ne ""} {
        SchemaValidationError "Schema validation failed: $result"
    }
    
    return 1
}

# Parst, repariert und validiert JSON gegen Schema
proc validate_and_convert {raw_input schema {repair 1}} {
    # Parse JSON (vereinfachte Version)
    if {[catch {parse_json $raw_input $repair} data]} {
        error "JSON processing error: $data"
    }
    
    # Validiere
    if {[catch {validate_with_jsonschema $data $schema} result]} {
        error "Validation failed: $result"
    }
    
    return $data
}

# Einfacher JSON Parser (da tcllib::json nicht alle Features hat)
proc parse_json {raw_input repair} {
    # Entferne einfache Anführungszeichen und konvertiere zu doppelten
    set fixed_input [regsub -all {'} $raw_input {"}]
    
    if {[catch {::json::json2dict $fixed_input} result]} {
        if {$repair} {
            # Versuche einfache Reparaturen
            set repaired [regsub -all {,\s*}} $fixed_input "}"]
            set repaired [regsub -all {,\s*\]} $repaired "]"]
            if {[catch {::json::json2dict $repaired} result]} {
                error "Cannot parse JSON even after repair: $result"
            }
            return $result
        } else {
            error "Cannot parse JSON: $result"
        }
    }
    return $result
}

# Hilfsklasse zum Erstellen von JSON Schemas (prozedural)
namespace eval SchemaBuilder {
    proc object {properties {required ""}} {
        set schema [dict create type object properties $properties]
        if {$required ne ""} {
            dict set schema required $required
        }
        return $schema
    }
    
    proc string {{enum ""} {pattern ""} {min_length ""}} {
        set schema [dict create type string]
        if {$enum ne ""} {
            dict set schema enum $enum
        }
        if {$pattern ne ""} {
            dict set schema pattern $pattern
        }
        if {$min_length ne "" && $min_length ne "none"} {
            dict set schema minLength $min_length
        }
        return $schema
    }
    
    proc integer {{minimum ""} {maximum ""}} {
        set schema [dict create type integer]
        if {$minimum ne "" && $minimum ne "none"} {
            dict set schema minimum $minimum
        }
        if {$maximum ne "" && $maximum ne "none"} {
            dict set schema maximum $maximum
        }
        return $schema
    }
    
    proc array {items {min_items ""}} {
        set schema [dict create type array items $items]
        if {$min_items ne "" && $min_items ne "none"} {
            dict set schema minItems $min_items
        }
        return $schema
    }
}

# Hauptprogramm
proc main {} {
    global argv argc
    
    # Einfacher Argparser
    set input ""
    set schema ""
    set is_file 0
    set repair 1
    
    # Parse Argumente
    for {set i 0} {$i < $argc} {incr i} {
        set arg [lindex $argv $i]
        if {$arg eq "--schema" || $arg eq "-s"} {
            incr i
            set schema [lindex $argv $i]
        } elseif {$arg eq "--file" || $arg eq "-f"} {
            set is_file 1
        } elseif {$arg eq "--repair" || $arg eq "-r"} {
            set repair 1
        } elseif {$input eq ""} {
            set input $arg
        }
    }
    
    if {$input eq "" || $schema eq ""} {
        puts stderr "Usage: $argv0 <input> --schema <schema> \[--file] \[--repair]"
        exit 1
    }
    
    # Lade Input (Auto-detect file vs string)
    if {$is_file || ([file exists $input] && [file isfile $input])} {
        if {[catch {read_file $input} raw_input]} {
            puts stderr "✗ Cannot read input file: $raw_input"
            exit 1
        }
    } else {
        set raw_input $input
    }
    
    # Validiere
    if {[catch {validate_and_convert $raw_input $schema $repair} result]} {
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
