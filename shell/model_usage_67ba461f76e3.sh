#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "11821e93fa5899435c1fa4476f7eb3bbf4002706191d1a94b18b74110d0278db", "source_sha256": "502dcda47466a4ab74da59badbe4b12c4782ed031c43d5038f8bd8534373cd35", "target_language": "shell"}
# model_usage.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
# auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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
PRETTY=""

usage() {
  echo "Usage: $0 [--provider codex|claude] [--mode current|all] [--model MODEL]"
  echo "         [--input FILE|-] [--days DAYS] [--format text|json] [--pretty]"
  exit 1
}

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
      PRETTY="--pretty"
      shift
      ;;
    *)
      usage
      ;;
  esac
done

# Load JSON data from input source
load_payload() {
  local input="$1"
  local provider="$2"
  
  if [[ -n "$input" ]]; then
    if [[ "$input" == "-" ]]; then
      DATA=$(cat)
    else
      DATA=$(cat "$input")
    fi
  else
    # Run codexbar cost command
    if ! command -v codexbar >/dev/null 2>&1; then
      echo "codexbar not found on PATH. Install CodexBar CLI first." >&2
      exit 1
    fi
    
    if ! DATA=$(codexbar cost --format json --provider "$provider" 2>/dev/null); then
      echo "codexbar cost failed" >&2
      exit 1
    fi
  fi
  
  # Validate JSON structure and extract provider data
  if echo "$DATA" | jq -e 'type == "object"' >/dev/null; then
    echo "$DATA"
    return
  elif echo "$DATA" | jq -e 'type == "array"' >/dev/null; then
    local result
    result=$(echo "$DATA" | jq -r ".[] | select(.provider == \"$provider\")")
    if [[ -n "$result" ]]; then
      echo "$result"
      return
    else
      echo "Provider '$provider' not found in codexbar payload." >&2
      exit 1
    fi
  else
    echo "Unsupported JSON input format." >&2
    exit 1
  fi
}

# Parse daily entries from payload
parse_daily_entries() {
  local payload="$1"
  echo "$payload" | jq -c '.daily // []'
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
  cutoff=$(date -d "$days days ago" +%Y-%m-%d)
  echo "$entries" | jq -c "[.[] | select(.date >= \"$cutoff\")]"
}

# Aggregate costs by model
aggregate_costs() {
  local entries="$1"
  echo "$entries" | jq -c '
    [.[]
     | .modelBreakdowns[]
     | {(.modelName): .cost}]
    | reduce .[] as $item ({}; 
        . + $item 
        | to_entries 
        | map(select(.value != null)) 
        | from_entries)
  '
}

# Pick current model based on most recent high-cost usage
pick_current_model() {
  local entries="$1"
  local model=""
  local date=""
  
  # Sort entries by date descending
  local sorted_entries
  sorted_entries=$(echo "$entries" | jq -c 'sort_by(.date) | reverse')
  
  # Look through entries for model breakdowns
  while IFS= read -r entry; do
    local breakdowns
    breakdowns=$(echo "$entry" | jq -c '.modelBreakdowns // []')
    
    if [[ $(echo "$breakdowns" | jq 'length') -gt 0 ]]; then
      # Find highest cost model in this entry
      local top_model
      top_model=$(echo "$breakdowns" | jq -r 'map(select(.cost and .modelName)) | sort_by(.cost) | reverse | .[0] | .modelName // ""')
      
      if [[ -n "$top_model" && "$top_model" != "null" ]]; then
        model="$top_model"
        date=$(echo "$entry" | jq -r '.date // ""')
        echo "$model|$date"
        return
      fi
    fi
    
    # Fallback to modelsUsed
    local models_used
    models_used=$(echo "$entry" | jq -c '.modelsUsed // []')
    if [[ $(echo "$models_used" | jq 'length') -gt 0 ]]; then
      local last_model
      last_model=$(echo "$models_used" | jq -r '.[-1]')
      if [[ -n "$last_model" && "$last_model" != "null" ]]; then
        model="$last_model"
        date=$(echo "$entry" | jq -r '.date // ""')
        echo "$model|$date"
        return
      fi
    fi
  done < <(echo "$sorted_entries" | jq -c '.[]')
  
  echo "|"
}

# Format USD value
usd() {
  local value="$1"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "—"
  else
    printf "$%.2f" "$value" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'
  fi
}

# Get latest day cost for a specific model
latest_day_cost() {
  local entries="$1"
  local model="$2"
  
  # Sort entries by date descending
  local sorted_entries
  sorted_entries=$(echo "$entries" | jq -c 'sort_by(.date) | reverse')
  
  while IFS= read -r entry; do
    local breakdowns
    breakdowns=$(echo "$entry" | jq -c '.modelBreakdowns // []')
    
    while IFS= read -r item; do
      local item_model
      item_model=$(echo "$item" | jq -r '.modelName // ""')
      
      if [[ "$item_model" == "$model" ]]; then
        local cost
        cost=$(echo "$item" | jq -r '.cost // "null"')
        local day
        day=$(echo "$entry" | jq -r '.date // "null"')
        echo "$day|$cost"
        return
      fi
    done < <(echo "$breakdowns" | jq -c '.[]')
  done < <(echo "$sorted_entries" | jq -c '.[]')
  
  echo "null|null"
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
  
  while IFS='|' read -r model cost; do
    echo "- $model: $(usd "$cost")"
  done < <(echo "$totals" | jq -r 'to_entries | sort_by(-.value) | .[] | "\(.key)|\(.value)"')
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
  
  jq -n \
    --arg provider "$provider" \
    --arg model "$model" \
    --arg latest_date "$latest_date" \
    --arg total_cost "$total_cost" \
    --arg latest_cost "$latest_cost" \
    --arg latest_cost_date "$latest_cost_date" \
    --arg entry_count "$entry_count" \
    '{
      provider: $provider,
      mode: "current",
      model: $model,
      latestModelDate: ($latest_date | if . == "null" then null else . end),
      totalCostUSD: ($total_cost | if . == "null" then null else tonumber end),
      latestDayCostUSD: ($latest_cost | if . == "null" then null else tonumber end),
      latestDayCostDate: ($latest_cost_date | if . == "null" then null else . end),
      dailyRowCount: ($entry_count | tonumber)
    }'
}

# Build JSON output for all mode
build_json_all() {
  local provider="$1"
  local totals="$2"
  
  local models_json=""
  local first=true
  while IFS='|' read -r model cost; do
    if [[ "$first" == true ]]; then
      models_json="{\"model\":\"$model\",\"totalCostUSD\":$cost}"
      first=false
    else
      models_json="$models_json,{\"model\":\"$model\",\"totalCostUSD\":$cost}"
    fi
  done < <(echo "$totals" | jq -r 'to_entries | sort_by(-.value) | .[] | "\(.key)|\(.value)"')
  
  if [[ -z "$models_json" ]]; then
    models_json=""
  else
    models_json="[$models_json]"
  fi
  
  jq -n \
    --arg provider "$provider" \
    --argjson models "$models_json" \
    '{
      provider: $provider,
      mode: "all",
      models: $models
    }'
}

# Main execution
main() {
  # Load payload data
  local PAYLOAD
  PAYLOAD=$(load_payload "$INPUT" "$PROVIDER") || exit $?
  
  # Parse and filter daily entries
  local ENTRIES
  ENTRIES=$(parse_daily_entries "$PAYLOAD")
  ENTRIES=$(filter_by_days "$ENTRIES" "$DAYS")
  
  if [[ "$MODE" == "current" ]]; then
    local model="$MODEL"
    local latest_date=""
    
    if [[ -z "$model" ]]; then
      local model_date
      model_date=$(pick_current_model "$ENTRIES")
      model=$(echo "$model_date" | cut -d'|' -f1)
      latest_date=$(echo "$model_date" | cut -d'|' -f2)
      
      if [[ -z "$model" || "$model" == "null" ]]; then
        echo "No model data found in codexbar cost payload." >&2
        exit 2
      fi
    fi
    
    # Calculate totals
    local TOTALS
    TOTALS=$(aggregate_costs "$ENTRIES")
    
    local total_cost
    total_cost=$(echo "$TOTALS" | jq -r ".\"$model\" // \"null\"")
    
    local latest_cost_result
    latest_cost_result=$(latest_day_cost "$ENTRIES" "$model")
    local latest_cost_date
    latest_cost_date=$(echo "$latest_cost_result" | cut -d'|' -f1)
    local latest_cost
    latest_cost=$(echo "$latest_cost_result" | cut -d'|' -f2)
    
    local entry_count
    entry_count=$(echo "$ENTRIES" | jq 'length')
    
    if [[ "$FORMAT" == "json" ]]; then
      build_json_current "$PROVIDER" "$model" "$latest_date" "$total_cost" "$latest_cost" "$latest_cost_date" "$entry_count" | \
        if [[ -n "$PRETTY" ]]; then
          jq .
        else
          cat
        fi
    else
      render_text_current "$PROVIDER" "$model" "$latest_date" "$total_cost" "$latest_cost" "$latest_cost_date" "$entry_count"
    fi
  else
    # All mode
    local TOTALS
    TOTALS=$(aggregate_costs "$ENTRIES")
    
    if [[ $(echo "$TOTALS" | jq 'length') -eq 0 ]]; then
      echo "No model breakdowns found in codexbar cost payload." >&2
      exit 2
    fi
    
    if [[ "$FORMAT" == "json" ]]; then
      build_json_all "$PROVIDER" "$TOTALS" | \
        if [[ -n "$PRETTY" ]]; then
          jq .
        else
          cat
        fi
    else
      render_text_all "$PROVIDER" "$TOTALS"
    fi
  fi
}

main
