#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "09f4014b5559708725662d56aa773be66c52a680371be8997005153d0ef2e29d", "source_sha256": "d8cfbb58894cc82e4e8ba7def8f5bcc6b6c011986e853dba0f1c96ca81a4b49e", "target_language": "tcl"}
# docs-list.js — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-list.js
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

# Tcl doesn't have built-in file utilities like Node.js, so we'll implement them
proc file_exists {path} {
    return [expr {[file exists $path] && ![catch {open $path r} fid]}]
}

proc is_directory {path} {
    return [file isdirectory $path]
}

proc read_file {path} {
    if {[catch {open $path r} fid]} {
        error "Cannot open file: $path"
    }
    set content [read $fid]
    close $fid
    return $content
}

proc get_cwd {} {
    return [pwd]
}

proc join_path {args} {
    return [join $args "/"]
}

proc relative_path {from_path to_path} {
    # Simplified relative path calculation for this use case
    # Assumes both paths are absolute and to_path starts with from_path
    set from_len [string length $from_path]
    if {[string range $to_path 0 [expr {$from_len - 1}]] eq $from_path} {
        return [string range $to_path [expr {$from_len + 1}] end]
    }
    return $to_path
}

proc trim {str} {
    return [string trim $str]
}

proc starts_with {str prefix} {
    return [string match "${prefix}*" $str]
}

proc ends_with {str suffix} {
    return [string match "*${suffix}" $str]
}

proc compact_strings {values} {
    set result {}
    foreach value $values {
        if {$value eq "" || $value eq "null" || $value eq "undefined"} {
            continue
        }
        set normalized [trim $value]
        if {[string length $normalized] > 0} {
            lappend result $normalized
        }
    }
    return $result
}

# Global variables
set DOCS_DIR [join_path [get_cwd] "docs"]
set EXCLUDED_DIRS [dict create archive 1 research 1]

# Check if docs directory exists
if {![file_exists $DOCS_DIR]} {
    puts stderr "docs:list: missing docs directory. Run from repo root."
    exit 1
}

if {![is_directory $DOCS_DIR]} {
    puts stderr "docs:list: docs path is not a directory."
    exit 1
}

# Function to walk markdown files recursively
proc walk_markdown_files {dir {base ""}} {
    global EXCLUDED_DIRS
    if {$base eq ""} {
        set base $dir
    }
    
    set files {}
    set entries [glob -nocomplain -directory $dir .* *]
    
    foreach entry $entries {
        # Skip current and parent directory references
        if {[file tail $entry] eq "." || [file tail $entry] eq ".."} {
            continue
        }
        
        # Skip hidden files/directories
        if {[string index [file tail $entry] 0] eq "."} {
            continue
        }
        
        if {[is_directory $entry]} {
            set dir_name [file tail $entry]
            if {[dict exists $EXCLUDED_DIRS $dir_name]} {
                continue
            }
            set sub_files [walk_markdown_files $entry $base]
            set files [concat $files $sub_files]
        } elseif {[file extension $entry] eq ".md"} {
            # Calculate relative path
            set rel_path [string range $entry [string length $base]+1 end]
            lappend files $rel_path
        }
    }
    
    # Sort the files
    set sorted_files {}
    foreach f [lsort $files] {
        lappend sorted_files $f
    }
    return $sorted_files
}

# Function to extract metadata from markdown file
proc extract_metadata {full_path} {
    set content [read_file $full_path]
    
    # Check for front matter
    if {![starts_with $content "---"]} {
        return [dict create summary "" readWhen {} error "missing front matter"]
    }
    
    # Find end of front matter
    set end_index [string first "\n---" $content 3]
    if {$end_index == -1} {
        return [dict create summary "" readWhen {} error "unterminated front matter"]
    }
    
    set front_matter [string range $content 3 $end_index-1]
    set lines [split $front_matter "\n"]
    
    set summary_line ""
    set read_when {}
    set collecting_field ""
    
    foreach raw_line $lines {
        set line [trim $raw_line]
        
        if {[starts_with $line "summary:"]} {
            set summary_line $line
            set collecting_field ""
            continue
        }
        
        if {[starts_with $line "read_when:"]} {
            set collecting_field "read_when"
            set inline [trim [string range $line 10 end]]
            if {[starts_with $inline "\["] && [ends_with $inline "\]"]} {
                # Try to parse as JSON-like array
                # Remove single quotes and replace with double quotes for valid JSON
                set json_str [regsub -all "'" $inline "\""]
                if {[catch {set parsed [::json::json2dict $json_str]}]} {
                    # If parsing fails, try manual parsing
                    set parsed_list {}
                    set items [split [string range $inline 1 end-1] ","]
                    foreach item $items {
                        lappend parsed_list [trim [string trim $item "'\""]]
                    }
                    set read_when [concat $read_when [compact_strings $parsed_list]]
                } else {
                    # This would work if we had a proper JSON parser
                    # For now, we'll handle it manually
                    set read_when [concat $read_when [compact_strings $parsed]]
                }
            }
            continue
        }
        
        if {$collecting_field eq "read_when"} {
            if {[starts_with $line "- "]} {
                set hint [trim [string range $line 2 end]]
                if {$hint ne ""} {
                    lappend read_when $hint
                }
            } elseif {$line eq ""} {
                # Allow blank lines inside the list
            } else {
                set collecting_field ""
            }
        }
    }
    
    if {$summary_line eq ""} {
        return [dict create summary "" readWhen $read_when error "summary key missing"]
    }
    
    set summary_value [trim [string range $summary_line 9 end]]
    # Remove surrounding quotes if present
    set normalized [regsub {^['"](.*)['"]$} $summary_value {\1}]
    # Normalize whitespace
    set normalized [regsub {\s+} [trim $normalized] " "]
    
    if {$normalized eq ""} {
        return [dict create summary "" readWhen $read_when error "summary is empty"]
    }
    
    return [dict create summary $normalized readWhen $read_when]
}

# Main execution
puts "Listing all markdown files in docs folder:"

set markdown_files [walk_markdown_files $DOCS_DIR]

foreach relative_path $markdown_files {
    set full_path [join_path $DOCS_DIR $relative_path]
    set metadata [extract_metadata $full_path]
    
    set summary [dict get $metadata summary]
    set read_when [dict get $metadata readWhen]
    set error [dict get $metadata error]
    
    if {$summary ne ""} {
        puts "$relative_path - $summary"
        if {[llength $read_when] > 0} {
            puts "  Read when: [join $read_when "; "]"
        }
    } else {
        set reason ""
        if {$error ne ""} {
            set reason " - \[$error\]"
        }
        puts "$relative_path$reason"
    }
}

puts ""
puts "Reminder: keep docs up to date as behavior changes. When your task matches any \"Read when\" hint above (React hooks, cache directives, database work, tests, etc.), read that doc before coding, and suggest new coverage when it is missing."
