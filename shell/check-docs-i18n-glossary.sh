#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "4b447692fc9cd9201d606078db03bad663e400f4046aa6ad12e055c070cdafde", "source_sha256": "e290d06e27f18dbd9a54def6168fe32ba54f3cdb01ec2175510727f412ff6a70", "target_language": "shell"}
# check-docs-i18n-glossary.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-docs-i18n-glossary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

ROOT="$(pwd)"
GLOSSARY_PATH="$ROOT/docs/.i18n/glossary.zh-CN.json"
DOC_FILE_RE='^docs/(?!zh-CN/).+\.(md|mdx)$'
LIST_ITEM_LINK_RE='^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]*\[([^]]+)\]\((/[^)]+)\)'
MAX_TITLE_WORDS=8
MAX_LABEL_WORDS=6
MAX_TERM_LENGTH=80

# Parse command-line arguments
parse_args() {
    local base="" head=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base)
                base="${2:-}"
                shift 2
                ;;
            --head)
                head="${2:-}"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    echo "$base|$head"
}

run_git() {
    git -C "$ROOT" "$@" 2>/dev/null | tr -d '\n'
}

resolve_base() {
    local explicit_base="$1"
    if [[ -n "$explicit_base" ]]; then
        echo "$explicit_base"
        return
    fi

    local env_base="${DOCS_I18N_GLOSSARY_BASE:-}"
    if [[ -n "${env_base// /}" ]]; then
        echo "$env_base"
        return
    fi

    local candidates=("origin/main" "fork/main" "main")
    for candidate in "${candidates[@]}"; do
        if base_candidate=$(run_git merge-base "$candidate" HEAD); then
            echo "$base_candidate"
            return
        fi
    done

    echo ""
}

list_changed_docs() {
    local base="$1"
    local head="$2"
    local args=("diff" "--name-only" "--diff-filter=ACMR" "$base")
    
    if [[ -n "$head" ]]; then
        args+=("$head")
    fi
    args+=("--" "docs")

    run_git "${args[@]}" | grep -E "$DOC_FILE_RE" || true
}

load_glossary_sources() {
    jq -r '.[].source | select(. != null) | gsub("^\\s+|\\s+$"; "") | select(length > 0)' "$GLOSSARY_PATH" 2>/dev/null | sort -u
}

contains_latin() {
    [[ "$1" =~ [A-Za-z] ]]
}

word_count() {
    local text="$1"
    echo "$text" | xargs -n1 | wc -l | tr -d ' '
}

unquote_scalar() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    
    if [[ ("${value:0:1}" == '"' && "${value: -1}" == '"') || 
          ("${value:0:1}" == "'" && "${value: -1}" == "'") ]]; then
        value="${value:1:${#value}-2}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
    fi
    
    echo "$value"
}

is_glossary_candidate() {
    local term="$1"
    local max_words="$2"
    
    if [[ -z "$term" ]]; then
        return 1
    fi
    
    if ! contains_latin "$term"; then
        return 1
    fi
    
    if [[ "$term" == *'`'* ]]; then
        return 1
    fi
    
    if [[ ${#term} -gt $MAX_TERM_LENGTH ]]; then
        return 1
    fi
    
    local words
    words=$(word_count "$term")
    if [[ $words -le $max_words ]]; then
        return 0
    else
        return 1
    fi
}

read_git_file() {
    local base="$1"
    local rel_path="$2"
    run_git show "$base:$rel_path" 2>/dev/null || echo ""
}

extract_terms() {
    local file="$1"
    local text="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    local terms_file="$temp_dir/terms"
    touch "$terms_file"
    
    # Process frontmatter title
    local lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done <<< "$text"
    
    if [[ "${lines[0]:-}" == "---" ]]; then
        for ((index=1; index<${#lines[@]}; index++)); do
            local line="${lines[$index]}"
            if [[ "$line" == "---" ]]; then
                break
            fi
            
            if [[ "$line" =~ ^title:[[:space:]]*(.*)$ ]]; then
                local title_match="${BASH_REMATCH[1]}"
                local title
                title=$(unquote_scalar "$title_match")
                if is_glossary_candidate "$title" "$MAX_TITLE_WORDS"; then
                    echo "title|$file|$((index + 1))|$title" >> "$terms_file"
                fi
                break
            fi
        done
    fi
    
    # Process list item links
    local index=0
    while IFS= read -r line; do
        if [[ "$line" =~ $LIST_ITEM_LINK_RE ]]; then
            local label="${BASH_REMATCH[2]}"
            label="${label#"${label%%[![:space:]]*}"}"
            label="${label%"${label##*[![:space:]]}"}"
            
            if is_glossary_candidate "$label" "$MAX_LABEL_WORDS"; then
                if ! grep -q "^.*|.*|.*|$label$" "$terms_file" 2>/dev/null; then
                    echo "link label|$file|$((index + 1))|$label" >> "$terms_file"
                fi
            fi
        fi
        ((index++))
    done <<< "$text"
    
    cat "$terms_file"
    rm -rf "$temp_dir"
}

main() {
    local parsed_args
    parsed_args=$(parse_args "$@")
    local base head
    IFS='|' read -r base head <<< "$parsed_args"
    
    base=$(resolve_base "$base")
    
    if [[ -z "$base" ]]; then
        echo "docs:check-i18n-glossary: no merge base found; skipping glossary coverage check." >&2
        exit 0
    fi
    
    local changed_docs
    changed_docs=$(list_changed_docs "$base" "$head")
    
    if [[ -z "$changed_docs" ]]; then
        exit 0
    fi
    
    local glossary_temp
    glossary_temp=$(mktemp)
    load_glossary_sources > "$glossary_temp"
    
    local missing_temp
    missing_temp=$(mktemp)
    touch "$missing_temp"
    
    while IFS= read -r rel_path; do
        if [[ -z "$rel_path" ]]; then
            continue
        fi
        
        local abs_path="$ROOT/$rel_path"
        if [[ ! -f "$abs_path" ]]; then
            continue
        fi
        
        local current_terms_temp base_terms_temp
        current_terms_temp=$(mktemp)
        base_terms_temp=$(mktemp)
        
        extract_terms "$rel_path" "$(cat "$abs_path")" > "$current_terms_temp"
        extract_terms "$rel_path" "$(read_git_file "$base" "$rel_path")" > "$base_terms_temp"
        
        while IFS='|' read -r kind file line term; do
            if [[ -z "$kind" ]]; then
                continue
            fi
            
            if grep -q "^.*|.*|.*|$term$" "$base_terms_temp" 2>/dev/null; then
                continue
            fi
            
            if grep -q "^$term$" "$glossary_temp" 2>/dev/null; then
                continue
            fi
            
            echo "$file|$line|$kind|$term" >> "$missing_temp"
        done < "$current_terms_temp"
        
        rm -f "$current_terms_temp" "$base_terms_temp"
    done <<< "$changed_docs"
    
    if [[ ! -s "$missing_temp" ]]; then
        rm -f "$glossary_temp" "$missing_temp"
        exit 0
    fi
    
    echo "docs:check-i18n-glossary: missing zh-CN glossary entries for changed doc labels:" >&2
    while IFS='|' read -r file line kind term; do
        echo "- $file:$line $kind \"$term\"" >&2
    done < "$missing_temp"
    
    echo "" >&2
    echo "Add exact source terms to docs/.i18n/glossary.zh-CN.json before rerunning docs-i18n." >&2
    echo "Checked changed English docs relative to $base." >&2
    
    rm -f "$glossary_temp" "$missing_temp"
    exit 1
}

main "$@"
