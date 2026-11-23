#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "1a0cd472292b46df1b5296a24f3a47d8786f47d1bf8a0ec1fa5acf5bf880cbce", "source_sha256": "c6c7301dda8709e6c39c53f79a83f8f7938854384f4e21e1114095d876e51a6d", "target_language": "shell"}
# test-cli-startup-bench-budget.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-cli-startup-bench-budget.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

CLI_STARTUP_BENCH_FIXTURE_PATH="test/fixtures/cli-startup-bench.json"

# Default options
baseline="$CLI_STARTUP_BENCH_FIXTURE_PATH"
report=""
entry="openclaw.mjs"
preset="all"
runs=1
warmup=0
timeout_ms=30000
max_duration_regression_pct="${OPENCLAW_STARTUP_BENCH_MAX_DURATION_REGRESSION_PCT:-20}"
max_rss_regression_pct="${OPENCLAW_STARTUP_BENCH_MAX_RSS_REGRESSION_PCT:-20}"

# Help function
show_help() {
  cat << EOF
Usage: $0 [options]

Compare current CLI benchmark results against the checked-in fixture.

Options:
  --baseline <path>             Baseline fixture path
  --report <path>               Reuse an existing current benchmark report
  --entry <path>                CLI entry to benchmark when report is omitted
  --preset <name>               startup | real | all (default: all)
  --runs <n>                    Measured runs per case (default: 1)
  --warmup <n>                  Warmup runs per case (default: 0)
  --timeout-ms <ms>             Per-run timeout (default: 30000)
  --max-duration-regression-pct <n>
                                Fail if avg duration regresses more than this percent
  --max-rss-regression-pct <n>  Fail if avg RSS regresses more than this percent
  --help                        Show this help text

Example:
  $0 --preset real --max-duration-regression-pct 15
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      show_help
      exit 0
      ;;
    --baseline)
      baseline="$2"
      shift 2
      ;;
    --report)
      report="$2"
      shift 2
      ;;
    --entry)
      entry="$2"
      shift 2
      ;;
    --preset)
      preset="$2"
      shift 2
      ;;
    --runs)
      runs="$2"
      shift 2
      ;;
    --warmup)
      warmup="$2"
      shift 2
      ;;
    --timeout-ms)
      timeout_ms="$2"
      shift 2
      ;;
    --max-duration-regression-pct)
      max_duration_regression_pct="$2"
      shift 2
      ;;
    --max-rss-regression-pct)
      max_rss_regression_pct="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Format functions
format_ms() {
  printf "%.1fms" "$1"
}

format_mb() {
  printf "%.1fMB" "$1"
}

# Resolve current report path
resolve_current_report_path() {
  if [[ -n "$report" ]]; then
    echo "$report"
    return
  fi
  
  local report_path=".artifacts/cli-startup-bench.current.json"
  mkdir -p ".artifacts"
  
  local args=(
    "--import" "tsx"
    "scripts/bench-cli-startup.ts"
    "--entry" "$entry"
    "--preset" "$preset"
    "--runs" "$runs"
    "--warmup" "$warmup"
    "--timeout-ms" "$timeout_ms"
    "--output" "$report_path"
  )
  
  if ! node "${args[@]}"; then
    exit 1
  fi
  
  echo "$report_path"
}

# Read JSON and extract cases
read_json_cases() {
  local file="$1"
  jq -c '.primary.cases[] | {id: .id, name: .name, durationMs: .summary.durationMs.avg, maxRssMb: .summary.maxRssMb.avg}' "$file" 2>/dev/null || echo ""
}

# Index cases by ID
index_cases() {
  local input="$1"
  jq -c 'group_by(.id) | map({key: .[0].id, value: .[0]}) | from_entries' <<< "$input"
}

# Main execution
main() {
  local current_report_path
  current_report_path=$(resolve_current_report_path)
  
  # Read baseline and current reports
  local baseline_data
  local current_data
  baseline_data=$(read_json_cases "$baseline")
  current_data=$(read_json_cases "$current_report_path")
  
  # Index cases
  local baseline_indexed
  local current_indexed
  baseline_indexed=$(index_cases "$baseline_data")
  current_indexed=$(index_cases "$current_data")
  
  local failed=false
  
  # Process each baseline case
  while IFS= read -r line; do
    local id
    id=$(jq -r '.key' <<< "$line")
    
    local baseline_case
    baseline_case=$(jq -r ".[\"$id\"]" <<< "$baseline_indexed")
    
    local current_case
    current_case=$(jq -r ".[\"$id\"]" <<< "$current_indexed")
    
    if [[ "$current_case" == "null" ]]; then
      echo "[test-cli-startup-bench-budget] missing current case $id" >&2
      failed=true
      continue
    fi
    
    local baseline_name
    local baseline_duration
    local current_duration
    local baseline_rss
    local current_rss
    
    baseline_name=$(jq -r '.name' <<< "$baseline_case")
    baseline_duration=$(jq -r '.durationMs' <<< "$baseline_case")
    current_duration=$(jq -r '.durationMs' <<< "$current_case")
    baseline_rss=$(jq -r '.maxRssMb' <<< "$baseline_case")
    current_rss=$(jq -r '.maxRssMb' <<< "$current_case")
    
    # Check duration regression
    if [[ "$baseline_duration" != "null" && "$current_duration" != "null" ]] && 
       (( $(echo "$baseline_duration > 0" | bc -l) )); then
      
      local allowed_duration
      allowed_duration=$(echo "$baseline_duration * (1 + $max_duration_regression_pct / 100)" | bc -l)
      
      if (( $(echo "$current_duration > $allowed_duration" | bc -l) )); then
        local formatted_current_duration formatted_allowed_duration formatted_baseline_duration
        formatted_current_duration=$(format_ms "$current_duration")
        formatted_allowed_duration=$(format_ms "$allowed_duration")
        formatted_baseline_duration=$(format_ms "$baseline_duration")
        
        echo "[test-cli-startup-bench-budget] $baseline_name avg duration $formatted_current_duration exceeded $formatted_allowed_duration (baseline $formatted_baseline_duration, +$max_duration_regression_pct%)." >&2
        failed=true
      fi
    fi
    
    # Check RSS regression
    if [[ "$baseline_rss" != "null" && "$current_rss" != "null" ]] && 
       (( $(echo "$baseline_rss > 0" | bc -l) )); then
      
      local allowed_rss
      allowed_rss=$(echo "$baseline_rss * (1 + $max_rss_regression_pct / 100)" | bc -l)
      
      if (( $(echo "$current_rss > $allowed_rss" | bc -l) )); then
        local formatted_current_rss formatted_allowed_rss formatted_baseline_rss
        formatted_current_rss=$(format_mb "$current_rss")
        formatted_allowed_rss=$(format_mb "$allowed_rss")
        formatted_baseline_rss=$(format_mb "$baseline_rss")
        
        echo "[test-cli-startup-bench-budget] $baseline_name avg RSS $formatted_current_rss exceeded $formatted_allowed_rss (baseline $formatted_baseline_rss, +$max_rss_regression_pct%)." >&2
        failed=true
      fi
    fi
    
    # Print summary
    local duration_str baseline_duration_str rss_str baseline_rss_str
    duration_str=$(format_ms "$current_duration")
    baseline_duration_str=$(format_ms "$baseline_duration")
    
    if [[ "$current_rss" != "null" ]]; then
      rss_str=$(format_mb "$current_rss")
    else
      rss_str="n/a"
    fi
    
    if [[ "$baseline_rss" != "null" ]]; then
      baseline_rss_str=$(format_mb "$baseline_rss")
    else
      baseline_rss_str="n/a"
    fi
    
    echo "[test-cli-startup-bench-budget] $baseline_name duration=$duration_str baseline=$baseline_duration_str rss=$rss_str baselineRss=$baseline_rss_str"
  done < <(jq -c 'to_entries[]' <<< "$baseline_indexed")
  
  if [[ "$failed" == true ]]; then
    exit 1
  fi
}

# Run main function
main
