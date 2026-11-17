#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "f147be6518c783b67b934a18a5cd85de85d9d2339352d4e6d1afb3c5a0cc16eb", "source_sha256": "9411ee01f75190a7b3bf9f276fc6bb624d2c943629885c1ddfc9f71a0039070e", "target_language": "tcl"}
# gemini-ask.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# gemini-ask.tcl - CLI tool for Google Gemini API
# 
# Usage:
#   tclsh gemini-ask.tcl "Your question here"
#   echo "Your question" | tclsh gemini-ask.tcl
#   tclsh gemini-ask.tcl --file prompt.txt
#   tclsh gemini-ask.tcl --model gemini-pro "Your question"
# 
# Environment:
#   GEMINI_API_KEY - Required API key
#   GEMINI_MODEL   - Optional default model (default: gemini-pro)

package require http
package require json
package require tls

# Initialize TLS for HTTPS support
http::register https 443 [list ::tls::socket]

# Default model
set DEFAULT_MODEL [expr {[info exists ::env(GEMINI_MODEL)] ? $::env(GEMINI_MODEL) : "gemini-pro"}]

proc main {} {
    global argc argv DEFAULT_MODEL
    
    # Check API key
    if {![info exists ::env(GEMINI_API_KEY)] || $::env(GEMINI_API_KEY) eq ""} {
        puts stderr "Error: GEMINI_API_KEY environment variable is required"
        exit 1
    }
    
    # Parse arguments
    set prompt ""
    set modelName $DEFAULT_MODEL
    set args $argv
    
    # Check for --model flag
    set modelIndex [lsearch -exact $args "--model"]
    if {$modelIndex == -1} {
        set modelIndex [lsearch -exact $args "-m"]
    }
    if {$modelIndex != -1 && [expr {$modelIndex + 1}] < [llength $args]} {
        set modelName [lindex $args [expr {$modelIndex + 1}]]
        set args [lreplace $args $modelIndex [expr {$modelIndex + 1}]]
    }
    
    # Check for --system flag (system prompt)
    set systemPrompt ""
    set systemIndex [lsearch -exact $args "--system"]
    if {$systemIndex == -1} {
        set systemIndex [lsearch -exact $args "-s"]
    }
    if {$systemIndex != -1 && [expr {$systemIndex + 1}] < [llength $args]} {
        set systemPrompt [lindex $args [expr {$systemIndex + 1}]]
        set args [lreplace $args $systemIndex [expr {$systemIndex + 1}]]
    }
    
    if {"--file" in $args || "-f" in $args} {
        set fileIndex [lsearch -exact $args "--file"]
        if {$fileIndex == -1} {
            set fileIndex [lsearch -exact $args "-f"]
        }
        if {$fileIndex == -1 || [expr {$fileIndex + 1}] >= [llength $args]} {
            puts stderr "Error: No file specified"
            exit 1
        }
        set filePath [lindex $args [expr {$fileIndex + 1}]]
        if {[catch {open $filePath r} fileId]} {
            puts stderr "Error: Could not read file $filePath"
            exit 1
        }
        set prompt [read $fileId]
        close $fileId
        # Remove --file and path from args
        set args [lreplace $args $fileIndex [expr {$fileIndex + 1}]]
    } elseif {[llength $args] > 0} {
        set prompt [join $args " "]
    } elseif {[chan pending stdin] > 0} {
        # Read from stdin
        set prompt [read stdin]
    }
    
    if {[string trim $prompt] eq ""} {
        puts stderr "Error: No prompt provided"
        puts stderr "Usage: gemini-ask \"your question\""
        puts stderr "       gemini-ask --model gemini-pro \"your question\""
        puts stderr "       echo \"your question\" | gemini-ask"
        exit 1
    }
    
    # Call the Gemini API
    if {[catch {call_gemini_api $modelName $prompt $systemPrompt} result]} {
        puts stderr "Error: $result"
        if {[string match "*API key*" $result]} {
            puts stderr "Make sure GEMINI_API_KEY is set correctly"
        }
        exit 1
    } else {
        puts $result
    }
}

proc call_gemini_api {modelName prompt systemPrompt} {
    set apiKey $::env(GEMINI_API_KEY)
    set url "https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey"
    
    # Prepare generation config
    array set generationConfig {
        maxOutputTokens 8192
        temperature     0.7
        topP           0.95
    }
    
    # Build request content
    if {$systemPrompt ne ""} {
        # For chat with system prompt, we'll include it as part of the conversation history
        set contents [list \
            [list role user parts [list [list text $systemPrompt]]] \
            [list role model parts [list [list text "Understood. I will follow that instruction."]]] \
            [list role user parts [list [list text $prompt]]] \
        ]
    } else {
        # Direct generation
        set contents [list [list role user parts [list [list text $prompt]]]]
    }
    
    # Create JSON payload
    set jsonData [dict create \
        contents $contents \
        generationConfig [array get generationConfig] \
    ]
    
    set jsonPayload [::json::write object {*}$jsonData]
    
    # Make HTTP POST request
    set token [http::geturl $url -method POST -headers [list Content-Type application/json] -query $jsonPayload]
    set status [http::status $token]
    set code [http::ncode $token]
    set body [http::data $token]
    http::cleanup $token
    
    if {$status != "ok" || $code != 200} {
        error "HTTP Error: $code - $body"
    }
    
    # Parse response
    if {[catch {::json::json2dict $body} responseDict]} {
        error "Failed to parse JSON response: $body"
    }
    
    # Extract text from response
    if {[dict exists $responseDict candidates 0 content parts 0 text]} {
        return [dict get $responseDict candidates 0 content parts 0 text]
    } else {
        error "Unexpected response format: $body"
    }
}

# Run main function
main
