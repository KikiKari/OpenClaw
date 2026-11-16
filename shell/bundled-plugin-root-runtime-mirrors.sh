#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "c63238593b8db884ee63cb0767078dcfa2ada7d2151695065bce095b592227bd", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "shell"}
# bundled-plugin-root-runtime-mirrors.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Globale Variablen
declare -A JS_EXTENSIONS=([.cjs]=1 [.js]=1 [.mjs]=1)

# Funktion zum Lesen einer JSON-Datei und Zurückgeben als assoziatives Array
read_json() {
  local file_path="$1"
  # jq wird benötigt, um JSON zu parsen
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq ist erforderlich, aber nicht installiert." >&2
    exit 1
  fi
  jq -c '.' "$file_path"
}

# Sammelt Laufzeitabhängigkeiten aus package.json
collect_runtime_dependency_specs() {
  local package_json_content="${1:-}"
  declare -A deps_map=()

  if [[ -z "$package_json_content" ]]; then
    echo "{}"
    return
  fi

  # Extrahiere Dependencies und OptionalDependencies
  local deps_json
  deps_json=$(echo "$package_json_content" | jq -c '(.dependencies // {}) + (.optionalDependencies // {})')

  # Iteriere durch alle Schlüssel-Wert-Paare
  local key
  local value
  while IFS=$'\n' read -r line; do
    key=$(echo "$line" | cut -d$'\t' -f1)
    value=$(echo "$line" | cut -d$'\t' -f2)
    if [[ -n "$key" && -n "$value" ]]; then
      deps_map["$key"]="$value"
    fi
  done < <(echo "$deps_json" | jq -r 'to_entries[] | "\(.key)\t\(.value)"')

  # Konvertiere in JSON-Map-Format
  local json_result="{"
  local first=true
  for k in "${!deps_map[@]}"; do
    if [[ "$first" == true ]]; then
      first=false
    else
      json_result+=","
    fi
    json_result+="\"$k\":\"${deps_map[$k]}\""
  done
  json_result+="}"
  echo "$json_result"
}

# Extrahiert Paketnamen aus einem Spezifizierer
package_name_from_specifier() {
  local specifier="$1"

  if [[ -z "$specifier" ]] || [[ "$specifier" == .* ]] || [[ "$specifier" == /* ]] || [[ "$specifier" == node:* ]] || [[ "$specifier" == \#* ]]; then
    echo "null"
    return
  fi

  IFS='/' read -ra parts <<< "$specifier"
  if [[ ${#parts[@]} -eq 0 ]] || [[ -z "${parts[0]}" ]]; then
    echo "null"
    return
  fi

  if [[ "${parts[0]}" == @* ]] && [[ ${#parts[@]} -ge 2 ]]; then
    echo "${parts[0]}/${parts[1]}"
    return
  fi

  echo "${parts[0]}"
}

# Sammelt Pfade zu package.json Dateien innerhalb eines Verzeichnisses
collect_package_json_paths() {
  local root_dir="$1"
  local paths=()

  if [[ ! -d "$root_dir" ]]; then
    echo "[]"
    return
  fi

  while IFS= read -r -d '' dir; do
    local pkg_json="$dir/package.json"
    if [[ -f "$pkg_json" ]]; then
      paths+=("$pkg_json")
    fi
  done < <(find "$root_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

  # Sortieren
  IFS=$'\n' sorted_paths=($(sort <<<"${paths[*]}"))
  unset IFS

  # In JSON-Array konvertieren
  local json_array="["
  local first=true
  for p in "${sorted_paths[@]}"; do
    if [[ "$first" == true ]]; then
      first=false
    else
      json_array+=","
    fi
    json_array+="\"$p\""
  done
  json_array+="]"
  echo "$json_array"
}

# Sammelt Laufzeitabhängigkeiten für gebündelte Plugins
collect_bundled_plugin_runtime_dependency_specs() {
  local bundled_plugins_dir="$1"
  declare -A specs=()
  declare -A all_conflicts=()
  declare -A plugin_ids_per_dep=()
  declare -A spec_values=()

  local pkg_json_paths_json
  pkg_json_paths_json=$(collect_package_json_paths "$bundled_plugins_dir")
  
  # Parsen des JSON-Arrays
  local temp_file
  temp_file=$(mktemp)
  echo "$pkg_json_paths_json" > "$temp_file"
  mapfile -t pkg_json_paths < <(jq -r '.[]' "$temp_file")
  rm -f "$temp_file"

  for package_json_path in "${pkg_json_paths[@]}"; do
    local package_json_content
    package_json_content=$(read_json "$package_json_path")
    local plugin_id
    plugin_id=$(basename "$(dirname "$package_json_path")")

    local deps_json
    deps_json=$(collect_runtime_dependency_specs "$package_json_content")

    # Parsen der Abhängigkeiten
    local dep_name
    local dep_spec
    local deps_temp
    deps_temp=$(mktemp)
    echo "$deps_json" > "$deps_temp"
    while IFS=$'\t' read -r dep_name dep_spec; do
      if [[ -n "$dep_name" && -n "$dep_spec" ]]; then
        if [[ -n "${specs[$dep_name]:-}" ]]; then
          if [[ "${specs[$dep_name]}" != "$dep_spec" ]]; then
            # Konflikt hinzufügen
            if [[ -n "${all_conflicts[$dep_name]:-}" ]]; then
              all_conflicts["$dep_name"]+=",{\"pluginId\":\"$plugin_id\",\"spec\":\"$dep_spec\"}"
            else
              all_conflicts["$dep_name"]="{\"pluginId\":\"$plugin_id\",\"spec\":\"$dep_spec\"}"
            fi
          elif [[ ":${plugin_ids_per_dep[$dep_name]}:" != *":$plugin_id:"* ]]; then
            plugin_ids_per_dep["$dep_name"]+="$plugin_id:"
          fi
        else
          specs["$dep_name"]="$dep_spec"
          plugin_ids_per_dep["$dep_name"]="$plugin_id:"
          spec_values["$dep_name"]="$dep_spec"
        fi
      fi
    done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$deps_temp")
    rm -f "$deps_temp"
  done

  # Ergebnis als JSON zurückgeben
  local result="{"
  local first_entry=true
  for name in "${!specs[@]}"; do
    if [[ "$first_entry" == true ]]; then
      first_entry=false
    else
      result+=","
    fi
    local conflicts="[]"
    if [[ -n "${all_conflicts[$name]:-}" ]]; then
      # Konflikte parsen und formatieren
      local conflict_entries=()
      IFS=',' read -ra conflict_parts <<< "${all_conflicts[$name]}"
      for part in "${conflict_parts[@]}"; do
        conflict_entries+=("$part")
      done
      conflicts="[$(IFS=','; echo "${conflict_entries[*]}")]"
    fi
    local plugin_ids_cleaned
    plugin_ids_cleaned=$(echo "${plugin_ids_per_dep[$name]}" | sed 's/:$//' | tr ':' '\n' | sort | uniq)
    local plugin_ids_json
    plugin_ids_json=$(printf '%s\n' $plugin_ids_cleaned | jq -R . | jq -s .)
    result+="\"$name\":{\"conflicts\":$conflicts,\"pluginIds\":$plugin_ids_json,\"spec\":\"${specs[$name]}\"}"
  done
  result+="}"
  echo "$result"
}

# Durchläuft JavaScript-Dateien rekursiv
walk_javascript_files() {
  local root_dir="$1"
  local files=()

  if [[ ! -d "$root_dir" ]]; then
    echo "[]"
    return
  fi

  while IFS= read -r -d '' file; do
    local ext="${file##*.}"
    if [[ -n "${JS_EXTENSIONS[.$ext]:-}" ]]; then
      # Prüfen, ob der Pfad "extensions" enthält
      if [[ "$file" != *"extensions"* ]]; then
        files+=("$file")
      fi
    fi
  done < <(find "$root_dir" -type f -print0 2>/dev/null)

  # Sortieren
  IFS=$'\n' sorted_files=($(sort <<<"${files[*]}"))
  unset IFS

  # In JSON-Array konvertieren
  local json_array="["
  local first=true
  for f in "${sorted_files[@]}"; do
    if [[ "$first" == true ]]; then
      first=false
    else
      json_array+=","
    fi
    json_array+="\"$f\""
  done
  json_array+="]"
  echo "$json_array"
}

# Extrahiert Modul-Spezifizierer aus dem Quelltext
extract_module_specifiers() {
  local source="$1"
  local specifiers=()

  # Muster anwenden
  while IFS= read -r line; do
    specifiers+=("$line")
  done < <(grep -oP '(?<=\bfrom\s*["'"'"'])[^"'"'"']+(?=["'"'"'])' <<< "$source" 2>/dev/null || true)
  
  while IFS= read -r line; do
    specifiers+=("$line")
  done < <(grep -oP '(?<=\bimport\s*["'"'"'])[^"'"'"']+(?=["'"'"'])' <<< "$source" 2>/dev/null || true)
  
  while IFS= read -r line; do
    specifiers+=("$line")
  done < <(grep -oP '(?<=\bimport\s*\(\s*["'"'"'])[^"'"'"']+(?=\s*["'"'"']\s*\))' <<< "$source" 2>/dev/null || true)
  
  while IFS= read -r line; do
    specifiers+=("$line")
  done < <(grep -oP '(?<=\brequire\s*\(\s*["'"'"'])[^"'"'"']+(?=\s*["'"'"']\s*\))' <<< "$source" 2>/dev/null || true)

  # Eindeutige Specifiers
  local unique_specifiers=($(printf '%s\n' "${specifiers[@]}" | sort -u))

  # In JSON-Array konvertieren
  local json_array="["
  local first=true
  for s in "${unique_specifiers[@]}"; do
    if [[ -n "$s" ]]; then
      if [[ "$first" == true ]]; then
        first=false
      else
        json_array+=","
      fi
      json_array+="\"$s\""
    fi
  done
  json_array+="]"
  echo "$json_array"
}

# Sammelt Spiegelungen von gebündelten Plugin-Laufzeitabhängigkeiten im Root-Dist
collect_root_dist_bundled_runtime_mirrors() {
  local dist_dir="$1"
  local bundled_specs_json="$2"
  
  declare -A mirrors=()
  declare -A bundled_specs_map=()
  declare -A plugin_ids_map=()
  declare -A spec_map=()

  # Parse bundled specs
  local bundled_specs_temp
  bundled_specs_temp=$(mktemp)
  echo "$bundled_specs_json" > "$bundled_specs_temp"
  while IFS=$'\t' read -r name bundled_data; do
    bundled_specs_map["$name"]=1
    plugin_ids_map["$name"]=$(echo "$bundled_data" | jq -r '.pluginIds[]' 2>/dev/null | paste -sd "," -)
    spec_map["$name"]=$(echo "$bundled_data" | jq -r '.spec')
  done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$bundled_specs_temp")
  rm -f "$bundled_specs_temp"

  local js_files_json
  js_files_json=$(walk_javascript_files "$dist_dir")
  
  local js_files_temp
  js_files_temp=$(mktemp)
  echo "$js_files_json" > "$js_files_temp"
  mapfile -t js_files < <(jq -r '.[]' "$js_files_temp")
  rm -f "$js_files_temp"

  for file_path in "${js_files[@]}"; do
    local source
    source=$(cat "$file_path")
    local relative_path
    relative_path=$(realpath --relative-to="$dist_dir" "$file_path" 2>/dev/null || echo "$file_path")
    relative_path=${relative_path//\\/\/}

    local specifiers_json
    specifiers_json=$(extract_module_specifiers "$source")
    
    local specifiers_temp
    specifiers_temp=$(mktemp)
    echo "$specifiers_json" > "$specifiers_temp"
    mapfile -t specifiers < <(jq -r '.[]' "$specifiers_temp")
    rm -f "$specifiers_temp"

    for specifier in "${specifiers[@]}"; do
      local dependency_name
      dependency_name=$(package_name_from_specifier "$specifier")
      
      if [[ "$dependency_name" == "null" ]] || [[ -z "${bundled_specs_map[$dependency_name]:-}" ]]; then
        continue
      fi
      
      local bundled_spec_plugin_ids="${plugin_ids_map[$dependency_name]}"
      local bundled_spec_spec="${spec_map[$dependency_name]}"
      
      if [[ -n "${mirrors[$dependency_name]:-}" ]]; then
        # Importer hinzufügen
        local current_importers
        current_importers=$(echo "${mirrors[$dependency_name]}" | jq -r '.importers[]')
        if ! grep -q "^$relative_path$" <<< "$current_importers"; then
          local updated_importers
          updated_importers=$(printf "%s\n%s" "$current_importers" "$relative_path" | sort -u)
          local importers_json
          importers_json=$(printf '%s\n' $updated_importers | jq -R . | jq -s .)
          local plugin_ids_json
          plugin_ids_json=$(echo "$bundled_spec_plugin_ids" | jq -R . | jq -s .)
          mirrors["$dependency_name"]="{\"importers\":$importers_json,\"pluginIds\":$plugin_ids_json,\"spec\":\"$bundled_spec_spec\"}"
        fi
      else
        local importers_json
        importers_json=$(printf '%s\n' "$relative_path" | jq -R . | jq -s .)
        local plugin_ids_json
        plugin_ids_json=$(echo "$bundled_spec_plugin_ids" | tr ',' '\n' | jq -R . | jq -s .)
        mirrors["$dependency_name"]="{\"importers\":$importers_json,\"pluginIds\":$plugin_ids_json,\"spec\":\"$bundled_spec_spec\"}"
      fi
    done
  done

  # Ergebnis als JSON zurückgeben
  local result="{"
  local first_entry=true
  for name in "${!mirrors[@]}"; do
    if [[ "$first_entry" == true ]]; then
      first_entry=false
    else
      result+=","
    fi
    result+="\"$name\":${mirrors[$name]}"
  done
  result+="}"
  echo "$result"
}

# Sammelt Fehler bei Spiegelungen von gebündelten Plugin-Laufzeitabhängigkeiten
collect_bundled_plugin_root_runtime_mirror_errors() {
  local root_package_json_content="$1"
  local bundled_runtime_dependency_specs_json="$2"
  local required_root_mirrors_json="$3"
  local errors=()

  # Root-Laufzeitabhängigkeiten sammeln
  local root_runtime_deps_json
  root_runtime_deps_json=$(collect_runtime_dependency_specs "$root_package_json_content")
  
  declare -A root_runtime_deps=()
  local root_runtime_temp
  root_runtime_temp=$(mktemp)
  echo "$root_runtime_deps_json" > "$root_runtime_temp"
  while IFS=$'\t' read -r name spec; do
    root_runtime_deps["$name"]="$spec"
  done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$root_runtime_temp")
  rm -f "$root_runtime_temp"

  # Konflikte prüfen
  local bundled_specs_temp
  bundled_specs_temp=$(mktemp)
  echo "$bundled_runtime_dependency_specs_json" > "$bundled_specs_temp"
  while IFS=$'\t' read -r dependency_name record_data; do
    local conflicts_json
    conflicts_json=$(echo "$record_data" | jq -r '.conflicts // []')
    if [[ "$conflicts_json" != "[]" ]]; then
      local plugin_ids
      plugin_ids=$(echo "$record_data" | jq -r '.pluginIds | join(", ")')
      local spec
      spec=$(echo "$record_data" | jq -r '.spec')
      
      local conflicts_temp
      conflicts_temp=$(mktemp)
      echo "$conflicts_json" > "$conflicts_temp"
      while IFS=$'\t' read -r conflict_plugin_id conflict_spec; do
        errors+=("bundled runtime dependency '$dependency_name' has conflicting plugin specs: $plugin_ids use '$spec', $conflict_plugin_id uses '$conflict_spec'.")
      done < <(jq -r '.[] | "\(.pluginId)\t\(.spec)"' "$conflicts_temp")
      rm -f "$conflicts_temp"
    fi
  done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$bundled_specs_temp")
  rm -f "$bundled_specs_temp"

  # Required Root Mirrors prüfen
  local required_mirrors_temp
  required_mirrors_temp=$(mktemp)
  echo "$required_root_mirrors_json" > "$required_mirrors_temp"
  while IFS=$'\t' read -r dependency_name mirror_data; do
    local root_spec="${root_runtime_deps[$dependency_name]:-}"
    local importers_list
    importers_list=$(echo "$mirror_data" | jq -r '.importers | sort | join(", ")')
    local plugin_label
    plugin_label=$(echo "$mirror_data" | jq -r '.pluginIds | sort | join(", ")')
    
    if [[ -z "$root_spec" ]]; then
      local spec
      spec=$(echo "$mirror_data" | jq -r '.spec')
      errors+=("root dist imports bundled plugin runtime dependency '$dependency_name' from $importers_list; mirror '$dependency_name: $spec' in root package.json (declared by $plugin_label).")
    else
      local mirror_spec
      mirror_spec=$(echo "$mirror_data" | jq -r '.spec')
      if [[ "$root_spec" != "$mirror_spec" ]]; then
        errors+=("root dist imports bundled plugin runtime dependency '$dependency_name' from $importers_list; root package.json has '$root_spec' but plugin manifest declares '$mirror_spec' ($plugin_label).")
      fi
    fi
  done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$required_mirrors_temp")
  rm -f "$required_mirrors_temp"

  # In JSON-Array konvertieren
  local json_array="["
  local first=true
  for error in "${errors[@]}"; do
    if [[ "$first" == true ]]; then
      first=false
    else
      json_array+=","
    fi
    json_array+="\"$error\""
  done
  json_array+="]"
  echo "$json_array"
}
