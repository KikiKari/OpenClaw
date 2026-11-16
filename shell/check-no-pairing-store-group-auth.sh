#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "5126b374f9f682dc6cf76492d073cb419f04d485265a825d92c98553b2d5455b", "source_sha256": "a9a15237ac26649d4fe81c84ab0e7be0474d07af42503d8016279ce5a868359c", "target_language": "shell"}
# check-no-pairing-store-group-auth.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-pairing-store-group-auth.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This script is a translation of the original JavaScript file to Bash.
# It performs similar checks on TypeScript files to detect improper usage
# of pairing-store identifiers within group authentication contexts.

# Since Bash doesn't have native TypeScript parsing capabilities, this
# implementation uses grep/sed/awk to approximate the detection logic.

# Define repository root and source roots (these would need to be passed or derived)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_ROOTS=("$REPO_ROOT/src")

# Allowed files that can reference store/group fields
ALLOWED_FILES=(
  "$REPO_ROOT/src/security/dm-policy-shared.ts"
  "$REPO_ROOT/src/channels/allow-from.ts"
  "$REPO_ROOT/src/security/fix.ts"
  "$REPO_ROOT/src/security/audit-channel.ts"
)

# Regular expressions for detecting store and group identifiers
STORE_IDENTIFIER_RE='storeAllowFrom|storedAllowFrom|storeAllowList'
GROUP_NAME_RE='groupAllowFrom|effectiveGroupAllowFrom|groupAllowed|groupAllow|groupAuth|groupSender'
STORE_SOURCE_CALL_NAMES='readChannelAllowFromStore|readChannelAllowFromStoreSync|readStoreAllowFromForDmPolicy'
ALLOWED_RESOLVER_CALL_NAMES='resolveEffectiveAllowFromLists|resolveDmGroupAccessWithLists|resolveMattermostEffectiveAllowFromLists|resolveIrcEffectiveAllowlists'

# Function to check if a file is in the allowed list
is_allowed_file() {
  local file="$1"
  for allowed in "${ALLOWED_FILES[@]}"; do
    if [[ "$file" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

# Function to check for violations in a file
check_file_for_violations() {
  local file="$1"
  local violations_found=0

  # Skip allowed files
  if is_allowed_file "$file"; then
    return 0
  fi

  # Check for group-scoped variables referencing store identifiers
  while IFS= read -r line; do
    if [[ $line =~ ^[^#]*\b($GROUP_NAME_RE)\b.*\b($STORE_IDENTIFIER_RE)\b ]]; then
      echo "$file:$line_number: group-scoped variable \"${BASH_REMATCH[1]}\" references pairing-store identifiers"
      violations_found=1
    fi
    ((line_number++))
  done < <(grep -n "$GROUP_NAME_RE" "$file")

  # Check for group-scoped properties referencing store identifiers
  while IFS= read -r line; do
    if [[ $line =~ ^[^#]*\b($GROUP_NAME_RE)\b.*\b($STORE_IDENTIFIER_RE)\b ]]; then
      echo "$file:$line_number: group-scoped property \"${BASH_REMATCH[1]}\" references pairing-store identifiers"
      violations_found=1
    fi
    ((line_number++))
  done < <(grep -n "$GROUP_NAME_RE" "$file")

  # Check for suspicious normalizeAllowFromWithStore calls
  while IFS= read -r line; do
    if [[ $line =~ normalizeAllowFromWithStore ]] && \
       [[ $line =~ ($STORE_IDENTIFIER_RE) ]] && \
       [[ $line =~ ($GROUP_NAME_RE) ]]; then
      echo "$file:$line_number: group allowlist uses normalizeAllowFromWithStore(...) with pairing-store entries"
      violations_found=1
    fi
    ((line_number++))
  done < <(grep -n "normalizeAllowFromWithStore" "$file")

  return $violations_found
}

# Main function
main() {
  local exit_code=0

  # Find all .ts files in source roots
  mapfile -t ts_files < <(find "${SRC_ROOTS[@]}" -name "*.ts" -type f)

  # Check each file for violations
  for file in "${ts_files[@]}"; do
    if ! check_file_for_violations "$file"; then
      exit_code=1
    fi
  done

  # If violations were found, print error message and exit
  if [[ $exit_code -ne 0 ]]; then
    echo "Found pairing-store identifiers referenced in group auth composition:"
    echo "Group auth must be composed via shared resolvers (resolveDmGroupAccessWithLists / resolveEffectiveAllowFromLists)."
    exit 1
  fi
}

# Run main function
main "$@"
