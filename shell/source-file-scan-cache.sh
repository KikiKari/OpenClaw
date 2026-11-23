#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "89ea8351e2076bbd2824c5964c57beca544b88f67ccc95ab34c125a1987b73dc", "source_sha256": "44f04cb59342c4d1b0965cd87195e903f79fc80231b0f537dba10313bc29aa00", "target_language": "shell"}
# source-file-scan-cache.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/source-file-scan-cache.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Cache file for storing scanned results
CACHE_FILE="/tmp/source_file_scan_cache.json"

# Function to normalize repository path
normalize_repo_path() {
    local repo_root="$1"
    local file_path="$2"
    
    # Get relative path and convert backslashes to forward slashes
    local rel_path
    rel_path=$(realpath --relative-to="$repo_root" "$file_path" 2>/dev/null) || {
        echo "$file_path"
        return
    }
    
    echo "${rel_path//\\//}"
}

# Function to walk files recursively
walk_files() {
    local root_dir="$1"
    local ignored_dirs="$2"
    local extensions="$3"
    local found_files=()
    
    # Check if directory exists
    if [[ ! -d "$root_dir" ]]; then
        return 0
    fi
    
    # Process all entries in the directory
    while IFS= read -r -d '' entry; do
        local entry_path="$root_dir/$entry"
        
        if [[ -d "$entry_path" ]]; then
            # Skip ignored directories
            if [[ ! "$ignored_dirs" =~ (^| )$entry($| ) ]]; then
                # Recursively process subdirectory
                local subdir_files
                subdir_files=$(walk_files "$entry_path" "$ignored_dirs" "$extensions")
                if [[ -n "$subdir_files" ]]; then
                    printf '%s\n' "$subdir_files"
                fi
            fi
        elif [[ -f "$entry_path" ]]; then
            # Check if extension matches
            local ext="${entry_path##*.}"
            if [[ "$extensions" =~ (^| )$ext($| ) ]]; then
                echo "$entry_path"
            fi
        fi
    done < <(find "$root_dir" -maxdepth 1 -mindepth 1 -printf '%f\0' 2>/dev/null || true)
    
    return 0
}

# Main function to collect source file contents
collect_source_file_contents() {
    local repo_root="$1"
    shift
    local scan_roots=("$@")
    
    # Create cache key based on parameters
    local cache_key
    cache_key=$(echo "$repo_root ${scan_roots[*]}" | md5sum | cut -d' ' -f1)
    
    # Check if result is already cached
    if [[ -f "$CACHE_FILE" ]] && grep -q "\"$cache_key\":" "$CACHE_FILE"; then
        jq -r ".\"$cache_key\"" "$CACHE_FILE"
        return 0
    fi
    
    # Initialize temporary storage for results
    local temp_results=()
    
    # Walk through each scan root
    for root in "${scan_roots[@]}"; do
        local full_path="$repo_root/$root"
        if [[ -d "$full_path" ]]; then
            # Collect matching files
            while IFS= read -r file; do
                if [[ -n "$file" ]]; then
                    temp_results+=("$file")
                fi
            done < <(find "$full_path" -type f)
        fi
    done
    
    # Sort files by normalized path
    local sorted_files=()
    local file_map=()
    
    for file in "${temp_results[@]}"; do
        local norm_path
        norm_path=$(normalize_repo_path "$repo_root" "$file")
        file_map+=("$norm_path|$file")
    done
    
    # Sort by normalized path
    IFS=$'\n' sorted_files=($(sort <<<"${file_map[*]}"))
    unset IFS
    
    # Prepare output structure
    local output="{"
    local first=true
    
    for item in "${sorted_files[@]}"; do
        local norm_path="${item%%|*}"
        local file_path="${item##*|}"
        
        if [[ -f "$file_path" ]]; then
            local content
            content=$(cat "$file_path" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/ $//')
            
            if [[ "$first" == false ]]; then
                output+=","
            else
                first=false
            fi
            
            output+="{\"filePath\":\"$file_path\",\"relativeFile\":\"$norm_path\",\"content\":\"$content\"}"
        fi
    done
    
    output+="}"
    
    # Cache the result
    mkdir -p "$(dirname "$CACHE_FILE")"
    echo "{\"$cache_key\":$output}" > "$CACHE_FILE"
    
    echo "$output"
}
