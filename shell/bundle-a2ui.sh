#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "36a7a3fec658deeba32480d6721cffa20a5799acdafd54a26470b37ebb5603f6", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "shell"}
# bundle-a2ui.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
HASH_FILE="$ROOT_DIR/src/canvas-host/a2ui/.bundle.hash"
OUTPUT_FILE="$ROOT_DIR/src/canvas-host/a2ui/a2ui.bundle.js"
A2UI_RENDERER_DIR="$ROOT_DIR/vendor/a2ui/renderers/lit"
A2UI_APP_DIR="$ROOT_DIR/apps/shared/OpenClawKit/Tools/CanvasA2UI"

INPUT_PATHS=(
  "$ROOT_DIR/package.json"
  "$ROOT_DIR/pnpm-lock.yaml"
  "$A2UI_RENDERER_DIR"
  "$A2UI_APP_DIR"
)

IGNORED_BUNDLE_HASH_INPUT_PREFIXES=("vendor/a2ui/renderers/lit/dist")

# Funktionen
fail() {
  echo >&2 "$1"
  echo >&2 "A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle"
  echo >&2 "If this persists, verify pnpm deps and try again."
  exit 1
}

path_exists() {
  [[ -e "$1" ]]
}

normalize_path() {
  echo "${1//\\//}"
}

is_bundle_hash_input_path() {
  local file_path="$1"
  local repo_root="${2:-$ROOT_DIR}"
  local relative_path
  relative_path=$(realpath --relative-to="$repo_root" "$file_path" 2>/dev/null || echo "$file_path")
  relative_path=$(normalize_path "$relative_path")
  
  for ignored_path in "${IGNORED_BUNDLE_HASH_INPUT_PREFIXES[@]}"; do
    if [[ "$relative_path" == "$ignored_path" ]] || [[ "$relative_path" == "$ignored_path/"* ]]; then
      return 1
    fi
  done
  return 0
}

get_local_rolldown_cli_candidates() {
  echo "$ROOT_DIR/node_modules/rolldown/bin/cli.mjs"
  echo "$ROOT_DIR/node_modules/.pnpm/node_modules/rolldown/bin/cli.mjs"
  echo "$ROOT_DIR/node_modules/.pnpm/rolldown@1.0.0-rc.12/node_modules/rolldown/bin/cli.mjs"
}

walk_files() {
  local entry_path="$1"
  local -n files_ref="$2"
  
  if ! is_bundle_hash_input_path "$entry_path"; then
    return
  fi
  
  if [[ -d "$entry_path" ]]; then
    while IFS= read -r -d '' file; do
      walk_files "$file" files_ref
    done < <(find "$entry_path" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  elif [[ -f "$entry_path" ]]; then
    files_ref+=("$entry_path")
  fi
}

list_tracked_input_files() {
  local output
  output=$(cd "$ROOT_DIR" && git ls-files -- "${INPUT_PATHS[@]/#"$ROOT_DIR"/}") || return 1
  
  mapfile -t tracked_files <<<"$output"
  local filtered_files=()
  
  for file in "${tracked_files[@]}"; do
    if [[ -n "$file" ]] && is_bundle_hash_input_path "$ROOT_DIR/$file"; then
      filtered_files+=("$ROOT_DIR/$file")
    fi
  done
  
  printf '%s\n' "${filtered_files[@]}"
}

compute_hash() {
  local files=()
  local tracked_files_output=""
  
  if tracked_files_output=$(list_tracked_input_files); then
    mapfile -t files <<<"$tracked_files_output"
  else
    for input_path in "${INPUT_PATHS[@]}"; do
      walk_files "$input_path" files
    done
  fi
  
  # Sortieren der Dateien
  IFS=$'\n' sorted_files=($(sort <<<"${files[*]}"))
  unset IFS
  
  {
    for file_path in "${sorted_files[@]}"; do
      normalize_path "$(realpath --relative-to="$ROOT_DIR" "$file_path")"
      echo -ne '\0'
      cat "$file_path"
      echo -ne '\0'
    done
  } | sha256sum | cut -d' ' -f1
}

run_step() {
  local command="$1"
  shift
  local args=("$@")
  
  if ! "$command" "${args[@]}"; then
    exit $?
  fi
}

run_pnpm() {
  local pnpm_args=("$@")
  # Da wir keine direkte Entsprechung zu resolvePnpmRunner haben,
  # verwenden wir einfach `pnpm` direkt
  run_step pnpm "${pnpm_args[@]}"
}

main() {
  local has_renderer_dir=false
  local has_app_dir=false
  local has_output_file=false
  
  if path_exists "$A2UI_RENDERER_DIR"; then has_renderer_dir=true; fi
  if path_exists "$A2UI_APP_DIR"; then has_app_dir=true; fi
  if path_exists "$OUTPUT_FILE"; then has_output_file=true; fi
  
  if [[ "$has_renderer_dir" != true ]] || [[ "$has_app_dir" != true ]]; then
    if [[ "$has_output_file" == true ]]; then
      echo "A2UI sources missing; keeping prebuilt bundle."
      return
    fi
    
    if [[ -n "${OPENCLAW_SPARSE_PROFILE:-}" ]] || [[ "${OPENCLAW_A2UI_SKIP_MISSING:-}" == "1" ]]; then
      echo >&2 "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set."
      return
    fi
    
    fail "A2UI sources missing and no prebuilt bundle found at: $OUTPUT_FILE"
  fi
  
  local current_hash
  current_hash=$(compute_hash)
  
  if path_exists "$HASH_FILE"; then
    local previous_hash
    previous_hash=$(cat "$HASH_FILE" | tr -d '[:space:]')
    
    if [[ "$previous_hash" == "$current_hash" ]] && [[ "$has_output_file" == true ]]; then
      echo "A2UI bundle up to date; skipping."
      return
    fi
  fi
  
  run_pnpm "-s" "exec" "tsc" "-p" "$A2UI_RENDERER_DIR/tsconfig.json"
  
  local local_rolldown_cli=""
  while IFS= read -r candidate; do
    if path_exists "$candidate"; then
      local_rolldown_cli="$candidate"
      break
    fi
  done < <(get_local_rolldown_cli_candidates)
  
  if [[ -n "$local_rolldown_cli" ]]; then
    run_step node "$local_rolldown_cli" "-c" "$A2UI_APP_DIR/rolldown.config.mjs"
  else
    run_pnpm "-s" "exec" "rolldown" "-c" "$A2UI_APP_DIR/rolldown.config.mjs"
  fi
  
  echo "$current_hash" > "$HASH_FILE"
}

# Skriptausführung
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@" || fail "An error occurred during execution"
fi
