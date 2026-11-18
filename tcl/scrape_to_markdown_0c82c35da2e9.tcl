#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "1b2c373d1b382cf5721725209be54e4d36b5b1cba71e2e3a194cf40f0980c8f8", "source_sha256": "f76d25200d74ebc530580d7a7afb24c88ee8981f06c4d1734500f4cc830c4fe9", "target_language": "tcl"}
# scrape_to_markdown.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package require http
package require json
package require fileutil
package require uri

proc to_str {value} {
    if {$value eq "" || $value eq "null"} {
        return ""
    }
    return $value
}

proc slugify {text {max_len 80}} {
    set text [string map {" " "-" "_" "-" "." "-" "?" "-" "!" "-" "\"" "" "'" ""} [string tolower [regsub -all {[^a-zA-Z0-9_\-\s]} $text ""]]]
    regsub -all {\-+} $text "-" text
    set text [string trim $text "-"]
    if {$text eq ""} {
        set text "page"
    }
    return [string range $text 0 [expr {$max_len - 1}]]
}

proc extract_html {obj} {
    if {$obj eq ""} {
        return ""
    }
    
    foreach attr {"html" "raw_html" "content" "markup" "body" "inner_html"} {
        if {[dict exists $obj $attr]} {
            set value [dict get $obj $attr]
            if {[string match "*<*" $value] && [string match "*>*" $value]} {
                return $value
            }
        }
    }
    
    set text [to_str $obj]
    if {[string match "*<*" $text] && [string match "*>*" $text]} {
        return $text
    }
    return ""
}

proc extract_title {html} {
    if {[regexp -nocase {<title[^>]*>(.*?)</title>} $html match title_content]} {
        regsub -all {<[^>]+>} $title_content " " title
        regsub -all {\s+} $title " " title
        return [string trim $title]
    }
    return ""
}

proc fetch_page {url {js false} {wait_selector ""} {timeout 30} {automatch_domain ""}} {
    if {$js} {
        error "JavaScript rendering not supported in Tcl version"
    }
    
    set token [http::geturl $url -timeout [expr {$timeout * 1000}]]
    set status [http::status $token]
    set code [http::ncode $token]
    
    if {$status ne "ok" || ($code < 200 || $code >= 300)} {
        http::cleanup $token
        error "Failed to fetch $url: HTTP $code"
    }
    
    set data [http::data $token]
    http::cleanup $token
    
    return [list $data "http.geturl"]
}

proc pick_main_html {page preferred_selector} {
    set selectors {}
    if {$preferred_selector ne ""} {
        lappend selectors $preferred_selector
    }
    foreach sel {"article" "main" "[role='main']" ".post-content" ".entry-content" ".article-content" "body"} {
        lappend selectors $sel
    }
    
    # Simple approach since we don't have CSS selection in Tcl
    set html [extract_html $page]
    if {[string length $html] > 120} {
        return [list $html "body"]
    }
    
    return [list $html ""]
}

proc html_to_markdown {html {preserve_links false} {body_width 0}} {
    # Basic HTML to Markdown conversion
    set md $html
    
    # Remove script and style tags
    regsub -all {<(script|style)[^>]*>.*?</\1>} $md "" md
    
    # Convert headers
    regsub -all -nocase {<h1[^>]*>(.*?)</h1>} $md "# \\1\n" md
    regsub -all -nocase {<h2[^>]*>(.*?)</h2>} $md "## \\1\n" md
    regsub -all -nocase {<h3[^>]*>(.*?)</h3>} $md "### \\1\n" md
    regsub -all -nocase {<h4[^>]*>(.*?)</h4>} $md "#### \\1\n" md
    regsub -all -nocase {<h5[^>]*>(.*?)</h5>} $md "##### \\1\n" md
    regsub -all -nocase {<h6[^>]*>(.*?)</h6>} $md "###### \\1\n" md
    
    # Convert paragraphs
    regsub -all -nocase {<p[^>]*>(.*?)</p>} $md "\\1\n\n" md
    
    # Convert links
    if {$preserve_links} {
        regsub -all -nocase {<a[^>]*href=["']([^"']*)["'][^>]*>(.*?)</a>} $md "\\2 (\\1)" md
    } else {
        regsub -all -nocase {<a[^>]*href=["'][^"']*["'][^>]*>(.*?)</a>} $md "\\1" md
    }
    
    # Convert bold/strong
    regsub -all -nocase {<b[^>]*>(.*?)</b>} $md "**\\1**" md
    regsub -all -nocase {<strong[^>]*>(.*?)</strong>} $md "**\\1**" md
    
    # Convert italic/em
    regsub -all -nocase {<i[^>]*>(.*?)</i>} $md "*\\1*" md
    regsub -all -nocase {<em[^>]*>(.*?)</em>} $md "*\\1*" md
    
    # Convert lists
    regsub -all -nocase {<ul[^>]*>(.*?)</ul>} $md "\\1" md
    regsub -all -nocase {<ol[^>]*>(.*?)</ol>} $md "\\1" md
    regsub -all -nocase {<li[^>]*>(.*?)</li>} $md "* \\1" md
    
    # Convert images (remove but keep alt text)
    regsub -all -nocase {<img[^>]*alt=["']([^"']*)["'][^>]*/?>} $md "\\1" md
    regsub -all -nocase {<img[^>]*/?>} $md "" md
    
    # Remove remaining HTML tags
    regsub -all {<[^>]+>} $md "" md
    
    # Clean up whitespace
    regsub -all {\n{3,}} $md "\n\n" md
    return [string trim $md]
}

proc load_urls {url_args url_file} {
    set urls $url_args
    
    if {$url_file ne ""} {
        set fd [open $url_file r]
        while {[gets $fd line] >= 0} {
            set line [string trim $line]
            if {$line ne "" && ![string match "#*" $line]} {
                lappend urls $line
            }
        }
        close $fd
    }
    
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
    if {[catch {package require uri}]} {
        # Fallback validation
        return [expr {[string match "http:*" $url] || [string match "https:*" $url]}]
    }
    set parsed [uri::split $url]
    set scheme [dict get $parsed scheme]
    set host [dict get $parsed host]
    return [expr {$scheme in {"http" "https"} && $host ne ""}]
}

proc main {argv} {
    array set args {
        url {}
        url_file ""
        selector ""
        js false
        wait_selector ""
        preserve_links false
        body_width 0
        timeout 30
        output_dir "outputs"
        automatch_domain ""
    }
    
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        incr i
        
        switch -exact -- $arg {
            --url {
                if {$i < [llength $argv]} {
                    lappend args(url) [lindex $argv $i]
                    incr i
                }
            }
            --url-file {
                if {$i < [llength $argv]} {
                    set args(url_file) [lindex $argv $i]
                    incr i
                }
            }
            --selector {
                if {$i < [llength $argv]} {
                    set args(selector) [lindex $argv $i]
                    incr i
                }
            }
            --js {
                set args(js) true
            }
            --wait-selector {
                if {$i < [llength $argv]} {
                    set args(wait_selector) [lindex $argv $i]
                    incr i
                }
            }
            --preserve-links {
                set args(preserve_links) true
            }
            --body-width {
                if {$i < [llength $argv]} {
                    set args(body_width) [lindex $argv $i]
                    incr i
                }
            }
            --timeout {
                if {$i < [llength $argv]} {
                    set args(timeout) [lindex $argv $i]
                    incr i
                }
            }
            --output-dir {
                if {$i < [llength $argv]} {
                    set args(output_dir) [lindex $argv $i]
                    incr i
                }
            }
            --automatch-domain {
                if {$i < [llength $argv]} {
                    set args(automatch_domain) [lindex $argv $i]
                    incr i
                }
            }
        }
    }
    
    set urls [load_urls $args(url) $args(url_file)]
    if {[llength $urls] == 0} {
        puts [json::encode [dict create ok false error "No URLs provided"]]
        exit 1
    }
    
    foreach u $urls {
        if {![validate_url $u]} {
            puts [json::encode [dict create ok false error "Invalid URL: $u"]]
            exit 1
        }
    }
    
    file mkdir $args(output_dir)
    set results {}
    
    foreach url $urls {
        set item [dict create \
            url $url \
            ok false \
            title "" \
            status "" \
            selector_used "" \
            backend "" \
            markdown "" \
            preview "" \
            output_markdown_file "" \
            error ""]
        
        if {[catch {
            lassign [fetch_page $url $args(js) $args(wait_selector) $args(timeout) $args(automatch_domain)] page backend
            lassign [pick_main_html $page $args(selector)] html selector_used
            
            if {$html eq ""} {
                error "No HTML content extracted from page"
            }
            
            set title [extract_title $html]
            if {$title eq ""} {
                set parsed [uri::split $url]
                set title [dict get $parsed host]
            }
            
            set markdown [html_to_markdown $html $args(preserve_links) $args(body_width)]
            
            set filename [slugify "$title"]\.md
            set md_path [file join $args(output_dir) $filename]
            set fd [open $md_path w]
            puts $fd $markdown
            close $fd
            
            dict set item ok true
            dict set item title $title
            dict set item status "200"
            dict set item selector_used $selector_used
            dict set item backend $backend
            dict set item markdown $markdown
            dict set item preview [string range $markdown 0 1199]
            dict set item output_markdown_file $md_path
        } err]} {
            dict set item error $err
        }
        
        lappend results $item
    }
    
    set ok [expr {[llength [lsearch -all -inline [dict values $results] "*ok true*"]] > 0}]
    set index_path [file join $args(output_dir) "index.json"]
    
    set payload [dict create \
        ok $ok \
        count [llength $results] \
        success_count [llength [lsearch -all -inline $results "*ok true*"]] \
        failure_count [llength [lsearch -all -inline $results "*ok false*"]] \
        output_index_file $index_path \
        results $results]
    
    set fd [open $index_path w]
    puts $fd [json::encode $payload]
    close $fd
    
    puts [json::encode $payload]
}

if {[info script] eq $argv0} {
    main $argv
}
