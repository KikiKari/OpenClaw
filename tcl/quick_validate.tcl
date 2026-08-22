#!/usr/bin/env tclsh
# quick_validate.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Quick validation script for skills - minimal version

package require Tcl 8.6
package require yaml 0.5

set MAX_SKILL_NAME_LENGTH 64

proc _extract_frontmatter {content} {
    set lines [split $content \n]
    if {[llength $lines] == 0 || [string trim [lindex $lines 0]] ne "---"} {
        return ""
    }
    set frontmatter_lines {}
    for {set i 1} {$i < [llength $lines]} {incr i} {
        set line [lindex $lines $i]
        if {[string trim $line] eq "---"} {
            return [join $frontmatter_lines \n]
        }
        lappend frontmatter_lines $line
    }
    return ""
}

proc _parse_simple_frontmatter {frontmatter_text} {
    array set parsed {}
    set current_key ""
    
    foreach raw_line [split $frontmatter_text \n] {
        set stripped [string trim $raw_line]
        if {$stripped eq "" || [string index $stripped 0] eq "#"} {
            continue
        }
        
        set is_indented [expr {[string length $raw_line] > 0 && [string is space -strict [string index $raw_line 0]]}]
        if {$is_indented} {
            if {$current_key eq ""} {
                return ""
            }
            set current_value $parsed($current_key)
            if {$current_value eq ""} {
                set parsed($current_key) $stripped
            } else {
                set parsed($current_key) "$current_value\n$stripped"
            }
            continue
        }
        
        if {![regexp {^([^:]+):(.*)$} $stripped -> key_part value_part]} {
            return ""
        }
        set key [string trim $key_part]
        set value [string trim $value_part]
        if {$key eq ""} {
            return ""
        }
        if {([string index $value 0] eq "\"" && [string index $value end] eq "\"") ||
            ([string index $value 0] eq "'" && [string index $value end] eq "'")} {
            set value [string range $value 1 end-1]
        }
        set parsed($key) $value
        set current_key $key
    }
    
    # Convert array to dict-like list
    set result {}
    foreach {k v} [array get parsed] {
        lappend result $k $v
    }
    return $result
}

proc validate_skill {skill_path} {
    # Basic validation of a skill
    
    set skill_md [file join $skill_path "SKILL.md"]
    if {![file exists $skill_md]} {
        return [list false "SKILL.md not found"]
    }
    
    if {[catch {set fd [open $skill_md r]} err]} {
        return [list false "Could not read SKILL.md: $err"]
    }
    if {[catch {set content [read $fd]} err]} {
        close $fd
        return [list false "Could not read SKILL.md: $err"]
    }
    close $fd
    
    set frontmatter_text [_extract_frontmatter $content]
    if {$frontmatter_text eq ""} {
        return [list false "Invalid frontmatter format"]
    }
    
    set frontmatter {}
    if {[package present yaml] ne ""} {
        if {[catch {set frontmatter [::yaml::load $frontmatter_text]} err]} {
            return [list false "Invalid YAML in frontmatter: $err"]
        }
        if {[llength $frontmatter] % 2 != 0} {
            return [list false "Frontmatter must be a YAML dictionary"]
        }
    } else {
        set frontmatter [_parse_simple_frontmatter $frontmatter_text]
        if {$frontmatter eq ""} {
            return [list false "Invalid YAML in frontmatter: unsupported syntax without PyYAML installed"]
        }
    }
    
    # Convert frontmatter to dict for easier access
    array set fm_dict {}
    foreach {k v} $frontmatter {
        set fm_dict($k) $v
    }
    
    set allowed_properties {name description license allowed-tools metadata}
    set unexpected_keys {}
    foreach {key val} $frontmatter {
        if {$key ni $allowed_properties} {
            lappend unexpected_keys $key
        }
    }
    
    if {[llength $unexpected_keys] > 0} {
        set allowed [lsort $allowed_properties]
        set unexpected_sorted [lsort $unexpected_keys]
        set allowed_str [join $allowed ", "]
        set unexpected_str [join $unexpected_sorted ", "]
        return [list false "Unexpected key(s) in SKILL.md frontmatter: $unexpected_str. Allowed properties are: $allowed_str"]
    }
    
    if {![info exists fm_dict(name)]} {
        return [list false "Missing 'name' in frontmatter"]
    }
    if {![info exists fm_dict(description)]} {
        return [list false "Missing 'description' in frontmatter"]
    }
    
    set name $fm_dict(name)
    if {$name eq ""} {
        return [list false "Name must be a string, got [llength $name]"]
    }
    set name [string trim $name]
    if {$name ne ""} {
        if {![regexp {^[a-z0-9-]+$} $name]} {
            return [list false "Name '$name' should be hyphen-case (lowercase letters, digits, and hyphens only)"]
        }
        if {[string index $name 0] eq "-" || 
            [string index $name end] eq "-" || 
            [string first "--" $name] != -1} {
            return [list false "Name '$name' cannot start/end with hyphen or contain consecutive hyphens"]
        }
        if {[string length $name] > $::MAX_SKILL_NAME_LENGTH} {
            return [list false "Name is too long ([string length $name] characters). Maximum is $::MAX_SKILL_NAME_LENGTH characters."]
        }
    }
    
    set description $fm_dict(description)
    if {$description eq ""} {
        return [list false "Description must be a string, got [llength $description]"]
    }
    set description [string trim $description]
    if {$description ne ""} {
        if {[string first "<" $description] != -1 || [string first ">" $description] != -1} {
            return [list false "Description cannot contain angle brackets (< or >)"]
        }
        if {[string length $description] > 1024} {
            return [list false "Description is too long ([string length $description] characters). Maximum is 1024 characters."]
        }
    }
    
    return [list true "Skill is valid!"]
}

# Main execution
if {$argc != 1} {
    puts "Usage: tclsh quick_validate.tcl <skill_directory>"
    exit 1
}

lassign [validate_skill [lindex $argv 0]] valid message
puts $message
exit [expr {!$valid}]
