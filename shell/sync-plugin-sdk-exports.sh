#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "f70f8c3ef07f3bf1da3e1b82c47c1ea64a4b4a10256151855005070a59fcddc6", "source_sha256": "44c9196ec2dbaf8ef45323397e44f66d128313ddae44f9dfc8bba7439fe6e844", "target_language": "shell"}
# sync-plugin-sdk-exports.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sync-plugin-sdk-exports.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to get absolute path
get_abs_path() {
    if [[ "${1}" == /* ]]; then
        echo "${1}"
    else
        echo "$(pwd)/${1}"
    fi
}

# Check if --check flag is present
check_only=false
for arg in "$@"; do
    if [[ "${arg}" == "--check" ]]; then
        check_only=true
        break
    fi
done

# Define paths
package_json_path="$(get_abs_path "package.json")"

# Check if package.json exists
if [[ ! -f "${package_json_path}" ]]; then
    echo "Error: package.json not found at ${package_json_path}" >&2
    exit 1
fi

# Read package.json
package_json_content=$(cat "${package_json_path}")

# Extract current exports (if any)
current_exports=""
if echo "${package_json_content}" | jq -e '.exports' >/dev/null 2>&1; then
    current_exports=$(echo "${package_json_content}" | jq '.exports')
else
    current_exports="{}"
fi

# Build synced plugin SDK exports (simulated)
# In the original JS code, this comes from ./lib/plugin-sdk-entries.mjs
# We'll simulate it here with a function that generates the same structure
build_plugin_sdk_package_exports() {
    cat <<EOF
{
  "./plugin-sdk/": {
    "types": "./dist/plugin-sdk/src/index.d.ts",
    "default": "./dist/plugin-sdk/src/index.js"
  },
  "./plugin-sdk/package.json": "./package.json"
}
EOF
}

# Generate the synced exports
synced_plugin_sdk_exports=$(build_plugin_sdk_package_exports)

# Process exports and build nextExports
next_exports=""
inserted_plugin_sdk_exports=false

# Get all keys from current exports
mapfile -t export_keys < <(echo "${current_exports}" | jq -r 'keys[]')

# If there are no keys, create empty object
if [[ ${#export_keys[@]} -eq 0 ]]; then
    next_exports="{}"
else
    # Start building nextExports
    next_exports="{"
    first_entry=true
    
    for key in "${export_keys[@]}"; do
        # Get the value for this key
        value=$(echo "${current_exports}" | jq -c --arg k "${key}" '.[$k]')
        
        # Skip plugin-sdk entries
        if [[ "${key}" == "./plugin-sdk"* ]]; then
            if [[ "${inserted_plugin_sdk_exports}" == false ]]; then
                # Add all plugin-sdk exports
                plugin_entries=$(echo "${synced_plugin_sdk_exports}" | jq -c 'to_entries[]')
                while IFS= read -r entry; do
                    p_key=$(echo "${entry}" | jq -r '.key')
                    p_value=$(echo "${entry}" | jq -c '.value')
                    
                    if [[ "${first_entry}" == false ]]; then
                        next_exports+=","
                    fi
                    next_exports+="\"${p_key}\":${p_value}"
                    first_entry=false
                done <<< "$(echo "${plugin_entries}" | jq -c '.')"
                
                inserted_plugin_sdk_exports=true
            fi
            continue
        fi
        
        # Add regular entry
        if [[ "${first_entry}" == false ]]; then
            next_exports+=","
        fi
        next_exports+="\"${key}\":${value}"
        first_entry=false
        
        # Special case: if key is ".", insert plugin-sdk exports after it
        if [[ "${key}" == "." ]] && [[ "${inserted_plugin_sdk_exports}" == false ]]; then
            plugin_entries=$(echo "${synced_plugin_sdk_exports}" | jq -c 'to_entries[]')
            while IFS= read -r entry; do
                p_key=$(echo "${entry}" | jq -r '.key')
                p_value=$(echo "${entry}" | jq -c '.value')
                
                if [[ "${first_entry}" == false ]]; then
                    next_exports+=","
                fi
                next_exports+="\"${p_key}\":${p_value}"
                first_entry=false
            done <<< "$(echo "${plugin_entries}" | jq -c '.')"
            
            inserted_plugin_sdk_exports=true
        fi
    done
    
    # If we never inserted plugin-sdk exports, add them at the end
    if [[ "${inserted_plugin_sdk_exports}" == false ]]; then
        plugin_entries=$(echo "${synced_plugin_sdk_exports}" | jq -c 'to_entries[]')
        while IFS= read -r entry; do
            p_key=$(echo "${entry}" | jq -r '.key')
            p_value=$(echo "${entry}" | jq -c '.value')
            
            if [[ "${first_entry}" == false ]]; then
                next_exports+=","
            fi
            next_exports+="\"${p_key}\":${p_value}"
            first_entry=false
        done <<< "$(echo "${plugin_entries}" | jq -c '.')"
    fi
    
    next_exports+="}"
fi

# Handle case where nextExports is still empty
if [[ -z "${next_exports}" ]]; then
    next_exports="{}"
fi

# Convert to JSON strings for comparison
current_exports_json=$(echo "${current_exports}" | jq -S .)
next_exports_json=$(echo "${next_exports}" | jq -S .)

# Check mode
if [[ "${check_only}" == true ]]; then
    if [[ "${current_exports_json}" != "${next_exports_json}" ]]; then
        echo "plugin-sdk exports out of sync. Run \`pnpm plugin-sdk:sync-exports\`." >&2
        exit 1
    fi
    echo "plugin-sdk exports synced."
    exit 0
fi

# Update package.json with new exports
updated_package_json=$(echo "${package_json_content}" | jq --argjson newExports "${next_exports}" '.exports = $newExports')

# Write back to package.json with proper formatting
echo "${updated_package_json}" | jq '.' > "${package_json_path}"

exit 0
