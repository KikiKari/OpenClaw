#!/bin/bash
# model_usage.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
# auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Summarize CodexBar local cost usage by model.
#
# Defaults to current model (most recent daily entry), or list all models.

PROVIDER="codex"
MODE="current"
MODEL=""
INPUT=""
DAYS=""
FORMAT="text"
PRETTY=false

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Summarize CodexBar model usage from local cost logs.

Options:
  --provider PROVIDER     Provider to use (codex or claude) [default: codex]
  --mode MODE             Mode to run in (current or all) [default: current]
  --model MODEL           Explicit model name to report instead of auto-current
  --input INPUT           Path to codexbar cost JSON (or '-' for stdin)
  --days DAYS             Limit to last N days (based on daily rows)
  --format FORMAT         Output format (text or json) [default: text]
  --pretty                Pretty-print JSON output
  -h, --help              Show this help message and exit
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider)
            PROVIDER="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --input)
            INPUT="$2"
            shift 2
            ;;
        --days)
            DAYS="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --pretty)
            PRETTY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Print error message to stderr
eprint() {
    echo "$*" >&2
}

# Run codexbar cost command and get JSON output
run_codexbar_cost() {
    local provider="$1"
    local cmd=(codexbar cost --format json --provider "$provider")
    
    if ! command -v codexbar >/dev/null 2>&1; then
        eprint "codexbar not found on PATH. Install CodexBar CLI first."
        return 1
    fi
    
    if ! output=$( "${cmd[@]}" ); then
        eprint "codexbar cost failed."
        return 1
    fi
    
    echo "$output"
}

# Load payload from input path or run codexbar cost
load_payload() {
    local input_path="$1"
    local provider="$2"
    local data
    
    if [[ -n "$input_path" ]]; then
        if [[ "$input_path" == "-" ]]; then
            data=$(cat)
        else
            if [[ ! -f "$input_path" ]]; then
                eprint "Input file not found: $input_path"
                return 1
            fi
            data=$(cat "$input_path")
        fi
    else
        data=$(run_codexbar_cost "$provider") || return $?
    fi
    
    # Validate that it's valid JSON
    if ! echo "$data" | jq empty >/dev/null 2>&1; then
        eprint "Invalid JSON input"
        return 1
    fi
    
    echo "$data"
}

# Parse daily entries from payload
parse_daily_entries() {
    local payload="$1"
    echo "$payload" | jq -c '.daily // [] | map(select(type == "object"))'
}

# Filter entries by number of days
filter_by_days() {
    local entries="$1"
    local days="$2"
    
    if [[ -z "$days" ]]; then
        echo "$entries"
        return
    fi
    
    local cutoff
    cutoff=$(date -d "@$(($(date +%s) - (days - 1) * 86400))" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null || echo "")
    
    if [[ -z "$cutoff" ]]; then
        # Fallback: calculate manually
        cutoff=$(date -I)
        for ((i=1; i<days; i++)); do
            cutoff=$(date -d "$cutoff -1 day" +%Y-%m-%d 2>/dev/null || date -v-1d -j -f %Y-%m-%d "$cutoff" +%Y-%m-%d 2>/dev/null || echo "$cutoff")
        done
    fi
    
    echo "$entries" | jq -c --arg cutoff "$cutoff" '
        map(select(.date and (.date >= $cutoff)))
    '
}

# Aggregate costs across all entries
aggregate_costs() {
    local entries="$1"
    echo "$entries" | jq -c '
        {} |
        reduce inputs[] as $entry (.; 
            ($entry.modelBreakdowns // []) |
            map(select(.modelName and .cost)) |
            map({key: .modelName, value: .cost}) |
            reduce .[] as $item (.;
                .[$item.key] += $item.value
            )
        )
    ' < <(echo "$entries" | jq -c '.[]')
}

# Pick the current model based on most recent high-cost usage
pick_current_model() {
    local entries="$1"
    local sorted_entries
    sorted_entries=$(echo "$entries" | jq -c 'sort_by(.date)')
    
    # Process in reverse order (newest first)
    local entry
    while IFS= read -r entry; do
        local breakdowns
        breakdowns=$(echo "$entry" | jq -c '.modelBreakdowns // []')
        
        if [[ $(echo "$breakdowns" | jq length) -gt 0 ]]; then
            local scored
            scored=$(echo "$breakdowns" | jq -c 'map(select(.modelName and .cost)) | sort_by(-.cost)')
            
            if [[ $(echo "$scored" | jq length) -gt 0 ]]; then
                local model
                model=$(echo "$scored" | jq -r '.[0].modelName' | head -n1)
                local date_val
                date_val=$(echo "$entry" | jq -r '.date // ""')
                echo "$model,$date_val"
                return 0
            fi
        fi
        
        local models_used
        models_used=$(echo "$entry" | jq -c '.modelsUsed // []')
        if [[ $(echo "$models_used" | jq length) -gt 0 ]]; then
            local last_model
            last_model=$(echo "$models_used" | jq -r '.[-1]' | head -n1)
            if [[ -n "$last_model" && "$last_model" != "null" ]]; then
                local date_val
                date_val=$(echo "$entry" | jq -r '.date // ""')
                echo "$last_model,$date_val"
                return 0
            fi
        fi
    done < <(echo "$sorted_entries" | jq -c '.[]' | tail -r)
    
    echo ","
    return 0
}

# Format USD value
usd() {
    local value="$1"
    if [[ "$value" == "null" || -z "$value" ]]; then
        echo "—"
    else
        printf '$%.2f' "$value"
    fi
}

# Get latest day cost for a specific model
latest_day_cost() {
    local entries="$1"
    local model="$2"
    local sorted_entries
    sorted_entries=$(echo "$entries" | jq -c 'sort_by(.date)')
    
    # Process in reverse order (newest first)
    local entry
    while IFS= read -r entry; do
        local breakdowns
        breakdowns=$(echo "$entry" | jq -c '.modelBreakdowns // []')
        
        local item
        while IFS= read -r item; do
            local item_model
            item_model=$(echo "$item" | jq -r '.modelName // ""')
            if [[ "$item_model" == "$model" ]]; then
                local cost
                cost=$(echo "$item" | jq -r '.cost // "null"')
                local day
                day=$(echo "$entry" | jq -r '.date // "null"')
                echo "$day,$cost"
                return 0
            fi
        done < <(echo "$breakdowns" | jq -c '.[]')
    done < <(echo "$sorted_entries" | jq -c '.[]' | tail -r)
    
    echo "null,null"
    return 0
}

# Render text output for current mode
render_text_current() {
    local provider="$1"
    local model="$2"
    local latest_date="$3"
    local total_cost="$4"
    local latest_cost="$5"
    local latest_cost_date="$6"
    local entry_count="$7"
    
    echo "Provider: $provider"
    echo "Current model: $model"
    if [[ -n "$latest_date" && "$latest_date" != "null" ]]; then
        echo "Latest model date: $latest_date"
    fi
    echo "Total cost (rows): $(usd "$total_cost")"
    if [[ -n "$latest_cost_date" && "$latest_cost_date" != "null" ]]; then
        echo "Latest day cost: $(usd "$latest_cost") ($latest_cost_date)"
    fi
    echo "Daily rows: $entry_count"
}

# Render text output for all mode
render_text_all() {
    local provider="$1"
    local totals="$2"
    
    echo "Provider: $provider"
    echo "Models:"
    
    # Sort by cost descending
    echo "$totals" | jq -r 'to_entries | sort_by(-.value) | .[] | "- \(.key): \(.value)"' | while IFS= read -r line; do
        local model cost
        model=$(echo "$line" | cut -d':' -f1 | sed 's/^- //')
        cost=$(echo "$line" | cut -d':' -f2 | xargs)
        echo "- $model: $(usd "$cost")"
    done
}

# Build JSON output for current mode
build_json_current() {
    local provider="$1"
    local model="$2"
    local latest_date="$3"
    local total_cost="$4"
    local latest_cost="$5"
    local latest_cost_date="$6"
    local entry_count="$7"
    
    local json_str="{\"provider\":\"$provider\",\"mode\":\"current\",\"model\":\"$model\""
    
    if [[ -n "$latest_date" && "$latest_date" != "null" ]]; then
        json_str="$json_str,\"latestModelDate\":\"$latest_date\""
    fi
    
    if [[ -n "$total_cost" && "$total_cost" != "null" ]]; then
        json_str="$json_str,\"totalCostUSD\":$total_cost"
    else
        json_str="$json_str,\"totalCostUSD\":null"
    fi
    
    if [[ -n "$latest_cost" && "$latest_cost" != "null" ]]; then
        json_str="$json_str,\"latestDayCostUSD\":$latest_cost"
    else
        json_str="$json_str,\"latestDayCostUSD\":null"
    fi
    
    if [[ -n "$latest_cost_date" && "$latest_cost_date" != "null" ]]; then
        json_str="$json_str,\"latestDayCostDate\":\"$latest_cost_date\""
    else
        json_str="$json_str,\"latestDayCostDate\":null"
    fi
    
    json_str="$json_str,\"dailyRowCount\":$entry_count}"
    echo "$json_str"
}

# Build JSON output for all mode
build_json_all() {
    local provider="$1"
    local totals="$2"
    
    local models_json
    models_json=$(echo "$totals" | jq -c 'to_entries | sort_by(-.value) | map({"model": .key, "totalCostUSD": .value})')
    echo "{\"provider\":\"$provider\",\"mode\":\"all\",\"models\":$models_json}"
}

# Main function
main() {
    local payload
    payload=$(load_payload "$INPUT" "$PROVIDER") || return $?
    
    local entries
    entries=$(parse_daily_entries "$payload")
    
    if [[ -n "$DAYS" ]]; then
        entries=$(filter_by_days "$entries" "$DAYS")
    fi
    
    if [[ "$MODE" == "current" ]]; then
        local model="$MODEL"
        local latest_date=""
        
        if [[ -z "$model" ]]; then
            local result
            result=$(pick_current_model "$entries")
            model=$(echo "$result" | cut -d',' -f1)
            latest_date=$(echo "$result" | cut -d',' -f2)
            
            if [[ -z "$model" || "$model" == "null" || "$model" == "," ]]; then
                eprint "No model data found in codexbar cost payload."
                return 2
            fi
            
            # Clean up empty values
            if [[ "$model" == "," ]]; then
                model=""
            fi
            if [[ "$latest_date" == "," || "$latest_date" == "null" ]]; then
                latest_date=""
            fi
        fi
        
        if [[ -z "$model" ]]; then
            eprint "No model data found in codexbar cost payload."
            return 2
        fi
        
        local totals
        totals=$(aggregate_costs "$entries")
        
        local total_cost
        total_cost=$(echo "$totals" | jq -r ".\"$model\" // \"null\"")
        
        local latest_result
        latest_result=$(latest_day_cost "$entries" "$model")
        local latest_cost_date
        latest_cost_date=$(echo "$latest_result" | cut -d',' -f1)
        local latest_cost
        latest_cost=$(echo "$latest_result" | cut -d',' -f2)
        
        # Clean up null values
        if [[ "$latest_cost_date" == "null" ]]; then
            latest_cost_date=""
        fi
        if [[ "$latest_cost" == "null" ]]; then
            latest_cost=""
        fi
        
        local entry_count
        entry_count=$(echo "$entries" | jq length)
        
        if [[ "$FORMAT" == "json" ]]; then
            local json_output
            json_output=$(build_json_current "$PROVIDER" "$model" "$latest_date" "$total_cost" "$latest_cost" "$latest_cost_date" "$entry_count")
            if [[ "$PRETTY" == true ]]; then
                echo "$json_output" | jq .
            else
                echo "$json_output"
            fi
        else
            render_text_current "$PROVIDER" "$model" "$latest_date" "$total_cost" "$latest_cost" "$latest_cost_date" "$entry_count"
        fi
        return 0
    fi
    
    local totals
    totals=$(aggregate_costs "$entries")
    
    # Check if we have any data
    if [[ $(echo "$totals" | jq length) -eq 0 ]]; then
        eprint "No model breakdowns found in codexbar cost payload."
        return 2
    fi
    
    if [[ "$FORMAT" == "json" ]]; then
        local json_output
        json_output=$(build_json_all "$PROVIDER" "$totals")
        if [[ "$PRETTY" == true ]]; then
            echo "$json_output" | jq .
        else
            echo "$json_output"
        fi
    else
        render_text_all "$PROVIDER" "$totals"
    fi
    
    return 0
}

# Run main function
main "$@"
