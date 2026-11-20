#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "8b2a7a604025a70ea0401e5aaa48923ec2df26d950b0a1b9307da98b9b79b8dd", "source_sha256": "c28e85cfc52b92ed64eb8e20b072fd218cfe0e1ab0787781c1a9abd3355c3514", "target_language": "shell"}
# extension-test-plan.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-test-plan.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Globale Variablen
repo_root="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")"
BUNDLED_PLUGIN_PATH_PREFIX="packages/bundled-plugins"
BUNDLED_PLUGIN_ROOT_DIR="packages/bundled-plugins"

# Standard-Shard-Anzahl
DEFAULT_EXTENSION_TEST_SHARD_COUNT=6

# Liste der verfügbaren Extension-IDs (muss implementiert werden)
list_available_extension_ids() {
  local ids=()
  local plugin_dir="${repo_root}/${BUNDLED_PLUGIN_ROOT_DIR}"
  
  if [[ -d "$plugin_dir" ]]; then
    for dir in "$plugin_dir"/*/; do
      if [[ -d "$dir" && -f "${dir}/package.json" ]]; then
        ids+=("$(basename "$dir")")
      fi
    done
  fi
  
  printf '%s\n' "${ids[@]}"
}

# Hilfsfunktion zur Pfadnormalisierung
normalize_relative() {
  local input_path="$1"
  echo "${input_path//\\//}"
}

# Zählt Testdateien rekursiv
count_test_files() {
  local root_path="$1"
  local total=0
  
  if [[ ! -d "$root_path" ]]; then
    echo 0
    return
  fi
  
  while IFS= read -r -d '' file; do
    if [[ "$file" == *.test.ts ]] || [[ "$file" == *.test.tsx ]]; then
      ((total++))
    fi
  done < <(find "$root_path" -type f \( -name "*.test.ts" -o -name "*.test.tsx" \) -print0 2>/dev/null || true)
  
  echo $total
}

# Löst das Extension-Verzeichnis auf
resolve_extension_directory() {
  local target_arg="${1:-}"
  local cwd="${2:-$(pwd)}"
  
  if [[ -n "$target_arg" ]]; then
    local as_given="$(realpath "${cwd}/${target_arg}" 2>/dev/null || echo "")"
    if [[ -n "$as_given" ]] && [[ -f "${as_given}/package.json" ]]; then
      echo "$as_given"
      return
    fi
    
    local by_name="${repo_root}/${BUNDLED_PLUGIN_ROOT_DIR}/${target_arg}"
    if [[ -f "${by_name}/package.json" ]]; then
      echo "$by_name"
      return
    fi
    
    echo "Unknown extension target \"${target_arg}\". Use a plugin name like \"slack\" or a path inside the bundled plugin workspace tree." >&2
    exit 1
  fi
  
  local current="$cwd"
  while [[ "$current" != "/" ]]; do
    local rel_path="$(realpath --relative-to="$repo_root" "$current" 2>/dev/null || echo "")"
    if [[ -n "$rel_path" ]] && [[ "$rel_path" == ${BUNDLED_PLUGIN_PATH_PREFIX}* ]] && [[ -f "${current}/package.json" ]]; then
      echo "$current"
      return
    fi
    current="$(dirname "$current")"
  done
  
  echo "No extension target provided, and current working directory is not inside the bundled plugin workspace tree." >&2
  exit 1
}

# Prüft verschiedene Extension-Typen
is_acpx_extension_root() {
  local root="$1"
  [[ "$root" == *"acpx"* ]]
}

is_bluebubbles_extension_root() {
  local root="$1"
  [[ "$root" == *"bluebubbles"* ]]
}

is_diffs_extension_root() {
  local root="$1"
  [[ "$root" == *"diffs"* ]]
}

is_feishu_extension_root() {
  local root="$1"
  [[ "$root" == *"feishu"* ]]
}

is_irc_extension_root() {
  local root="$1"
  [[ "$root" == *"irc"* ]]
}

is_matrix_extension_root() {
  local root="$1"
  [[ "$root" == *"matrix"* ]]
}

is_mattermost_extension_root() {
  local root="$1"
  [[ "$root" == *"mattermost"* ]]
}

is_memory_extension_root() {
  local root="$1"
  [[ "$root" == *"memory"* ]]
}

is_messaging_extension_root() {
  local root="$1"
  [[ "$root" == *"messaging"* ]]
}

is_msteams_extension_root() {
  local root="$1"
  [[ "$root" == *"msteams"* ]]
}

is_provider_extension_root() {
  local root="$1"
  [[ "$root" == *"provider"* ]]
}

is_telegram_extension_root() {
  local root="$1"
  [[ "$root" == *"telegram"* ]]
}

is_voice_call_extension_root() {
  local root="$1"
  [[ "$root" == *"voice-call"* ]]
}

is_whatsapp_extension_root() {
  local root="$1"
  [[ "$root" == *"whatsapp"* ]]
}

is_zalo_extension_root() {
  local root="$1"
  [[ "$root" == *"zalo"* ]]
}

# Channel-Test-Pfade (vereinfacht)
channel_test_roots=("slack" "discord")

# Löst den Extension-Test-Plan auf
resolve_extension_test_plan() {
  local cwd="${1:-$(pwd)}"
  local target_arg="${2:-}"
  
  local extension_dir
  extension_dir="$(resolve_extension_directory "$target_arg" "$cwd")"
  local extension_id
  extension_id="$(basename "$extension_dir")"
  local relative_extension_dir
  relative_extension_dir="$(realpath --relative-to="$repo_root" "$extension_dir")"
  
  local roots=("$relative_extension_dir")
  
  local config="test/vitest/vitest.extensions.config.ts"
  
  # Prüfung auf spezielle Konfigurationen
  local root
  for root in "${roots[@]}"; do
    if [[ " ${channel_test_roots[*]} " =~ " $root " ]]; then
      config="test/vitest/vitest.extension-channels.config.ts"
      break
    elif is_acpx_extension_root "$root"; then
      config="test/vitest/vitest.extension-acpx.config.ts"
      break
    elif is_diffs_extension_root "$root"; then
      config="test/vitest/vitest.extension-diffs.config.ts"
      break
    elif is_bluebubbles_extension_root "$root"; then
      config="test/vitest/vitest.extension-bluebubbles.config.ts"
      break
    elif is_feishu_extension_root "$root"; then
      config="test/vitest/vitest.extension-feishu.config.ts"
      break
    elif is_irc_extension_root "$root"; then
      config="test/vitest/vitest.extension-irc.config.ts"
      break
    elif is_mattermost_extension_root "$root"; then
      config="test/vitest/vitest.extension-mattermost.config.ts"
      break
    elif is_matrix_extension_root "$root"; then
      config="test/vitest/vitest.extension-matrix.config.ts"
      break
    elif is_telegram_extension_root "$root"; then
      config="test/vitest/vitest.extension-telegram.config.ts"
      break
    elif is_voice_call_extension_root "$root"; then
      config="test/vitest/vitest.extension-voice-call.config.ts"
      break
    elif is_whatsapp_extension_root "$root"; then
      config="test/vitest/vitest.extension-whatsapp.config.ts"
      break
    elif is_zalo_extension_root "$root"; then
      config="test/vitest/vitest.extension-zalo.config.ts"
      break
    elif is_memory_extension_root "$root"; then
      config="test/vitest/vitest.extension-memory.config.ts"
      break
    elif is_msteams_extension_root "$root"; then
      config="test/vitest/vitest.extension-msteams.config.ts"
      break
    elif is_messaging_extension_root "$root"; then
      config="test/vitest/vitest.extension-messaging.config.ts"
      break
    elif is_provider_extension_root "$root"; then
      config="test/vitest/vitest.extension-providers.config.ts"
      break
    fi
  done
  
  local test_file_count=0
  local root_path
  for root in "${roots[@]}"; do
    root_path="${repo_root}/${root}"
    test_file_count=$((test_file_count + $(count_test_files "$root_path")))
  done
  
  local has_tests=false
  if [[ $test_file_count -gt 0 ]]; then
    has_tests=true
  fi
  
  # Ausgabe als JSON-ähnliches Format
  cat <<EOF
{
  "config": "$config",
  "extensionDir": "$relative_extension_dir",
  "extensionId": "$extension_id",
  "hasTests": $has_tests,
  "roots": ["$(IFS='","'; echo "${roots[*]}")"],
  "testFileCount": $test_file_count
}
EOF
}

# Führt mehrere Testpläne zusammen
merge_test_plans() {
  local plans_json="$1"
  
  # Extrahieren der eindeutigen Konfigurationen
  local configs=($(echo "$plans_json" | jq -r '.[].config' | sort -u))
  
  local plan_groups=""
  local total_test_files=0
  local all_extension_ids=()
  
  local config
  for config in "${configs[@]}"; do
    local group_extension_ids=($(echo "$plans_json" | jq -r --arg cfg "$config" '.[] | select(.config==$cfg) | .extensionId'))
    local group_roots=($(echo "$plans_json" | jq -r --arg cfg "$config" '.[] | select(.config==$cfg) | .roots[]'))
    local group_test_count=0
    
    local ext_id
    for ext_id in "${group_extension_ids[@]}"; do
      local count=$(echo "$plans_json" | jq -r --arg id "$ext_id" '.[] | select(.extensionId==$id) | .testFileCount')
      group_test_count=$((group_test_count + count))
    done
    
    # Entfernen von Duplikaten in Roots
    local unique_roots=()
    local root
    for root in "${group_roots[@]}"; do
      if [[ ! " ${unique_roots[*]} " =~ " $root " ]]; then
        unique_roots+=("$root")
      fi
    done
    
    plan_groups+="{
      \"config\": \"$config\",
      \"extensionIds\": [\"$(IFS='\",\"'; echo "${group_extension_ids[*]}")\"],
      \"roots\": [\"$(IFS='\",\"'; echo "${unique_roots[*]}")\"],
      \"testFileCount\": $group_test_count
    },"
    
    total_test_files=$((total_test_files + group_test_count))
    all_extension_ids+=("${group_extension_ids[@]}")
  done
  
  # Entfernen des letzten Kommas
  plan_groups="${plan_groups%,}"
  
  # Sortieren der Extension-IDs
  IFS=$'\n' all_extension_ids=($(sort <<<"${all_extension_ids[*]}"))
  unset IFS
  
  local extension_count=${#all_extension_ids[@]}
  local has_tests=false
  if [[ $extension_count -gt 0 ]]; then
    has_tests=true
  fi
  
  cat <<EOF
{
  "extensionCount": $extension_count,
  "extensionIds": ["$(IFS='\",\"'; echo "${all_extension_ids[*]}")"],
  "hasTests": $has_tests,
  "planGroups": [$plan_groups],
  "testFileCount": $total_test_files
}
EOF
}

# Löst den Batch-Plan für Extensions auf
resolve_extension_batch_plan() {
  local cwd="${1:-$(pwd)}"
  shift
  local extension_ids=("$@")
  
  if [[ ${#extension_ids[@]} -eq 0 ]]; then
    mapfile -t extension_ids < <(list_available_extension_ids)
  fi
  
  local plans_json=""
  local valid_plans=()
  
  local ext_id
  for ext_id in "${extension_ids[@]}"; do
    local plan
    plan=$(resolve_extension_test_plan "$cwd" "$ext_id" 2>/dev/null || echo "{}")
    if [[ $(echo "$plan" | jq -r '.hasTests') == "true" ]]; then
      valid_plans+=("$plan")
    fi
  done
  
  if [[ ${#valid_plans[@]} -eq 0 ]]; then
    echo '{
      "extensionCount": 0,
      "extensionIds": [],
      "hasTests": false,
      "planGroups": [],
      "testFileCount": 0
    }'
    return
  fi
  
  plans_json=$(printf '%s\n' "${valid_plans[@]}" | jq -s '.')
  merge_test_plans "$plans_json"
}

# Wählt den am wenigsten belasteten Shard aus
pick_least_loaded_shard() {
  local shards_json="$1"
  local best_index=-1
  
  local indices=($(echo "$shards_json" | jq -r 'keys[]'))
  
  for index in "${indices[@]}"; do
    if [[ $best_index -eq -1 ]]; then
      best_index=$index
      continue
    fi
    
    local current_count
    current_count=$(echo "$shards_json" | jq -r ".[$index].testFileCount")
    local best_count
    best_count=$(echo "$shards_json" | jq -r ".[$best_index].testFileCount")
    
    if [[ $current_count -ne $best_count ]]; then
      if [[ $current_count -lt $best_count ]]; then
        best_index=$index
      fi
      continue
    fi
    
    local current_length
    current_length=$(echo "$shards_json" | jq -r ".[$index].plans | length")
    local best_length
    best_length=$(echo "$shards_json" | jq -r ".[$best_index].plans | length")
    
    if [[ $current_length -ne $best_length ]]; then
      if [[ $current_length -lt $best_length ]]; then
        best_index=$index
      fi
      continue
    fi
    
    if [[ $index -lt $best_index ]]; then
      best_index=$index
    fi
  done
  
  echo $best_index
}

# Erstellt Extension-Test-Shards
create_extension_test_shards() {
  local cwd="${1:-$(pwd)}"
  shift
  local params=("$@")
  
  local shard_count=$DEFAULT_EXTENSION_TEST_SHARD_COUNT
  local extension_ids=()
  
  # Parsen der Parameter
  while [[ $# -gt 0 ]]; do
    case $1 in
      --shard-count)
        shard_count="$2"
        shift 2
        ;;
      --extension-ids)
        shift
        while [[ $# -gt 0 && $1 != --* ]]; do
          extension_ids+=("$1")
          shift
        done
        ;;
      *)
        shift
        ;;
    esac
  done
  
  if [[ ${#extension_ids[@]} -eq 0 ]]; then
    mapfile -t extension_ids < <(list_available_extension_ids)
  fi
  
  # Abrufen der Pläne
  local plans=()
  local ext_id
  for ext_id in "${extension_ids[@]}"; do
    local plan
    plan=$(resolve_extension_test_plan "$cwd" "$ext_id" 2>/dev/null || echo "{}")
    if [[ $(echo "$plan" | jq -r '.hasTests') == "true" ]]; then
      plans+=("$plan")
    fi
  done
  
  if [[ ${#plans[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi
  
  # Sortieren der Pläne nach Anzahl der Testdateien
  local sorted_plans=()
  readarray -t sorted_plans < <(printf '%s\n' "${plans[@]}" | jq -s 'sort_by(-.testFileCount) | .[]')
  
  local effective_shard_count
  effective_shard_count=$((shard_count < ${#sorted_plans[@]} ? shard_count : ${#sorted_plans[@]}))
  effective_shard_count=$((effective_shard_count > 0 ? effective_shard_count : 1))
  
  # Initialisieren der Shards
  local shards_json="{"
  local i
  for ((i=0; i<effective_shard_count; i++)); do
    shards_json+="\"$i\": {\"plans\":[], \"testFileCount\": 0},"
  done
  shards_json="${shards_json%,}}}"
  
  # Verteilen der Pläne auf die Shards
  local plan
  for plan in "${sorted_plans[@]}"; do
    local target_index
    target_index=$(pick_least_loaded_shard "$shards_json")
    
    local plan_test_count
    plan_test_count=$(echo "$plan" | jq -r '.testFileCount')
    
    local updated_plans
    updated_plans=$(echo "$shards_json" | jq -r --argjson plan "$plan" --arg idx "$target_index" '
      .[$idx | tonumber].plans |= . + [$plan] |
      .[$idx | tonumber].testFileCount |= . + ($plan.testFileCount | tonumber) |
      .
    ')
    
    shards_json="$updated_plans"
  done
  
  # Erstellen der finalen Shard-Struktur
  local result="["
  for ((i=0; i<effective_shard_count; i++)); do
    local shard_plans
    shard_plans=$(echo "$shards_json" | jq -r --arg idx "$i" '.[$idx | tonumber].plans')
    
    if [[ $(echo "$shard_plans" | jq 'length') -gt 0 ]]; then
      local merged_plan
      merged_plan=$(merge_test_plans "$shard_plans")
      
      result+="{
        \"index\": $i,
        \"checkName\": \"checks-node-extensions-shard-$((i+1))\",
        $(echo "$merged_plan" | jq -c '.')
      },"
    fi
  done
  result="${result%,}]"
  
  echo "$result" | jq -c '.'
}
