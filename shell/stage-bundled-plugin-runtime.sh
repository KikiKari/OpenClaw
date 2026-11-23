#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "83140ca803011666fca0ac14f1f472f62ba1abb6f3818312b76226de62217227", "source_sha256": "dc65d4759ce1efe8d0c6f037b64d65c1aa1f73b83a3cd928ceebdaf24ed53da6", "target_language": "shell"}
# stage-bundled-plugin-runtime.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Import shared functions (simulated)
source "$(dirname "${BASH_SOURCE[0]}")/runtime-postbuild-shared.sh"

symlink_type() {
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "junction"
  else
    echo "dir"
  fi
}

relative_symlink_target() {
  local source_path="$1"
  local target_path="$2"
  local target_dir
  target_dir="$(dirname "$target_path")"
  local relative_target
  relative_target="$(realpath --relative-to="$target_dir" "$source_path" 2>/dev/null)" || {
    echo "."
    return
  }
  echo "${relative_target:-.}"
}

should_fallback_to_copy() {
  local error_code="${1:-}"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]] && \
     [[ "$error_code" == "EPERM" || "$error_code" == "EINVAL" || "$error_code" == "UNKNOWN" ]]; then
    return 0
  fi
  return 1
}

copy_path_fallback() {
  local source_path="$1"
  local target_path="$2"
  
  remove_path_if_exists "$target_path"
  
  local target_dir
  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir"
  
  if [[ -d "$source_path" ]]; then
    cp -r "$source_path" "$target_path"
    return
  fi
  
  cp "$source_path" "$target_path"
}

ensure_symlink() {
  local target_value="$1"
  local target_path="$2"
  local type="${3:-}"
  local fallback_source_path="${4:-}"
  
  # Try to create symlink first
  if [[ "$type" == "junction" ]]; then
    # On Windows, we might need to use mklink or other approaches
    # For now, we'll fall back to copying if needed
    ln -sf "$target_value" "$target_path" 2>/dev/null || {
      local error_code=$?
      if [[ -n "$fallback_source_path" ]] && should_fallback_to_copy "$error_code"; then
        copy_path_fallback "$fallback_source_path" "$target_path"
        return
      elif [[ $error_code -ne 0 && ! -e "$target_path" ]]; then
        return $error_code
      fi
    }
  else
    ln -sf "$target_value" "$target_path" 2>/dev/null || {
      local error_code=$?
      if [[ -n "$fallback_source_path" ]] && should_fallback_to_copy "$error_code"; then
        copy_path_fallback "$fallback_source_path" "$target_path"
        return
      elif [[ $error_code -ne 0 && ! -e "$target_path" ]]; then
        return $error_code
      fi
    }
  fi
  
  # Check if existing symlink matches what we want
  if [[ -L "$target_path" ]]; then
    local current_target
    current_target=$(readlink "$target_path")
    if [[ "$current_target" == "$target_value" ]]; then
      return
    fi
  fi
  
  # Remove and recreate if mismatched or not a symlink
  remove_path_if_exists "$target_path"
  
  if [[ "$type" == "junction" ]]; then
    ln -sf "$target_value" "$target_path" 2>/dev/null || {
      local error_code=$?
      if [[ -n "$fallback_source_path" ]] && should_fallback_to_copy "$error_code"; then
        copy_path_fallback "$fallback_source_path" "$target_path"
        return
      else
        return $error_code
      fi
    }
  else
    ln -sf "$target_value" "$target_path"
  fi
}

symlink_path() {
  local source_path="$1"
  local target_path="$2"
  local type="${3:-}"
  local target_value
  target_value=$(relative_symlink_target "$source_path" "$target_path")
  ensure_symlink "$target_value" "$target_path" "$type" "$source_path"
}

should_wrap_runtime_js_file() {
  local source_path="$1"
  [[ "${source_path##*.}" == "js" ]]
}

should_copy_runtime_file() {
  local source_path="$1"
  local relative_path
  relative_path="${source_path//\\//}"
  
  [[ "$relative_path" == */package.json ]] || \
  [[ "$relative_path" == */openclaw.plugin.json ]] || \
  [[ "$relative_path" == */.codex-plugin/plugin.json ]] || \
  [[ "$relative_path" == */.claude-plugin/plugin.json ]] || \
  [[ "$relative_path" == */.cursor-plugin/plugin.json ]] || \
  [[ "$relative_path" == */SKILL.md ]]
}

write_runtime_module_wrapper() {
  local source_path="$1"
  local target_path="$2"
  local specifier
  specifier=$(relative_symlink_target "$source_path" "$target_path")
  specifier="${specifier//\\//}"
  
  if [[ ! "$specifier" =~ ^\.* ]]; then
    specifier="./$specifier"
  fi
  
  cat > "$target_path" <<EOF
export * from ${specifier@Q};
import * as module from ${specifier@Q};
export default module.default;

EOF
}

stage_plugin_runtime_overlay() {
  local source_dir="$1"
  local target_dir="$2"
  
  mkdir -p "$target_dir"
  
  local item
  for item in "$source_dir"/*; do
    if [[ ! -e "$item" ]]; then
      continue
    fi
    
    local name
    name=$(basename "$item")
    
    if [[ "$name" == "node_modules" ]]; then
      continue
    fi
    
    local source_path="$item"
    local target_path="$target_dir/$name"
    
    if [[ -d "$source_path" ]]; then
      stage_plugin_runtime_overlay "$source_path" "$target_path"
      continue
    fi
    
    if [[ -L "$source_path" ]]; then
      local link_target
      link_target=$(readlink "$source_path")
      ensure_symlink "$link_target" "$target_path" "" "$source_path"
      continue
    fi
    
    if [[ ! -f "$source_path" ]]; then
      continue
    fi
    
    if should_wrap_runtime_js_file "$source_path"; then
      write_runtime_module_wrapper "$source_path" "$target_path"
      continue
    fi
    
    if should_copy_runtime_file "$source_path"; then
      cp "$source_path" "$target_path"
      continue
    fi
    
    symlink_path "$source_path" "$target_path" "$(symlink_type)"
  done
}

link_plugin_node_modules() {
  local runtime_plugin_dir="$1"
  local source_plugin_node_modules_dir="$2"
  
  local runtime_node_modules_dir="$runtime_plugin_dir/node_modules"
  remove_path_if_exists "$runtime_node_modules_dir"
  
  if [[ ! -d "$source_plugin_node_modules_dir" ]]; then
    return
  fi
  
  ensure_symlink "$source_plugin_node_modules_dir" "$runtime_node_modules_dir" "$(symlink_type)" "$source_plugin_node_modules_dir"
}

stage_bundled_plugin_runtime() {
  local cwd="${1:-$(pwd)}"
  
  local repo_root="$cwd"
  local dist_root="$repo_root/dist"
  local runtime_root="$repo_root/dist-runtime"
  local dist_extensions_root="$dist_root/extensions"
  local runtime_extensions_root="$runtime_root/extensions"
  
  if [[ ! -d "$dist_extensions_root" ]]; then
    remove_path_if_exists "$runtime_root"
    return
  fi
  
  remove_path_if_exists "$runtime_root"
  mkdir -p "$runtime_extensions_root"
  
  local plugin_dir
  for plugin_dir in "$dist_extensions_root"/*/; do
    if [[ ! -d "$plugin_dir" ]]; then
      continue
    fi
    
    local plugin_name
    plugin_name=$(basename "$plugin_dir")
    local runtime_plugin_dir="$runtime_extensions_root/$plugin_name"
    local dist_plugin_node_modules_dir="$plugin_dir/node_modules"
    
    stage_plugin_runtime_overlay "$plugin_dir" "$runtime_plugin_dir"
    link_plugin_node_modules "$runtime_plugin_dir" "$dist_plugin_node_modules_dir"
  done
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  stage_bundled_plugin_runtime
fi
