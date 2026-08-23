#!/usr/bin/env tclsh
# test-search.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-search.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

package require http
package require json
package require tls

# Set HTTP to use TLS
http::register https 443 [list ::tls::socket -autoservername true]

# Check for required environment variable
if {![info exists env(PERPLEXITY_API_KEY)] || $env(PERPLEXITY_API_KEY) eq ""} {
    puts stderr "PERPLEXITY_API_KEY is required"
    exit 1
}

# Get command line argument or default
set query [lindex $argv 0]
if {$query eq ""} {
    set query "Perplexity API Platform"
}

# Get environment variables or defaults
set max_results [expr {[info exists env(PERPLEXITY_MAX_RESULTS)] ? $env(PERPLEXITY_MAX_RESULTS) : 3}]
set max_tokens_per_page [expr {[info exists env(PERPLEXITY_MAX_TOKENS_PER_PAGE)] ? $env(PERPLEXITY_MAX_TOKENS_PER_PAGE) : 256}]

# Determine temp directory
set tmpdir "/tmp"
if {[info exists env(TMPDIR)] && $env(TMPDIR) ne ""} {
    set tmpdir $env(TMPDIR)
}
set out [file join $tmpdir "perplexity-search-test.json"]

# Create JSON payload
set data [dict create \
    query $query \
    max_results $max_results \
    max_tokens_per_page $max_tokens_per_page]
set json_payload [json::write object {*}$data]

# Set up HTTP request
set url "https://api.perplexity.ai/search"
set headers [list \
    "Authorization" "Bearer $env(PERPLEXITY_API_KEY)" \
    "Content-Type" "application/json"]

# Perform HTTP request
set token [http::geturl $url \
    -headers $headers \
    -method POST \
    -query $json_payload \
    -binary true]

# Get response information
set code [http::status $token]
set http_code [http::ncode $token]

# Write response to file
set fp [open $out w]
puts -nonewline $fp [http::data $token]
close $fp

# Clean up
http::cleanup $token

# Output HTTP status
puts "search_http=$http_code"

# Process and output JSON response
set fp [open $out r]
set content [read $fp]
close $fp

# Parse JSON and extract information
if {[catch {json::json2dict $content} parsed]} {
    puts "{ \"keys\": [], \"result_count\": 0, \"first\": null }"
    exit
}

set keys [dict keys $parsed]
set results_list {}

# Try to get results from different possible locations
if {[dict exists $parsed results]} {
    set results_list [dict get $parsed results]
} elseif {[dict exists $parsed data]} {
    set results_list [dict get $parsed data]
} else {
    set results_list {}
}

set result_count [llength $results_list]
set first null

if {$result_count > 0} {
    set first [lindex $results_list 0]
}

# Output in the requested format
puts -nonewline "{ \"keys\": \["
set key_list {}
foreach key $keys {
    lappend key_list "\"$key\""
}
puts -nonewline [join $key_list ", "]
puts -nonewline "\], \"result_count\": $result_count, \"first\": "
if {$first eq "null"} {
    puts "null }"
} else {
    puts "$first }"
}
