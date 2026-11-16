#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "c203ac5333234e6aed1c65a0549442d7d96b5c7047fea46b0aedafdf4b83424e", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "shell"}
# bundled-plugin-source-utils.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to read file content if it exists, otherwise return null
read_if_exists() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        cat "$file_path"
    else
        echo "null"
    fi
}

# Function to collect bundled plugin sources
collect_bundled_plugin_sources() {
    local repo_root="${1:-$(pwd)}"
    local require_package_json="${2:-false}"
    
    local extensions_root="$repo_root/extensions"
    
    # Check if extensions directory exists
    if [[ ! -d "$extensions_root" ]]; then
        return 0
    fi
    
    # Create temporary directory for storing plugin data
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    
    # Array to store plugin directories
    local plugin_dirs=()
    
    # Read directories in extensions folder
    while IFS= read -r dir; do
        if [[ -d "$extensions_root/$dir" ]]; then
            plugin_dirs+=("$dir")
        fi
    done < <(find "$extensions_root" -maxdepth 1 -type d -not -path "$extensions_root" -exec basename {} \; | sort)
    
    # Process each plugin directory
    for dir_name in "${plugin_dirs[@]}"; do
        local plugin_dir="$extensions_root/$dir_name"
        local manifest_path="$plugin_dir/openclaw.plugin.json"
        local package_json_path="$plugin_dir/package.json"
        
        # Check if manifest exists
        if [[ ! -f "$manifest_path" ]]; then
            continue
        fi
        
        # Check if package.json is required and exists
        if [[ "$require_package_json" == "true" ]] && [[ ! -f "$package_json_path" ]]; then
            continue
        fi
        
        # Store plugin information
        echo "dirName:$dir_name" >> "$temp_dir/plugins.txt"
        echo "pluginDir:$plugin_dir" >> "$temp_dir/plugins.txt"
        echo "manifestPath:$manifest_path" >> "$temp_dir/plugins.txt"
        
        # Add manifest content
        echo "manifest:" >> "$temp_dir/plugins.txt"
        cat "$manifest_path" >> "$temp_dir/plugins.txt"
        echo "" >> "$temp_dir/plugins.txt"
        
        # Add package.json info if it exists
        if [[ -f "$package_json_path" ]]; then
            echo "packageJsonPath:$package_json_path" >> "$temp_dir/plugins.txt"
            echo "packageJson:" >> "$temp_dir/plugins.txt"
            cat "$package_json_path" >> "$temp_dir/plugins.txt"
            echo "" >> "$temp_dir/plugins.txt"
        fi
        echo "---" >> "$temp_dir/plugins.txt"
    done
    
    # Output collected plugin data
    if [[ -f "$temp_dir/plugins.txt" ]]; then
        cat "$temp_dir/plugins.txt"
    fi
}
