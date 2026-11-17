#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "c62b38ae6016620819b6b544829e1cd5bc5a945ce82812ce31a73c48b8229a43", "source_sha256": "0a55a33f11db266892b50c887fd8d01783f387e3072c8c5b9ed86ca6788a8c52", "target_language": "shell"}
# gen_tree.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
# (used because the `tree` binary is unavailable in this sandbox).

readonly ROOT="/workspace"
readonly OUT="/workspace/important/openclaw-tree.txt"
readonly MAX_DEPTH=6

# Function to collect directory entries recursively
collect() {
    local path="$1"
    local prefix="${2:-}"
    local depth="${3:-1}"
    local lines=()
    local entries=()
    
    # Read directory entries into array, handling hidden files and sorting
    while IFS= read -r -d '' entry 2>/dev/null; do
        entries+=("${entry##*/}")
    done < <(find "$path" -maxdepth 1 -mindepth 1 -name '.*' -o -name '*' 2>/dev/null | LC_ALL=C sort -z)
    
    local total=${#entries[@]}
    local i=0
    
    for name in "${entries[@]}"; do
        local is_last=$((i == total - 1))
        local connector=""
        
        if ((is_last)); then
            connector="└── "
        else
            connector="├── "
        fi
        
        lines+=("${prefix}${connector}${name}")
        
        local full="${path}/${name}"
        
        if [[ $depth -lt $MAX_DEPTH && -d "$full" && ! -L "$full" ]]; then
            local next_prefix=""
            
            if ((is_last)); then
                next_prefix="${prefix}    "
            else
                next_prefix="${prefix}│   "
            fi
            
            # Recursively collect subdirectory contents
            local sublines=()
            while IFS= read -r line; do
                sublines+=("$line")
            done < <(collect "$full" "$next_prefix" $((depth + 1)))
            
            lines+=("${sublines[@]}")
        fi
        
        ((i++))
    done
    
    printf '%s\n' "${lines[@]}"
}

# Generate the tree content
mapfile -t body < <(collect "$ROOT")

# Create header with timestamp
read -r timestamp < <(date --iso-8601=seconds)
header="# OpenClaw Workspace Tree
# Generiert: ${timestamp}
# Befehl: tree -a -L 6 ${ROOT} (emuliert via gen_tree.sh)
# Diese Datei wird automatisch von db-maintainer aktualisiert

"

# Build final content
content="${header}.
$(printf '%s\n' "${body[@]}")
"

# Write to file
echo "$content" > "$OUT"

# Print summary
echo "written ${OUT}: $((${#body[@]} + 1)) lines, ${#content} bytes"
