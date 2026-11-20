#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "7e3186fee13ffb582e8b8ed98752c435fcdf811ad6b8e145988c9cb5edb8e592", "source_sha256": "5826d57477404d40d10bccd3a144f22f3f46ce4897073fa71d1d3868edfe8719", "target_language": "shell"}
# format-generated-module.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/format-generated-module.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

format_generated_module() {
    local source="$1"
    local repo_root="$2"
    local output_path="$3"
    local error_label="$4"

    # Resolve paths
    local resolved_repo_root
    resolved_repo_root=$(realpath "$repo_root")
    
    local relative_output_path
    if [[ "$output_path" == /* ]]; then
        # If absolute, make it relative to repo_root
        relative_output_path=$(realpath --relative-to="$resolved_repo_root" "$output_path" 2>/dev/null || echo "${output_path#/}")
    else
        relative_output_path="$output_path"
    fi
    
    local resolved_output_path
    resolved_output_path="$resolved_repo_root/$relative_output_path"
    
    # Check for direct formatter (oxfmt)
    local use_direct_formatter=false
    local direct_formatter_path="$resolved_repo_root/node_modules/.bin/oxfmt"
    if [[ "$OSTYPE" != "cygwin" && "$OSTYPE" != "msys" ]] && [[ -x "$direct_formatter_path" ]]; then
        use_direct_formatter=true
    fi

    # Create temporary directory and file
    local temp_dir
    temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/openclaw-generated-format-XXXXXX")
    local temp_output_path="$temp_dir/$(basename "$resolved_output_path")"
    
    # Cleanup function
    cleanup() {
        rm -rf "$temp_dir"
    }
    trap cleanup EXIT

    # Write source to temp file
    printf '%s' "$source" > "$temp_output_path"

    # Run formatter
    local command
    local args=()
    
    if [[ "$use_direct_formatter" == true ]]; then
        command="$direct_formatter_path"
        args=(--write "$temp_output_path")
    else
        command="pnpm"
        args=(exec oxfmt --write "$temp_output_path")
    fi

    local result
    if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
        # Windows requires shell for package manager shims
        result=$("$command" "${args[@]}" 2>&1)
    else
        result=$("$command" "${args[@]}" 2>&1)
    fi
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        local details=""
        if [[ -n "${result:-}" ]]; then
            details="$result"
        else
            details="unknown formatter failure"
        fi
        echo "failed to format generated $error_label: $details" >&2
        return 1
    fi

    # Read formatted content
    cat "$temp_output_path"
}
