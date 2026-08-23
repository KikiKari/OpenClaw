#!/usr/bin/env tclsh
# tavily_search.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/tavily/scripts/tavily_search.py
# auch in: OpenClaw@gateway2:skills/tavily/scripts/tavily_search.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Tavily AI Search - Optimized search for LLMs and AI applications
# Requires: curl and jq for HTTP requests and JSON parsing

package require http
package require json
package require cmdline

proc search {args} {
    array set options {
        query ""
        api_key ""
        search_depth "basic"
        topic "general"
        max_results 5
        include_answer true
        include_raw_content false
        include_images false
        include_domains ""
        exclude_domains ""
    }
    
    foreach {key value} $args {
        set options($key) $value
    }
    
    # Check if curl is available
    if {[catch {exec which curl}]} {
        return [dict create \
            error "curl is required but not found" \
            install_command "Install curl package"]
    }
    
    # Check if jq is available
    if {[catch {exec which jq}]} {
        return [dict create \
            error "jq is required but not found" \
            install_command "Install jq package"]
    }
    
    if {$options(api_key) eq ""} {
        return [dict create \
            error "Tavily API key required. Get one at https://tavily.com" \
            setup_instructions "Set TAVILY_API_KEY environment variable or pass --api-key"]
    }
    
    # Build request body
    set body [dict create]
    dict set body api_key $options(api_key)
    dict set body query $options(query)
    dict set body search_depth $options(search_depth)
    dict set body topic $options(topic)
    dict set body max_results $options(max_results)
    dict set body include_answer [string is true $options(include_answer)]
    dict set body include_raw_content [string is true $options(include_raw_content)]
    dict set body include_images [string is true $options(include_images)]
    
    if {$options(include_domains) ne ""} {
        dict set body include_domains [split $options(include_domains) ,]
    }
    
    if {$options(exclude_domains) ne ""} {
        dict set body exclude_domains [split $options(exclude_domains) ,]
    }
    
    # Convert to JSON
    set json_body [::json::dict2json $body]
    
    # Make HTTP request using curl
    if {[catch {
        set temp_file [::mktemp tmp.XXXXXX]
        set fh [open $temp_file w]
        puts $fh $json_body
        close $fh
        
        set cmd [list curl -s -X POST \
            -H "Content-Type: application/json" \
            -d @$temp_file \
            https://api.tavily.com/search]
        
        set response [exec {*}$cmd]
        file delete $temp_file
        set parsed_response [::json::json2dict $response]
        
        return [dict create \
            success true \
            query $options(query) \
            answer [dict get $parsed_response answer] \
            results [dict get $parsed_response results] \
            images [dict get $parsed_response images] \
            response_time [dict get $parsed_response response_time] \
            usage [dict get $parsed_response usage]]
    } err]} {
        return [dict create error $err query $options(query)]
    }
}

proc format_output {result json_flag} {
    if {$json_flag} {
        puts [::json::dict2json $result]
        return
    }
    
    if {[dict exists $result error]} {
        puts stderr "Error: [dict get $result error]"
        if {[dict exists $result install_command]} {
            puts stderr "\nTo install: [dict get $result install_command]"
        }
        if {[dict exists $result setup_instructions]} {
            puts stderr "\nSetup: [dict get $result setup_instructions]"
        }
        exit 1
    }
    
    # Format human-readable output
    puts "Query: [dict get $result query]"
    puts "Response time: [dict get $result response_time]s"
    set usage_dict [dict get $result usage]
    puts "Credits used: [dict get $usage_dict credits]\n"
    
    if {[dict exists $result answer] && [dict get $result answer] ne ""} {
        puts "=== AI ANSWER ==="
        puts [dict get $result answer]
        puts ""
    }
    
    if {[dict exists $result results]} {
        set results [dict get $result results]
        puts "=== RESULTS ==="
        set i 1
        foreach item $results {
            puts "\n$i. [dict get $item title]"
            puts "   URL: [dict get $item url]"
            puts "   Score: [format "%.3f" [dict get $item score]]"
            if {[dict exists $item content]} {
                set content [dict get $item content]
                if {[string length $content] > 200} {
                    set content [string range $content 0 199]...
                }
                puts "   $content"
            }
            incr i
        }
    }
    
    if {[dict exists $result images]} {
        set images [dict get $result images]
        puts "\n=== IMAGES ([llength $images]) ==="
        set count 0
        foreach img_url $images {
            if {$count >= 5} break
            puts "   $img_url"
            incr count
        }
    }
}

proc main {} {
    global argv
    
    set optionSpec {
        {query.arg "" "Search query"}
        {api_key.arg "" "Tavily API key (or set TAVILY_API_KEY env var)"}
        {depth.arg "basic" "Search depth: basic (fast) or advanced (comprehensive)"}
        {topic.arg "general" "Search topic: general or news (current events)"}
        {max_results.arg 5 "Maximum number of results (1-10)"}
        {no_answer "Exclude AI-generated answer summary"}
        {raw_content "Include raw HTML content of sources"}
        {images "Include relevant images in results"}
        {include_domains.arg "" "List of domains to specifically include"}
        {exclude_domains.arg "" "List of domains to exclude"}
        {json "Output raw JSON response"}
        {help "Show help message"}
    }
    
    if {[catch {array set opts [cmdline::typedGetopt optionSpec $argv]} err]} {
        puts stderr $err
        exit 1
    }
    
    if {$opts(help)} {
        puts "Tavily AI Search - Optimized search for LLMs"
        puts ""
        puts "Usage: [info script] \[OPTIONS\] QUERY"
        puts ""
        puts "Options:"
        puts "  --api-key API_KEY     Tavily API key (or set TAVILY_API_KEY env var)"
        puts "  --depth DEPTH         Search depth: basic or advanced"
        puts "  --topic TOPIC         Search topic: general or news"
        puts "  --max-results N       Maximum number of results (1-10)"
        puts "  --no-answer           Exclude AI-generated answer summary"
        puts "  --raw-content         Include raw HTML content of sources"
        puts "  --images              Include relevant images in results"
        puts "  --include-domains D   List of domains to specifically include"
        puts "  --exclude-domains D   List of domains to exclude"
        puts "  --json                Output raw JSON response"
        puts "  --help                Show this help message"
        puts ""
        puts "Examples:"
        puts "  # Basic search"
        puts "  [info script] \"What is quantum computing?\""
        puts ""
        puts "  # Advanced search with more results"
        puts "  [info script] \"Climate change solutions\" --depth advanced --max_results 10"
        puts ""
        puts "  # News-focused search"
        puts "  [info script] \"AI developments\" --topic news"
        puts ""
        puts "  # Domain filtering"
        puts "  [info script] \"Python tutorials\" --include_domains python.org --exclude_domains w3schools.com"
        puts ""
        puts "  # Include images in results"
        puts "  [info script] \"Eiffel Tower\" --images"
        puts ""
        puts "Environment Variables:"
        puts "  TAVILY_API_KEY    Your Tavily API key (get one at https://tavily.com)"
        return
    }
    
    if {[llength $argv] == 0 && !$opts(help)} {
        puts stderr "Error: Query argument is required"
        puts stderr "Use --help for usage information"
        exit 1
    }
    
    # Extract query from remaining arguments
    set query_parts {}
    foreach arg $argv {
        if {![string match "--*" $arg]} {
            lappend query_parts $arg
        }
    }
    set query [join $query_parts " "]
    
    if {$query eq "" && !$opts(help)} {
        puts stderr "Error: Query argument is required"
        puts stderr "Use --help for usage information"
        exit 1
    }
    
    # Get API key from args or environment
    set api_key $opts(api_key)
    if {$api_key eq ""} {
        if {[info exists ::env(TAVILY_API_KEY)]} {
            set api_key $::env(TAVILY_API_KEY)
        }
    }
    
    # Prepare search parameters
    set search_params [list \
        query $query \
        api_key $api_key \
        search_depth $opts(depth) \
        topic $opts(topic) \
        max_results $opts(max_results) \
        include_answer [expr {!$opts(no_answer)}] \
        include_raw_content $opts(raw_content) \
        include_images $opts(images) \
        include_domains $opts(include_domains) \
        exclude_domains $opts(exclude_domains) \
    ]
    
    set result [search {*}$search_params]
    format_output $result $opts(json)
}

if {[info script] eq $argv0} {
    main
}
