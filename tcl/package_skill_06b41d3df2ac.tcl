#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "c0747897e70f3e3baacd2f3a81104594910e577ec4f0150b59c02f3d1ccd9439", "source_sha256": "f290101073ee6a167f46edadda164d2c88affc03c554135fe101a4e422c44c22", "target_language": "tcl"}
# package_skill.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

#
# Skill Packager - Creates a distributable .skill file of a skill folder
#
# Usage:
#    tclsh utils/package_skill.tcl <path/to/skill-folder> [output-directory]
#
# Example:
#    tclsh utils/package_skill.tcl skills/public/my-skill
#    tclsh utils/package_skill.tcl skills/public/my-skill ./dist

package require Tcl 8.6
package require fileutil
package require cmdline

proc _is_within {path root} {
    set path [file normalize $path]
    set root [file normalize $root]
    return [string equal -length [string length $root] $path $root]
}

proc validate_skill {skill_path} {
    # Placeholder for validation function - should be implemented separately
    # Returns list {valid message}
    return {1 "Skill validation passed"}
}

proc package_skill {skill_path {output_dir ""}} {
    #
    # Package a skill folder into a .skill file.
    #
    # Args:
    #    skill_path: Path to the skill folder
    #    output_dir: Optional output directory for the .skill file (defaults to current directory)
    #
    # Returns:
    #    Path to the created .skill file, or empty string if error
    #
    
    set skill_path [file normalize $skill_path]

    # Validate skill folder exists
    if {![file exists $skill_path]} {
        puts "[ERROR] Skill folder not found: $skill_path"
        return ""
    }

    if {![file isdirectory $skill_path]} {
        puts "[ERROR] Path is not a directory: $skill_path"
        return ""
    }

    # Validate SKILL.md exists
    set skill_md [file join $skill_path "SKILL.md"]
    if {![file exists $skill_md]} {
        puts "[ERROR] SKILL.md not found in $skill_path"
        return ""
    }

    # Run validation before packaging
    puts "Validating skill..."
    set validation_result [validate_skill $skill_path]
    set valid [lindex $validation_result 0]
    set message [lindex $validation_result 1]
    
    if {!$valid} {
        puts "[ERROR] Validation failed: $message"
        puts "   Please fix the validation errors before packaging."
        return ""
    }
    puts "[OK] $message\n"

    # Determine output location
    set skill_name [file tail $skill_path]
    if {$output_dir ne ""} {
        set output_path [file normalize $output_dir]
        file mkdir $output_path
    } else {
        set output_path [pwd]
    }

    set skill_filename [file join $output_path "${skill_name}.skill"]

    set EXCLUDED_DIRS [list ".git" ".svn" ".hg" "__pycache__" "node_modules"]

    # Create the .skill file (zip format)
    try {
        set zip [open "|zip -qr $skill_filename -" w]
        
        # Walk through the skill directory
        set files [fileutil::find $skill_path]
        foreach file_path $files {
            # Security: never follow or package symlinks.
            if {[file type $file_path] eq "link"} {
                puts "[WARN] Skipping symlink: $file_path"
                continue
            }

            set rel_path [fileutil::relative $skill_path $file_path]
            set rel_parts [file split $rel_path]
            
            # Check if any part is in excluded directories
            set exclude 0
            foreach part $rel_parts {
                if {$part in $EXCLUDED_DIRS} {
                    set exclude 1
                    break
                }
            }
            if {$exclude} {
                continue
            }

            if {[file isfile $file_path]} {
                set resolved_file [file normalize $file_path]
                if {![_is_within $resolved_file $skill_path]} {
                    puts "[ERROR] File escapes skill root: $file_path"
                    close $zip
                    file delete $skill_filename
                    return ""
                }
                # If output lives under skill_path, avoid writing archive into itself.
                if {$resolved_file eq [file normalize $skill_filename]} {
                    puts "[WARN] Skipping output archive: $file_path"
                    continue
                }

                # Calculate the relative path within the zip.
                set arcname [file join $skill_name $rel_path]
                puts $zip "$arcname=$file_path"
                puts "  Added: $arcname"
            }
        }
        
        close $zip
        
        # Check if zip command succeeded
        if {[catch {exec zip -T $skill_filename} error]} {
            puts "[ERROR] Error creating .skill file: $error"
            file delete $skill_filename
            return ""
        }
        
        puts "\n[OK] Successfully packaged skill to: $skill_filename"
        return $skill_filename

    } trap {CHILDSTATUS} {result options} {
        puts "[ERROR] Error creating .skill file: [lindex [dict get $options -errorcode] 2]"
        catch {file delete $skill_filename}
        return ""
    } trap {} {result} {
        puts "[ERROR] Error creating .skill file: $result"
        catch {file delete $skill_filename}
        return ""
    }
}

proc main {} {
    if {[llength $::argv] < 1} {
        puts "Usage: tclsh utils/package_skill.tcl <path/to/skill-folder> [output-directory]"
        puts "\nExample:"
        puts "  tclsh utils/package_skill.tcl skills/public/my-skill"
        puts "  tclsh utils/package_skill.tcl skills/public/my-skill ./dist"
        exit 1
    }

    set skill_path [lindex $::argv 0]
    set output_dir [lindex $::argv 1]

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

if {![info exists ::tcl_interactive]} {
    main
}
