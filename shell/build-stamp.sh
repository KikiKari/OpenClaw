#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "d115c59a397dae5915105976fddaf2dee48b64604b6e4602cab392991b77669e", "source_sha256": "8537e4253cc6ca148bc7b8cee5f458bfd0843576263cad8e98ca2c46fa47f2f1", "target_language": "shell"}
# build-stamp.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-stamp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Resolve the current git HEAD commit hash
# Returns the commit hash or an empty string if not in a git repository
resolve_git_head() {
    local cwd="${1:-$(pwd)}"
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git rev-parse HEAD 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Write build timestamp and git HEAD to .buildstamp file
write_build_stamp() {
    local cwd="${1:-$(pwd)}"
    local dist_root="${cwd}/dist"
    local build_stamp_path="${dist_root}/.buildstamp"
    
    # Create dist directory if it doesn't exist
    mkdir -p "${dist_root}"
    
    # Get current timestamp (milliseconds since epoch)
    local built_at
    if command -v date >/dev/null 2>&1; then
        # Try to get milliseconds if supported
        if date -u +%s%3N >/dev/null 2>&1; then
            built_at=$(date -u +%s%3N)
        else
            # Fallback to seconds precision
            built_at=$(($(date -u +%s) * 1000))
        fi
    else
        # Very basic fallback using shell arithmetic (seconds only)
        built_at=$(( $(printf '%(%s)T' -1) * 1000 ))
    fi
    
    # Get git HEAD
    local head
    head=$(resolve_git_head "${cwd}")
    
    # Write JSON to .buildstamp file
    {
        echo "{"
        echo "  \"builtAt\": ${built_at},"
        if [ -n "${head}" ]; then
            echo "  \"head\": \"${head}\""
        else
            echo "  \"head\": null"
        fi
        echo "}"
    } > "${build_stamp_path}"
    
    echo "${build_stamp_path}"
}

# Main execution when script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    write_build_stamp "$(pwd)"
fi
