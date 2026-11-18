#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "3bdd25a1c20aa8af0668798a3b3bbedb0734af6d0762119dfb1b9f90ba01fd00", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "tcl"}
# quick_validate.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

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
        
        if {![string match "*:*" $stripped]} {
            return ""
        }
        set parts [split $stripped ":"]
        set key [string trim [lindex $parts 0]]
        set value [string trim [join [lrange $parts 1 end] ":"]]
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
    
    return [array get parsed]
}

proc validate_skill {skill_path} {
    set skill_md [file join $skill_path "SKILL.md"]
    if {![file exists $skill_md]} {
        return [list false "SKILL.md not found"]
    }
    
    if {[catch {set fd [open $skill_md r]} err]} {
        return [list false "Could not read SKILL.md: $err"]
    }
    set content [read $fd]
    close $fd
    
    set frontmatter_text [_extract_frontmatter $content]
    if {$frontmatter_text eq ""} {
        return [list false "Invalid frontmatter format"]
    }
    
    set frontmatter {}
    if {[package vsatisfies [package present yaml] 0.5]} {
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
    
    array set fm_arr $frontmatter
    set allowed_properties [list name description license "allowed-tools" metadata]
    
    set unexpected_keys {}
    foreach key [array names fm_arr] {
        if {$key ni $allowed_properties} {
            lappend unexpected_keys $key
        }
    }
    
    if {[llength $unexpected_keys] > 0} {
        set allowed [lsort $allowed_properties]
        set unexpected [lsort $unexpected_keys]
        return [list false "Unexpected key(s) in SKILL.md frontmatter: [join $unexpected ", "]. Allowed properties are: [join $allowed ", "]"]
    }
    
    if {![info exists fm_arr(name)]} {
        return [list false "Missing 'name' in frontmatter"]
    }
    if {![info exists fm_arr(description)]} {
        return [list false "Missing 'description' in frontmatter"]
    }
    
    set name $fm_arr(name)
    if {[string trim $name] eq ""} {
        return [list false "Name must be a non-empty string"]
    }
    if {![regexp {^[a-z0-9-]+$} $name]} {
        return [list false "Name '$name' should be hyphen-case (lowercase letters, digits, and hyphens only)"]
    }
    if {[string index $name 0] eq "-" || [string index $name end] eq "-" || [string first "--" $name] != -1} {
        return [list false "Name '$name' cannot start/end with hyphen or contain consecutive hyphens"]
    }
    if {[string length $name] > $::MAX_SKILL_NAME_LENGTH} {
        return [list false "Name is too long ([string length $name] characters). Maximum is $::MAX_SKILL_NAME_LENGTH characters."]
    }
    
    set description $fm_arr(description)
    if {[string first "<" $description] != -1 || [string first ">" $description] != -1} {
        return [list false "Description cannot contain angle brackets (< or >)"]
    }
    if {[string length $description] > 1024} {
        return [list false "Description is too long ([string length $description] characters). Maximum is 1024 characters."]
    }
    
    return [list true "Skill is valid!"]
}

if {$argc != 1} {
    puts "Usage: tclsh quick_validate.tcl <skill_directory>"
    exit 1
}

lassign [validate_skill [lindex $argv 0]] valid message
puts $message
if {!$valid} {
    exit 1
} else {
    exit 0
}
