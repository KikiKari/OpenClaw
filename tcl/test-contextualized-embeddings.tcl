#!/usr/bin/env tclsh
# test-contextualized-embeddings.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

package require http
package require json
package require json::write

# Set strict error handling
if {![info exists env(PERPLEXITY_API_KEY)] || $env(PERPLEXITY_API_KEY) eq ""} {
    error "PERPLEXITY_API_KEY is required"
}

set tmpdir [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}]
set out [file join $tmpdir "perplexity-contextualized-embeddings-test.json"]

# Create JSON payload
set payload [json::write object \
    input [json::write array \
        [json::write array \
            "OpenClaw can route web search through Perplexity." \
            "The Perplexity MCP server exposes search and reasoning tools." \
            "Contextualized embeddings improve document chunk retrieval."]] \
    model "pplx-embed-context-v1-4b"]

# Configure HTTP request
http::register https 443 [list ::http::socket4]
set headers [list \
    Authorization "Bearer $env(PERPLEXITY_API_KEY)" \
    Content-Type "application/json"]

# Perform HTTP POST request
set token [http::geturl "https://api.perplexity.ai/v1/contextualizedembeddings" \
    -headers $headers \
    -query $payload \
    -type "application/json" \
    -method POST]

# Write response to file
set fh [open $out w]
puts -nonewline $fh [http::data $token]
close $fh

# Get HTTP status code
set code [http::status $token]
if {$code eq "ok"} {
    set code [http::ncode $token]
}
http::cleanup $token

puts "contextualized_embeddings_http=$code"

# Process and display response data
set fh [open $out r]
set response_data [read $fh]
close $fh

# Parse JSON and extract information
if {[catch {json::json2dict $response_data} parsed_data]} {
    puts [json::write object \
        keys [json::write array] \
        model {} \
        document_count 0 \
        first_chunk_count 0 \
        error "Invalid JSON response"]
} else {
    # Extract values with safe defaults
    set keys_list [dict keys $parsed_data]
    set model [expr {[dict exists $parsed_data model] ? [dict get $parsed_data model] : {}}]
    set data_list [expr {[dict exists $parsed_data data] ? [dict get $parsed_data data] : {}}]
    set document_count [llength $data_list]
    
    set first_chunk_count 0
    if {$document_count > 0} {
        set first_doc [lindex $data_list 0]
        if {[dict exists $first_doc data]} {
            set first_chunks [dict get $first_doc data]
            set first_chunk_count [llength $first_chunks]
        }
    }
    
    set error_val [expr {[dict exists $parsed_data error] ? [dict get $parsed_data error] : {}}]
    
    # Output results
    puts [json::write object \
        keys [json::write array {*}$keys_list] \
        model $model \
        document_count $document_count \
        first_chunk_count $first_chunk_count \
        error $error_val]
}
