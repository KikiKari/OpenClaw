#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "fff646a8833b7ee9bead7d9a799f01db25458ea0589ba6f57942c7d765766060", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "tcl"}
# tm.go — portiert nach tcl
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Translation Memory implementation in Tcl
# This provides similar functionality to the Go version

namespace eval tm {
    # Define TMEntry structure as dict
    # Fields: cache_key segment_id source_path text_hash text translated provider model src_lang tgt_lang updated_at
    
    # TranslationMemory structure
    variable translation_memory
    
    # Initialize empty translation memory
    proc init {} {
        variable translation_memory
        set translation_memory [dict create entries [dict create]]
    }
    
    # Load translation memory from file
    proc load_translation_memory {path} {
        variable translation_memory
        
        # Initialize with path
        set tm_path $path
        set tm_entries [dict create]
        
        # Check if file exists
        if {[file exists $path]} {
            if {[catch {set fd [open $path r]}]} {
                error "Failed to open file: $path"
            }
            
            while {[gets $fd line] >= 0} {
                set trimmed [string trim $line]
                if {$trimmed ne ""} {
                    if {[catch {set entry [json::json2dict $trimmed]} err]} {
                        close $fd
                        error "translation memory decode failed: $err"
                    }
                    
                    set cache_key [dict get $entry cache_key]
                    set translated [string trim [dict get $entry translated]]
                    
                    if {$cache_key ne "" && $translated ne ""} {
                        dict set tm_entries $cache_key $entry
                    }
                }
            }
            close $fd
        }
        
        # Store in global variable
        set translation_memory [dict create path $tm_path entries $tm_entries]
        return
    }
    
    # Get entry by cache key
    proc get {cache_key} {
        variable translation_memory
        
        set entries [dict get $translation_memory entries]
        if {[dict exists $entries $cache_key]} {
            set entry [dict get $entries $cache_key]
            set translated [string trim [dict get $entry translated]]
            if {$translated eq ""} {
                return [list [dict create] 0]
            }
            return [list $entry 1]
        }
        return [list [dict create] 0]
    }
    
    # Put entry into translation memory
    proc put {entry} {
        variable translation_memory
        
        set cache_key [dict get $entry cache_key]
        if {$cache_key eq ""} {
            return
        }
        
        set entries [dict get $translation_memory entries]
        dict set entries $cache_key $entry
        dict set translation_memory entries $entries
    }
    
    # Save translation memory to file
    proc save {} {
        variable translation_memory
        
        set path [dict get $translation_memory path]
        if {$path eq ""} {
            return
        }
        
        set dir [file dirname $path]
        file mkdir $dir
        
        set tmp_path "${path}.tmp"
        if {[catch {set fd [open $tmp_path w]} err]} {
            error "Failed to create temporary file: $err"
        }
        
        set entries [dict get $translation_memory entries]
        set keys [lsort [dict keys $entries]]
        
        foreach key $keys {
            set entry [dict get $entries $key]
            if {[catch {set payload [json::dict2json $entry]} err]} {
                close $fd
                error "Failed to marshal entry: $err"
            }
            puts $fd $payload
        }
        
        close $fd
        file rename -force $tmp_path $path
    }
    
    # Helper procedures for working with entries
    proc create_entry {cache_key segment_id source_path text_hash text translated provider model src_lang tgt_lang updated_at} {
        return [dict create \
            cache_key $cache_key \
            segment_id $segment_id \
            source_path $source_path \
            text_hash $text_hash \
            text $text \
            translated $translated \
            provider $provider \
            model $model \
            src_lang $src_lang \
            tgt_lang $tgt_lang \
            updated_at $updated_at]
    }
    
    proc get_field {entry field} {
        if {[dict exists $entry $field]} {
            return [dict get $entry $field]
        }
        return ""
    }
    
    # Initialize on load
    init
}

# Load required packages
package require json
package require json::write

# Set up json writing format
json::write indented false
