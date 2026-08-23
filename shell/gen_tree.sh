#!/bin/bash
# gen_tree.py — portiert nach shell
# Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
# (used because the `tree` binary is unavailable in this sandbox).

readonly ROOT="/workspace"
readonly OUT="/workspace/important/openclaw-tree.txt"
readonly MAX_DEPTH=6

# Unicode box-drawing characters
readonly LAST_ITEM="└── "
readonly MIDDLE_ITEM="├── "
readonly INDENT_LAST="    "
readonly INDENT_MIDDLE="│   "

collect() {
    local path="$1"
    local prefix="${2:-}"
    local depth="${3:-1}"
    local lines=()
    
    # Try to get directory listing, return empty array on error
    local entries
    if ! entries=$(find "$path" -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null | sort); then
        echo ""
        return
    fi
    
    # Convert to array
    local entry_array=()
    while IFS= read -r line; do
        entry_array+=("$line")
    done <<< "$entries"
    
    local total=${#entry_array[@]}
    local i=0
    
    for name in "${entry_array[@]}"; do
        local is_last=$((i == total - 1))
        local connector
        if ((is_last)); then
            connector="$LAST_ITEM"
        else
            connector="$MIDDLE_ITEM"
        fi
        
        lines+=("${prefix}${connector}${name}")
        
        local full_path="${path}/${name}"
        
        if ((depth < MAX_DEPTH)) && [[ -d "$full_path" ]] && [[ ! -L "$full_path" ]]; then
            local next_prefix
            if ((is_last)); then
                next_prefix="${prefix}${INDENT_LAST}"
            else
                next_prefix="${prefix}${INDENT_MIDDLE}"
            fi
            local sublines
            sublines=$(collect "$full_path" "$next_prefix" $((depth + 1)))
            if [[ -n "$sublines" ]]; then
                lines+=("$sublines")
            fi
        fi
        
        ((i++))
    done
    
    printf '%s\n' "${lines[@]}"
}

# Generate the tree content
body=$(collect "$ROOT")

# Create header
header="# OpenClaw Workspace Tree
# Generiert: $(date --iso-8601=seconds)
# Befehl: tree -a -L 6 ${ROOT} (emuliert via gen_tree.sh)
# Diese Datei wird automatisch von db-maintainer aktualisiert

"

content="${header}.
${body}
"

# Write to file
echo "$content" > "$OUT"

# Count lines and bytes
line_count=$(echo "$content" | wc -l)
byte_count=$(echo -n "$content" | wc -c)

echo "written ${OUT}: ${line_count} lines, ${byte_count} bytes"
