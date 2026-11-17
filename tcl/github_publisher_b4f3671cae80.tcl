#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "e1247fbb364a8d6a7dfa459cdec8cb109133dfd05fcb5d107bca9af008b7ba88", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "tcl"}
# github_publisher.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Publish queued, provenance-checked artifacts without staging unrelated files.

package require http
package require json
package require sha256

namespace eval github_publisher {
    variable supported_lang_dirs [list perl5 powershell perl6 tcl javascript ruby python lua shell go]

    proc queue_artifact {state root path} {
        # Resolve paths
        set root [file normalize $root]
        set resolved_path [file normalize $path]
        
        # Check if path is a symlink
        if {[file type $path] eq "link"} {
            error "artifact must not be a symlink"
        }
        
        # Get relative path
        set relative [string range $resolved_path [string length $root] end]
        if {[string index $relative 0] eq "/"} {
            set relative [string range $relative 1 end]
        }
        
        # Validate that path is under a language directory
        set parts [split $relative "/"]
        if {![llength $parts] || [lsearch -exact $::github_publisher::supported_lang_dirs [lindex $parts 0]] == -1} {
            error "artifact is outside a language directory"
        }
        
        # Read file and calculate SHA256 hash
        if {[catch {open $path rb} fd]} {
            error "cannot read file: $path"
        }
        set data [read $fd]
        close $fd
        set hash [sha256::sha256 -hex $data]
        
        # Add to pending publications
        dict set state ausstehende_veroeffentlichungen $relative $hash
        return $state
    }

    proc publish_pending {root state save token {opener ""}} {
        # Set default opener if not provided
        if {$opener eq ""} {
            set opener [list ::github_publisher::default_opener]
        }
        
        # Validate pending publications
        if {![dict exists $state ausstehende_veroeffentlichungen]} {
            dict set state ausstehende_veroeffentlichungen {}
        }
        set pending [dict get $state ausstehende_veroeffentlichungen]
        
        if {![dict size $pending]} {
            return 1
        }
        
        if {![string trim $token]} {
            return 0
        }
        
        set root [file normalize $root]
        set headers [list Authorization "Bearer [string trim $token]" \
                         Accept "application/vnd.github+json" \
                         X-GitHub-Api-Version "2022-11-28" \
                         User-Agent "abstractions-manager"]
        set success 1
        
        dict for {name expected} $pending {
            if {[catch {
                set full_path [file join $root $name]
                
                # Validate path
                if {[file type $full_path] eq "link"} {
                    error "invalid queued path"
                }
                set resolved [file normalize $full_path]
                set rel_path [string range $resolved [string length $root] end]
                if {[string index $rel_path 0] eq "/"} {
                    set rel_path [string range $rel_path 1 end]
                }
                if {$rel_path ne $name} {
                    error "invalid queued path"
                }
                
                # Read file and check hash
                if {[catch {open $full_path rb} fd]} {
                    error "cannot read file: $full_path"
                }
                set data [read $fd]
                close $fd
                set actual_hash [sha256::sha256 -hex $data]
                if {$actual_hash ne $expected} {
                    error "queued artifact changed"
                }
                
                # Define lookup function
                proc lookup {remote_name} {
                    upvar headers headers root root name name
                    set encoded_name [string map {/ %2F} $remote_name]
                    set endpoint "https://api.github.com/repos/KikiKari/OpenClaw/contents/$encoded_name"
                    set query_params "?ref=gateway1-abstractions"
                    
                    if {[catch {eval $opener [list $endpoint$query_params] $headers} result]} {
                        return [list $endpoint ""]
                    }
                    
                    return [list $endpoint $result]
                }
                
                # Define same function
                proc same {existing} {
                    upvar data data
                    if {![dict exists $existing encoding] || 
                        [dict get $existing encoding] ne "base64"} {
                        return 0
                    }
                    if {![dict exists $existing content]} {
                        return 0
                    }
                    set decoded [binary decode base64 [dict get $existing content]]
                    return [expr {$decoded eq $data}]
                }
                
                # Lookup existing file
                foreach {endpoint existing} [lookup $name] break
                
                if {$existing ne "" && ![same $existing]} {
                    # Handle conflicts by creating alternate name
                    set candidate_parts [file split $name]
                    set stem [file rootname [lindex $candidate_parts end]]
                    set suffix [file extension [lindex $candidate_parts end]]
                    set dir_parts [lrange $candidate_parts 0 end-1]
                    set alternate_name "[join $dir_parts /]/${stem}_[string range $expected 0 11]$suffix"
                    
                    foreach {endpoint existing} [lookup $alternate_name] break
                    
                    if {$existing ne "" && ![same $existing]} {
                        error "remote artifact conflict"
                    }
                }
                
                # Upload if needed
                if {$existing eq ""} {
                    set encoded_data [binary encode base64 $data]
                    set body_dict [dict create message "Publish script abstraction" \
                                          branch "gateway1-abstractions" \
                                          content $encoded_data]
                    set body [::json::encode $body_dict]
                    
                    # Make PUT request
                    set http_request [http::geturl $endpoint \
                                      -headers $headers \
                                      -method PUT \
                                      -query $body \
                                      -timeout 60000]
                    set status [http::status $http_request]
                    if {$status eq "ok"} {
                        set response_data [http::data $http_request]
                        ::json::decode $response_data
                    }
                    http::cleanup $http_request
                }
                
                # Remove from pending
                dict unset state ausstehende_veroeffentlichungen $name
                eval $save [list $state]
                
            } err]} {
                set success 0
            }
        }
        
        return $success
    }
    
    proc default_opener {url headers} {
        # Create HTTP request with headers
        set http_request [http::geturl $url -headers $headers -timeout 60000]
        set status [http::status $http_request]
        if {$status ne "ok"} {
            set code [http::ncode $http_request]
            http::cleanup $http_request
            if {$code == 404} {
                return ""
            } else {
                error "HTTP error: $code"
            }
        }
        set response_data [http::data $http_request]
        http::cleanup $http_request
        
        # Parse JSON response
        if {$response_data ne ""} {
            return [::json::decode $response_data]
        }
        return ""
    }
}

# Export procedures
proc queue_artifact {state root path} {
    return [github_publisher::queue_artifact $state $root $path]
}

proc publish_pending {root state save token {opener ""}} {
    return [github_publisher::publish_pending $root $state $save $token $opener]
}
