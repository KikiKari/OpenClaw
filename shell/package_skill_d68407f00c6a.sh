#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "2c487ba75f2081d1ad71563a02b9064698da7b74a49b31723150b17dfafbdc36", "source_sha256": "f290101073ee6a167f46edadda164d2c88affc03c554135fe101a4e422c44c22", "target_language": "shell"}
# package_skill.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Skill Packager - Creates a distributable .skill file of a skill folder
#
# Usage:
#   package_skill.sh <path/to/skill-folder> [output-directory]
#
# Example:
#   package_skill.sh skills/public/my-skill
#   package_skill.sh skills/public/my-skill ./dist

# Check if quick_validate.sh exists and is executable
if ! command -v quick_validate.sh >/dev/null 2>&1; then
    echo "[ERROR] quick_validate.sh not found or not executable"
    exit 1
fi

_is_within() {
    local path="$1"
    local root="$2"
    [[ "$path" == "$root"/* ]] || return 1
}

package_skill() {
    local skill_path="$1"
    local output_dir="$2"
    local skill_name skill_md output_path skill_filename
    
    # Resolve skill path
    skill_path=$(realpath -e "$skill_path")
    
    # Validate skill folder exists
    if [[ ! -e "$skill_path" ]]; then
        echo "[ERROR] Skill folder not found: $skill_path"
        return 1
    fi
    
    if [[ ! -d "$skill_path" ]]; then
        echo "[ERROR] Path is not a directory: $skill_path"
        return 1
    fi
    
    # Validate SKILL.md exists
    skill_md="$skill_path/SKILL.md"
    if [[ ! -f "$skill_md" ]]; then
        echo "[ERROR] SKILL.md not found in $skill_path"
        return 1
    fi
    
    # Run validation before packaging
    echo "Validating skill..."
    if ! quick_validate.sh "$skill_path"; then
        echo "[ERROR] Validation failed"
        echo "   Please fix the validation errors before packaging."
        return 1
    fi
    echo "[OK] Validation passed"
    echo
    
    # Determine output location
    skill_name=$(basename "$skill_path")
    if [[ -n "$output_dir" ]]; then
        output_path=$(realpath -m "$output_dir")
        mkdir -p "$output_path"
    else
        output_path=$(pwd)
    fi
    
    skill_filename="$output_path/${skill_name}.skill"
    
    local EXCLUDED_DIRS=(".git" ".svn" ".hg" "__pycache__" "node_modules")
    
    # Create the .skill file (zip format)
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    
    # Copy files to temp directory, excluding unwanted directories
    cd "$skill_path" || return 1
    
    # Find all files, excluding directories and symlinks
    while IFS= read -r -d '' file_path; do
        # Skip symlinks
        if [[ -L "$file_path" ]]; then
            echo "[WARN] Skipping symlink: $file_path"
            continue
        fi
        
        # Check if file is in excluded directory
        local exclude=0
        for excluded in "${EXCLUDED_DIRS[@]}"; do
            if [[ "$file_path" == *"/$excluded/"* ]] || [[ "$file_path" == "$excluded/"* ]]; then
                exclude=1
                break
            fi
        done
        [[ $exclude -eq 1 ]] && continue
        
        # Security check: ensure file doesn't escape skill root
        local resolved_file
        resolved_file=$(realpath -e "$file_path")
        if ! _is_within "$resolved_file" "$skill_path"; then
            echo "[ERROR] File escapes skill root: $file_path"
            return 1
        fi
        
        # If output lives under skill_path, avoid writing archive into itself
        if [[ "$resolved_file" == "$skill_filename" ]]; then
            echo "[WARN] Skipping output archive: $file_path"
            continue
        fi
        
        # Create directory structure in temp dir
        local dest_path="$temp_dir/$skill_name/$file_path"
        mkdir -p "$(dirname "$dest_path")"
        cp "$file_path" "$dest_path"
        
    done < <(find . -type f -print0)
    
    # Create zip file
    cd "$temp_dir" || return 1
    if zip -rq "$skill_filename" "$skill_name"; then
        echo "[OK] Successfully packaged skill to: $skill_filename"
        echo "$skill_filename"
        return 0
    else
        echo "[ERROR] Error creating .skill file"
        return 1
    fi
}

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: ${0##*/} <path/to/skill-folder> [output-directory]"
        echo
        echo "Example:"
        echo "  ${0##*/} skills/public/my-skill"
        echo "  ${0##*/} skills/public/my-skill ./dist"
        exit 1
    fi
    
    local skill_path="$1"
    local output_dir="${2:-}"
    
    echo "Packaging skill: $skill_path"
    if [[ -n "$output_dir" ]]; then
        echo "   Output directory: $output_dir"
    fi
    echo
    
    if package_skill "$skill_path" "$output_dir"; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
