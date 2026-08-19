#!/usr/bin/env tclsh
# gemini-ask.js — portiert nach tcl
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

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

set DEFAULT_MODEL [expr {[info exists env(GEMINI_MODEL)] ? $env(GEMINI_MODEL) : "gemini-pro"}]

proc main {} {
    global argv argc env DEFAULT_MODEL
    
    # Check API key
    if {![info exists env(GEMINI_API_KEY)] || $env(GEMINI_API_KEY) eq ""} {
        puts stderr "Error: GEMINI_API_KEY environment variable is required"
        exit 1
    }
    
    # Parse arguments
    set prompt ""
    set modelName $DEFAULT_MODEL
    set args $argv
    
    # Check for --model flag
    set modelIndex -1
    for {set i 0} {$i < [llength $args]} {incr i} {
        set arg [lindex $args $i]
        if {$arg eq "--model" || $arg eq "-m"} {
            set modelIndex $i
            break
        }
    }
    
    if {$modelIndex != -1 && $modelIndex + 1 < [llength $args]} {
        set modelName [lindex $args [expr {$modelIndex + 1}]]
        set args [lreplace $args $modelIndex [expr {$modelIndex + 1}]]
    }
    
    # Check for --system flag (system prompt)
    set systemPrompt ""
    set systemIndex -1
    for {set i 0} {$i < [llength $args]} {incr i} {
        set arg [lindex $args $i]
        if {$arg eq "--system" || $arg eq "-s"} {
            set systemIndex $i
            break
        }
    }
    
    if {$systemIndex != -1 && $systemIndex + 1 < [llength $args]} {
        set systemPrompt [lindex $args [expr {$systemIndex + 1}]]
        set args [lreplace $args $systemIndex [expr {$systemIndex + 1}]]
    }
    
    # Check for --file flag
    set fileFlagIndex -1
    for {set i 0} {$i < [llength $args]} {incr i} {
        set arg [lindex $args $i]
        if {$arg eq "--file" || $arg eq "-f"} {
            set fileFlagIndex $i
            break
        }
    }
    
    if {$fileFlagIndex != -1} {
        if {$fileFlagIndex + 1 >= [llength $args]} {
            puts stderr "Error: No file specified"
            exit 1
        }
        set filePath [lindex $args [expr {$fileFlagIndex + 1}]]
        if {[catch {open $filePath r} fileHandle]} {
            puts stderr "Error: Cannot read file $filePath"
            exit 1
        }
        set prompt [read $fileHandle]
        close $fileHandle
        set args [lreplace $args $fileFlagIndex [expr {$fileFlagIndex + 1}]]
    } elseif {[llength $args] > 0} {
        set prompt [join $args " "]
    } elseif {[info exists env(STDIN_IS_TTY)] && !$env(STDIN_IS_TTY)} {
        # Read from stdin
        set prompt [read stdin]
    } else {
        # Try to read from stdin anyway
        set stdinChan [chan create r]
        if {[chan pending readable stdin]} {
            set prompt [read stdin]
        }
    }
    
    if {[string trim $prompt] eq ""} {
        puts stderr "Error: No prompt provided"
        puts stderr "Usage: gemini-ask \"your question\""
        puts stderr "       gemini-ask --model gemini-pro \"your question\""
        puts stderr "       echo \"your question\" | gemini-ask"
        exit 1
    }
    
    # Call Gemini API
    if {[catch {call_gemini_api $env(GEMINI_API_KEY) $modelName $prompt $systemPrompt} result]} {
        puts stderr "Error: $result"
        if {[string match "*API key*" $result]} {
            puts stderr "Make sure GEMINI_API_KEY is set correctly"
        }
        exit 1
    }
    
    puts $result
}

proc call_gemini_api {apiKey model prompt systemPrompt} {
    set url "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey"
    
    # Prepare generation config
    set generationConfig [dict create \
        maxOutputTokens 8192 \
        temperature 0.7 \
        topP 0.95 \
    ]
    
    # Build request content
    if {$systemPrompt ne ""} {
        # Use chat-like approach with system prompt
        set contents [list \
            [dict create role user parts [list [dict create text $systemPrompt]]] \
            [dict create role model parts [list [dict create text "Understood. I will follow that instruction."]]] \
            [dict create role user parts [list [dict create text $prompt]]] \
        ]
    } else {
        # Direct generation
        set contents [list [dict create role user parts [list [dict create text $prompt]]]]
    }
    
    set requestData [dict create \
        contents $contents \
        generationConfig $generationConfig \
    ]
    
    set jsonData [json::write object \
        contents [json::write array {*}[lmap c $contents {
            json::write object \
                role [dict get $c role] \
                parts [json::write array [json::write object text [dict get [lindex [dict get $c parts] 0] text]]]
        }]] \
        generationConfig [json::write object \
            maxOutputTokens [dict get $generationConfig maxOutputTokens] \
            temperature [dict get $generationConfig temperature] \
            topP [dict get $generationConfig topP] \
        ] \
    ]
    
    # Make HTTP request
    set headers [list Content-Type application/json]
    set token [http::geturl $url -headers $headers -query $jsonData -method POST]
    
    set status [http::status $token]
    set code [http::ncode $token]
    set data [http::data $token]
    http::cleanup $token
    
    if {$status ne "ok" || $code != 200} {
        error "HTTP Error: $code - $data"
    }
    
    # Parse response
    if {[catch {json::json2dict $data} responseDict]} {
        error "Failed to parse response: $data"
    }
    
    # Extract text from response
    if {[dict exists $responseDict candidates 0 content parts 0 text]} {
        return [dict get $responseDict candidates 0 content parts 0 text]
    } else {
        error "Unexpected response format"
    }
}

# Run main function
main
