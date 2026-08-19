#!/bin/bash
# package_skill.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/package_skill.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Skill Packager - Creates a distributable .skill file of a skill folder

# Usage:
#     bash utils/package_skill.sh <path/to/skill-folder> [output-directory]

# Example:
#     bash utils/package_skill.sh skills/public/my-skill
#     bash utils/package_skill.sh skills/public/my-skill ./dist

# Function to check if a path is within another path
_is_within() {
    local path="$1"
    local root="$2"
    
    case "$(realpath "$path")/" in
        "$(realpath "$root")/"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

package_skill() {
    local skill_path="$1"
    local output_dir="${2:-}"

    # Validate skill folder exists
    if [[ ! -e "$skill_path" ]]; then
        echo "[ERROR] Skill folder not found: $skill_path" >&2
        return 1
    fi

    if [[ ! -d "$skill_path" ]]; then
        echo "[ERROR] Path is not a directory: $skill_path" >&2
        return 1
    fi

    # Resolve to absolute path
    skill_path=$(realpath "$skill_path")

    # Validate SKILL.md exists
    if [[ ! -f "$skill_path/SKILL.md" ]]; then
        echo "[ERROR] SKILL.md not found in $skill_path" >&2
        return 1
    fi

    # Run validation before packaging
    echo "Validating skill..."
    if ! python3 -c "
import sys
sys.path.append('$(dirname "${BASH_SOURCE[0]}")')
from quick_validate import validate_skill
valid, message = validate_skill('$skill_path')
if valid:
    print(f'[OK] {message}')
else:
    print(f'[ERROR] Validation failed: {message}')
    print('   Please fix the validation errors before packaging.')
sys.exit(0 if valid else 1)
"; then
        return 1
    fi
    echo

    # Determine output location
    local skill_name=$(basename "$skill_path")
    
    if [[ -n "$output_dir" ]]; then
        mkdir -p "$output_dir"
        output_dir=$(realpath "$output_dir")
    else
        output_dir=$(pwd)
    fi

    local skill_filename="$output_dir/${skill_name}.skill"

    # Create temporary directory for building the archive
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT

    # Copy files to temp directory excluding unwanted directories and handling symlinks
    local excluded_dirs=("*.git*" "*.svn*" "*.hg*" "*__pycache__*" "*node_modules*")
    
    # Find all files and process them
    while IFS= read -r -d '' file; do
        # Skip if it's a symlink
        if [[ -L "$file" ]]; then
            echo "[WARN] Skipping symlink: $file"
            continue
        fi
        
        # Check if file is in excluded directories
        local exclude_file=false
        for pattern in "${excluded_dirs[@]}"; do
            if [[ "$file" == $pattern ]] || [[ "$file/" == $pattern/* ]]; then
                exclude_file=true
                break
            fi
        done
        
        if [[ "$exclude_file" == true ]]; then
            continue
        fi
        
        # Security check: ensure file doesn't escape skill root
        if ! _is_within "$file" "$skill_path"; then
            echo "[ERROR] File escapes skill root: $file" >&2
            return 1
        fi
        
        # Skip output archive if it would be written into itself
        if [[ "$(realpath "$file" 2>/dev/null || echo "$file")" == "$(realpath "$skill_filename" 2>/dev/null || echo "$skill_filename")" ]]; then
            echo "[WARN] Skipping output archive: $file"
            continue
        fi
        
        # Calculate relative path and copy to temp structure
        local rel_path
        rel_path=$(realpath --relative-to="$skill_path" "$file")
        
        local dest_dir="$temp_dir/$skill_name/$rel_path"
        mkdir -p "$(dirname "$dest_dir")"
        cp "$file" "$dest_dir"
        echo "  Added: $skill_name/$rel_path"
    done < <(find "$skill_path" -type f -print0)

    # Create the .skill file (zip format)
    (cd "$temp_dir" && zip -rq "$skill_filename" "./$skill_name")
    
    echo
    echo "[OK] Successfully packaged skill to: $skill_filename"
    echo "$skill_filename"
    return 0
}

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: bash utils/package_skill.sh <path/to/skill-folder> [output-directory]"
        echo
        echo "Example:"
        echo "  bash utils/package_skill.sh skills/public/my-skill"
        echo "  bash utils/package_skill.sh skills/public/my-skill ./dist"
        exit 1
    fi

    local skill_path="$1"
    local output_dir=""
    if [[ $# -gt 1 ]]; then
        output_dir="$2"
    fi

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
