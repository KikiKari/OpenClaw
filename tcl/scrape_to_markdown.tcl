#!/usr/bin/env tclsh8.6
# scrape_to_markdown.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# SECURITY MANIFEST:
# Environment variables accessed: none
# External endpoints called: only URLs supplied by the user at runtime via --url / --url-file
# Local files read: --url-file path (if provided by user)
# Local files written: --output-dir/*.md, --output-dir/index.json (if --output-dir provided)
#                      Scrapling automatch SQLite DB (managed by Scrapling, local only)
# Credentials handled: --proxy value (never logged or transmitted beyond the proxy itself)
# Shell injection risk: none (pure Tcl, no exec or shell interpolation)

package require http
package require json
package require fileutil
package require uri
package require textutil

# Helper functions
proc to_str {value} {
    if {$value eq "" || $value eq "None"} {
        return ""
    }
    return [string trim $value]
}

proc slugify {text {max_len 80}} {
    # Remove non-word characters
    regsub -all {[^\w\s-]} [string tolower [string trim $text]] "" text
    # Replace spaces and hyphens with single hyphen
    regsub -all {[-\s]+} $text "-" text
    # Trim to max length and remove leading/trailing hyphens
    set text [string range $text 0 [expr {$max_len - 1}]]
    set text [string trim $text "-"]
    if {$text eq ""} {
        return "page"
    }
    return $text
}

proc extract_html {obj} {
    if {$obj eq "" || $obj eq "None"} {
        return ""
    }
    
    # Try common attributes that might contain HTML
    foreach attr {"html" "raw_html" "content" "markup" "body" "inner_html"} {
        if {[info exists obj($attr)]} {
            set value $obj($attr)
            if {[string match "*<*" $value] && [string match "*>*" $value]} {
                return $value
            }
        }
    }
    
    # If obj itself looks like HTML
    if {[string match "*<*" $obj] && [string match "*>*" $obj]} {
        return $obj
    }
    
    return ""
}

proc extract_title {html} {
    if {[regexp -nocase {<title[^>]*>(.*?)</title>} $html -> title]} {
        # Remove HTML tags from title
        regsub -all {<[^>]+>} $title " " title
        regsub -all {\s+} $title " " title
        return [string trim $title]
    }
    return ""
}

proc load_urls {url_args url_file} {
    set urls $url_args
    
    if {$url_file ne "" && [file exists $url_file]} {
        set fd [open $url_file r]
        while {[gets $fd line] >= 0} {
            set line [string trim $line]
            if {$line ne "" && ![string match "#*" $line]} {
                lappend urls $line
            }
        }
        close $fd
    }
    
    # Remove duplicates while preserving order
    set clean {}
    set seen {}
    foreach u $urls {
        if {$u ni $seen} {
            lappend clean $u
            lappend seen $u
        }
    }
    
    return $clean
}

proc validate_url {url} {
    if {[catch {::uri::split $url} parts]} {
        return 0
    }
    
    array set uri_parts $parts
    set scheme [string tolower $uri_parts(-scheme)]
    set host $uri_parts(-host)
    
    if {($scheme eq "http" || $scheme eq "https") && $host ne ""} {
        return 1
    }
    return 0
}

proc fetch_page {url args} {
    array set opts $args
    
    # Set up HTTP request options
    set headers [list User-Agent "Mozilla/5.0 (compatible; Tcl http client)"]
    
    if {[info exists opts(-timeout)]} {
        set timeout [expr {$opts(-timeout) * 1000}] ;# Convert to milliseconds
    } else {
        set timeout 30000
    }
    
    # Configure HTTP request
    ::http::config -useragent "Mozilla/5.0 (compatible; Tcl http client)"
    
    if {[catch {::http::geturl $url -headers $headers -timeout $timeout} token]} {
        error "Failed to fetch page: $token"
    }
    
    set status [::http::status $token]
    if {$status ne "ok"} {
        ::http::cleanup $token
        error "HTTP request failed with status: $status"
    }
    
    set data [::http::data $token]
    set ncode [::http::ncode $token]
    ::http::cleanup $token
    
    # Create a simple object-like structure for the response
    array set page [list \
        html $data \
        status $ncode \
        status_code $ncode]
    
    return [list [array get page] "http.geturl"]
}

proc pick_main_html {page_data preferred_selector} {
    array set page $page_data
    
    set selectors {}
    if {$preferred_selector ne ""} {
        lappend selectors $preferred_selector
    }
    
    lappend selectors "article" "main" "[role='main']" ".post-content" ".entry-content" ".article-content" "body"
    
    # For now we just return the full HTML since we don't have CSS selection capabilities in pure Tcl
    # In a real implementation you'd want to use something like tdom or htmldoc to parse and select elements
    
    return [list $page(html) "body"]
}

proc html_to_markdown {html preserve_links body_width} {
    # Very basic HTML to Markdown conversion
    # This is a simplified version - a full implementation would be much more complex
    
    set md $html
    
    # Remove script and style tags
    regsub -all -nocase {<script[^>]*>.*?</script>} $md "" md
    regsub -all -nocase {<style[^>]*>.*?</style>} $md "" md
    
    # Convert headers
    regsub -all -nocase {<h1[^>]*>(.*?)</h1>} $md {"# " . [string map {"\n" " "} $m1]} md
    regsub -all -nocase {<h2[^>]*>(.*?)</h2>} $md {"## " . [string map {"\n" " "} $m1]} md
    regsub -all -nocase {<h3[^>]*>(.*?)</h3>} $md {"### " . [string map {"\n" " "} $m1]} md
    
    # Convert paragraphs
    regsub -all -nocase {<p[^>]*>(.*?)</p>} $md {"\n\n" . $m1} md
    
    # Convert links if preserving them
    if {$preserve_links} {
        regsub -all -nocase {<a[^>]+href=["']([^"']+)["'][^>]*>(.*?)</a>} $md {"\[$m2\]\($m1\)"} md
    } else {
        regsub -all -nocase {<a[^>]*>(.*?)</a>} $md {$m1} md
    }
    
    # Convert bold/strong
    regsub -all -nocase {<b[^>]*>(.*?)</b>} $md {"**" . $m1 . "**"} md
    regsub -all -nocase {<strong[^>]*>(.*?)</strong>} $md {"**" . $m1 . "**"} md
    
    # Convert italic/em
    regsub -all -nocase {<i[^>]*>(.*?)</i>} $md {"*" . $m1 . "*"} md
    regsub -all -nocase {<em[^>]*>(.*?)</em>} $md {"*" . $m1 . "*"} md
    
    # Remove remaining HTML tags
    regsub -all {<[^>]+>} $md "" md
    
    # Normalize whitespace
    regsub -all {\n{3,}} $md "\n\n" md
    
    return [string trim $md]
}

proc main {argv} {
    # Parse command line arguments manually since we don't have argparse equivalent
    set url {}
    set url_file ""
    set selector ""
    set js false
    set wait_selector ""
    set preserve_links false
    set body_width 0
    set timeout 30
    set output_dir "outputs"
    set automatch_domain ""
    
    # Simple argument parsing
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set arg [lindex $argv $i]
        switch -- $arg {
            "--url" {
                incr i
                lappend url [lindex $argv $i]
            }
            "--url-file" {
                incr i
                set url_file [lindex $argv $i]
            }
            "--selector" {
                incr i
                set selector [lindex $argv $i]
            }
            "--js" {
                set js true
            }
            "--wait-selector" {
                incr i
                set wait_selector [lindex $argv $i]
            }
            "--preserve-links" {
                set preserve_links true
            }
            "--body-width" {
                incr i
                set body_width [lindex $argv $i]
            }
            "--timeout" {
                incr i
                set timeout [lindex $argv $i]
            }
            "--output-dir" {
                incr i
                set output_dir [lindex $argv $i]
            }
            "--automatch-domain" {
                incr i
                set automatch_domain [lindex $argv $i]
            }
        }
    }
    
    # Load URLs
    set urls [load_urls $url $url_file]
    if {[llength $urls] == 0} {
        puts [::json::encode {"ok" false "error" "No URLs provided"}]
        exit 1
    }
    
    # Validate URLs
    foreach u $urls {
        if {![validate_url $u]} {
            puts [::json::encode {"ok" false "error" "Invalid URL: $u"}]
            exit 1
        }
    }
    
    # Create output directory
    if {![file exists $output_dir]} {
        file mkdir $output_dir
    }
    
    set results {}
    
    foreach url $urls {
        array set item [list \
            "url" $url \
            "ok" false \
            "title" "" \
            "status" "None" \
            "selector_used" "None" \
            "backend" "None" \
            "markdown" "" \
            "preview" "" \
            "output_markdown_file" "None" \
            "error" "None"]
            
        if {[catch {
            # Fetch page
            set fetch_opts [list -timeout $timeout]
            lassign [fetch_page $url {*}$fetch_opts] page_data backend
            
            # Extract HTML
            lassign [pick_main_html $page_data $selector] html selector_used
            
            if {$html eq ""} {
                error "No HTML content extracted from page"
            }
            
            # Extract title
            set title [extract_title $html]
            if {$title eq ""} {
                array set uri_parts [::uri::split $url]
                set title $uri_parts(-host)
            }
            
            # Convert to markdown
            set markdown [html_to_markdown $html $preserve_links $body_width]
            
            # Write markdown file
            set filename [slugify "$uri_parts(-host)-$title"].md
            set md_path [file join $output_dir $filename]
            set fd [open $md_path w]
            puts $fd $markdown
            close $fd
            
            # Get status from page data
            array set page $page_data
            set status $page(status)
            
            # Update item
            array set item [list \
                "ok" true \
                "title" $title \
                "status" $status \
                "selector_used" $selector_used \
                "backend" $backend \
                "markdown" $markdown \
                "preview" [string range $markdown 0 1199] \
                "output_markdown_file" $md_path]
                
        } error]} {
            set item(error) $error
        }
        
        lappend results [array get item]
    }
    
    # Calculate summary statistics
    set success_count 0
    set failure_count 0
    
    foreach result_item $results {
        array set item $result_item
        if {$item(ok)} {
            incr success_count
        } else {
            incr failure_count
        }
    }
    
    set ok [expr {$success_count > 0}]
    set index_path [file join $output_dir "index.json"]
    
    array set payload [list \
        "ok" $ok \
        "count" [llength $results] \
        "success_count" $success_count \
        "failure_count" $failure_count \
        "output_index_file" $index_path \
        "results" $results]
    
    # Write index file
    set fd [open $index_path w]
    puts $fd [::json::encode [array get payload]]
    close $fd
    
    # Print JSON output
    puts [::json::encode [array get payload]]
}

# Run main if this script is executed directly
if {[info script] eq $argv0} {
    main $argv
}
