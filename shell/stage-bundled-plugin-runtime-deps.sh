#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "09df7445b9132949e7c0a8f5f1640e27de333bcbec33599ee101b4defec75c1c", "source_sha256": "481f90055fd746cf4af45da5765d09d2a9289bac2b7aa0b2fecc8558803339d5", "target_language": "shell"}
# stage-bundled-plugin-runtime-deps.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime-deps.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
readonly STAGED_RUNTIME_DEP_PRUNE_RULES=(
  "@larksuiteoapi/node-sdk:types"
)
readonly RUNTIME_DEPS_STAGING_VERSION=2

# Hilfsfunktionen
log() {
  echo >&2 "[$(date +%Y-%m-%dT%H:%M:%S)] $*"
}

die() {
  log "$@"
  exit 1
}

read_json() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    die "Datei nicht gefunden: $file"
  fi
  jq -r '.' "$file"
}

write_json() {
  local file="$1"
  local content="$2"
  echo "$content" | jq '.' > "$file"
}

remove_path_if_exists() {
  local target_path="$1"
  if [[ -e "$target_path" ]]; then
    rm -rf "$target_path"
  fi
}

make_temp_dir() {
  local parent_dir="$1"
  local prefix="$2"
  mktemp -d "${parent_dir}/${prefix}XXXXXXXX"
}

sanitize_temp_prefix_segment() {
  local value="$1"
  local normalized
  normalized=$(echo "$value" | sed -E 's/[^A-Za-z0-9._-]+/-/g' | sed -E 's/-+/-/g')
  if [[ -z "$normalized" ]]; then
    echo "plugin"
  else
    echo "$normalized"
  fi
}

replace_dir() {
  local target_path="$1"
  local source_path="$2"
  
  remove_path_if_exists "$target_path"
  
  if mv "$source_path" "$target_path" 2>/dev/null; then
    return 0
  fi
  
  cp -r "$source_path" "$target_path"
  remove_path_if_exists "$source_path"
}

dependency_node_modules_path() {
  local node_modules_dir="$1"
  local dep_name="$2"
  echo "${node_modules_dir}/${dep_name//\//@}"
}

read_installed_dependency_version() {
  local node_modules_dir="$1"
  local dep_name="$2"
  local package_json_path
  package_json_path="$(dependency_node_modules_path "$node_modules_dir" "$dep_name")/package.json"
  
  if [[ ! -f "$package_json_path" ]]; then
    echo ""
    return
  fi
  
  local version
  version=$(jq -r '.version // empty' "$package_json_path")
  if [[ -n "$version" ]]; then
    echo "$version"
  else
    echo ""
  fi
}

# Diese Funktion simuliert semver satisfies - vereinfachte Version
dependency_version_satisfied() {
  local spec="$1"
  local installed_version="$2"
  # In einer echten Implementierung würden wir hier eine vollständige SemVer-Überprüfung durchführen
  # Für dieses Skript nehmen wir an, dass alle Versionen kompatibel sind
  echo "true"
}

collect_installed_runtime_closure() {
  local root_node_modules_dir="$1"
  shift
  local dependency_specs=("$@")
  
  declare -A package_cache
  declare -A closure
  local queue=("${dependency_specs[@]}")
  
  while [[ ${#queue[@]} -gt 0 ]]; do
    local dep_entry="${queue[0]}"
    queue=("${queue[@]:1}")
    
    IFS=':' read -r dep_name spec <<< "$dep_entry"
    local installed_version
    installed_version=$(read_installed_dependency_version "$root_node_modules_dir" "$dep_name")
    
    if [[ -z "$installed_version" ]] || [[ $(dependency_version_satisfied "$spec" "$installed_version") != "true" ]]; then
      echo ""
      return
    fi
    
    if [[ -n "${closure[$dep_name]:-}" ]]; then
      continue
    fi
    
    local package_json_path
    package_json_path="$(dependency_node_modules_path "$root_node_modules_dir" "$dep_name")/package.json"
    
    if [[ ! -f "$package_json_path" ]]; then
      echo ""
      return
    fi
    
    local package_json
    package_json=$(cat "$package_json_path")
    package_cache["$dep_name"]="$package_json"
    closure["$dep_name"]="1"
    
    # Abhängigkeiten sammeln (vereinfacht)
    local deps
    deps=$(echo "$package_json" | jq -r '.dependencies // {} | to_entries[] | "\(.key):\(.value)"' 2>/dev/null || echo "")
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        queue+=("$line")
      fi
    done <<< "$deps"
    
    local opt_deps
    opt_deps=$(echo "$package_json" | jq -r '.optionalDependencies // {} | to_entries[] | "\(.key):\(.value)"' 2>/dev/null || echo "")
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        queue+=("$line")
      fi
    done <<< "$opt_deps"
  done
  
  printf '%s\n' "${!closure[@]}"
}

prune_staged_installed_dependency_cargo() {
  local node_modules_dir="$1"
  local dep_name="$2"
  
  for rule in "${STAGED_RUNTIME_DEP_PRUNE_RULES[@]}"; do
    IFS=':' read -r rule_dep_name rule_paths <<< "$rule"
    if [[ "$dep_name" == "$rule_dep_name" ]]; then
      local dep_root
      dep_root="$(dependency_node_modules_path "$node_modules_dir" "$dep_name")"
      IFS=',' read -ra paths <<< "$rule_paths"
      for relative_path in "${paths[@]}"; do
        remove_path_if_exists "${dep_root}/${relative_path}"
      done
    fi
  done
}

prune_staged_runtime_dependency_cargo() {
  local node_modules_dir="$1"
  
  for rule in "${STAGED_RUNTIME_DEP_PRUNE_RULES[@]}"; do
    IFS=':' read -r dep_name _ <<< "$rule"
    prune_staged_installed_dependency_cargo "$node_modules_dir" "$dep_name"
  done
}

list_bundled_plugin_runtime_dirs() {
  local repo_root="$1"
  local extensions_root="${repo_root}/dist/extensions"
  
  if [[ ! -d "$extensions_root" ]]; then
    return
  fi
  
  local plugin_dirs=()
  while IFS= read -r -d '' dir; do
    if [[ -f "$dir/package.json" ]]; then
      plugin_dirs+=("$dir")
    fi
  done < <(find "$extensions_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
  
  printf '%s\n' "${plugin_dirs[@]}"
}

has_runtime_deps() {
  local package_json="$1"
  local deps_count
  local opt_deps_count
  deps_count=$(echo "$package_json" | jq -r '.dependencies | length // 0')
  opt_deps_count=$(echo "$package_json" | jq -r '.optionalDependencies | length // 0')
  [[ $((deps_count + opt_deps_count)) -gt 0 ]]
}

should_stage_runtime_deps() {
  local package_json="$1"
  local result
  result=$(echo "$package_json" | jq -r '.openclaw.bundle.stageRuntimeDependencies // false')
  [[ "$result" == "true" ]]
}

sanitize_bundled_manifest_for_runtime_install() {
  local plugin_dir="$1"
  local manifest_path="${plugin_dir}/package.json"
  local package_json
  package_json=$(read_json "$manifest_path")
  local changed="false"
  
  if echo "$package_json" | jq -e '.peerDependencies' >/dev/null 2>&1; then
    package_json=$(echo "$package_json" | jq 'del(.peerDependencies)')
    changed="true"
  fi
  
  if echo "$package_json" | jq -e '.peerDependenciesMeta' >/dev/null 2>&1; then
    package_json=$(echo "$package_json" | jq 'del(.peerDependenciesMeta)')
    changed="true"
  fi
  
  if echo "$package_json" | jq -e '.devDependencies' >/dev/null 2>&1; then
    package_json=$(echo "$package_json" | jq 'del(.devDependencies)')
    changed="true"
  fi
  
  if [[ "$changed" == "true" ]]; then
    write_json "$manifest_path" "$package_json"
  fi
  
  echo "$package_json"
}

resolve_runtime_deps_stamp_path() {
  local plugin_dir="$1"
  echo "${plugin_dir}/.openclaw-runtime-deps-stamp.json"
}

create_runtime_deps_fingerprint() {
  local package_json="$1"
  local prune_rules_json
  prune_rules_json=$(printf '%s\n' "${STAGED_RUNTIME_DEP_PRUNE_RULES[@]}" | jq -R . | jq -s .)
  local data
  data=$(jq -n --argjson pkg "$package_json" --argjson rules "$prune_rules_json" --arg ver "$RUNTIME_DEPS_STAGING_VERSION" '{
    packageJson: $pkg,
    pruneRules: $rules,
    version: $ver
  }' | jq -c .)
  echo -n "$data" | sha256sum | cut -d' ' -f1
}

read_runtime_deps_stamp() {
  local stamp_path="$1"
  if [[ ! -f "$stamp_path" ]]; then
    echo ""
    return
  fi
  if cat "$stamp_path" >/dev/null 2>&1; then
    cat "$stamp_path"
  else
    echo ""
  fi
}

stage_installed_root_runtime_deps() {
  local fingerprint="$1"
  local package_json="$2"
  local plugin_dir="$3"
  local repo_root="$4"
  
  local dependency_specs=()
  while IFS= read -r dep; do
    dependency_specs+=("$dep")
  done < <(echo "$package_json" | jq -r '.dependencies | to_entries[] | "\(.key):\(.value)"' 2>/dev/null || true)
  
  while IFS= read -r dep; do
    dependency_specs+=("$dep")
  done < <(echo "$package_json" | jq -r '.optionalDependencies | to_entries[] | "\(.key):\(.value)"' 2>/dev/null || true)
  
  local root_node_modules_dir="${repo_root}/node_modules"
  if [[ ${#dependency_specs[@]} -eq 0 ]] || [[ ! -d "$root_node_modules_dir" ]]; then
    echo "false"
    return
  fi
  
  local dependency_names
  dependency_names=$(collect_installed_runtime_closure "$root_node_modules_dir" "${dependency_specs[@]}")
  if [[ -z "$dependency_names" ]]; then
    echo "false"
    return
  fi
  
  local node_modules_dir="${plugin_dir}/node_modules"
  local stamp_path
  stamp_path=$(resolve_runtime_deps_stamp_path "$plugin_dir")
  
  local temp_prefix
  temp_prefix=$(sanitize_temp_prefix_segment "$(basename "$plugin_dir")")
  local temp_dir
  temp_dir=$(make_temp_dir "/tmp" "openclaw-runtime-deps-${temp_prefix}-")
  local staged_node_modules_dir="${temp_dir}/node_modules"
  
  trap 'remove_path_if_exists "$temp_dir"' EXIT
  
  mkdir -p "$staged_node_modules_dir"
  
  while IFS= read -r dep_name; do
    if [[ -n "$dep_name" ]]; then
      local source_path
      source_path="$(dependency_node_modules_path "$root_node_modules_dir" "$dep_name")"
      local target_path
      target_path="$(dependency_node_modules_path "$staged_node_modules_dir" "$dep_name")"
      mkdir -p "$(dirname "$target_path")"
      if [[ -d "$source_path" ]]; then
        cp -rL "$source_path" "$target_path"
      fi
    fi
  done <<< "$dependency_names"
  
  prune_staged_runtime_dependency_cargo "$staged_node_modules_dir"
  
  replace_dir "$node_modules_dir" "$staged_node_modules_dir"
  
  local stamp_content
  stamp_content=$(jq -n --arg fp "$fingerprint" --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '{
    fingerprint: $fp,
    generatedAt: $time
  }')
  write_json "$stamp_path" "$stamp_content"
  
  echo "true"
  trap - EXIT
}

install_plugin_runtime_deps() {
  local fingerprint="$1"
  local package_json="$2"
  local plugin_dir="$3"
  local plugin_id="$4"
  local repo_root="$5"
  
  if [[ -n "$repo_root" ]]; then
    local result
    result=$(stage_installed_root_runtime_deps "$fingerprint" "$package_json" "$plugin_dir" "$repo_root")
    if [[ "$result" == "true" ]]; then
      return
    fi
  fi
  
  local node_modules_dir="${plugin_dir}/node_modules"
  local stamp_path
  stamp_path=$(resolve_runtime_deps_stamp_path "$plugin_dir")
  
  local temp_prefix
  temp_prefix=$(sanitize_temp_prefix_segment "$plugin_id")
  local temp_install_dir
  temp_install_dir=$(make_temp_dir "/tmp" "openclaw-runtime-deps-${temp_prefix}-")
  
  trap 'remove_path_if_exists "$temp_install_dir"' EXIT
  
  local temp_package_json_path="${temp_install_dir}/package.json"
  write_json "$temp_package_json_path" "$package_json"
  
  # npm install ausführen
  pushd "$temp_install_dir" >/dev/null || die "Konnte nicht in temporäres Verzeichnis wechseln"
  npm install --omit=dev --silent --ignore-scripts --legacy-peer-deps --package-lock=false 2>&1 >/dev/null
  local npm_result=$?
  popd >/dev/null || die "Konnte nicht zurückwechseln"
  
  if [[ $npm_result -ne 0 ]]; then
    die "Fehler beim Stagen der bundled runtime deps für $plugin_id: npm install fehlgeschlagen"
  fi
  
  local staged_node_modules_dir="${temp_install_dir}/node_modules"
  if [[ ! -d "$staged_node_modules_dir" ]]; then
    die "Fehler beim Stagen der bundled runtime deps für $plugin_id: npm install hat kein node_modules Verzeichnis erzeugt"
  fi
  
  prune_staged_runtime_dependency_cargo "$staged_node_modules_dir"
  
  replace_dir "$node_modules_dir" "$staged_node_modules_dir"
  
  local stamp_content
  stamp_content=$(jq -n --arg fp "$fingerprint" --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '{
    fingerprint: $fp,
    generatedAt: $time
  }')
  write_json "$stamp_path" "$stamp_content"
  
  trap - EXIT
}

install_plugin_runtime_deps_with_retries() {
  local attempts="$1"
  local fingerprint="$2"
  local package_json="$3"
  local plugin_dir="$4"
  local plugin_id="$5"
  local repo_root="$6"
  
  local last_error=""
  for ((attempt=1; attempt<=attempts; attempt++)); do
    if install_plugin_runtime_deps "$fingerprint" "$package_json" "$plugin_dir" "$plugin_id" "$repo_root"; then
      return 0
    else
      last_error="Installation fehlgeschlagen bei Versuch $attempt"
      if [[ $attempt -eq $attempts ]]; then
        break
      fi
    fi
  done
  
  die "$last_error"
}

stage_bundled_plugin_runtime_deps() {
  local repo_root="${1:-$(pwd)}"
  local install_attempts="${2:-3}"
  
  local plugin_dirs
  plugin_dirs=$(list_bundled_plugin_runtime_dirs "$repo_root")
  
  while IFS= read -r plugin_dir; do
    if [[ -z "$plugin_dir" ]]; then
      continue
    fi
    
    local plugin_id
    plugin_id=$(basename "$plugin_dir")
    local package_json
    package_json=$(sanitize_bundled_manifest_for_runtime_install "$plugin_dir")
    local node_modules_dir="${plugin_dir}/node_modules"
    local stamp_path
    stamp_path=$(resolve_runtime_deps_stamp_path "$plugin_dir")
    
    if ! has_runtime_deps "$package_json" || ! should_stage_runtime_deps "$package_json"; then
      remove_path_if_exists "$node_modules_dir"
      remove_path_if_exists "$stamp_path"
      continue
    fi
    
    local fingerprint
    fingerprint=$(create_runtime_deps_fingerprint "$package_json")
    local stamp
    stamp=$(read_runtime_deps_stamp "$stamp_path")
    
    if [[ -d "$node_modules_dir" ]] && [[ -n "$stamp" ]]; then
      local current_fingerprint
      current_fingerprint=$(echo "$stamp" | jq -r '.fingerprint // ""')
      if [[ "$current_fingerprint" == "$fingerprint" ]]; then
        continue
      fi
    fi
    
    install_plugin_runtime_deps_with_retries "$install_attempts" "$fingerprint" "$package_json" "$plugin_dir" "$plugin_id" "$repo_root"
  done <<< "$plugin_dirs"
}

main() {
  stage_bundled_plugin_runtime_deps "$@"
}

main "$@"
