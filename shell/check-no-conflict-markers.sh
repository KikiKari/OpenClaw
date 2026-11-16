#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "a7adff7277d789b8323afc7f6bd91fb6c64a51ac3e9367ac9ec1baeec05cfc55", "source_sha256": "c76d61da97f14736857987d3dd8234160c73b0a1b52ade5aac72de04cc61e7e6", "target_language": "shell"}
# check-no-conflict-markers.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-conflict-markers.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to check if a file is binary
is_binary() {
    local file="$1"
    # Use grep to check for null bytes which indicate binary files
    if grep -q $'\0' "$file" 2>/dev/null; then
        return 0  # Is binary
    else
        return 1  # Not binary
    fi
}

# Function to find conflict marker lines in a file
find_conflict_marker_lines() {
    local file="$1"
    local line_number=0
    local matches=()
    
    # Read the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number++))
        if [[ "$line" == "<<<<<<< "* ]] || 
           [[ "$line" == "||||||| "* ]] || 
           [[ "$line" == "=======" ]] || 
           [[ "$line" == ">>>>>>> "* ]]; then
            matches+=("$line_number")
        fi
    done < "$file"
    
    # Return the array of matching line numbers
    echo "${matches[@]}"
}

# Function to list tracked files
list_tracked_files() {
    local cwd="${1:-$(pwd)}"
    (
        cd "$cwd"
        git ls-files -z 2>/dev/null | tr '\0' '\n' | grep -v '^$' | while read -r file; do
            echo "$cwd/$file"
        done
    )
}

# Function to find conflict markers in files
find_conflict_markers_in_files() {
    local violations=()
    local tmp_file
    tmp_file=$(mktemp)
    trap 'rm -f "$tmp_file"' EXIT
    
    list_tracked_files "$(pwd)" > "$tmp_file"
    
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        
        # Skip if file doesn't exist or is not readable
        [[ ! -r "$file_path" ]] && continue
        
        # Skip binary files
        is_binary "$file_path" && continue
        
        # Find conflict markers
        local lines
        lines=$(find_conflict_marker_lines "$file_path")
        
        if [[ -n "$lines" ]]; then
            violations+=("$file_path:${lines// /,}")
        fi
    done < "$tmp_file"
    
    printf '%s\n' "${violations[@]}"
}

# Main function
main() {
    local violations
    violations=$(find_conflict_markers_in_files)
    
    if [[ -z "$violations" ]]; then
        return 0
    fi
    
    echo "Found unresolved merge conflict markers:" >&2
    echo "$violations" | while IFS= read -r violation; do
        [[ -z "$violation" ]] && continue
        echo "- $violation" >&2
    done
    
    exit 1
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
