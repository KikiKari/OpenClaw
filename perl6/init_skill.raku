#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "5a6660e7f45177fdf3cd38a09e7706ad20402920095438eb92fac74afe6f8a3f", "source_sha256": "bcd6b802c400a9e89319844c6c3d965855c8b0555e982eb72cd4accb7ee67e3e", "target_language": "perl6"}
# init_skill.py — portiert nach perl6
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/init_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/init_skill.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use v6.d;

# Skill Initializer - Creates a new skill from template

# Usage:
#     init_skill.raku <skill-name> --path <path> [--resources scripts,references,assets] [--examples]
#
# Examples:
#     init_skill.raku my-new-skill --path skills/public
#     init_skill.raku my-new-skill --path skills/public --resources scripts,references
#     init_skill.raku my-api-helper --path skills/private --resources scripts --examples
#     init_skill.raku custom-skill --path /custom/location

my constant MAX_SKILL_NAME_LENGTH = 64;
my constant ALLOWED_RESOURCES = set <scripts references assets>;

my constant SKILL_TEMPLATE = q:to/END_TEMPLATE/;
---
name: {skill_name}
description: [TODO: Complete and informative explanation of what the skill does and when to use it. Include WHEN to use this skill - specific scenarios, file types, or tasks that trigger it.]
---

# {skill_title}

## Overview

[TODO: 1-2 sentences explaining what this skill enables]

## Structuring This Skill

[TODO: Choose the structure that best fits this skill's purpose. Common patterns:

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

Delete this entire "Structuring This Skill" section when done - it's just guidance.]

## [TODO: Replace with the first main section based on chosen structure]

[TODO: Add content here. See examples in existing skills:
- Code samples for technical skills
- Decision trees for complex workflows
- Concrete examples with realistic user requests
- References to scripts/templates/references as needed]

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
END_TEMPLATE

my constant EXAMPLE_SCRIPT = q:to/END_SCRIPT/;
#!/usr/bin/env python3
"""
Example helper script for {skill_name}

This is a placeholder script that can be executed directly.
Replace with actual implementation or delete if not needed.

Example real scripts from other skills:
- pdf/scripts/fill_fillable_fields.py - Fills PDF form fields
- pdf/scripts/convert_pdf_to_images.py - Converts PDF pages to images
"""

def main():
    print("This is an example script for {skill_name}")
    # TODO: Add actual script logic here
    # This could be data processing, file conversion, API calls, etc.

if __name__ == "__main__":
    main()
END_SCRIPT

my constant EXAMPLE_REFERENCE = q:to/END_REFERENCE/;
# Reference Documentation for {skill_title}

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
END_REFERENCE

my constant EXAMPLE_ASSET = q:to/END_ASSET/;
# Example Asset File

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
END_ASSET

sub normalize-skill-name(Str $skill-name --> Str) {
    my $normalized = $skill-name.trim.lc;
    $normalized ~~ s:g/<-[a..z0..9]>+/\-/;
    $normalized .= trim: '-';
    $normalized ~~ s:g/'-'+/\-/;
    return $normalized;
}

sub title-case-skill-name(Str $skill-name --> Str) {
    return $skill-name.split('-').map({ .tc }).join(' ');
}

sub parse-resources(Str $raw-resources --> Array[Str]) {
    return [] unless $raw-resources;
    
    my @resources = $raw-resources.split(',')
        .map({ .trim })
        .grep({ .chars > 0 });
    
    my @invalid = @resources.grep({ $_ ∉ ALLOWED_RESOURCES }).sort;
    if @invalid {
        note "[ERROR] Unknown resource type(s): {@invalid.join(', ')}";
        note "   Allowed: {ALLOWED_RESOURCES.keys.sort.join(', ')}";
        exit 1;
    }
    
    return @resources.unique;
}

sub create-resource-dirs(IO::Path $skill-dir, Str $skill-name, Str $skill-title, @resources, Bool $include-examples) {
    for @resources -> $resource {
        my $resource-dir = $skill-dir.add($resource);
        $resource-dir.mkdir;
        note "[OK] Created $resource/";
        
        if $include-examples {
            given $resource {
                when 'scripts' {
                    my $example-script = $resource-dir.add('example.py');
                    $example-script.spurt(EXAMPLE_SCRIPT.subst('{skill_name}', $skill-name, :g));
                    $example-script.chmod(0o755);
                    note "[OK] Created scripts/example.py";
                }
                when 'references' {
                    my $example-reference = $resource-dir.add('api_reference.md');
                    $example-reference.spurt(EXAMPLE_REFERENCE.subst('{skill_title}', $skill-title, :g));
                    note "[OK] Created references/api_reference.md";
                }
                when 'assets' {
                    my $example-asset = $resource-dir.add('example_asset.txt');
                    $example-asset.spurt(EXAMPLE_ASSET);
                    note "[OK] Created assets/example_asset.txt";
                }
            }
        }
    }
}

sub init-skill(Str $skill-name, Str $path, @resources, Bool $include-examples --> IO::Path) {
    my $skill-dir = $path.IO.resolve.add($skill-name);
    
    if $skill-dir.e {
        note "[ERROR] Skill directory already exists: $skill-dir";
        exit 1;
    }
    
    $skill-dir.mkdir;
    note "[OK] Created skill directory: $skill-dir";
    
    my $skill-title = title-case-skill-name($skill-name);
    my $skill-content = SKILL_TEMPLATE.subst('{skill_name}', $skill-name, :g)
        .subst('{skill_title}', $skill-title, :g);
    
    my $skill-md-path = $skill-dir.add('SKILL.md');
    $skill-md-path.spurt($skill-content);
    note "[OK] Created SKILL.md";
    
    if @resources {
        create-resource-dirs($skill-dir, $skill-name, $skill-title, @resources, $include-examples);
    }
    
    note "\n[OK] Skill '$skill-name' initialized successfully at $skill-dir";
    note "\nNext steps:";
    note "1. Edit SKILL.md to complete the TODO items and update the description";
    if @resources {
        if $include-examples {
            note "2. Customize or delete the example files in scripts/, references/, and assets/";
        } else {
            note "2. Add resources to scripts/, references/, and assets/ as needed";
        }
    } else {
        note "2. Create resource directories only if needed (scripts/, references/, assets/)";
    }
    note "3. Run the validator when ready to check the skill structure";
    
    return $skill-dir;
}

sub MAIN(
    Str $skill-name,
    Str :$path!,
    Str :$resources = '',
    Bool :$examples = False
) {
    my $normalized-name = normalize-skill-name($skill-name);
    
    unless $normalized-name.chars > 0 {
        note "[ERROR] Skill name must include at least one letter or digit.";
        exit 1;
    }
    
    if $normalized-name.chars > MAX_SKILL_NAME_LENGTH {
        note "[ERROR] Skill name '$normalized-name' is too long ({$normalized-name.chars} characters). Maximum is {MAX_SKILL_NAME_LENGTH} characters.";
        exit 1;
    }
    
    if $normalized-name ne $skill-name {
        note "Note: Normalized skill name from '$skill-name' to '$normalized-name'.";
    }
    
    my @resources = parse-resources($resources);
    
    if $examples && @resources.elems == 0 {
        note "[ERROR] --examples requires --resources to be set.";
        exit 1;
    }
    
    note "Initializing skill: $normalized-name";
    note "   Location: $path";
    if @resources {
        note "   Resources: {@resources.join(', ')}";
        note "   Examples: enabled" if $examples;
    } else {
        note "   Resources: none (create as needed)";
    }
    note "";
    
    init-skill($normalized-name, $path, @resources, $examples);
}
