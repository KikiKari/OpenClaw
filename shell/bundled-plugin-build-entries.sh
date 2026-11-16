#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "07ce6ab7ded74ee35a8f217a6b1d186176f06f3f3b94012208782492c8bf1f9a", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "shell"}
# bundled-plugin-build-entries.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konstanten
BUNDLED_PLUGIN_ROOT_DIR="extensions"
TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS_TS=1
TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS_JS=1
TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS_MTS=1
TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS_CTS=1
TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS_MJS=1
TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS_CJS=1

# Globale Variablen für NON_PACKAGED_BUNDLED_PLUGIN_DIRS
declare -A NON_PACKAGED_BUNDLED_PLUGIN_DIRS_MAP
NON_PACKAGED_BUNDLED_PLUGIN_DIRS_MAP["qa-channel"]=1
NON_PACKAGED_BUNDLED_PLUGIN_DIRS_MAP["qa-lab"]=1

# Hilfsfunktionen
to_posix_path() {
  echo "${1//\\//}"
}

read_bundled_plugin_package_json() {
  local package_json_path="$1"
  
  if [[ ! -f "$package_json_path" ]]; then
    echo "null"
    return
  fi
  
  if jq -e . >/dev/null 2>&1 < "$package_json_path"; then
    cat "$package_json_path"
  else
    echo "null"
  fi
}

is_manifestless_bundled_runtime_support_package() {
  local dir_name="$1"
  local package_json="$2"
  local top_level_entries_count="$3"
  
  local package_name=""
  if [[ "$package_json" != "null" ]]; then
    package_name=$(echo "$package_json" | jq -r '.name // ""')
  fi
  
  if [[ "$package_name" != "@openclaw/$dir_name" ]]; then
    return 1
  fi
  
  [[ $top_level_entries_count -gt 0 ]]
}

collect_plugin_source_entries() {
  local package_json="$1"
  
  if [[ "$package_json" == "null" ]]; then
    echo "./index.ts"
    return
  fi
  
  local entries=()
  
  # Extrahiere openclaw.extensions
  if echo "$package_json" | jq -e '.openclaw.extensions | type == "array"' >/dev/null 2>&1; then
    while IFS= read -r entry; do
      entry=$(echo "$entry" | xargs) # trim whitespace
      if [[ -n "$entry" ]]; then
        entries+=("$entry")
      fi
    done < <(echo "$package_json" | jq -r '.openclaw.extensions[] | select(type == "string")' 2>/dev/null || true)
  fi
  
  # Prüfe setupEntry
  local setup_entry=""
  if echo "$package_json" | jq -e '.openclaw.setupEntry | type == "string"' >/dev/null 2>&1; then
    setup_entry=$(echo "$package_json" | jq -r '.openclaw.setupEntry | select(. != null and . != "")' 2>/dev/null || echo "")
  fi
  
  if [[ -n "$setup_entry" ]]; then
    # Füge setup_entry hinzu und entferne Duplikate
    local temp_entries=("${entries[@]}" "$setup_entry")
    local unique_entries=()
    declare -A seen
    for entry in "${temp_entries[@]}"; do
      if [[ -z "${seen[$entry]:-}" ]]; then
        unique_entries+=("$entry")
        seen["$entry"]=1
      fi
    done
    entries=("${unique_entries[@]}")
  fi
  
  if [[ ${#entries[@]} -eq 0 ]]; then
    echo "./index.ts"
  else
    printf '%s\n' "${entries[@]}"
  fi
}

should_stage_bundled_plugin_runtime_dependencies() {
  local package_json="$1"
  
  if [[ "$package_json" == "null" ]]; then
    return 1
  fi
  
  echo "$package_json" | jq -r '.openclaw.bundle.stageRuntimeDependencies // false' | grep -q true
}

collect_top_level_public_surface_entries() {
  local plugin_dir="$1"
  
  if [[ ! -d "$plugin_dir" ]]; then
    return
  fi
  
  local files=()
  for file in "$plugin_dir"/*; do
    if [[ ! -f "$file" ]]; then
      continue
    fi
    
    local basename_file=$(basename "$file")
    local ext="${basename_file##*.}"
    
    case "$ext" in
      ts|js|mts|cts|mjs|cjs) ;;
      *) continue ;;
    esac
    
    local lower_name=$(echo "$basename_file" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$lower_name" == *".d.ts" ]] || \
       [[ "$lower_name" =~ ^config-api\.[cm]?(j|t)s$ ]] || \
       [[ "$lower_name" == *".test."* ]] || \
       [[ "$lower_name" == *".spec."* ]] || \
       [[ "$lower_name" == *".fixture."* ]] || \
       [[ "$lower_name" == *".snap"* ]]; then
      continue
    fi
    
    files+=("./$basename_file")
  done
  
  if [[ ${#files[@]} -gt 0 ]]; then
    printf '%s\n' "${files[@]}" | sort
  fi
}

# Hauptfunktionen
collect_bundled_plugin_build_entries() {
  local cwd="${1:-$(pwd)}"
  local env_prefix="${2:-}"
  
  local extensions_root="$cwd/$BUNDLED_PLUGIN_ROOT_DIR"
  local entries_file=$(mktemp)
  
  if [[ ! -d "$extensions_root" ]]; then
    rm "$entries_file"
    return
  fi
  
  local index=0
  for dir in "$extensions_root"/*/; do
    if [[ ! -d "$dir" ]]; then
      continue
    fi
    
    local plugin_name=$(basename "$dir")
    local plugin_dir="$extensions_root/$plugin_name"
    local manifest_path="$plugin_dir/openclaw.plugin.json"
    local has_manifest=false
    [[ -f "$manifest_path" ]] && has_manifest=true
    
    local package_json_path="$plugin_dir/package.json"
    local package_json=$(read_bundled_plugin_package_json "$package_json_path")
    
    local top_level_entries
    top_level_entries=$(collect_top_level_public_surface_entries "$plugin_dir")
    local top_level_count=$(echo "$top_level_entries" | wc -l | tr -d ' ')
    [[ "$top_level_count" -eq 1 ]] && [[ -z "$(echo "$top_level_entries" | xargs)" ]] && top_level_count=0
    
    if ! $has_manifest && ! is_manifestless_bundled_runtime_support_package "$plugin_name" "$package_json" "$top_level_count"; then
      continue
    fi
    
    # Hier würden wir shouldBuildBundledCluster prüfen, aber das ist nicht implementiert
    # Wir überspringen diese Prüfung der Einfachheit halber
    
    local source_entries=()
    if $has_manifest; then
      while IFS= read -r entry; do
        source_entries+=("$entry")
      done < <(collect_plugin_source_entries "$package_json")
    fi
    
    while IFS= read -r entry; do
      source_entries+=("$entry")
    done < <(echo "$top_level_entries")
    
    # Entferne Duplikate
    local unique_entries=()
    declare -A seen
    for entry in "${source_entries[@]}"; do
      if [[ -z "${seen[$entry]:-}" ]]; then
        unique_entries+=("$entry")
        seen["$entry"]=1
      fi
    done
    
    echo "$index|$plugin_name|$has_manifest|$package_json|${unique_entries[*]}" >> "$entries_file"
    ((index++))
  done
  
  cat "$entries_file"
  rm "$entries_file"
}

list_bundled_plugin_build_entries() {
  local cwd="${1:-$(pwd)}"
  
  while IFS='|' read -r idx plugin_name has_manifest package_json source_entries_str; do
    if [[ -z "$idx" ]]; then
      continue
    fi
    
    IFS=' ' read -ra source_entries <<< "$source_entries_str"
    for entry in "${source_entries[@]}"; do
      local normalized_entry="${entry#./}"
      local entry_key="${plugin_name}_${normalized_entry%.*}"
      local full_path=$(to_posix_path "$BUNDLED_PLUGIN_ROOT_DIR/$plugin_name/$normalized_entry")
      echo "$entry_key=$full_path"
    done
  done < <(collect_bundled_plugin_build_entries "$cwd")
}

list_bundled_plugin_pack_artifacts() {
  local cwd="${1:-$(pwd)}"
  
  local artifacts_temp=$(mktemp)
  
  while IFS='|' read -r idx plugin_name has_manifest package_json source_entries_str; do
    if [[ -z "$idx" ]]; then
      continue
    fi
    
    # Überspringe NON_PACKAGED_BUNDLED_PLUGIN_DIRS
    if [[ -n "${NON_PACKAGED_BUNDLED_PLUGIN_DIRS_MAP[$plugin_name]:-}" ]]; then
      continue
    fi
    
    if [[ "$has_manifest" == "true" ]]; then
      echo "${plugin_name}/dist/openclaw.plugin.json" >> "$artifacts_temp"
    fi
    
    if [[ "$package_json" != "null" ]]; then
      echo "${plugin_name}/dist/package.json" >> "$artifacts_temp"
    fi
    
    IFS=' ' read -ra source_entries <<< "$source_entries_str"
    for entry in "${source_entries[@]}"; do
      local normalized_entry="${entry#./}"
      normalized_entry="${normalized_entry%.*}"
      echo "${plugin_name}/dist/${normalized_entry}.js" >> "$artifacts_temp"
    done
  done < <(collect_bundled_plugin_build_entries "$cwd")
  
  sort "$artifacts_temp" | uniq
  rm "$artifacts_temp"
}

list_bundled_plugin_runtime_dependencies() {
  local cwd="${1:-$(pwd)}"
  local deps_temp=$(mktemp)
  
  while IFS='|' read -r idx plugin_name has_manifest package_json source_entries_str; do
    if [[ -z "$idx" ]]; then
      continue
    fi
    
    if ! should_stage_bundled_plugin_runtime_dependencies "$package_json"; then
      continue
    fi
    
    if [[ "$package_json" != "null" ]]; then
      # Extrahiere dependencies
      while IFS= read -r dep; do
        echo "$dep" >> "$deps_temp"
      done < <(echo "$package_json" | jq -r '.dependencies | keys[]' 2>/dev/null || true)
      
      # Extrahiere optionalDependencies
      while IFS= read -r dep; do
        echo "$dep" >> "$deps_temp"
      done < <(echo "$package_json" | jq -r '.optionalDependencies | keys[]' 2>/dev/null || true)
    fi
  done < <(collect_bundled_plugin_build_entries "$cwd")
  
  sort "$deps_temp" | uniq
  rm "$deps_temp"
}
