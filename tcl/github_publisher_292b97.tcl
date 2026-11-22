#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "7083e265a084316c680d8f065459ffccd2ad55020bdfe933e7657df46bcdd568", "source_sha256": "292b977dd14f55e08a3852eccaf235d04d5f7e909ab6139a9ab2e379ae2305a1", "target_language": "tcl"}
# github_publisher.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Publish queued, provenance-checked artifacts without staging unrelated files.

package require Tcl 8.6
package require http
package require json
package require sha256

namespace eval github_publisher {
    variable LANGUAGES [list perl5 powershell perl6 tcl javascript ruby python lua shell go]

    proc synchronize_checkout {root {remote "https://github.com/KikiKari/OpenClaw.git"} {branch "gateway1-abstractions"}} {
        # Reconcile a remote snapshot into the checkout without changing its Git history.
        set root [file normalize $root]
        
        # Create temporary directory
        set tmp [exec mktemp -d abstractions-snapshot-XXXXXX]
        set snapshot [file join $tmp repo]
        
        # Clone repository
        if {[catch {
            exec git clone --quiet --depth=1 --single-branch \
                --branch $branch -- $remote $snapshot
        } err]} {
            file delete -force $tmp
            error "Failed to clone repository: $err"
        }
        
        # Get revision
        set revision [string trim [exec git -C $snapshot rev-parse HEAD]]
        
        array set counts {}
        
        foreach language [lsort $::github_publisher::LANGUAGES] {
            set source [file join $snapshot $language]
            set target [file join $root $language]
            
            # Check if directories are symlinks
            if {[file type $source] eq "link" || ([file exists $target] && [file type $target] eq "link")} {
                file delete -force $tmp
                error "language directory is a symlink"
            }
            
            # Create target directory
            file mkdir $target
            
            # Get known file hashes
            set known [dict create]
            foreach item [glob -nocomplain -tails -directory $target *] {
                set filepath [file join $target $item]
                if {[file isfile $filepath] && [file type $filepath] ne "link"} {
                    set hash [get_file_hash $filepath]
                    dict set known $hash 1
                }
            }
            
            # Process files
            set files {}
            if {[file exists $source] && [file isdirectory $source]} {
                set files [lsort [glob -nocomplain -directory $source *]]
            }
            
            # Validate files
            foreach item $files {
                if {[file type $item] eq "link" || ![file isfile $item]} {
                    file delete -force $tmp
                    error "invalid remote abstraction"
                }
            }
            
            set counts($language) [llength $files]
            
            foreach item $files {
                set data [read_file_binary $item]
                set digest [sha256::sha256 -hex $data]
                
                if {[dict exists $known $digest]} {
                    continue
                }
                
                set destination [file join $target [file tail $item]]
                if {[file exists $destination] || [file type $destination] eq "link"} {
                    set stem [file rootname [file tail $item]]
                    set suffix [file extension [file tail $item]]
                    set destination [file join $target "${stem}__pool_${digest}${suffix}"]
                }
                
                if {[catch {
                    set fd [open $destination wb]
                    puts -nonewline $fd $data
                    close $fd
                } err]} {
                    if {[file type $destination] eq "link" || 
                        ![file isfile $destination] || 
                        [read_file_binary $destination] ne $data} {
                        file delete -force $tmp
                        error "local abstraction conflict"
                    }
                }
                
                dict set known $digest 1
            }
        }
        
        file delete -force $tmp
        return [list $revision [array get counts]]
    }
    
    proc update_status_counts {path revision counts} {
        set text [read_file_text $path]
        
        set rows [list "## Bestand" "" "GitHub-Stand: \`${revision}\`" "" \
                  "| Zielsprache | Dateien |" "|---|---:|"]
        
        foreach language [lsort $::github_publisher::LANGUAGES] {
            set count 0
            if {[dict exists $counts $language]} {
                set count [dict get $counts $language]
            }
            lappend rows "| ${language} | ${count} |"
        }
        
        set total 0
        dict for {lang count} $counts {
            incr total $count
        }
        lappend rows "| **gesamt** | **${total}** |" "" ""
        
        set updated_rows [join $rows "\n"]
        regsub -all -- {^## Bestand\n.*?(?=^## Quellen\n)} $text $updated_rows text
        
        if {![regexp {^## Bestand\n} $text]} {
            error "status inventory section missing"
        }
        
        write_file_text $path $text
    }
    
    proc queue_artifact {state root path} {
        set root [file normalize $root]
        set path [file normalize $path]
        
        if {[file type $path] eq "link"} {
            error "artifact must not be a symlink"
        }
        
        set full_path [file normalize $path]
        set relative [get_relative_path $full_path $root]
        
        if {$relative ne "STATUS.md"} {
            set parts [split $relative "/"]
            if {![llength $parts] || [lindex $parts 0] ni $::github_publisher::LANGUAGES} {
                error "artifact is outside a language directory"
            }
        }
        
        set data [read_file_binary $path]
        set hash [sha256::sha256 -hex $data]
        
        dict set state "ausstehende_veroeffentlichungen" $relative $hash
        return $state
    }
    
    proc publish_pending {root state save token {opener "http::geturl"} {sync ""}} {
        set pending [dict get $state "ausstehende_veroeffentlichungen"]
        if {![dict size $pending] && $sync eq ""} {
            return 1
        }
        
        if {![string trim $token]} {
            return 0
        }
        
        set root [file normalize $root]
        
        # Set up HTTP headers
        set headers [list Authorization "Bearer [string trim $token]" \
                      Accept "application/vnd.github+json" \
                      X-GitHub-Api-Version "2022-11-28" \
                      User-Agent "abstractions-manager"]
        
        set success 1
        set entries {}
        
        dict for {name expected} $pending {
            if {$name eq "STATUS.md"} {
                lappend entries [list $name $expected]
            } else {
                set temp_entries [list]
                lappend temp_entries [list $name $expected]
                set entries [concat $temp_entries $entries]
            }
        }
        
        set synced 0
        
        foreach entry $entries {
            lassign $entry name expected
            if {[catch {
                set path [file join $root $name]
                if {[file type $path] eq "link" || [get_relative_path [file normalize $path] $root] ne $name} {
                    error "invalid queued path"
                }
                
                set data [read_file_binary $path]
                set actual_hash [sha256::sha256 -hex $data]
                if {$actual_hash ne $expected} {
                    error "queued artifact changed"
                }
                
                if {$name eq "STATUS.md" && $sync ne ""} {
                    if {!$success} {
                        error "artifact publication incomplete"
                    }
                    
                    set result [$sync $root]
                    lassign $result revision counts
                    set synced 1
                    
                    update_status_counts $path $revision $counts
                    set data [read_file_binary $path]
                    set expected [sha256::sha256 -hex $data]
                    dict set pending $name $expected
                    set state [dict replace $state "ausstehende_veroeffentlichungen" $pending]
                    $save $state
                }
                
                set endpoint "https://api.github.com/repos/KikiKari/OpenClaw/contents/[string map {/ %2F} $name]"
                set request_options [list -headers $headers -timeout 60000]
                
                # Try to get existing file
                set existing_url "${endpoint}?ref=gateway1-abstractions"
                set existing_data [fetch_with_retries $existing_url $request_options]
                set existing [json::json2dict $existing_data]
                
                # Check if content is the same
                proc same_content {existing data} {
                    if {[dict exists $existing encoding] && 
                        [dict get $existing encoding] eq "base64"} {
                        set content [dict get $existing content]
                        set decoded [binary decode base64 $content]
                        return [expr {$decoded eq $data}]
                    }
                    return 0
                }
                
                if {$name eq "STATUS.md" && $existing_data ne "" && ![same_content $existing $data]} {
                    set sha [dict get $existing sha]
                    if {![dict exists $existing sha] || $sha eq ""} {
                        error "missing remote status version"
                    }
                    
                    set content_b64 [binary encode base64 $data]
                    set body [json::dict2json [dict create message "Update abstraction status" \
                                                branch "gateway1-abstractions" \
                                                content $content_b64 \
                                                sha $sha]]
                    
                    set put_options [concat $request_options [list -method PUT -query $body]]
                    set response_data [fetch_with_retries $endpoint $put_options]
                } elseif {$existing_data ne "" && ![same_content $existing $data]} {
                    # Handle conflicts by creating alternate filename
                    set candidate_parts [split $name "/"]
                    set candidate_name [lindex $candidate_parts end]
                    set candidate_dir [join [lrange $candidate_parts 0 end-1] "/"]
                    set stem [file rootname $candidate_name]
                    set suffix [file extension $candidate_name]
                    set alternate_name "${stem}_${expected:0:12}${suffix}"
                    set alternate [expr {$candidate_dir ne "" ? "$candidate_dir/$alternate_name" : $alternate_name}]
                    
                    set alt_endpoint "https://api.github.com/repos/KikiKari/OpenClaw/contents/[string map {/ %2F} $alternate]"
                    set alt_existing_url "${alt_endpoint}?ref=gateway1-abstractions"
                    set alt_existing_data [fetch_with_retries $alt_existing_url $request_options]
                    set alt_existing [json::json2dict $alt_existing_data]
                    
                    if {$alt_existing_data ne "" && ![same_content $alt_existing $data]} {
                        error "remote artifact conflict"
                    }
                    set endpoint $alt_endpoint
                    set existing_data $alt_existing_data
                }
                
                if {$existing_data eq ""} {
                    set content_b64 [binary encode base64 $data]
                    set body [json::dict2json [dict create message "Publish script abstraction" \
                                                branch "gateway1-abstractions" \
                                                content $content_b64]]
                    
                    set put_options [concat $request_options [list -method PUT -query $body]]
                    set response_data [fetch_with_retries $endpoint $put_options]
                }
                
                dict unset pending $name
                set state [dict replace $state "ausstehende_veroeffentlichungen" $pending]
                $save $state
                
            } err]} {
                set success 0
            }
        }
        
        if {$sync ne "" && !$synced} {
            if {[catch {$sync $root} err]} {
                set success 0
            }
        }
        
        return $success
    }
    
    # Helper procedures
    proc get_file_hash {filepath} {
        set data [read_file_binary $filepath]
        return [sha256::sha256 -hex $data]
    }
    
    proc read_file_binary {filepath} {
        set fd [open $filepath rb]
        set data [read $fd]
        close $fd
        return $data
    }
    
    proc read_file_text {filepath} {
        set fd [open $filepath r]
        set data [read $fd]
        close $fd
        return $data
    }
    
    proc write_file_text {filepath text} {
        set fd [open $filepath w]
        puts -nonewline $fd $text
        close $fd
    }
    
    proc get_relative_path {path root} {
        # Simplified implementation - in real usage would need proper path handling
        set root_len [string length $root]
        if {[string range $path 0 $root_len-1] eq $root} {
            return [string range $path $root_len+1 end]
        }
        return $path
    }
    
    proc fetch_with_retries {url options} {
        # Simple wrapper around http::geturl with basic error handling
        set token [http::geturl $url {*}$options]
        set status [http::status $token]
        if {$status eq "ok"} {
            set data [http::data $token]
            http::cleanup $token
            return $data
        } else {
            http::cleanup $token
            error "HTTP request failed: $status"
        }
    }
}

# Export public procedures
namespace export synchronize_checkout update_status_counts queue_artifact publish_pending
