#!/usr/bin/env tclsh
# test-agent.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-agent.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

package require http
package require json
package require json::write

# Set strict error handling
if {![info exists env(PERPLEXITY_API_KEY)] || $env(PERPLEXITY_API_KEY) eq ""} {
    puts stderr "PERPLEXITY_API_KEY is required"
    exit 1
}

set prompt [lindex $argv 0]
if {$prompt eq ""} {
    set prompt "Compare recent open-source LLMs in terms of performance, licensing, and practical use."
}

set tmpdir [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}]
set out [file join $tmpdir "perplexity-agent-test.json"]

# Create JSON payload
set input $prompt
set data [json::write object preset "fast-search" input $input]
set data_len [string length $data]

# Make HTTP request
set token [http::geturl https://api.perplexity.ai/v1/agent \
    -headers [list \
        Authorization "Bearer $env(PERPLEXITY_API_KEY)" \
        Content-Type "application/json" \
        Content-Length $data_len \
    ] \
    -query $data \
    -type application/json
]

set code [http::status $token]
set http_code [lindex [split [http::code $token] " "] 1]

# Write response to file
set fh [open $out w]
puts -nonewline $fh [http::data $token]
close $fh

http::cleanup $token

puts "agent_http=$http_code"

# Process JSON response
if {[catch {set json_data [json::json2dict [http::data $token]]}]} {
    puts [json::write object keys {} id null status null output_count 0 error null]
} else {
    set keys [dict keys $json_data]
    set id [expr {[dict exists $json_data id] ? [dict get $json_data id] : "null"}]
    set status [expr {[dict exists $json_data status] ? [dict get $json_data status] : "null"}]
    
    if {[dict exists $json_data output] && [llength [dict get $json_data output]] > 0} {
        set output_count [llength [dict get $json_data output]]
    } else {
        set output_count 0
    }
    
    set error [expr {[dict exists $json_data error] ? [dict get $json_data error] : "null"}]
    
    puts [json::write object \
        keys [json::write array {*}$keys] \
        id $id \
        status $status \
        output_count $output_count \
        error $error \
    ]
}
