#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "f115bd9cd016a989675b8d48f0b4972a89687ebeb1ee1d8e0c172b098641d209", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "tcl"}
# github_publisher.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# Publish queued, provenance-checked artifacts without staging unrelated files.

package require http
package require json
package require base64

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
    
    # Validate language directory
    set parts [split $relative "/"]
    if {![llength $parts] || [lindex $parts 0] ni {
        perl5 powershell perl6 tcl javascript ruby python lua shell go
    }} {
        error "artifact is outside a language directory"
    }
    
    # Read file and calculate SHA256 hash
    set fp [open $path rb]
    set data [read $fp]
    close $fp
    
    set temp_file [open [file join $::env(TMP) temp_sha256.txt] wb]
    puts -nonewline $temp_file $data
    close $temp_file
    
    set sha256_hash [exec openssl dgst -sha256 -hex [file join $::env(TMP) temp_sha256.txt]]
    file delete [file join $::env(TMP) temp_sha256.txt]
    
    # Extract just the hash part from openssl output
    set sha256_hash [lindex [split $sha256_hash " "] end]
    
    # Add to pending publications
    dict set state ausstehende_veroeffentlichungen $relative $sha256_hash
    return $state
}

proc publish_pending {root state save token {opener ""}} {
    # Get pending publications
    if {[dict exists $state ausstehende_veroeffentlichungen]} {
        set pending [dict get $state ausstehende_veroeffentlichungen]
    } else {
        set pending {}
    }
    
    # Validate pending queue
    if {![dict size $pending] && ![dict exists $pending]} {
        return true
    }
    
    if {![string trim $token]} {
        return false
    }
    
    set root [file normalize $root]
    set success true
    
    # Headers for GitHub API
    array set headers {
        Authorization ""
        Accept "application/vnd.github+json"
        X-GitHub-Api-Version "2022-11-28"
        User-Agent "abstractions-manager"
    }
    set headers(Authorization) "Bearer [string trim $token]"
    
    # Process each pending item
    foreach {name expected} [dict get $pending *] {
        if {!$success} break
        
        set path [file join $root $name]
        
        # Validate path
        if {[file type $path] eq "link"} {
            set success false
            continue
        }
        
        set resolved_path [file normalize $path]
        set rel_path [string range $resolved_path [string length $root] end]
        if {[string index $rel_path 0] eq "/"} {
            set rel_path [string range $rel_path 1 end]
        }
        
        if {$rel_path ne $name} {
            set success false
            continue
        }
        
        # Read file and check hash
        set fp [open $path rb]
        set data [read $fp]
        close $fp
        
        set temp_file [open [file join $::env(TMP) temp_sha256_check.txt] wb]
        puts -nonewline $temp_file $data
        close $temp_file
        
        set actual_hash [exec openssl dgst -sha256 -hex [file join $::env(TMP) temp_sha256_check.txt]]
        file delete [file join $::env(TMP) temp_sha256_check.txt]
        set actual_hash [lindex [split $actual_hash " "] end]
        
        if {$actual_hash ne $expected} {
            set success false
            continue
        }
        
        # Lookup function
        proc lookup {remote_name headers} {
            set encoded_name [string map {/ %2F} $remote_name]
            set endpoint "https://api.github.com/repos/KikiKari/OpenClaw/contents/$encoded_name?ref=gateway1-abstractions"
            
            array set req_headers [array get headers]
            set req_headers(Timeout) 60
            
            if {[catch {http::geturl $endpoint -headers [array get req_headers]} token]} {
                return [list $endpoint {}]
            }
            
            set ncode [http::ncode $token]
            if {$ncode == 404} {
                http::cleanup $token
                return [list $endpoint {}]
            } elseif {$ncode >= 400} {
                http::cleanup $token
                error "HTTP Error: $ncode"
            }
            
            set result [http::data $token]
            http::cleanup $token
            
            if {[catch {::json::json2dict $result} json_result]} {
                return [list $endpoint {}]
            }
            
            return [list $endpoint $json_result]
        }
        
        # Same function
        proc same {existing data} {
            if {![dict exists $existing encoding] || 
                [dict get $existing encoding] ne "base64"} {
                return false
            }
            
            if {![dict exists $existing content]} {
                return false
            }
            
            set decoded_content [base64::decode [dict get $existing content]]
            return [string equal $decoded_content $data]
        }
        
        # Lookup existing file
        lassign [lookup $name [array get headers]] endpoint existing
        
        if {$existing ne "" && ![same $existing $data]} {
            # Handle conflicts by creating alternate filename
            set candidate_parts [file split $name]
            set stem [file rootname [lindex $candidate_parts end]]
            set suffix [file extension [lindex $candidate_parts end]]
            set parent [join [lrange $candidate_parts 0 end-1] "/"]
            set alternate "$parent/${stem}_${expected}s$suffix"
            
            lassign [lookup $alternate [array get headers]] endpoint existing
            
            if {$existing ne "" && ![same $existing $data]} {
                set success false
                break
            }
        }
        
        # Upload file if it doesn't exist
        if {$existing eq ""} {
            # Encode data as base64
            set encoded_data [base64::encode $data]
            
            # Create JSON payload
            set message "Publish script abstraction"
            set branch "gateway1-abstractions"
            set json_payload "{\"message\":\"$message\",\"branch\":\"$branch\",\"content\":\"$encoded_data\"}"
            
            # Make PUT request
            set put_headers [array get headers]
            dict set put_headers "Content-Type" "application/json"
            
            if {[catch {
                set token [http::geturl $endpoint -method PUT -headers $put_headers -query $json_payload -timeout 60]
                set ncode [http::ncode $token]
                if {$ncode >= 400} {
                    error "HTTP Error: $ncode"
                }
                http::cleanup $token
            } err]} {
                set success false
                break
            }
        }
        
        # Remove from pending and save state
        dict unset state ausstehende_veroeffentlichungen $name
        {*}$save $state
    }
    
    return $success
}
