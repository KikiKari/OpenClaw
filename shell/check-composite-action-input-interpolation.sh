#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "5229aab716a02b499b1c896508afda1a786e17c7f6838727ad891f4378a31efa", "source_sha256": "00c9566941995c9087b6e678da6c1d9714313ba570c7e02eeada841de0f8ddde", "target_language": "shell"}
# check-composite-action-input-interpolation.py — portiert nach shell
# Quelle: python, workspace@local:skills/github-clones/openclaw/scripts/check-composite-action-input-interpolation.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konstanten für reguläre Ausdrücke
INPUT_INTERPOLATION_RE='\$\{\{ *inputs\.'
RUN_LINE_RE='^([[:space:]]*)run:[[:space:]]*(.*)$'
USING_COMPOSITE_RE='^[[:space:]]*using:[[:space:]]*composite[[:space:]]*$'

# Funktion zur Bestimmung der Einrückungstiefe
indentation() {
    local line="$1"
    local stripped
    stripped="${line#"${line%%[![:space:]]*}"}"  # Entferne führende Leerzeichen
    echo $(( ${#line} - ${#stripped} ))
}

# Funktion zum Scannen einer Datei auf Verstöße
scan_file() {
    local path="$1"
    local text
    text=$(cat "$path")

    # Prüfe ob using: composite vorhanden ist
    if ! grep -qE "$USING_COMPOSITE_RE" "$path"; then
        return 0
    fi

    local violations=()
    local lines
    mapfile -t lines < "$path"
    local line_count=${#lines[@]}
    local index=0

    while [ $index -lt $line_count ]; do
        local line="${lines[$index]}"
        if [[ ! $line =~ $RUN_LINE_RE ]]; then
            ((index++))
            continue
        fi

        local run_indent=${#BASH_REMATCH[1]}
        local run_value
        run_value=$(echo "${BASH_REMATCH[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        local line_no=$((index + 1))

        if [ -n "$run_value" ] && [ "${run_value:0:1}" != "|" ] && [ "${run_value:0:1}" != ">" ]; then
            if [[ $run_value =~ $INPUT_INTERPOLATION_RE ]]; then
                violations+=("$line_no:${line}")
            fi
            ((index++))
            continue
        fi

        ((index++))
        while [ $index -lt $line_count ]; do
            local script_line="${lines[$index]}"
            if [ -z "$(echo "$script_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" ]; then
                ((index++))
                continue
            fi
            local script_indent
            script_indent=$(indentation "$script_line")
            if [ $script_indent -le $run_indent ]; then
                break
            fi
            if [[ $script_line =~ $INPUT_INTERPOLATION_RE ]]; then
                violations+=("$((index + 1)):${script_line}")
            fi
            ((index++))
        done
    done

    # Gebe alle Verstöße aus
    for violation in "${violations[@]}"; do
        echo "$path:$violation"
    done
}

# Hauptfunktion
main() {
    local root=".github/actions"
    local files
    mapfile -t files < <(find "$root" -type f \( -name "action.yml" -o -name "action.yaml" \) | sort)
    local all_violations=()

    for file_path in "${files[@]}"; do
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                all_violations+=("$line")
            fi
        done < <(scan_file "$file_path")
    done

    if [ ${#all_violations[@]} -gt 0 ]; then
        echo "Disallowed direct inputs interpolation in composite run blocks:"
        for violation in "${all_violations[@]}"; do
            echo "- $violation"
        done
        echo "Use env: and reference shell variables instead."
        return 1
    fi

    echo "No direct inputs interpolation found in composite run blocks."
    return 0
}

main "$@"
