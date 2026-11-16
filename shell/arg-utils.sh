#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "a8388cb8ec512a706631c9b5e94aa1fb0bd8490a5c6bdc8b4a192cf1988f41c7", "source_sha256": "a1a384d35f3380f69c57a009348f8a076cc5e3fc09ba866cde4cf59a1c6ac88b", "target_language": "shell"}
# arg-utils.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/arg-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Liest eine Umgebungsvariable als Zahl
read_env_number() {
    local name="$1"
    local raw="${!name:-}"
    raw="$(echo "$raw" | xargs)" # trim
    if [[ -z "$raw" ]]; then
        echo "null"
        return
    fi
    if [[ "$raw" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$raw" != *.*.* ]]; then
        local parsed="$raw"
        if [[ "$parsed" =~ ^-?[0-9]+$ ]]; then
            parsed+=".0"
        fi
        if [[ "$parsed" != "inf" ]] && [[ "$parsed" != "-inf" ]] && [[ "$parsed" != "nan" ]]; then
            echo "$raw"
        else
            echo "null"
        fi
    else
        echo "null"
    fi
}

# Verarbeitet ein String-Flag mit Standardwert
consume_string_flag() {
    local argv_name="$1"
    local index="$2"
    local flag="$3"
    local current_value="$4"

    eval "local arg=\${${argv_name}[$index]:-}"
    if [[ "$arg" != "$flag" ]]; then
        echo "null"
        return
    fi

    local next_index=$((index + 1))
    eval "local value=\${${argv_name}[$next_index]:-$current_value}"
    echo "{\"nextIndex\":$next_index,\"value\":\"$value\"}"
}

# Verarbeitet ein String-Listen-Flag
consume_string_list_flag() {
    local argv_name="$1"
    local index="$2"
    local flag="$3"

    eval "local arg=\${${argv_name}[$index]:-}"
    if [[ "$arg" != "$flag" ]]; then
        echo "null"
        return
    fi

    local next_index=$((index + 1))
    eval "local value=\${${argv_name}[$next_index]:-}"

    if [[ -n "$value" ]]; then
        echo "{\"nextIndex\":$next_index,\"value\":\"$value\"}"
    else
        echo "{\"nextIndex\":$next_index,\"value\":null}"
    fi
}

# Verarbeitet ein Integer-Flag mit Optionen
consume_int_flag() {
    local argv_name="$1"
    local index="$2"
    local flag="$3"
    local current_value="$4"
    local options_min="${5:-NEGATIVE_INFINITY}"

    eval "local arg=\${${argv_name}[$index]:-}"
    if [[ "$arg" != "$flag" ]]; then
        echo "null"
        return
    fi

    local next_index=$((index + 1))
    eval "local raw_value=\${${argv_name}[$next_index]:-}"

    if [[ -n "$raw_value" ]] && [[ "$raw_value" =~ ^-?[0-9]+$ ]]; then
        local parsed="$raw_value"
        local min="$options_min"
        if [[ "$min" == "NEGATIVE_INFINITY" ]] || (( parsed >= min )); then
            echo "{\"nextIndex\":$next_index,\"value\":$parsed}"
            return
        fi
    fi

    echo "{\"nextIndex\":$next_index,\"value\":$current_value}"
}

# Verarbeitet ein Float-Flag mit Optionen
consume_float_flag() {
    local argv_name="$1"
    local index="$2"
    local flag="$3"
    local current_value="$4"
    local options_min="${5:-NEGATIVE_INFINITY}"
    local options_include_min="${6:-true}"

    eval "local arg=\${${argv_name}[$index]:-}"
    if [[ "$arg" != "$flag" ]]; then
        echo "null"
        return
    fi

    local next_index=$((index + 1))
    eval "local raw_value=\${${argv_name}[$next_index]:-}"

    if [[ -n "$raw_value" ]] && [[ "$raw_value" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$raw_value" != *.*.* ]]; then
        local parsed="$raw_value"
        local min="$options_min"
        local include_min="$options_include_min"

        local is_valid=false
        if [[ "$min" == "NEGATIVE_INFINITY" ]]; then
            is_valid=true
        elif [[ "$include_min" == "true" ]] && (( $(echo "$parsed >= $min" | bc -l) )); then
            is_valid=true
        elif [[ "$include_min" != "true" ]] && (( $(echo "$parsed > $min" | bc -l) )); then
            is_valid=true
        fi

        if [[ "$is_valid" == "true" ]]; then
            echo "{\"nextIndex\":$next_index,\"value\":$parsed}"
            return
        fi
    fi

    echo "{\"nextIndex\":$next_index,\"value\":$current_value}"
}

# Erstellt ein String-Flag-Spec
string_flag() {
    local flag="$1"
    local key="$2"
    echo "STRING_FLAG:$flag:$key"
}

# Erstellt ein String-Listen-Flag-Spec
string_list_flag() {
    local flag="$1"
    local key="$2"
    echo "STRING_LIST_FLAG:$flag:$key"
}

# Erstellt ein Integer-Flag-Spec
int_flag() {
    local flag="$1"
    local key="$2"
    local options_min="${3:-NEGATIVE_INFINITY}"
    echo "INT_FLAG:$flag:$key:$options_min"
}

# Erstellt ein Float-Flag-Spec
float_flag() {
    local flag="$1"
    local key="$2"
    local options_min="${3:-NEGATIVE_INFINITY}"
    local options_include_min="${4:-true}"
    echo "FLOAT_FLAG:$flag:$key:$options_min:$options_include_min"
}

# Erstellt ein Boolean-Flag-Spec
boolean_flag() {
    local flag="$1"
    local key="$2"
    local value="${3:-true}"
    echo "BOOLEAN_FLAG:$flag:$key:$value"
}

# Parst die Kommandozeilenargumente
parse_flag_args() {
    local argv_name="$1"
    local args_name="$2"
    local specs_name="$3"
    local options_allow_unknown_options="${4:-false}"
    local options_ignore_double_dash="${5:-false}"

    eval "local argv_count=\${#${argv_name}[@]}"
    eval "local specs_count=\${#${specs_name}[@]}"

    local i=0
    while (( i < argv_count )); do
        eval "local arg=\${${argv_name}[$i]:-}"

        if [[ "$arg" == "--" ]] && [[ "$options_ignore_double_dash" == "true" ]]; then
            ((i++))
            continue
        fi

        local handled=false
        local j=0
        while (( j < specs_count )); do
            eval "local spec=\${${specs_name}[$j]:-}"
            IFS=':' read -r spec_type spec_flag spec_key spec_value spec_include <<< "$spec"

            case "$spec_type" in
                STRING_FLAG)
                    local result
                    result=$(consume_string_flag "$argv_name" "$i" "$spec_flag" "${!spec_key}")
                    if [[ "$result" != "null" ]]; then
                        local next_index value
                        next_index=$(echo "$result" | sed -E 's/.*"nextIndex":([^,}]+).*/\1/')
                        value=$(echo "$result" | sed -E 's/.*"value":"?([^"}]*)"?}.*/\1/')
                        eval "$spec_key=\$value"
                        i=$next_index
                        handled=true
                        break
                    fi
                    ;;
                STRING_LIST_FLAG)
                    local result
                    result=$(consume_string_list_flag "$argv_name" "$i" "$spec_flag")
                    if [[ "$result" != "null" ]]; then
                        local next_index value
                        next_index=$(echo "$result" | sed -E 's/.*"nextIndex":([^,}]+).*/\1/')
                        value=$(echo "$result" | sed -E 's/.*"value":"?([^"}]*)"?}.*/\1/')
                        if [[ "$value" != "null" ]]; then
                            eval "$spec_key+=(\"\$value\")"
                        fi
                        i=$next_index
                        handled=true
                        break
                    fi
                    ;;
                INT_FLAG)
                    local result
                    result=$(consume_int_flag "$argv_name" "$i" "$spec_flag" "${!spec_key}" "$spec_value")
                    if [[ "$result" != "null" ]]; then
                        local next_index value
                        next_index=$(echo "$result" | sed -E 's/.*"nextIndex":([^,}]+).*/\1/')
                        value=$(echo "$result" | sed -E 's/.*"value":([^,}]+).*/\1/')
                        eval "$spec_key=\$value"
                        i=$next_index
                        handled=true
                        break
                    fi
                    ;;
                FLOAT_FLAG)
                    local result
                    result=$(consume_float_flag "$argv_name" "$i" "$spec_flag" "${!spec_key}" "$spec_value" "$spec_include")
                    if [[ "$result" != "null" ]]; then
                        local next_index value
                        next_index=$(echo "$result" | sed -E 's/.*"nextIndex":([^,}]+).*/\1/')
                        value=$(echo "$result" | sed -E 's/.*"value":([^,}]+).*/\1/')
                        eval "$spec_key=\$value"
                        i=$next_index
                        handled=true
                        break
                    fi
                    ;;
                BOOLEAN_FLAG)
                    if [[ "$arg" == "$spec_flag" ]]; then
                        eval "$spec_key=\$spec_value"
                        handled=true
                        break
                    fi
                    ;;
            esac
            ((j++))
        done

        if [[ "$handled" == "false" ]]; then
            if [[ "$arg" == -* ]] && [[ "$options_allow_unknown_options" == "false" ]]; then
                echo "Unknown option: $arg" >&2
                exit 1
            fi
        fi

        ((i++))
    done
}
