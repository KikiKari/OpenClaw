#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "ce8e4d0b3a693489b28230d560fb3cf6d6daec5f1aed53a70df18963d7eb773e", "source_sha256": "a01dcf18c06d5aeb081cedf0088a13b316c08622615e4de86febe2deaee2596d", "target_language": "shell"}
# check-no-register-http-handler.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-register-http-handler.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This script checks for deprecated registerHttpHandler calls in TypeScript files
# and suggests using registerHttpRoute instead.

# Define source roots to search
source_roots=("src" "extensions")

# Function to check for deprecated registerHttpHandler calls
check_deprecated_register_http_handler() {
    local file="$1"
    local line_num=0
    local found_calls=()

    # Read the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        
        # Check if line contains registerHttpHandler(
        if [[ "$line" =~ registerHttpHandler\([^\)]*\) ]]; then
            # Make sure it's not a comment or string content
            # Remove comments and check if still matches
            local clean_line="${line%%//*}"
            if [[ "$clean_line" =~ registerHttpHandler\([^\)]*\) ]]; then
                found_calls+=("$file:$line_num")
            fi
        fi
    done < "$file"

    # Return results
    if [ ${#found_calls[@]} -gt 0 ]; then
        printf '%s\n' "${found_calls[@]}"
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    local found_any=0
    
    # Search through each source root
    for root in "${source_roots[@]}"; do
        if [[ -d "$root" ]]; then
            # Find all .ts and .tsx files
            while IFS= read -r -d '' file; do
                if check_deprecated_register_http_handler "$file"; then
                    found_any=1
                fi
            done < <(find "$root" -name "*.ts" -o -name "*.tsx" -print0 2>/dev/null || true)
        fi
    done

    # If any deprecated calls were found, show message and exit with error
    if [[ $found_any -eq 1 ]]; then
        echo "Found deprecated plugin API call registerHttpHandler(...):"
        echo "Use registerHttpRoute({ path, auth, match, handler }) and registerPluginHttpRoute for dynamic webhook paths."
        exit 1
    fi
}

# Run as script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
