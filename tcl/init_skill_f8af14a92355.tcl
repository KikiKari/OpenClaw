#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "d2aa3b65c95265e4b3c644a4f5f4f130a92f2f582476d294c895654f2227b327", "source_sha256": "bcd6b802c400a9e89319844c6c3d965855c8b0555e982eb72cd4accb7ee67e3e", "target_language": "tcl"}
# init_skill.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/init_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/init_skill.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Skill Initializer - Creates a new skill from template
#
# Usage:
#     init_skill.py <skill-name> --path <path> [--resources scripts,references,assets] [--examples]
#
# Examples:
#     init_skill.py my-new-skill --path skills/public
#     init_skill.py my-new-skill --path skills/public --resources scripts,references
#     init_skill.py my-api-helper --path skills/private --resources scripts --examples
#     init_skill.py custom-skill --path /custom/location

package require fileutil
package require cmdline
package require struct::list

set MAX_SKILL_NAME_LENGTH 64
array set ALLOWED_RESOURCES {
    scripts 1
    references 1
    assets 1
}

set SKILL_TEMPLATE {---
name: %s
description: \[TODO: Complete and informative explanation of what the skill does and when to use it. Include WHEN to use this skill - specific scenarios, file types, or tasks that trigger it.\]
---

# %s

## Overview

\[TODO: 1-2 sentences explaining what this skill enables\]

## Structuring This Skill

\[TODO: Choose the structure that best fits this skill's purpose. Common patterns:

**1. Workflow-Based** (best for sequential processes)
- Works well when there are clear step-by-step procedures
- Example: DOCX skill with "Workflow Decision Tree" -> "Reading" -> "Creating" -> "Editing"
- Structure: ## Overview -> ## Workflow Decision Tree -> ## Step 1 -> ## Step 2...

**2. Task-Based** (best for tool collections)
- Works well when the skill offers different operations/capabilities
- Example: PDF skill with "Quick Start" -> "Merge PDFs" -> "Split PDFs" -> "Extract Text"
- Structure: ## Overview -> ## Quick Start -> ## Task Category 1 -> ## Task Category 2...

**3. Reference/Guidelines** (best for standards or specifications)
- Works well for brand guidelines, coding standards, or requirements
- Example: Brand styling with "Brand Guidelines" -> "Colors" -> "Typography" -> "Features"
- Structure: ## Overview -> ## Guidelines -> ## Specifications -> ## Usage...

**4. Capabilities-Based** (best for integrated systems)
- Works well when the skill provides multiple interrelated features
- Example: Product Management with "Core Capabilities" -> numbered capability list
- Structure: ## Overview -> ## Core Capabilities -> ### 1. Feature -> ### 2. Feature...

Patterns can be mixed and matched as needed. Most skills combine patterns (e.g., start with task-based, add workflow for complex operations).

Delete this entire "Structuring This Skill" section when done - it's just guidance.\]

## \[TODO: Replace with the first main section based on chosen structure\]

\[TODO: Add content here. See examples in existing skills:
- Code samples for technical skills
- Decision trees for complex workflows
- Concrete examples with realistic user requests
- References to scripts/templates/references as needed\]

## Resources (optional)

Create only the resource directories this skill actually needs. Delete this section if no resources are required.

### scripts/
Executable code (Python/Bash/etc.) that can be run directly to perform specific operations.

**Examples from other skills:**
- PDF skill: `fill_fillable_fields.py`, `extract_form_field_info.py` - utilities for PDF manipulation
- DOCX skill: `document.py`, `utilities.py` - Python modules for document processing

**Appropriate for:** Python scripts, shell scripts, or any executable code that performs automation, data processing, or specific operations.

**Note:** Scripts may be executed without loading into context, but can still be read by Codex for patching or environment adjustments.

### references/
Documentation and reference material intended to be loaded into context to inform Codex's process and thinking.

**Examples from other skills:**
- Product management: `communication.md`, `context_building.md` - detailed workflow guides
- BigQuery: API reference documentation and query examples
- Finance: Schema documentation, company policies

**Appropriate for:** In-depth documentation, API references, database schemas, comprehensive guides, or any detailed information that Codex should reference while working.

### assets/
Files not intended to be loaded into context, but rather used within the output Codex produces.

**Examples from other skills:**
- Brand styling: PowerPoint template files (.pptx), logo files
- Frontend builder: HTML/React boilerplate project directories
- Typography: Font files (.ttf, .woff2)

**Appropriate for:** Templates, boilerplate code, document templates, images, icons, fonts, or any files meant to be copied or used in the final output.

---

**Not every skill requires all three types of resources.**
}

set EXAMPLE_SCRIPT {#!/usr/bin/env python3
"""
Example helper script for %s

This is a placeholder script that can be executed directly.
Replace with actual implementation or delete if not needed.

Example real scripts from other skills:
- pdf/scripts/fill_fillable_fields.py - Fills PDF form fields
- pdf/scripts/convert_pdf_to_images.py - Converts PDF pages to images
"""

def main():
    print("This is an example script for %s")
    # TODO: Add actual script logic here
    # This could be data processing, file conversion, API calls, etc.

if __name__ == "__main__":
    main()
}

set EXAMPLE_REFERENCE {# Reference Documentation for %s

This is a placeholder for detailed reference documentation.
Replace with actual reference content or delete if not needed.

Example real reference docs from other skills:
- product-management/references/communication.md - Comprehensive guide for status updates
- product-management/references/context_building.md - Deep-dive on gathering context
- bigquery/references/ - API references and query examples

## When Reference Docs Are Useful

Reference docs are ideal for:
- Comprehensive API documentation
- Detailed workflow guides
- Complex multi-step processes
- Information too lengthy for main SKILL.md
- Content that's only needed for specific use cases

## Structure Suggestions

### API Reference Example
- Overview
- Authentication
- Endpoints with examples
- Error codes
- Rate limits

### Workflow Guide Example
- Prerequisites
- Step-by-step instructions
- Common patterns
- Troubleshooting
- Best practices
}

set EXAMPLE_ASSET {# Example Asset File

This placeholder represents where asset files would be stored.
Replace with actual asset files (templates, images, fonts, etc.) or delete if not needed.

Asset files are NOT intended to be loaded into context, but rather used within
the output Codex produces.

Example asset files from other skills:
- Brand guidelines: logo.png, slides_template.pptx
- Frontend builder: hello-world/ directory with HTML/React boilerplate
- Typography: custom-font.ttf, font-family.woff2
- Data: sample_data.csv, test_dataset.json

## Common Asset Types

- Templates: .pptx, .docx, boilerplate directories
- Images: .png, .jpg, .svg, .gif
- Fonts: .ttf, .otf, .woff, .woff2
- Boilerplate code: Project directories, starter files
- Icons: .ico, .svg
- Data files: .csv, .json, .xml, .yaml

Note: This is a text placeholder. Actual assets can be any file type.
}


proc normalize_skill_name {skill_name} {
    # Normalize a skill name to lowercase hyphen-case.
    set normalized [string trim [string tolower $skill_name]]
    regsub -all {[^a-z0-9]+} $normalized {-} normalized
    set normalized [string trim $normalized {-}]
    regsub -all {\-{2,}} $normalized {-} normalized
    return $normalized
}


proc title_case_skill_name {skill_name} {
    # Convert hyphenated skill name to Title Case for display.
    set words {}
    foreach word [split $skill_name -] {
        lappend words [string totitle $word]
    }
    return [join $words " "]
}


proc parse_resources {raw_resources} {
    global ALLOWED_RESOURCES
    
    if {$raw_resources eq ""} {
        return {}
    }
    
    set resources {}
    foreach item [split $raw_resources ","] {
        set item [string trim $item]
        if {$item ne ""} {
            lappend resources $item
        }
    }
    
    set invalid {}
    foreach resource $resources {
        if {![info exists ALLOWED_RESOURCES($resource)]} {
            lappend invalid $resource
        }
    }
    
    if {[llength $invalid] > 0} {
        set invalid_sorted [lsort -unique $invalid]
        set allowed_sorted [lsort [array names ALLOWED_RESOURCES]]
        puts stderr "\[ERROR\] Unknown resource type(s): [join $invalid_sorted ", "]"
        puts stderr "   Allowed: [join $allowed_sorted ", "]"
        exit 1
    }
    
    # Remove duplicates while preserving order
    set deduped {}
    set seen {}
    foreach resource $resources {
        if {$resource ni $seen} {
            lappend deduped $resource
            lappend seen $resource
        }
    }
    
    return $deduped
}


proc create_resource_dirs {skill_dir skill_name skill_title resources include_examples} {
    global EXAMPLE_SCRIPT EXAMPLE_REFERENCE EXAMPLE_ASSET
    
    foreach resource $resources {
        set resource_dir [file join $skill_dir $resource]
        file mkdir $resource_dir
        
        if {$resource eq "scripts"} {
            if {$include_examples} {
                set example_script [file join $resource_dir "example.py"]
                set formatted_script [format $EXAMPLE_SCRIPT $skill_name $skill_name]
                set fh [open $example_script w]
                puts -nonewline $fh $formatted_script
                close $fh
                file attributes $example_script -permissions 0755
                puts "\[OK\] Created scripts/example.py"
            } else {
                puts "\[OK\] Created scripts/"
            }
        } elseif {$resource eq "references"} {
            if {$include_examples} {
                set example_reference [file join $resource_dir "api_reference.md"]
                set formatted_reference [format $EXAMPLE_REFERENCE $skill_title]
                set fh [open $example_reference w]
                puts -nonewline $fh $formatted_reference
                close $fh
                puts "\[OK\] Created references/api_reference.md"
            } else {
                puts "\[OK\] Created references/"
            }
        } elseif {$resource eq "assets"} {
            if {$include_examples} {
                set example_asset [file join $resource_dir "example_asset.txt"]
                set fh [open $example_asset w]
                puts -nonewline $fh $EXAMPLE_ASSET
                close $fh
                puts "\[OK\] Created assets/example_asset.txt"
            } else {
                puts "\[OK\] Created assets/"
            }
        }
    }
}


proc init_skill {skill_name path resources include_examples} {
    # Initialize a new skill directory with template SKILL.md.
    #
    # Args:
    #     skill_name: Name of the skill
    #     path: Path where the skill directory should be created
    #     resources: Resource directories to create
    #     include_examples: Whether to create example files in resource directories
    #
    # Returns:
    #     Path to created skill directory, or empty string if error

    # Determine skill directory path
    set skill_dir [file normalize [file join $path $skill_name]]

    # Check if directory already exists
    if {[file exists $skill_dir]} {
        puts stderr "\[ERROR\] Skill directory already exists: $skill_dir"
        return ""
    }

    # Create skill directory
    if {[catch {file mkdir $skill_dir} error]} {
        puts stderr "\[ERROR\] Error creating directory: $error"
        return ""
    }
    puts "\[OK\] Created skill directory: $skill_dir"

    # Create SKILL.md from template
    set skill_title [title_case_skill_name $skill_name]
    set skill_content [format $::SKILL_TEMPLATE $skill_name $skill_title]

    set skill_md_path [file join $skill_dir "SKILL.md"]
    if {[catch {
        set fh [open $skill_md_path w]
        puts -nonewline $fh $skill_content
        close $fh
        puts "\[OK\] Created SKILL.md"
    } error]} {
        puts stderr "\[ERROR\] Error creating SKILL.md: $error"
        return ""
    }

    # Create resource directories if requested
    if {[llength $resources] > 0} {
        if {[catch {
            create_resource_dirs $skill_dir $skill_name $skill_title $resources $include_examples
        } error]} {
            puts stderr "\[ERROR\] Error creating resource directories: $error"
            return ""
        }
    }

    # Print next steps
    puts "\n\[OK\] Skill '$skill_name' initialized successfully at $skill_dir"
    puts "\nNext steps:"
    puts "1. Edit SKILL.md to complete the TODO items and update the description"
    if {[llength $resources] > 0} {
        if {$include_examples} {
            puts "2. Customize or delete the example files in scripts/, references/, and assets/"
        } else {
            puts "2. Add resources to scripts/, references/, and assets/ as needed"
        }
    } else {
        puts "2. Create resource directories only if needed (scripts/, references/, assets/)"
    }
    puts "3. Run the validator when ready to check the skill structure"

    return $skill_dir
}


proc main {} {
    global argc argv MAX_SKILL_NAME_LENGTH
    
    set options {
        {skill_name.arg "" "Skill name (normalized to hyphen-case)"}
        {path.arg "" "Output directory for the skill"}
        {resources.arg "" "Comma-separated list: scripts,references,assets"}
        {examples "Create example files inside the selected resource directories"}
    }
    
    if {$argc < 1} {
        puts stderr "Error: Missing skill name argument"
        puts stderr "Usage: [info script] <skill-name> --path <path> \[--resources scripts,references,assets\] \[--examples\]"
        exit 1
    }
    
    set skill_name [lindex $argv 0]
    set remaining_args [lrange $argv 1 end]
    
    array set params [::cmdline::getoptions remaining_args $options]
    set params(skill_name) $skill_name
    
    # Validate required parameters
    if {$params(path) eq ""} {
        puts stderr "Error: --path is required"
        exit 1
    }
    
    set raw_skill_name $params(skill_name)
    set skill_name [normalize_skill_name $raw_skill_name]
    if {$skill_name eq ""} {
        puts stderr "\[ERROR\] Skill name must include at least one letter or digit."
        exit 1
    }
    if {[string length $skill_name] > $MAX_SKILL_NAME_LENGTH} {
        puts stderr "\[ERROR\] Skill name '$skill_name' is too long ([string length $skill_name] characters). Maximum is $MAX_SKILL_NAME_LENGTH characters."
        exit 1
    }
    if {$skill_name ne $raw_skill_name} {
        puts "Note: Normalized skill name from '$raw_skill_name' to '$skill_name'."
    }
    
    set resources [parse_resources $params(resources)]
    if {$params(examples) && [llength $resources] == 0} {
        puts stderr "\[ERROR\] --examples requires --resources to be set."
        exit 1
    }
    
    set path $params(path)
    
    puts "Initializing skill: $skill_name"
    puts "   Location: $path"
    if {[llength $resources] > 0} {
        puts "   Resources: [join $resources ", "]"
        if {$params(examples)} {
            puts "   Examples: enabled"
        }
    } else {
        puts "   Resources: none (create as needed)"
    }
    puts ""
    
    set result [init_skill $skill_name $path $resources $params(examples)]
    
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
