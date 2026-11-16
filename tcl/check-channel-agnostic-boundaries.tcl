#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "2391e80274cea8f5b5d5dda508377f0f73e90b4753a4175e28b5e731d721c95a", "source_sha256": "a2afe873e78fca9f7a9bf66785f17d7cad24c6285fd2c0dc6c6bb2abf1e375fa", "target_language": "tcl"}
# check-channel-agnostic-boundaries.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-channel-agnostic-boundaries.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 port of check-channel-agnostic-boundaries.mjs

package require Tcl 8.6
package require fileutil
package require cmdline

# Helper functions
proc resolve_repo_root {} {
    set script_dir [file dirname [info script]]
    return [file normalize [file join $script_dir ".."]]
}

proc collect_typescript_files {source_path} {
    set files {}
    if {[file isdirectory $source_path]} {
        foreach f [glob -nocomplain -dir $source_path *.ts] {
            lappend files $f
        }
    } elseif {[file extension $source_path] eq ".ts"} {
        if {[file exists $source_path]} {
            lappend files $source_path
        }
    }
    return $files
}

proc to_line {content pos} {
    set lines [split $content "\n"]
    set current_pos 0
    set line_num 1
    
    foreach line $lines {
        incr current_pos [string length $line]
        incr current_pos 1 ;# for newline
        if {$pos <= $current_pos} {
            return $line_num
        }
        incr line_num
    }
    return $line_num
}

# Configuration data
set repo_root [resolve_repo_root]

set acp_core_protected_sources [list \
    [file join $repo_root "src" "acp"] \
    [file join $repo_root "src" "agents" "acp-spawn.ts"] \
    [file join $repo_root "src" "auto-reply" "reply" "commands-acp"] \
    [file join $repo_root "src" "infra" "outbound" "conversation-id.ts"] \
]

set channel_core_protected_sources [list \
    [file join $repo_root "src" "channels" "thread-bindings-policy.ts"] \
    [file join $repo_root "src" "channels" "thread-bindings-messages.ts"] \
]

set acp_user_facing_text_sources [list \
    [file join $repo_root "src" "auto-reply" "reply" "commands-acp"] \
]

set system_mark_literal_guard_sources [list \
    [file join $repo_root "src" "auto-reply" "reply" "commands-acp"] \
    [file join $repo_root "src" "auto-reply" "reply" "dispatch-acp.ts"] \
    [file join $repo_root "src" "auto-reply" "reply" "directive-handling.shared.ts"] \
    [file join $repo_root "src" "channels" "thread-bindings-messages.ts"] \
]

set channel_ids [list \
    "bluebubbles" "discord" "googlechat" "imessage" "irc" "line" "matrix" \
    "msteams" "signal" "slack" "telegram" "web" "whatsapp" "zalo" "zalouser" \
]

set channel_id_set [dict create]
foreach id $channel_ids {
    dict set channel_id_set $id 1
}

set channel_segment_re "(^|\[._/-\])(?:[join $channel_ids "|"])(\[._/-\]|\$)"

set comparison_operators [dict create]
foreach op {== === != !==} {
    dict set comparison_operators $op 1
}

set allowed_violations [dict create]

# Utility functions
proc is_channel_literal_node {text} {
    global channel_id_set
    return [dict exists $channel_id_set $text]
}

proc matches_channel_module_specifier {specifier} {
    global channel_segment_re
    set normalized_spec [string map {\\ /} $specifier]
    return [regexp $channel_segment_re $normalized_spec]
}

set user_facing_channel_name_re {\b(discord|telegram|slack|signal|imessage|whatsapp|google\s*chat|irc|line|zalo|matrix|msteams|bluebubbles)\b}

set system_mark_literal "⚙️"

proc is_module_specifier_string_node {line context} {
    # Simplified check based on context
    if {$context in {"import" "export"}} {
        return 1
    }
    if {$context eq "dynamic_import"} {
        return 1
    }
    return 0
}

# Main scanning functions
proc find_channel_agnostic_boundary_violations {content file_name args} {
    global channel_id_set channel_segment_re comparison_operators
    array set opts [list \
        checkModuleSpecifiers 1 \
        checkConfigPaths 1 \
        checkChannelComparisons 1 \
        checkChannelAssignments 1 \
        moduleSpecifierMatcher "matches_channel_module_specifier" \
    ]
    
    foreach {key val} $args {
        set opts($key) $val
    }
    
    set violations [list]
    set lines [split $content "\n"]
    set line_num 1
    
    foreach line $lines {
        # Check import declarations
        if {$opts(checkModuleSpecifiers) && [regexp {import\s+.*from\s+"([^"]+)"} $line -> specifier]} {
            if {[matches_channel_module_specifier $specifier]} {
                lappend violations [dict create \
                    line $line_num \
                    reason "imports channel module \"$specifier\"" \
                ]
            }
        }
        
        # Check export declarations
        if {$opts(checkModuleSpecifiers) && [regexp {export\s+.*from\s+"([^"]+)"} $line -> specifier]} {
            if {[matches_channel_module_specifier $specifier]} {
                lappend violations [dict create \
                    line $line_num \
                    reason "re-exports channel module \"$specifier\"" \
                ]
            }
        }
        
        # Check dynamic imports
        if {$opts(checkModuleSpecifiers) && [regexp {import\s*\(\s*"([^"]+)"\s*\)} $line -> specifier]} {
            if {[matches_channel_module_specifier $specifier]} {
                lappend violations [dict create \
                    line $line_num \
                    reason "dynamically imports channel module \"$specifier\"" \
                ]
            }
        }
        
        # Check property access expressions
        if {$opts(checkConfigPaths)} {
            foreach channel_id [array names channel_id_set] {
                if {[regexp "channels\\.$channel_id" $line]} {
                    lappend violations [dict create \
                        line $line_num \
                        reason "references config path \"channels.$channel_id\"" \
                    ]
                }
                if {[regexp "channels\\\[\"?$channel_id\"?\]" $line]} {
                    lappend violations [dict create \
                        line $line_num \
                        reason "references config path \"channels\[\"$channel_id\"\]\"" \
                    ]
                }
            }
        }
        
        # Check comparisons with channel literals
        if {$opts(checkChannelComparisons)} {
            foreach channel_id [array names channel_id_set] {
                if {[regexp "(===|!==|==|!=).*\"?$channel_id\"?" $line]} {
                    lappend violations [dict create \
                        line $line_num \
                        reason "compares with channel id literal ($line)" \
                    ]
                }
                if {[regexp "\"?$channel_id\"?.*(===|!==|==|!=)" $line]} {
                    lappend violations [dict create \
                        line $line_num \
                        reason "compares with channel id literal ($line)" \
                    ]
                }
            }
        }
        
        # Check channel assignments
        if {$opts(checkChannelAssignments)} {
            foreach channel_id [array names channel_id_set] {
                if {[regexp "channel:\s*\"?$channel_id\"?" $line]} {
                    lappend violations [dict create \
                        line $line_num \
                        reason "assigns channel id literal to \"channel\" ($line)" \
                    ]
                }
            }
        }
        
        incr line_num
    }
    
    return $violations
}

proc find_channel_core_reverse_dependency_violations {content file_name} {
    return [find_channel_agnostic_boundary_violations $content $file_name \
        checkModuleSpecifiers 1 \
        checkConfigPaths 0 \
        checkChannelComparisons 0 \
        checkChannelAssignments 0 \
        moduleSpecifierMatcher "matches_channel_module_specifier"]
}

proc find_acp_user_facing_channel_name_violations {content file_name} {
    global user_facing_channel_name_re
    set violations [list]
    set lines [split $content "\n"]
    set line_num 1
    
    foreach line $lines {
        if {[regexp -nocase $user_facing_channel_name_re $line match]} {
            if {![regexp {(import|export|require)\s*["']} $line]} {
                lappend violations [dict create \
                    line $line_num \
                    reason "user-facing text references channel name (\"$match\")" \
                ]
            }
        }
        incr line_num
    }
    
    return $violations
}

proc find_system_mark_literal_violations {content file_name} {
    global system_mark_literal
    set violations [list]
    set lines [split $content "\n"]
    set line_num 1
    
    foreach line $lines {
        if {[string first $system_mark_literal $line] != -1} {
            if {![regexp {(import|export|require)\s*["']} $line]} {
                lappend violations [dict create \
                    line $line_num \
                    reason "hardcoded system mark literal ([string trim $line])" \
                ]
            }
        }
        incr line_num
    }
    
    return $violations
}

# Rule sets definition
set boundary_rule_sets [list \
    [dict create \
        id "acp-core" \
        sources $acp_core_protected_sources \
        scan "find_channel_agnostic_boundary_violations" \
    ] \
    [dict create \
        id "channel-core-reverse-deps" \
        sources $channel_core_protected_sources \
        scan "find_channel_core_reverse_dependency_violations" \
    ] \
    [dict create \
        id "acp-user-facing-text" \
        sources $acp_user_facing_text_sources \
        scan "find_acp_user_facing_channel_name_violations" \
    ] \
    [dict create \
        id "system-mark-literal-usage" \
        sources $system_mark_literal_guard_sources \
        scan "find_system_mark_literal_violations" \
    ] \
]

proc main {} {
    global repo_root boundary_rule_sets allowed_violations
    set violations [list]
    
    foreach rule_set $boundary_rule_sets {
        set rule_id [dict get $rule_set id]
        set sources [dict get $rule_set sources]
        set scan_func [dict get $rule_set scan]
        
        foreach source_path $sources {
            set files [collect_typescript_files $source_path]
            
            foreach file_path $files {
                set relative_file [fileutil::stripPath $repo_root $file_path]
                
                if {[dict exists $allowed_violations "$rule_id:$relative_file"] || 
                    [dict exists $allowed_violations $relative_file]} {
                    continue
                }
                
                if {[catch {open $file_path r} fh]} {
                    continue
                }
                set content [read $fh]
                close $fh
                
                set file_violations [$scan_func $content $relative_file]
                foreach violation $file_violations {
                    lappend violations "$rule_id $relative_file:[dict get $violation line]: [dict get $violation reason]"
                }
            }
        }
    }
    
    if {[llength $violations] == 0} {
        return
    }
    
    puts stderr "Found channel-specific references in channel-agnostic sources:"
    foreach violation $violations {
        puts stderr "- $violation"
    }
    puts stderr "Move channel-specific logic to channel adapters or add a justified allowlist entry."
    exit 1
}

# Run the main function
if {[info script] eq $argv0} {
    main
}
