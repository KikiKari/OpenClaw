#!/usr/bin/env tclsh8.6
# package_skill.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Skill Packager - Creates a distributable .skill file of a skill folder
#
# Usage:
#     tclsh8.6 utils/package_skill.tcl <path/to/skill-folder> ?output-directory?
#
# Example:
#     tclsh8.6 utils/package_skill.tcl skills/public/my-skill
#     tclsh8.6 utils/package_skill.tcl skills/public/my-skill ./dist

package require zipfile::encode

# Load quick_validate.tcl if available
if {[file exists "quick_validate.tcl"]} {
    source quick_validate.tcl
} elseif {[file exists "./utils/quick_validate.tcl"]} {
    source ./utils/quick_validate.tcl
} else {
    puts stderr "Warning: Could not find quick_validate.tcl - validation will be skipped"
}

proc is_within {path root} {
    # Check if path is within root directory
    set path_norm [file normalize $path]
    set root_norm [file normalize $root]
    
    # Get relative path from root to path
    if {[string first $root_norm $path_norm] == 0} {
        return 1
    } else {
        return 0
    }
}

proc package_skill {skill_path {output_dir ""}} {
    # Package a skill folder into a .skill file.
    #
    # Args:
    #     skill_path: Path to the skill folder
    #     output_dir: Optional output directory for the .skill file (defaults to current directory)
    #
    # Returns:
    #     Path to the created .skill file, or empty string if error
    
    set skill_path [file normalize $skill_path]
    
    # Validate skill folder exists
    if {![file exists $skill_path]} {
        puts stderr "\[ERROR\] Skill folder not found: $skill_path"
        return ""
    }
    
    if {![file isdirectory $skill_path]} {
        puts stderr "\[ERROR\] Path is not a directory: $skill_path"
        return ""
    }
    
    # Validate SKILL.md exists
    set skill_md [file join $skill_path "SKILL.md"]
    if {![file exists $skill_md]} {
        puts stderr "\[ERROR\] SKILL.md not found in $skill_path"
        return ""
    }
    
    # Run validation before packaging (if validate_skill proc exists)
    if {[info procs validate_skill] ne ""} {
        puts "Validating skill..."
        lassign [validate_skill $skill_path] valid message
        if {!$valid} {
            puts stderr "\[ERROR\] Validation failed: $message"
            puts stderr "   Please fix the validation errors before packaging."
            return ""
        }
        puts "\[OK\] $message\n"
    } else {
        puts "Note: Skipping validation - quick_validate not loaded"
    }
    
    # Determine output location
    set skill_name [file tail $skill_path]
    if {$output_dir ne ""} {
        set output_path [file normalize $output_dir]
        file mkdir $output_path
    } else {
        set output_path [pwd]
    }
    
    set skill_filename [file join $output_path "${skill_name}.skill"]
    
    set excluded_dirs [list ".git" ".svn" ".hg" "__pycache__" "node_modules"]
    
    # Create temporary directory for building the archive
    set temp_dir [file join [pwd] "_temp_[pid]"]
    file mkdir $temp_dir
    
    # Copy files to temporary directory while filtering
    set success 1
    set added_files {}
    
    # Recursive procedure to copy files
    proc copy_filtered_files {src_dir dest_dir excluded rel_base} {
        global added_files skill_path skill_filename
        
        foreach item [glob -nocomplain -dir $src_dir *] {
            set item_name [file tail $item]
            set full_item [file join $src_dir $item_name]
            
            # Skip excluded directories
            if {$item_name in $excluded} {
                continue
            }
            
            # Security: never follow or package symlinks
            if {[file type $full_item] eq "link"} {
                puts "\[WARN\] Skipping symlink: $full_item"
                continue
            }
            
            # Skip if file escapes skill root
            if {![is_within $full_item $skill_path]} {
                puts stderr "\[ERROR\] File escapes skill root: $full_item"
                error "File escape detected"
            }
            
            # If output lives under skill_path, avoid writing archive into itself
            if {[file normalize $full_item] eq [file normalize $skill_filename]} {
                puts "\[WARN\] Skipping output archive: $full_item"
                continue
            }
            
            set dest_item [file join $dest_dir $rel_base $item_name]
            
            if {[file isdirectory $full_item]} {
                file mkdir $dest_item
                lappend added_files [file join $rel_base $item_name]
                copy_filtered_files $full_item $dest_dir $excluded [file join $rel_base $item_name]
            } else {
                file copy $full_item $dest_item
                lappend added_files [file join $rel_base $item_name]
                puts "  Added: [file join $rel_base $item_name]"
            }
        }
    }
    
    # Try to create the .skill file (zip format)
    if {$success} {
        if {[catch {
            # Copy filtered files to temp directory
            copy_filtered_files $skill_path $temp_dir $excluded_dirs ""
            
            # Create the zip file
            ::zipfile::encode::encodeFile $temp_dir $skill_filename 9
            
        } error_msg]} {
            puts stderr "\[ERROR\] Error creating .skill file: $error_msg"
            set success 0
        }
    }
    
    # Clean up temporary directory
    if {[file exists $temp_dir]} {
        file delete -force $temp_dir
    }
    
    if {$success} {
        puts "\n\[OK\] Successfully packaged skill to: $skill_filename"
        return $skill_filename
    } else {
        return ""
    }
}

proc main {} {
    global argv
    
    if {[llength $argv] < 1} {
        puts "Usage: tclsh8.6 utils/package_skill.tcl <path/to/skill-folder> ?output-directory?"
        puts "\nExample:"
        puts "  tclsh8.6 utils/package_skill.tcl skills/public/my-skill"
        puts "  tclsh8.6 utils/package_skill.tcl skills/public/my-skill ./dist"
        exit 1
    }
    
    set skill_path [lindex $argv 0]
    set output_dir ""
    if {[llength $argv] > 1} {
        set output_dir [lindex $argv 1]
    }
    
    puts "Packaging skill: $skill_path"
    if {$output_dir ne ""} {
        puts "   Output directory: $output_dir"
    }
    puts ""
    
    set result [package_skill $skill_path $output_dir]
    
    if {$result ne ""} {
        exit 0
    } else {
        exit 1
    }
}

# Call main if script is run directly
if {[info script] eq $argv0} {
    main
}
