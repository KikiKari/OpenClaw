#!/usr/bin/env tclsh
# verify-downloads.py — portiert nach tcl
# Quelle: python, Projects@TikTok-Live-Companion:site/scripts/verify-downloads.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/scripts/verify-downloads.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Verify the candidate's actual HTTP downloads against committed files.

package require http
package require sha256
package require zipfile
package require json

proc main {} {
    global argv
    
    # Parse arguments
    set base_url ""
    set report ""
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        incr i
        switch -- $arg {
            --base-url {
                set base_url [lindex $argv $i]
                incr i
            }
            --report {
                set report [lindex $argv $i]
                incr i
            }
            default {
                error "Unknown argument: $arg"
            }
        }
    }
    
    if {$base_url eq "" || $report eq ""} {
        error "Both --base-url and --report are required"
    }
    
    # Get script directory
    set script_dir [file normalize [file dirname [info script]]]
    set root [file dirname $script_dir]
    set checksum_file [file join $root public downloads tiktok-live-companion-0.8.2-SHA256.txt]
    
    set results {}
    
    # Read checksum file
    set fh [open $checksum_file r]
    set content [read $fh]
    close $fh
    
    foreach line [split $content "\n"] {
        if {$line eq ""} continue
        
        # Split line into expected hash and filename
        set parts [split $line "  "]
        set expected [lindex $parts 0]
        set name [lindex $parts 1]
        
        # Download file
        set url [string trimright $base_url "/"]/downloads/$name
        set token [http::geturl $url -timeout 30000]
        set data [http::data $token]
        http::cleanup $token
        
        # Calculate SHA256
        set actual [sha2::sha256 -hex $data]
        
        # Check hash matches
        if {$actual ne $expected} {
            error "HTTP artifact mismatch: $name"
        }
        
        # Check local file matches
        set local_path [file join $root public downloads $name]
        set fh [open $local_path rb]
        set local_data [read $fh]
        close $fh
        
        if {$data ne $local_data} {
            error "HTTP artifact mismatch: $name"
        }
        
        # Test ZIP integrity
        set tmpfile [file tempfile tmp]
        set fh [open $tmpfile wb]
        puts -nonewline $fh $data
        close $fh
        
        if {[catch {exec unzip -t $tmpfile} result]} {
            error "Corrupt archive: $name"
        }
        
        # Special checks for extension archives
        if {[string match "*-extension-*" $name]} {
            # Extract manifest.json and check version
            set manifest_data [exec unzip -p $tmpfile manifest.json]
            set manifest [json::json2dict $manifest_data]
            if {[dict get $manifest version] ne "0.8.2"} {
                error "Wrong extension version"
            }
            
            # Check source files
            set plugin_source [file dirname [file dirname $root]]
            foreach source {background.js content.js sidepanel.js sidepanel.html} {
                set archive_data [exec unzip -p $tmpfile $source]
                set source_path [file join $plugin_source plugin-source browser-extension $source]
                set fh [open $source_path rb]
                set source_data [read $fh]
                close $fh
                
                if {$archive_data ne $source_data} {
                    error "Extension source mismatch: $source"
                }
            }
        }
        
        # Clean up temp file
        file delete $tmpfile
        
        # Add to results
        lappend results [dict create name $name sha256 $actual bytes [string length $data] verified true]
    }
    
    # Write report
    set report_data [dict create base_url $base_url artifacts $results]
    set fh [open $report w]
    puts $fh [json::format $report_data]
    close $fh
    
    # Print results
    puts [json::format $results]
}

main
