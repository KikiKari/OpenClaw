#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "e333d0a2db20c4f2a551fce12bf801e1a91564a2959d3cc43e2f5b4be738a01f", "source_sha256": "290dec5062f0c8675bc7304f9c93475a3e9667ed53e93894c5bc66f40e5ae5df", "target_language": "shell"}
# check-no-random-messaging-tmp.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-random-messaging-tmp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This script checks for usage of os.tmpdir() or tmpdir() in messaging-related TypeScript files.
# It's a translation of the JavaScript version to Bash 5 with strict error handling.

# Configuration variables
declare -a messaging_tmpdir_guard_source_roots=(
    "src/channels"
    "src/infra/outbound"
    "src/line"
    "src/media"
    "src/media-understanding"
    "extensions"
)

# Define allowed paths
declare -A allowed_relative_paths
allowed_relative_paths["$(dirname "${BASH_SOURCE[0]}")/lib/bundled-plugin-paths.mjs"]=1

# Function to check if a path is allowed
is_allowed_path() {
    local path="$1"
    [[ -n "${allowed_relative_paths[$path]:-}" ]]
}

# Main function that performs the check
main() {
    local header="Found os.tmpdir()/tmpdir() usage in messaging/channel runtime sources:"
    local footer="Use resolvePreferredOpenClawTmpDir() or plugin-sdk temp helpers instead of host tmp defaults."
    
    # Track violations found
    local violations_found=0
    
    # Iterate through each source root directory
    for source_root in "${messaging_tmpdir_guard_source_roots[@]}"; do
        if [[ ! -d "$source_root" ]]; then
            continue
        fi
        
        # Find all .ts files in the source root
        while IFS= read -r -d '' file; do
            # Skip non-files
            [[ -f "$file" ]] || continue
            
            # Check for tmpdir usage
            if check_file_for_tmpdir_usage "$file"; then
                if [[ $violations_found -eq 0 ]]; then
                    echo "$header"
                    violations_found=1
                fi
                echo "Violation found in: $file"
            fi
        done < <(find "$source_root" -name "*.ts" -type f -print0 2>/dev/null || true)
    done
    
    # If violations were found, print footer and exit with error code
    if [[ $violations_found -ne 0 ]]; then
        echo "$footer"
        exit 1
    fi
}

# Function to check individual file for tmpdir usage
check_file_for_tmpdir_usage() {
    local file="$1"
    
    # Check for direct tmpdir() calls
    if grep -q "tmpdir()" "$file"; then
        return 0
    fi
    
    # Check for os.tmpdir() calls
    if grep -q "os\.tmpdir()" "$file"; then
        return 0
    fi
    
    # Check for destructured tmpdir imports like: import { tmpdir } from 'os'
    if grep -q "import.*{.*tmpdir.*}.*from.*['\"]os['\"]" "$file"; then
        return 0
    fi
    
    # Check for namespace imports like: import * as os from 'os' followed by os.tmpdir()
    if grep -q "import \* as .* from ['\"]os['\"]" "$file" && grep -q "\..*\.tmpdir()" "$file"; then
        return 0
    fi
    
    return 1
}

# Run main function
main "$@"
