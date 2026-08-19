#!/usr/bin/env bash
# language_validator.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

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

usage() {
  echo "Usage: $0 --script SCRIPT --lang LANGUAGE [--no-websearch]"
  exit 1
}

log() {
  echo "$*" >&2
}

validate_script() {
  local lang="$1"
  local script_path="$2"
  local use_websearch="$3"
  
  local cmd args linter
  IFS=':' read -r cmd args linter <<<"${LANGUAGES[$lang]}"
  
  local errors=()
  local warnings=()
  local doc_url=""
  
  # Syntax check
  if [[ -n "$cmd" ]]; then
    local output
    local ret=0
    output=$(timeout 30 "$cmd" $args "$script_path" 2>&1) || ret=$?
    
    if [[ $ret -ne 0 ]]; then
      if [[ $ret -eq 124 ]]; then
        errors+=("Validation timeout")
      else
        errors+=("$output")
      fi
    fi
  else
    errors+=("Command not found: ${cmd}")
    if [[ "$use_websearch" == "true" ]]; then
      doc_url=$(fetch_docs "$lang")
    fi
  fi
  
  # Linter check if available
  if [[ -n "$linter" ]]; then
    mapfile -t linter_warnings < <(run_linter "$linter" "$script_path")
    warnings+=("${linter_warnings[@]}")
  fi
  
  # Output results
  echo "Language: $lang"
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

run_linter() {
  local linter="$1"
  local script_path="$2"
  
  local output
  local ret=0
  
  case "$linter" in
    shellcheck)
      output=$(shellcheck -f gcc "$script_path" 2>&1) || ret=$?
      ;;
    pylint)
      output=$(pylint --output-format=parseable "$script_path" 2>&1) || ret=$?
      ;;
    *)
      echo "Linter not installed: $linter" >&2
      return 0
      ;;
  esac
  
  if [[ $ret -ne 0 ]] || [[ -n "$output" ]]; then
    echo "$output"
  fi
}

fetch_docs() {
  local lang="$1"
  
  case "$lang" in
    powershell)
      echo "https://docs.microsoft.com/powershell/"
      ;;
    raku)
      echo "https://docs.raku.org/"
      ;;
    tcl)
      echo "https://www.tcl.tk/"
      ;;
    *)
      echo ""
      ;;
  esac
}

main() {
  local script=""
  local lang=""
  local use_websearch="true"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --script)
        script="$2"
        shift 2
        ;;
      --lang)
        lang="$2"
        shift 2
        ;;
      --no-websearch)
        use_websearch="false"
        shift
        ;;
      *)
        usage
        ;;
    esac
  done
  
  if [[ -z "$script" ]] || [[ -z "$lang" ]]; then
    usage
  fi
  
  if [[ ! -f "$script" ]]; then
    log "Script file not found: $script"
    exit 1
  fi
  
  if [[ -z "${LANGUAGES[$lang]+isset}" ]]; then
    log "Unsupported language: $lang"
    exit 1
  fi
  
  if validate_script "$lang" "$script" "$use_websearch"; then
    exit 0
  else
    exit 1
  fi
}

main "$@"
