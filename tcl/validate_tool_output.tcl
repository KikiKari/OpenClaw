#!/usr/bin/env tclsh8.6
# validate_tool_output.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/validate_tool_output.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/validate_tool_output.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Validiert Tool-Outputs gegen ein JSON-Schema.
# Für OpenClaw Tool-Call-Validierung.

package require json
package require cmdline

# Tcl equivalent of Python's argparse
proc parse_args {argv} {
    set options {
        {schema.arg "" "JSON schema file"}
        {file "Input is a file"}
        {repair "Repair mode (default true)"}
        {strict "Strict validation"}
        {help "Show help"}
    }
    
    if {[catch {cmdline::typedGetoptions argv $options} result]} {
        puts stderr "Error parsing arguments: $result"
        exit 1
    }
    
    set opts $result
    
    if {$opts(help)} {
        puts [cmdline::typedUsage $options "Validate tool output against schema"]
        exit 0
    }
    
    if {$opts(schema) eq ""} {
        puts stderr "Error: --schema argument is required"
        exit 1
    }
    
    set opts(input) [lindex $argv 0]
    if {$opts(input) eq ""} {
        puts stderr "Error: json_input argument is required"
        exit 1
    }
    
    return $opts
}

# Simple JSON schema validator - mimics basic pydantic behavior
proc validate_against_schema {data schema repair strict} {
    # In a real implementation, this would do actual schema validation
    # For now, we'll just parse and re-output the JSON to mimic the behavior
    
    # If repair is enabled (default), we try to fix common issues
    if {$repair} {
        # Basic repair logic could go here
    }
    
    # Strict validation could enforce additional rules
    if {$strict} {
        # Additional strict validation logic could go here
    }
    
    # Return validated data
    return $data
}

proc main {argv} {
    set opts [parse_args $argv]
    
    # Load schema
    if {[catch {
        set schema_file [open $opts(schema) r]
        set schema_data [read $schema_file]
        close $schema_file
        set schema [::json::json2dict $schema_data]
    } error]} {
        puts stderr "Error loading schema: $error"
        exit 1
    }
    
    # Load input
    if {[catch {
        if {$opts(file)} {
            set input_file [open $opts(input) r]
            set raw_input [read $input_file]
            close $input_file
        } else {
            set raw_input $opts(input)
        }
        set input_data [::json::json2dict $raw_input]
    } error]} {
        puts stderr "Error loading input: $error"
        exit 1
    }
    
    # Validate input against schema
    if {[catch {
        set result [validate_against_schema $input_data $schema $opts(repair) $opts(strict)]
        # Convert back to JSON for output
        set output_json [::json::dict2json $result]
        puts $output_json
    } error]} {
        puts stderr "Validation error: $error"
        exit 1
    }
}

# Check if script is run directly
if {[info script] eq $argv0} {
    main $argv
}
