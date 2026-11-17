#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "0072b8b9eccab3595bae595d15c2b6bd3125ecb15a2600192a42cf0d14e7355b", "source_sha256": "eb21431dabeaafc82a1e3ccf24278616e46ed082eca1de4d328c758ee82ee2c7", "target_language": "shell"}
# language_validator.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Multi-language script validator supporting 8+ languages.
# WebSearch integration for documentation lookup.

declare -A LANGUAGES=(
  [bash]="bash:-n:shellcheck"
  [sh]="sh:-n:shellcheck"
  [python]="python3:-m py_compile:pylint"
  [perl]="perl:-c:perlcritic"
  [raku]="raku:-c:"
  [powershell]="pwsh:-Command Get-Command:"
  [javascript]="node:--check:eslint"
  [tcl]="tclsh::"
)

validate_script() {
  local language="$1"
  local script_path="$2"
  local use_websearch="${3:-true}"
  
  if [[ ! -v LANGUAGES[$language] ]]; then
    echo "Unsupported language: $language" >&2
    return 1
  fi
  
  IFS=':' read -r cmd args linter <<< "${LANGUAGES[$language]}"
  
  local errors=()
  local warnings=()
  local doc_url=""
  
  # Syntax check
  local output
  if output=$("$cmd" $args "$script_path" 2>&1); then
    true # Success
  else
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      errors+=("Validation timeout")
    else
      errors+=("$output")
    fi
  fi
  
  # Linter check if available
  if [[ -n "$linter" ]]; then
    local linter_output
    case "$linter" in
      shellcheck)
        if command -v shellcheck >/dev/null; then
          if linter_output=$(shellcheck -f gcc "$script_path" 2>&1); then
            if [[ -n "$linter_output" ]]; then
              mapfile -t warnings < <(echo "$linter_output")
            fi
          fi
        else
          warnings+=("Linter not installed: $linter")
        fi
        ;;
      pylint)
        if command -v pylint >/dev/null; then
          if linter_output=$(pylint --output-format=parseable "$script_path" 2>&1); then
            if [[ -n "$linter_output" ]]; then
              mapfile -t warnings < <(echo "$linter_output")
            fi
          fi
        else
          warnings+=("Linter not installed: $linter")
        fi
        ;;
    esac
  fi
  
  # Fetch documentation URL if needed and WebSearch is enabled
  if [[ "$use_websearch" == true ]] && [[ ${#errors[@]} -gt 0 ]]; then
    case "$language" in
      powershell) doc_url="https://docs.microsoft.com/powershell/" ;;
      raku) doc_url="https://docs.raku.org/" ;;
      tcl) doc_url="https://www.tcl.tk/" ;;
    esac
  fi
  
  # Print results
  echo "Language: $language"
  if [[ ${#errors[@]} -eq 0 ]]; then
    echo "Valid: true"
  else
    echo "Valid: false"
    echo "Errors: ${#errors[@]}"
    local i
    for ((i=0; i<${#errors[@]} && i<5; i++)); do
      echo "  - ${errors[i]}"
    done
  fi
  
  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "Warnings: ${#warnings[@]}"
    local j
    for ((j=0; j<${#warnings[@]} && j<5; j++)); do
      echo "  - ${warnings[j]}"
    done
  fi
  
  if [[ -n "$doc_url" ]]; then
    echo "Docs: $doc_url"
  fi
  
  [[ ${#errors[@]} -eq 0 ]]
}

main() {
  local script=""
  local lang=""
  local no_websearch=false
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --lang)
        lang="$2"
        shift 2
        ;;
      --no-websearch)
        no_websearch=true
        shift
        ;;
      -*)
        echo "Unknown option: $1" >&2
        return 1
        ;;
      *)
        if [[ -z "$script" ]]; then
          script="$1"
        else
          echo "Unexpected argument: $1" >&2
          return 1
        fi
        shift
        ;;
    esac
  done
  
  if [[ -z "$script" ]] || [[ -z "$lang" ]]; then
    echo "Usage: $0 [--lang LANGUAGE] [--no-websearch] SCRIPT" >&2
    return 1
  fi
  
  if [[ ! -f "$script" ]]; then
    echo "Script file does not exist: $script" >&2
    return 1
  fi
  
  validate_script "$lang" "$script" "$(! $no_websearch)"
}

main "$@"
