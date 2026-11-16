#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "324cdd7006ecca71c638cff0431cd9e36ca19a70b2120049feacbde078788f73", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "shell"}
# changed-extensions.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konfiguration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLED_PLUGIN_ROOT_DIR="packages/extensions"
BUNDLED_PLUGIN_PATH_PREFIX="$BUNDLED_PLUGIN_ROOT_DIR/"

# Funktion zum Ausführen von Git-Befehlen im Repository-Stammverzeichnis
run_git() {
  local args=("$@")
  git -C "$REPO_ROOT" "${args[@]}"
}

# Funktion zur Normalisierung von Pfaden (ersetzt Backslashes durch Slashes)
normalize_relative() {
  local input_path="$1"
  echo "${input_path//\\/\/}"
}

# Prüft, ob ein Git-Commit existiert
has_git_commit() {
  local ref="$1"
  if [[ -z "$ref" ]] || [[ "$ref" =~ ^0+$ ]]; then
    return 1
  fi

  if run_git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Bestimmt die Basis für geänderte Pfade
resolve_changed_paths_base() {
  local base="${1:-}"
  local head="${2:-HEAD}"
  local fallback_base_ref="${3:-}"

  if has_git_commit "$base"; then
    echo "$base"
    return
  fi

  if [[ -n "$fallback_base_ref" ]]; then
    local remote_base_ref
    if [[ "$fallback_base_ref" == origin/* ]]; then
      remote_base_ref="$fallback_base_ref"
    else
      remote_base_ref="origin/$fallback_base_ref"
    fi

    if has_git_commit "$remote_base_ref"; then
      local merge_base
      merge_base=$(run_git merge-base "$remote_base_ref" "$head" 2>/dev/null) || return 1
      merge_base=$(echo "$merge_base" | xargs) # trim whitespace
      if has_git_commit "$merge_base"; then
        echo "$merge_base"
        return
      fi
    fi
  fi

  if [[ -z "$base" ]]; then
    echo "A git base revision is required to list changed extensions." >&2
    exit 1
  fi

  echo "Git base revision is unavailable locally: $base" >&2
  exit 1
}

# Listet geänderte Pfade zwischen zwei Commits auf
list_changed_paths() {
  local base="$1"
  local head="${2:-HEAD}"

  if [[ -z "$base" ]]; then
    echo "A git base revision is required to list changed extensions." >&2
    exit 1
  fi

  run_git diff --name-only "$base" "$head" | grep -v '^$'
}

# Prüft, ob ein Extension-Package existiert
has_extension_package() {
  local extension_id="$1"
  local package_json_path="$REPO_ROOT/$BUNDLED_PLUGIN_ROOT_DIR/$extension_id/package.json"
  [[ -f "$package_json_path" ]]
}

# Listet alle verfügbaren Extension-IDs auf
list_available_extension_ids() {
  local extensions_dir="$REPO_ROOT/$BUNDLED_PLUGIN_ROOT_DIR"
  if [[ ! -d "$extensions_dir" ]]; then
    return
  fi

  local ids=()
  while IFS= read -r dir; do
    if [[ -d "$extensions_dir/$dir" ]] && has_extension_package "$dir"; then
      ids+=("$dir")
    fi
  done < <(find "$extensions_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

  printf '%s\n' "${ids[@]}" | sort
}

# Erkennt geänderte Extension-IDs anhand der geänderten Pfade
detect_changed_extension_ids() {
  local changed_paths="$1"
  local extension_ids=()

  while IFS= read -r raw_path; do
    raw_path=$(echo "$raw_path" | xargs) # trim whitespace
    if [[ -z "$raw_path" ]]; then
      continue
    fi

    local relative_path
    relative_path=$(normalize_relative "$raw_path")

    # Match für Extensions im BUNDLED_PLUGIN_PATH_PREFIX
    if [[ "$relative_path" =~ ^$BUNDLED_PLUGIN_PATH_PREFIX([^/]+)(/|$) ]]; then
      local extension_id="${BASH_REMATCH[1]}"
      if has_extension_package "$extension_id"; then
        extension_ids+=("$extension_id")
      fi
      continue
    fi

    # Match für Core-Dateien im src/-Verzeichnis
    if [[ "$relative_path" =~ ^src/([^/]+)(/|$) ]]; then
      local core_id="${BASH_REMATCH[1]}"
      if has_extension_package "$core_id"; then
        extension_ids+=("$core_id")
      fi
    fi
  done <<< "$changed_paths"

  # Entferne Duplikate und sortiere
  printf '%s\n' "${extension_ids[@]}" | sort -u
}

# Hauptfunktion zur Bestimmung geänderter Extension-IDs
list_changed_extension_ids() {
  local base="${1:-}"
  local head="${2:-HEAD}"
  local unavailable_base_behavior="${3:-error}"

  local resolved_base
  if resolved_base=$(resolve_changed_paths_base "$base" "$head" "" 2>/dev/null); then
    local changed_paths
    changed_paths=$(list_changed_paths "$resolved_base" "$head")
    detect_changed_extension_ids "$changed_paths"
  else
    case "$unavailable_base_behavior" in
      all)
        list_available_extension_ids
        ;;
      empty)
        # Gibt nichts aus
        ;;
      *)
        echo "Git base revision is unavailable locally: $base" >&2
        exit 1
        ;;
    esac
  fi
}
