#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "de588203a19cb7c1e4eddf8a4cb82494fd01eacdba056f7d003f0808aacf0844", "source_sha256": "dfe62418dcbef9ea8aa7f18ada4f57d0ef73593432b7c7cefd85ee87eee622b4", "target_language": "tcl"}
# github_publisher.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

# Publish queued, provenance-checked artifacts without staging unrelated files.

package require http
package require json
package require sha256

# Set of supported languages
set LANGUAGES [dict create perl5 {} powershell {} perl6 {} tcl {} javascript {} ruby {} python {} lua {} shell {} go {} java {} c {} cpp {} php {} fsharp {} css {}]

proc synchronize_checkout {root {remote "https://github.com/KikiKari/OpenClaw.git"} {branch "gateway1-abstractions"}} {
    # Reconcile a remote snapshot into the checkout without changing its Git history.
    
    # Resolve root path
    set root [file normalize $root]
    if {![file exists $root] || ![file isdirectory $root]} {
        error "Root directory does not exist or is not a directory"
    }
    
    # Create temporary directory
    set tmp [exec mktemp -d "/tmp/abstractions-snapshot-XXXXXX"]
    set snapshot [file join $tmp repo]
    
    # Clone repository
    if {[catch {
        exec git clone --quiet --depth=1 --single-branch --branch $branch -- $remote $snapshot
    } result]} {
        exec rm -rf $tmp
        error "Failed to clone repository: $result"
    }
    
    # Get revision
    set revision [string trim [exec git -C $snapshot rev-parse HEAD]]
    
    # Process each language
    array set counts {}
    foreach language [lsort [dict keys $::LANGUAGES]] {
        set source [file join $snapshot $language]
        set target [file join $root $language]
        
        # Check for symlinks
        if {[file type $source] eq "link" || ([file exists $target] && [file type $target] eq "link")} {
            exec rm -rf $tmp
            error "language directory is a symlink"
        }
        
        # Validate remote directory
        if {[file exists $source] && ![file isdirectory $source]} {
            exec rm -rf $tmp
            error "invalid remote language directory"
        }
        
        # Create target directory
        file mkdir $target
        
        # Get known hashes
        set known [dict create]
        foreach item [glob -nocomplain -tails -directory $target *] {
            set filepath [file join $target $item]
            if {[file isfile $filepath] && [file type $filepath] ne "link"} {
                set hash [sha256::sha256 -hex [read_binary_file $filepath]]
                dict set known $hash 1
            }
        }
        
        # Process files
        set files {}
        if {[file exists $source]} {
            foreach item [glob -nocomplain -tails -directory $source *] {
                lappend files $item
            }
        }
        
        # Validate files
        foreach item $files {
            set filepath [file join $source $item]
            if {[file type $filepath] eq "link" || ![file isfile $filepath]} {
                exec rm -rf $tmp
                error "invalid remote abstraction"
            }
        }
        
        set counts($language) [llength $files]
        
        # Copy files
        foreach item $files {
            set filepath [file join $source $item]
            set data [read_binary_file $filepath]
            set digest [sha256::sha256 -hex $data]
            
            if {[dict exists $known $digest]} {
                continue
            }
            
            set destination [file join $target $item]
            if {[file exists $destination] || [file type $destination] eq "link"} {
                set stem [file rootname $item]
                set suffix [file extension $item]
                set destination [file join $target "${stem}__pool_${digest}${suffix}"]
            }
            
            if {[catch {
                set fd [open $destination "w+b"]
                fconfigure $fd -translation binary
                puts -nonewline $fd $data
                close $fd
            } result]} {
                if {[file type $destination] eq "link" || 
                    ![file isfile $destination] || 
                    [read_binary_file $destination] ne $data} {
                    exec rm -rf $tmp
                    error "local abstraction conflict"
                }
            }
            
            dict set known $digest 1
        }
    }
    
    # Cleanup
    exec rm -rf $tmp
    
    # Return revision and counts
    set result_dict [dict create]
    dict set result_dict revision $revision
    foreach lang [array names counts] {
        dict set result_dict counts $lang $counts($lang)
    }
    return $result_dict
}

proc read_binary_file {filename} {
    set fh [open $filename rb]
    set data [read $fh]
    close $fh
    return $data
}

proc update_status_counts {path revision counts} {
    set fh [open $path r]
    set text [read $fh]
    close $fh
    
    set rows [list "## Bestand" "" "GitHub-Stand: `$revision`" "" "| Zielsprache | Dateien |" "|---|---:|"]
    
    foreach language [lsort [dict keys $::LANGUAGES]] {
        if {[dict exists $counts $language]} {
            set count [dict get $counts $language]
        } else {
            set count 0
        }
        lappend rows "| $language | $count |"
    }
    
    set total 0
    foreach lang [dict keys $counts] {
        incr total [dict get $counts $lang]
    }
    
    lappend rows "| **gesamt** | **$total** |" "" ""
    
    # Replace the section using regex
    set pattern {(?ms)^## Bestand\n.*?(?=^## Quellen\n)}
    set replacement [join $rows "\n"]
    regsub $pattern $text "$replacement" updated
    
    set fh [open $path w]
    puts -nonewline $fh $updated
    close $fh
}

proc queue_artifact {state_var root path} {
    upvar $state_var state
    
    set root [file normalize $root]
    set path [file normalize $path]
    
    if {[file type $path] eq "link"} {
        error "artifact must not be a symlink"
    }
    
    set full_path [file normalize $path]
    if {![file exists $full_path]} {
        error "artifact path does not exist"
    }
    
    # Calculate relative path
    set rel_path [get_relative_path $root $full_path]
    
    if {$rel_path ne "STATUS.md" && ($rel_path eq "" || [lindex [split $rel_path /] 0] ni [dict keys $::LANGUAGES])} {
        error "artifact is outside a language directory"
    }
    
    if {![info exists state(ausstehende_veroeffentlichungen)]} {
        set state(ausstehende_veroeffentlichungen) [dict create]
    }
    
    set data [read_binary_file $path]
    set hash [sha256::sha256 -hex $data]
    dict set state(ausstehende_veroeffentlichungen) $rel_path $hash
}

proc get_relative_path {root path} {
    # Normalize paths
    set root [file normalize $root]
    set path [file normalize $path]
    
    # Ensure root ends with separator
    if {[string index $root end] ne [file separator]} {
        append root [file separator]
    }
    
    # Check if path starts with root
    if {[string first $root $path] == 0} {
        return [string range $path [string length $root] end]
    } else {
        # Try to compute relative path manually
        set root_parts [file split $root]
        set path_parts [file split $path]
        
        # Remove common prefix
        set i 0
        while {$i < [llength $root_parts] && $i < [llength $path_parts] && \
               [lindex $root_parts $i] eq [lindex $path_parts $i]} {
            incr i
        }
        
        # Build relative path
        set rel_parts {}
        for {set j $i} {$j < [llength $root_parts]} {incr j} {
            lappend rel_parts ".."
        }
        for {set j $i} {$j < [llength $path_parts]} {incr j} {
            lappend rel_parts [lindex $path_parts $j]
        }
        
        return [join $rel_parts "/"]
    }
}

proc publish_pending {root state_var save_proc token {sync_proc ""}} {
    upvar $state_var state
    
    set pending [dict getdefault $state "ausstehende_veroeffentlichungen" [dict create]]
    
    if {![dict size $pending] && $sync_proc eq ""} {
        return true
    }
    
    if {![string trim $token]} {
        return false
    }
    
    set root [file normalize $root]
    
    array set headers [list Authorization "Bearer [string trim $token]" \
                            Accept "application/vnd.github+json" \
                            X-GitHub-Api-Version "2022-11-28" \
                            User-Agent "abstractions-manager"]
    
    set success true
    set entries {}
    
    # Sort entries putting STATUS.md last
    foreach {name expected} [dict get $pending] {
        if {$name eq "STATUS.md"} {
            lappend entries [list $name $expected 1]
        } else {
            lappend entries [list $name $expected 0]
        }
    }
    
    set entries [lsort -index 2 $entries]
    
    set synced false
    
    foreach entry $entries {
        lassign $entry name expected _
        if {[catch {
            set path [file join $root $name]
            if {[file type $path] eq "link"} {
                error "invalid queued path"
            }
            
            # Verify path is within root
            set full_path [file normalize $path]
            if {[get_relative_path $root $full_path] ne $name} {
                error "invalid queued path"
            }
            
            set data [read_binary_file $path]
            set actual_hash [sha256::sha256 -hex $data]
            if {$actual_hash ne $expected} {
                error "queued artifact changed"
            }
            
            if {$name eq "STATUS.md" && $sync_proc ne ""} {
                if {!$success} {
                    error "artifact publication incomplete"
                }
                
                set sync_result [uplevel #0 $sync_proc $root]
                set revision [dict get $sync_result revision]
                set counts [dict get $sync_result counts]
                set synced true
                
                update_status_counts $path $revision $counts
                set data [read_binary_file $path]
                set expected [sha256::sha256 -hex $data]
                dict set pending $name $expected
                uplevel #0 $save_proc state
            }
            
            proc lookup {remote_name} {
                set endpoint "https://api.github.com/repos/KikiKari/OpenClaw/contents/$remote_name"
                append endpoint "?ref=gateway1-abstractions"
                
                array set headers $::headers
                set token [dict get $headers Authorization]
                set auth_token [string range $token 7 end] ;# Remove "Bearer "
                
                # Make HTTP request
                set tok [http::geturl $endpoint -headers $headers -timeout 60000]
                set ncode [http::ncode $tok]
                
                if {$ncode == 404} {
                    http::cleanup $tok
                    return [list $endpoint ""]
                } elseif {$ncode >= 400} {
                    set err [http::error $tok]
                    http::cleanup $tok
                    error "HTTP Error: $err"
                }
                
                set body [http::data $tok]
                http::cleanup $tok
                
                if {$body eq ""} {
                    return [list $endpoint ""]
                }
                
                if {[catch {set result [::json::json2dict $body]}]} {
                    return [list $endpoint ""]
                }
                
                return [list $endpoint $result]
            }
            
            proc same {existing data} {
                if {![dict size $existing]} {
                    return false
                }
                
                if {[dict get $existing encoding] ne "base64"} {
                    return false
                }
                
                set content [dict get $existing content]
                set decoded [binary decode base64 $content]
                return [expr {$decoded eq $data}]
            }
            
            lassign [lookup $name] endpoint existing
            
            if {$name eq "STATUS.md" && [dict size $existing] && ![same $existing $data]} {
                set sha [dict get $existing sha]
                if {![string length $sha]} {
                    error "missing remote status version"
                }
                
                set content_b64 [binary encode base64 $data]
                set body [::json::dict2json [dict create message "Update abstraction status" \
                                              branch "gateway1-abstractions" \
                                              content $content_b64 \
                                              sha $sha]]
                
                array set put_headers $::headers
                dict set put_headers "Content-Type" "application/json"
                
                set tok [http::geturl $endpoint -method PUT -headers $put_headers -query $body -timeout 60000]
                set ncode [http::ncode $tok]
                
                if {$ncode >= 400} {
                    set err [http::error $tok]
                    http::cleanup $tok
                    error "HTTP Error: $err"
                }
                
                http::cleanup $tok
            } elseif {[dict size $existing] && ![same $existing $data]} {
                # Handle conflicts by creating alternate filename
                set candidate_parts [file split $name]
                set stem [file rootname [lindex $candidate_parts end]]
                set suffix [file extension [lindex $candidate_parts end]]
                set parent [join [lrange $candidate_parts 0 end-1] "/"]
                if {$parent eq ""} {
                    set alternate "${stem}_[string range $expected 0 11]$suffix"
                } else {
                    set alternate "$parent/${stem}_[string range $expected 0 11]$suffix"
                }
                
                lassign [lookup $alternate] endpoint existing
                if {[dict size $existing] && ![same $existing $data]} {
                    error "remote artifact conflict"
                }
            }
            
            if {![dict size $existing]} {
                set content_b64 [binary encode base64 $data]
                set body [::json::dict2json [dict create message "Publish script abstraction" \
                                              branch "gateway1-abstractions" \
                                              content $content_b64]]
                
                array set put_headers $::headers
                dict set put_headers "Content-Type" "application/json"
                
                set tok [http::geturl $endpoint -method PUT -headers $put_headers -query $body -timeout 60000]
                set ncode [http::ncode $tok]
                
                if {$ncode >= 400} {
                    set err [http::error $tok]
                    http::cleanup $tok
                    error "HTTP Error: $err"
                }
                
                http::cleanup $tok
            }
            
            dict unset pending $name
            uplevel #0 $save_proc state
            
        } result]} {
            set success false
        }
    }
    
    if {$sync_proc ne "" && !$synced} {
        if {[catch {uplevel #0 $sync_proc $root} result]} {
            set success false
        }
    }
    
    return $success
}
