#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "e800e87ae5201c570d88f3e5d47063222c546e3dc3d12814a8a3761279b2dcb2", "source_sha256": "b77d7ac77e305afea60b0aa9579426471649732bc9d7cb3bce3f14575d0d0bb6", "target_language": "shell"}
# check-no-raw-window-open.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-raw-window-open.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This script checks for raw window.open calls in TypeScript files
# and ensures they use the safe wrapper instead.

# Find the repository root (assuming script is in a subdirectory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Walk up directory tree to find package.json or .git
while [[ "$REPO_ROOT" != "/" ]]; do
  if [[ -f "$REPO_ROOT/package.json" ]] || [[ -d "$REPO_ROOT/.git" ]]; then
    break
  fi
  REPO_ROOT="$(dirname "$REPO_ROOT")"
done

UI_SOURCE_DIR="$REPO_ROOT/ui/src/ui"
ALLOWED_CALLSITE="$UI_SOURCE_DIR/open-external-url.ts"

# Function to check if a file contains raw window.open calls
check_file_for_violations() {
  local file_path="$1"
  local rel_path="${file_path#$REPO_ROOT/}"
  
  # Skip allowed callsite
  if [[ "$file_path" == "$ALLOWED_CALLSITE" ]]; then
    return 0
  fi
  
  # Search for raw window.open or globalThis.open patterns
  # This looks for calls that are not part of object method chains
  # and match window.open or globalThis.open directly
  local violations=()
  
  while IFS= read -r line_num || [[ -n "$line_num" ]]; do
    if [[ -n "$line_num" ]]; then
      violations+=("$rel_path:$line_num")
    fi
  done < <(grep -nE '\b(window|globalThis)\.open\s*\(' "$file_path" | grep -v '^\s*[a-zA-Z0-9_]+\.' | cut -d: -f1)
  
  # Output violations if found
  if [[ ${#violations[@]} -gt 0 ]]; then
    printf '%s\n' "${violations[@]}"
  fi
}

# Collect all TypeScript files in the UI source directory
mapfile -t ts_files < <(find "$UI_SOURCE_DIR" -name "*.ts" -not -name "*.d.ts")

# Also include test files with specific suffixes
mapfile -t test_files < <(find "$UI_SOURCE_DIR" \( -name "*.browser.test.ts" -o -name "*.node.test.ts" \))

# Combine all files
all_files=("${ts_files[@]}" "${test_files[@]}")

# Remove duplicates by converting to associative array and back
declare -A unique_files
for f in "${all_files[@]}"; do
  unique_files["$f"]=1
done

all_files=("${!unique_files[@]}")

# Check each file for violations
violations_found=false
violations_list=()

for file in "${all_files[@]}"; do
  if [[ -f "$file" ]]; then
    mapfile -t file_violations < <(check_file_for_violations "$file")
    if [[ ${#file_violations[@]} -gt 0 ]]; then
      violations_found=true
      violations_list+=("${file_violations[@]}")
    fi
  fi
done

# If violations were found, report them and exit with error
if [[ "$violations_found" == true ]]; then
  echo "Found raw window.open usage outside safe helper:" >&2
  for violation in "${violations_list[@]}"; do
    echo "- $violation" >&2
  done
  echo "Use openExternalUrlSafe(...) from ui/src/ui/open-external-url.ts instead." >&2
  exit 1
fi

# No violations found
exit 0
