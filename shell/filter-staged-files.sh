#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "de7f76e603670d9a957d4ba53242bdcfbd61e152283b92783c13a4ec001d9081", "source_sha256": "bf11781342e249f3bb5e5746f94668968b3fed5b83b099b77d5a9bb8ec38b713", "target_language": "shell"}
# filter-staged-files.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/pre-commit/filter-staged-files.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Prints selected files as NUL-delimited tokens to stdout.
#
# Usage:
#   ./filter-staged-files.sh lint -- <files...>
#   ./filter-staged-files.sh format -- <files...>
#
# Keep this dependency-free: the pre-commit hook runs in many environments.

mode="$1"
shift

# Parse arguments, handling optional -- separator
files=()
if [[ ${1:-} == "--" ]]; then
  shift
  files=("$@")
else
  files=("$@")
fi

if [[ "$mode" != "lint" && "$mode" != "format" ]]; then
  echo "usage: filter-staged-files.sh <lint|format> -- <files...>" >&2
  exit 2
fi

# Define extensions for linting and formatting
lint_exts=".ts .tsx .js .jsx .mjs .cjs"
format_exts=".ts .tsx .js .jsx .mjs .cjs .json .md .mdx"
format_ignored_paths="src/canvas-host/a2ui/a2ui.bundle.js"

should_select() {
  local file_path="$1"
  local ext="${file_path##*.}"
  # Add dot back to extension for comparison
  if [[ "$ext" != "$file_path" ]]; then
    ext=".$ext"
  else
    ext=""
  fi
  
  # Convert to lowercase for comparison
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  
  if [[ "$mode" == "lint" ]]; then
    case " $lint_exts " in
      *" $ext "*)
        return 0
        ;;
    esac
    return 1
  fi
  
  # Check if file is in ignored paths for format mode
  if [[ " $format_ignored_paths " == *" $file_path "* ]]; then
    return 1
  fi
  
  case " $format_exts " in
    *" $ext "*)
      return 0
      ;;
  esac
  return 1
}

# Process each file
for file in "${files[@]}"; do
  if should_select "$file"; then
    printf "%s\0" "$file"
  fi
done
