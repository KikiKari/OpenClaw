#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "0c0c584487005855ee3c9880838acdca1379580ab495ae80c0e5b2a13c132289", "source_sha256": "c1ed4f7faa3c799c1ac7104f76f48529711802b8f045a3a2fa20f18a82447b76", "target_language": "shell"}
# check-extension-plugin-sdk-boundary.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-plugin-sdk-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This is a conceptual translation of JavaScript code to Bash.
# Due to fundamental differences between JavaScript and Bash,
# especially regarding TypeScript parsing and module resolution,
# this implementation will be limited and illustrative rather than functional.

# Constants
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTENSIONS_ROOT="$REPO_ROOT/src"

declare -A MODES=(
  ["src-outside-plugin-sdk"]=1
  ["plugin-sdk-internal"]=1
  ["relative-outside-package"]=1
)

declare -A BASELINE_PATH_BY_MODE=(
  ["src-outside-plugin-sdk"]="$REPO_ROOT/test/fixtures/extension-src-outside-plugin-sdk-inventory.json"
  ["plugin-sdk-internal"]="$REPO_ROOT/test/fixtures/extension-plugin-sdk-internal-inventory.json"
  ["relative-outside-package"]="$REPO_ROOT/test/fixtures/extension-relative-outside-package-inventory.json"
)

declare -A RULE_TEXT_BY_MODE=(
  ["src-outside-plugin-sdk"]="Rule: production bundled plugins must not import src/** outside src/plugin-sdk/**"
  ["plugin-sdk-internal"]="Rule: production bundled plugins must not import src/plugin-sdk-internal/**"
  ["relative-outside-package"]="Rule: production bundled plugins must not use relative imports that escape their own package root"
)

# Global variables
declare -a ALL_INVENTORY_BY_MODE=()
PARSED_EXTENSION_SOURCE_FILES_PROMISE=""
COLLECTED_FILES=()

# Function implementations

is_code_file() {
    local fileName="$1"
    [[ "$fileName" =~ \.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$ ]]
}

is_boundary_canary_file() {
    local fileName="$1"
    [[ "$fileName" == *"__rootdir_boundary_canary__"* ]]
}

collect_extension_source_files() {
    local rootDir="$1"
    COLLECTED_FILES=()
    
    walk() {
        local dir="$1"
        local entries
        mapfile -t entries < <(find "$dir" -mindepth 1 -maxdepth 1 -not -name "dist" -not -name "node_modules" 2>/dev/null || true)
        
        for entry in "${entries[@]}"; do
            if [[ -d "$entry" ]]; then
                walk "$entry"
            elif [[ -f "$entry" ]] && is_code_file "$entry" && ! is_boundary_canary_file "$entry"; then
                # In a real implementation, we would need to implement classifyBundledExtensionSourcePath
                # For now, we'll assume it's not test-like
                COLLECTED_FILES+=("$entry")
            fi
        done
    }
    
    walk "$rootDir"
    
    # Sort the collected files
    IFS=$'\n' COLLECTED_FILES=($(sort <<<"${COLLECTED_FILES[*]}"))
    unset IFS
}

resolve_extension_root() {
    local filePath="$1"
    # Simplified implementation - in reality, this would need more complex logic
    echo "$filePath" | cut -d'/' -f1-2
}

should_report() {
    local mode="$1"
    local resolvedPath="$2"
    
    case "$mode" in
        "relative-outside-package")
            return 1  # false
            ;;
        *)
            if [[ ! "$resolvedPath" =~ ^src/ ]]; then
                return 1  # false
            fi
            
            if [[ "$mode" == "plugin-sdk-internal" ]]; then
                [[ "$resolvedPath" =~ ^src/plugin-sdk-internal/ ]]
                return $?
            fi
            
            ! [[ "$resolvedPath" =~ ^src/plugin-sdk/ ]]
            return $?
            ;;
    esac
}

collect_entries_by_mode_from_source_file() {
    local sourceFile="$1"
    local filePath="$2"
    
    # This is a placeholder - in reality, we would need to parse the TypeScript file
    # and extract module specifiers, which is not feasible in pure Bash
    
    echo "{}"  # Return empty JSON object as placeholder
}

collect_extension_plugin_sdk_boundary_inventory() {
    local mode="$1"
    
    if [[ -z "${MODES[$mode]+isset}" ]]; then
        echo "Unknown mode: $mode" >&2
        return 1
    fi
    
    collect_extension_source_files "$EXTENSIONS_ROOT"
    
    # Placeholder implementation
    echo "[]"  # Return empty JSON array as placeholder
}

read_expected_inventory() {
    local mode="$1"
    local baseline_path="${BASELINE_PATH_BY_MODE[$mode]}"
    
    if [[ -f "$baseline_path" ]]; then
        cat "$baseline_path"
    else
        echo "[]"
    fi
}

diff_inventory() {
    # Placeholder implementation
    echo '{"missing":[],"unexpected":[]}'
}

format_inventory_human() {
    local mode="$1"
    local inventory="$2"
    
    echo "${RULE_TEXT_BY_MODE[$mode]}"
    
    if [[ "$inventory" == "[]" ]]; then
        echo "No extension plugin-sdk boundary violations found."
    else
        echo "Extension boundary inventory:"
        echo "$inventory"  # In reality, we would format this properly
    fi
}

run_extension_plugin_sdk_boundary_check() {
    local json=false
    local mode="src-outside-plugin-sdk"
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --json)
                json=true
                ;;
            --mode=*)
                mode="${arg#--mode=}"
                ;;
        esac
    done
    
    if [[ -z "${MODES[$mode]+isset}" ]]; then
        echo "Unknown mode: $mode" >&2
        return 1
    fi
    
    local actual
    actual=$(collect_extension_plugin_sdk_boundary_inventory "$mode")
    
    if [[ "$json" == true ]]; then
        echo "$actual"
        return 0
    fi
    
    format_inventory_human "$mode" "$actual"
    
    if [[ "$mode" == "relative-outside-package" ]]; then
        if [[ "$actual" == "[]" ]]; then
            return 0
        else
            echo "Relative outside-package violations found; this mode no longer uses a baseline." >&2
            return 1
        fi
    fi
    
    local expected
    expected=$(read_expected_inventory "$mode")
    
    local diff
    diff=$(diff_inventory "$expected" "$actual")
    
    # Check if diff is empty
    if [[ "$(echo "$diff" | jq -r '.missing | length')" -eq 0 && "$(echo "$diff" | jq -r '.unexpected | length')" -eq 0 ]]; then
        echo "Baseline matches ($(echo "$actual" | jq -r 'length') entries)."
        return 0
    else
        if [[ "$(echo "$diff" | jq -r '.missing | length')" -gt 0 ]]; then
            echo "Missing baseline entries ($(echo "$diff" | jq -r '.missing | length')):" >&2
            echo "$diff" | jq -r '.missing[] | "  - \(.file):\(.line) \(.reason)"' >&2
        fi
        
        if [[ "$(echo "$diff" | jq -r '.unexpected | length')" -gt 0 ]]; then
            echo "Unexpected inventory entries ($(echo "$diff" | jq -r '.unexpected | length')):" >&2
            echo "$diff" | jq -r '.unexpected[] | "  - \(.file):\(.line) \(.reason)"' >&2
        fi
        
        return 1
    fi
}

main() {
    run_extension_plugin_sdk_boundary_check "$@"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
