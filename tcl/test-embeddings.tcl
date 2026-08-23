#!/usr/bin/env tclsh
# test-embeddings.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

if {![info exists env(PERPLEXITY_API_KEY)] || $env(PERPLEXITY_API_KEY) eq ""} {
    puts stderr "PERPLEXITY_API_KEY is required"
    exit 1
}

set out [file join [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}] "perplexity-embeddings-test.json"]

set payload "{\"input\":[\"Scientists explore the universe driven by curiosity.\",\"Curiosity compels us to seek explanations, not just observations.\",\"Historical discoveries began with curious questions.\",\"The pursuit of knowledge distinguishes human curiosity from mere stimulus response.\",\"Philosophy examines the nature of curiosity.\"],\"model\":\"pplx-embed-v1-4b\"}"

# Create temporary file for storing response
set tmpfile [open $out w]
close $tmpfile

# Execute curl command
if {[catch {
    set code [exec curl -sS -o $out -w "%{http_code}" \
        -X POST "https://api.perplexity.ai/v1/embeddings" \
        -H "Authorization: Bearer $env(PERPLEXITY_API_KEY)" \
        -H "Content-Type: application/json" \
        -d $payload]
} result]} {
    puts stderr "curl failed: $result"
    exit 1
}

puts "embeddings_http=$code"

# Process JSON response
if {[catch {
    set fd [open $out r]
    set json_data [read $fd]
    close $fd
    
    # Parse JSON manually since we can't assume json package availability
    # Extract keys
    set keys_list {}
    if {[regexp {\{} $json_data]} {
        lappend keys_list "object"
    }
    if {[regexp {\"model\":} $json_data]} {
        lappend keys_list "model"
    }
    if {[regexp {\"data\":} $json_data]} {
        lappend keys_list "data"
    }
    if {[regexp {\"error\":} $json_data]} {
        lappend keys_list "error"
    }
    
    # Extract model
    set model "null"
    if {[regexp {"model":"([^"]+)"} $json_data match model_val]} {
        set model "\"$model_val\""
    }
    
    # Count data items
    set item_count 0
    if {[regexp {\"data\":\[(.*?)\]} $json_data match data_content]} {
        # Count objects in data array
        set item_count [llength [split $data_content "\},\{"]]
        if {$data_content ne "" && $item_count == 0} {
            set item_count 1
        }
    }
    
    # Get first embedding dimension count
    set first_dim 0
    if {[regexp {\"embedding\":$(.*?)\]} $json_data match embedding_content]} {
        set first_dim [llength [split $embedding_content ","]]
    }
    
    # Check for error
    set error "null"
    if {[regexp {"error":(\{[^}]+\})} $json_data match error_obj]} {
        set error "$error_obj"
    }
    
    puts "\{keys: \[[join $keys_list ", "]\], model: $model, item_count: $item_count, first_dim: $first_dim, error: $error\}"
} result]} {
    puts stderr "JSON processing failed: $result"
    exit 1
}
