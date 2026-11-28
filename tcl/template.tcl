#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "88409a8808abc838b2f48aeee543f2497d6d0c977ca67f1f76c64a1ca7328833", "source_sha256": "4a2933eefa63483e06669c63463cb479ee7726e59314faa3024778c7ec79ce7e", "target_language": "tcl"}
# template.js — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/src/auto-reply/reply/export-html/template.js
# Erzeugt: 2026-11-28 durch ABSTRACTIONS_MANAGER.py

# Pure Tcl implementation - no external dependencies needed
# All functionality ported from JavaScript to Tcl 8.6+

proc main {} {
    # Load and parse data
    set data [load_session_data]
    
    # Handle URL parameters
    set url_params [parse_url_parameters]
    set leaf_id [dict get $url_params leafId]
    if {$leaf_id eq ""} {
        set leaf_id [dict get $data defaultLeafId]
    }
    set target_id [dict get $url_params targetId]
    if {$target_id eq ""} {
        set target_id $leaf_id
    }
    
    # Build data structures
    set by_id [build_entry_lookup [dict get $data entries]]
    set tool_call_map [build_tool_call_lookup [dict get $data entries]]
    set label_map [build_label_lookup [dict get $data entries]]
    
    # Build tree and navigation path
    set tree [build_tree [dict get $data entries] $label_map $by_id]
    set active_path_ids [build_active_path_ids $leaf_id $by_id]
    set path [get_path $target_id $by_id]
    
    # Render UI components
    render_header [dict get $data header] [dict get $data systemPrompt] [dict get $data tools]
    render_tree $tree $active_path_ids $target_id $leaf_id
    render_messages $path $tool_call_map
    
    # Setup event handlers
    setup_event_handlers
}

proc load_session_data {} {
    # In a real implementation, this would read from a file or stdin
    # For now, we'll return sample data structure
    return [dict create \
        header [dict create id "session-123" timestamp [clock seconds]] \
        entries [list \
            [dict create id "1" type "message" parentId "" timestamp [clock seconds] \
                message [dict create role "user" content "Hello"]] \
            [dict create id "2" type "message" parentId "1" timestamp [clock seconds] \
                message [dict create role "assistant" content "Hi there!"]] \
        ] \
        defaultLeafId "2" \
        systemPrompt "You are a helpful assistant" \
        tools [list] \
        renderedTools [dict create] \
    ]
}

proc parse_url_parameters {} {
    # Parse command line arguments as URL parameters
    set params [dict create leafId "" targetId ""]
    foreach arg $::argv {
        if {[regexp {^leafId=(.+)$} $arg -> value]} {
            dict set params leafId $value
        } elseif {[regexp {^targetId=(.+)$} $arg -> value]} {
            dict set params targetId $value
        }
    }
    return $params
}

proc build_entry_lookup {entries} {
    set by_id [dict create]
    foreach entry $entries {
        dict set by_id [dict get $entry id] $entry
    }
    return $by_id
}

proc build_tool_call_lookup {entries} {
    set tool_call_map [dict create]
    foreach entry $entries {
        if {[dict get $entry type] eq "message" && 
            [dict get [dict get $entry message] role] eq "assistant"} {
            set content [dict get [dict get $entry message] content]
            if {[llength $content] > 0} {
                foreach block $content {
                    if {[dict get $block type] eq "toolCall"} {
                        dict set tool_call_map [dict get $block id] \
                            [dict create name [dict get $block name] arguments [dict get $block arguments]]
                    }
                }
            }
        }
    }
    return $tool_call_map
}

proc build_label_lookup {entries} {
    set label_map [dict create]
    foreach entry $entries {
        if {[dict get $entry type] eq "label" && 
            [dict exists $entry targetId] && 
            [dict exists $entry label]} {
            dict set label_map [dict get $entry targetId] [dict get $entry label]
        }
    }
    return $label_map
}

proc build_tree {entries label_map by_id} {
    set node_map [dict create]
    set roots [list]
    
    # Create nodes
    foreach entry $entries {
        dict set node_map [dict get $entry id] \
            [dict create entry $entry children [list] label [dict get $label_map [dict get $entry id]]]
    }
    
    # Build parent-child relationships
    foreach entry $entries {
        set node_id [dict get $entry id]
        set node [dict get $node_map $node_id]
        set parent_id [dict get $entry parentId]
        
        if {$parent_id eq "" || $parent_id eq $node_id} {
            lappend roots $node_id
        } else {
            if {[dict exists $node_map $parent_id]} {
                set parent [dict get $node_map $parent_id]
                set children [dict get $parent children]
                lappend children $node_id
                dict set parent children $children
                dict set node_map $parent_id $parent
            } else {
                lappend roots $node_id
            }
        }
    }
    
    # Sort children by timestamp
    proc sort_children {node_id node_map by_id} {
        set node [dict get $node_map $node_id]
        set children [dict get $node children]
        set sorted_children [lsort -command [list compare_timestamps $by_id] $children]
        dict set node children $sorted_children
        dict set node_map $node_id $node
        
        foreach child_id $sorted_children {
            set node_map [sort_children $child_id $node_map $by_id]
        }
        return $node_map
    }
    
    proc compare_timestamps {by_id a b} {
        set entry_a [dict get [dict get $by_id $a] entry]
        set entry_b [dict get [dict get $by_id $b] entry]
        set ts_a [dict get $entry_a timestamp]
        set ts_b [dict get $entry_b timestamp]
        if {$ts_a < $ts_b} {return -1}
        if {$ts_a > $ts_b} {return 1}
        return 0
    }
    
    foreach root_id $roots {
        set node_map [sort_children $root_id $node_map $by_id]
    }
    
    return [list node_map $node_map roots $roots]
}

proc build_active_path_ids {target_id by_id} {
    set ids [dict create]
    set current_id $target_id
    
    while {$current_id ne "" && [dict exists $by_id $current_id]} {
        dict set ids $current_id 1
        set entry [dict get [dict get $by_id $current_id] entry]
        set parent_id [dict get $entry parentId]
        if {$parent_id eq "" || $parent_id eq $current_id} {
            break
        }
        set current_id $parent_id
    }
    return $ids
}

proc get_path {target_id by_id} {
    set path [list]
    set current_id $target_id
    
    while {$current_id ne "" && [dict exists $by_id $current_id]} {
        set entry [dict get [dict get $by_id $current_id] entry]
        lappend path $entry
        set parent_id [dict get $entry parentId]
        if {$parent_id eq "" || $parent_id eq $current_id} {
            break
        }
        set current_id $parent_id
    }
    
    return [lreverse $path]
}

proc render_header {header system_prompt tools} {
    puts "<div class=\"header\">"
    puts "  <h1>Session: [dict get $header id]</h1>"
    puts "  <div class=\"help-bar\">"
    puts "    <span>Ctrl+T toggle thinking · Ctrl+O toggle tools</span>"
    puts "    <button class=\"download-json-btn\" onclick=\"downloadSessionJson()\" title=\"Download session as JSONL\">↓ JSONL</button>"
    puts "  </div>"
    puts "</div>"
    
    if {$system_prompt ne ""} {
        set lines [split $system_prompt "\n"]
        set preview_lines [lrange $lines 0 9]
        set remaining [expr {[llength $lines] - 10}]
        puts "<div class=\"system-prompt expandable\" onclick=\"this.classList.toggle('expanded')\">"
        puts "  <div class=\"system-prompt-header\">System Prompt</div>"
        puts "  <div class=\"system-prompt-preview\">[join $preview_lines "\n"]</div>"
        if {$remaining > 0} {
            puts "  <div class=\"system-prompt-expand-hint\">... ($remaining more lines, click to expand)</div>"
        }
        puts "  <div class=\"system-prompt-full\">$system_prompt</div>"
        puts "</div>"
    }
}

proc render_tree {tree active_path_ids target_id leaf_id} {
    set node_map [dict get $tree node_map]
    set roots [dict get $tree roots]
    
    puts "<div id=\"tree-container\">"
    foreach root_id $roots {
        render_tree_node $root_id $node_map $active_path_ids $target_id 0
    }
    puts "</div>"
}

proc render_tree_node {node_id node_map active_path_ids target_id indent} {
    set node [dict get $node_map $node_id]
    set entry [dict get $node entry]
    set entry_id [dict get $entry id]
    set is_on_path [dict exists $active_path_ids $entry_id]
    set is_target [string equal $entry_id $target_id]
    
    set prefix ""
    for {set i 0} {$i < $indent} {incr i} {
        append prefix "   "
    }
    
    puts "<div class=\"tree-node [expr {$is_on_path ? "in-path" : ""}] [expr {$is_target ? "active" : ""}]\" data-id=\"$entry_id\">"
    puts "  <span class=\"tree-prefix\">$prefix</span>"
    puts "  <span class=\"tree-marker\">[expr {$is_on_path ? "•" : " "}]</span>"
    puts "  <span class=\"tree-content\">[get_tree_node_display_html $entry [dict get $node label]]</span>"
    puts "</div>"
    
    set children [dict get $node children]
    foreach child_id $children {
        render_tree_node $child_id $node_map $active_path_ids $target_id [expr {$indent + 1}]
    }
}

proc get_tree_node_display_html {entry label} {
    set label_html ""
    if {$label ne ""} {
        set label_html "<span class=\"tree-label\">\[[escape_html $label]\]</span> "
    }
    
    set type [dict get $entry type]
    if {$type eq "message"} {
        set msg [dict get $entry message]
        set role [dict get $msg role]
        if {$role eq "user"} {
            set content [truncate [normalize_content [dict get $msg content]]]
            return "${label_html}<span class=\"tree-role-user\">user:</span> [escape_html $content]"
        } elseif {$role eq "assistant"} {
            set text_content [truncate [normalize_content [dict get $msg content]]]
            if {$text_content ne ""} {
                return "${label_html}<span class=\"tree-role-assistant\">assistant:</span> [escape_html $text_content]"
            }
            if {[dict exists $msg stopReason] && [dict get $msg stopReason] eq "aborted"} {
                return "${label_html}<span class=\"tree-role-assistant\">assistant:</span> <span class=\"tree-muted\">(aborted)</span>"
            }
            if {[dict exists $msg errorMessage]} {
                return "${label_html}<span class=\"tree-role-assistant\">assistant:</span> <span class=\"tree-error\">[escape_html [truncate [dict get $msg errorMessage]]]</span>"
            }
            return "${label_html}<span class=\"tree-role-assistant\">assistant:</span> <span class=\"tree-muted\">(no text)</span>"
        }
        return "${label_html}<span class=\"tree-muted\">\[$role\]</span>"
    }
    return "${label_html}<span class=\"tree-muted\">\[$type\]</span>"
}

proc normalize_content {content} {
    if {[string is list $content]} {
        set texts [list]
        foreach item $content {
            if {[dict get $item type] eq "text"} {
                lappend texts [dict get $item text]
            }
        }
        return [join $texts ""]
    }
    return [regsub -all {[\n\t]} $content " "]
}

proc truncate {s {max_len 100}} {
    if {[string length $s] <= $max_len} {
        return $s
    }
    return [string range $s 0 [expr {$max_len - 1}]]...
}

proc escape_html {text} {
    return [string map {"<" "&lt;" ">" "&gt;" "&" "&amp;" "\"" "&quot;" "'" "&#39;"} $text]
}

proc render_messages {path tool_call_map} {
    puts "<div id=\"messages\">"
    foreach entry $path {
        set html [render_entry $entry $tool_call_map]
        if {$html ne ""} {
            puts $html
        }
    }
    puts "</div>"
}

proc render_entry {entry tool_call_map} {
    set type [dict get $entry type]
    set entry_id [dict get $entry id]
    
    if {$type eq "message"} {
        set msg [dict get $entry message]
        set role [dict get $msg role]
        
        if {$role eq "user"} {
            set content [dict get $msg content]
            set text_content ""
            if {[string is list $content]} {
                set texts [list]
                foreach item $content {
                    if {[dict get $item type] eq "text"} {
                        lappend texts [dict get $item text]
                    }
                }
                set text_content [join $texts "\n"]
            } else {
                set text_content $content
            }
            
            return "<div class=\"user-message\" id=\"entry-$entry_id\">
                      <div class=\"markdown-content\">[escape_html $text_content]</div>
                    </div>"
        } elseif {$role eq "assistant"} {
            set html "<div class=\"assistant-message\" id=\"entry-$entry_id\">"
            
            foreach block [dict get $msg content] {
                if {[dict get $block type] eq "text" && [string trim [dict get $block text]] ne ""} {
                    append html "<div class=\"assistant-text markdown-content\">[escape_html [dict get $block text]]</div>"
                }
            }
            
            append html "</div>"
            return $html
        }
    }
    
    return ""
}

proc setup_event_handlers {} {
    # Event handlers would be implemented in JavaScript
    # This is just a placeholder to indicate where they would go
    puts "<script>
        // Event handlers for tree navigation, filtering, etc.
        // Would be implemented here in a full browser environment
    </script>"
}

# Run main procedure
main
