#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "8ac87976375b2dffd5bd97cd8f231604440042f9dd5835d2f314c3bc00337666", "source_sha256": "a2afe873e78fca9f7a9bf66785f17d7cad24c6285fd2c0dc6c6bb2abf1e375fa", "target_language": "shell"}
# check-channel-agnostic-boundaries.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-channel-agnostic-boundaries.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This script is a translation of the original JavaScript file to Bash.
# It performs similar checks for channel-agnostic boundaries in TypeScript files.
# However, due to limitations of Bash and the complexity of TypeScript AST parsing,
# this implementation uses grep/sed/awk-based pattern matching instead of true AST analysis.

# Define repository root (assumed to be two directories up from this script)
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Define protected source paths
acp_core_protected_sources=(
  "$repo_root/src/acp"
  "$repo_root/src/agents/acp-spawn.ts"
  "$repo_root/src/auto-reply/reply/commands-acp"
  "$repo_root/src/infra/outbound/conversation-id.ts"
)

channel_core_protected_sources=(
  "$repo_root/src/channels/thread-bindings-policy.ts"
  "$repo_root/src/channels/thread-bindings-messages.ts"
)

acp_user_facing_text_sources=(
  "$repo_root/src/auto-reply/reply/commands-acp"
)

system_mark_literal_guard_sources=(
  "$repo_root/src/auto-reply/reply/commands-acp"
  "$repo_root/src/auto-reply/reply/dispatch-acp.ts"
  "$repo_root/src/auto-reply/reply/directive-handling.shared.ts"
  "$repo_root/src/channels/thread-bindings-messages.ts"
)

# Channel IDs
channel_ids=(bluebubbles discord googlechat imessage irc line matrix msteams signal slack telegram web whatsapp zalo zalouser)

# Create regex patterns for channel segments
channel_segment_pattern=$(IFS='|'; echo "${channel_ids[*]}")
channel_segment_re="(^|[._/-])($channel_segment_pattern)([._/-]|\$)"

# User facing channel names regex
user_facing_channel_names="discord|telegram|slack|signal|imessage|whatsapp|google\s*chat|irc|line|zalo|matrix|msteams|bluebubbles"
user_facing_channel_name_re="\\b($user_facing_channel_names)\\b"

# System mark literal
system_mark_literal="⚙️"

# Comparison operators
comparison_operators=("===" "!==" "==" "!=")

# Function to check if a file exists and is a TypeScript file
is_typescript_file() {
  local file="$1"
  [[ -f "$file" ]] && [[ "$file" == *.ts ]]
}

# Function to collect TypeScript files recursively
collect_typescript_files() {
  local source_path="$1"
  local files=()

  if [[ -d "$source_path" ]]; then
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(find "$source_path" -name "*.ts" -type f -print0 2>/dev/null || true)
  elif is_typescript_file "$source_path"; then
    files+=("$source_path")
  fi

  printf '%s\n' "${files[@]}"
}

# Function to check for channel module imports
check_module_specifiers() {
  local file="$1"
  local rule_id="$2"
  local violations=()

  # Check import declarations
  while IFS= read -r line_num_and_match; do
    if [[ -n "$line_num_and_match" ]]; then
      local line_num=$(echo "$line_num_and_match" | cut -d: -f1)
      local match=$(echo "$line_num_and_match" | cut -d: -f2-)
      violations+=("$rule_id $file:$line_num: imports channel module \"$match\"")
    fi
  done < <(grep -n "import.*from.*\($channel_segment_re\)" "$file" 2>/dev/null || true)

  # Check export declarations
  while IFS= read -r line_num_and_match; do
    if [[ -n "$line_num_and_match" ]]; then
      local line_num=$(echo "$line_num_and_match" | cut -d: -f1)
      local match=$(echo "$line_num_and_match" | cut -d: -f2-)
      violations+=("$rule_id $file:$line_num: re-exports channel module \"$match\"")
    fi
  done < <(grep -n "export.*from.*\($channel_segment_re\)" "$file" 2>/dev/null || true)

  # Check dynamic imports
  while IFS= read -r line_num_and_match; do
    if [[ -n "$line_num_and_match" ]]; then
      local line_num=$(echo "$line_num_and_match" | cut -d: -f1)
      local match=$(echo "$line_num_and_match" | cut -d: -f2-)
      violations+=("$rule_id $file:$line_num: dynamically imports channel module \"$match\"")
    fi
  done < <(grep -n "import(\(\".*\($channel_segment_re\)\"\)" "$file" 2>/dev/null || true)

  printf '%s\n' "${violations[@]}"
}

# Function to check for config path references
check_config_paths() {
  local file="$1"
  local rule_id="$2"
  local violations=()

  for channel in "${channel_ids[@]}"; do
    # Check property access expressions like channels.discord
    while IFS= read -r line_num_and_match; do
      if [[ -n "$line_num_and_match" ]]; then
        local line_num=$(echo "$line_num_and_match" | cut -d: -f1)
        violations+=("$rule_id $file:$line_num: references config path \"channels.$channel\"")
      fi
    done < <(grep -n "\.channels\.$channel\b" "$file" 2>/dev/null || true)

    # Check element access expressions like channels["discord"]
    while IFS= read -r line_num_and_match; do
      if [[ -n "$line_num_and_match" ]]; then
        local line_num=$(echo "$line_num_and_match" | cut -d: -f1)
        violations+=("$rule_id $file:$line_num: references config path \"channels[\"$channel\"]\"")
      fi
    done < <(grep -n "\.channels\[\"$channel\"\]" "$file" 2>/dev/null || true)
  done

  printf '%s\n' "${violations[@]}"
}

# Function to check for channel comparisons
check_channel_comparisons() {
  local file="$1"
  local rule_id="$2"
  local violations=()

  for op in "${comparison_operators[@]}"; do
    # Escape operator for use in regex
    local escaped_op=$(printf '%s\n' "$op" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    for channel in "${channel_ids[@]}"; do
      # Check comparisons like x === "discord" or "discord" === x
      while IFS= read -r line_num_and_match; do
        if [[ -n "$line_num_and_match" ]]; then
          local line_num=$(echo "$line_num_and_match" | cut -d: -f1)
          violations+=("$rule_id $file:$line_num: compares with channel id literal ($line_num_and_match)")
        fi
      done < <(grep -n "\"$channel\" *$escaped_op\|[^\" ]*$escaped_op *\"$channel\"" "$file" 2>/dev/null || true)
    done
  done

  printf '%s\n' "${violations[@]}"
}

# Function to check for channel assignments
check_channel_assignments() {
  local file="$1"
  local rule_id="$2"
  local violations=()

  for channel in "${channel_ids[@]}"; do
    # Check assignments like channel: "discord"
    while IFS= read -r line_num_and_match; do
      if [[ -n "$line_num_and_match" ]]; then
        local line_num=$(echo "$line_num_and_match" | cut -d: -f1)
        violations+=("$rule_id $file:$line_num: assigns channel id literal to \"channel\" (\"$channel\")")
      fi
    done < <(grep -n "channel:[[:space:]]*\"$channel\"" "$file" 2>/dev/null || true)
  done

  printf '%s\n' "${violations[@]}"
}

# Function to check for user-facing channel names
check_user_facing_channel_names() {
  local file="$1"
  local rule_id="$2"
  local violations=()

  # Find string literals containing channel names that are not in import/export statements
  while IFS= read -r line_num_and_match; do
    if [[ -n "$line_num_and_match" ]]; then
      local line_num=$(echo "$line_num_and_match" | cut -d: -f1)
      local match=$(echo "$line_num_and_match" | cut -d: -f2-)
      
      # Skip if this is part of an import/export statement
      if ! grep -q "^.*import.*$match\|^.*export.*$match\|^.*from.*$match" "$file" 2>/dev/null; then
        violations+=("$rule_id $file:$line_num: user-facing text references channel name (\"$match\")")
      fi
    fi
  done < <(grep -Eoih "(^|[[:space:]])($user_facing_channel_names)([[:space:]]|$)" "$file" | sort -u | \
           while read -r match; do
             grep -n "$match" "$file" 2>/dev/null || true
           done)

  printf '%s\n' "${violations[@]}"
}

# Function to check for system mark literal usage
check_system_mark_literal() {
  local file="$1"
  local rule_id="$2"
  local violations=()

  # Find occurrences of the system mark literal that are not in import/export statements
  while IFS= read -r line_num_and_match; do
    if [[ -n "$line_num_and_match" ]]; then
      local line_num=$(echo "$line_num_and_match" | cut -d: -f1)
      
      # Skip if this is part of an import/export statement
      if ! grep -q "^.*import.*$system_mark_literal\|^.*export.*$system_mark_literal\|^.*from.*$system_mark_literal" "$file" 2>/dev/null; then
        violations+=("$rule_id $file:$line_num: hardcoded system mark literal (\"$system_mark_literal\")")
      fi
    fi
  done < <(grep -n "$system_mark_literal" "$file" 2>/dev/null || true)

  printf '%s\n' "${violations[@]}"
}

# Main scanning functions for each rule set
scan_acp_core() {
  local file="$1"
  local violations=()
  
  # Combine all checks for ACP core
  violations+=($(check_module_specifiers "$file" "acp-core"))
  violations+=($(check_config_paths "$file" "acp-core"))
  violations+=($(check_channel_comparisons "$file" "acp-core"))
  violations+=($(check_channel_assignments "$file" "acp-core"))
  
  printf '%s\n' "${violations[@]}"
}

scan_channel_core_reverse_deps() {
  local file="$1"
  local violations=()
  
  # Only check module specifiers for reverse dependencies
  violations+=($(check_module_specifiers "$file" "channel-core-reverse-deps"))
  
  printf '%s\n' "${violations[@]}"
}

scan_acp_user_facing_text() {
  local file="$1"
  check_user_facing_channel_names "$file" "acp-user-facing-text"
}

scan_system_mark_literal_usage() {
  local file="$1"
  check_system_mark_literal "$file" "system-mark-literal-usage"
}

# Main execution
main() {
  local all_violations=()
  
  # Process ACP Core rules
  for source in "${acp_core_protected_sources[@]}"; do
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        while IFS= read -r violation; do
          if [[ -n "$violation" ]]; then
            all_violations+=("$violation")
          fi
        done < <(scan_acp_core "$file")
      fi
    done < <(collect_typescript_files "$source")
  done
  
  # Process Channel Core Reverse Dependencies rules
  for source in "${channel_core_protected_sources[@]}"; do
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        while IFS= read -r violation; do
          if [[ -n "$violation" ]]; then
            all_violations+=("$violation")
          fi
        done < <(scan_channel_core_reverse_deps "$file")
      fi
    done < <(collect_typescript_files "$source")
  done
  
  # Process ACP User Facing Text rules
  for source in "${acp_user_facing_text_sources[@]}"; do
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        while IFS= read -r violation; do
          if [[ -n "$violation" ]]; then
            all_violations+=("$violation")
          fi
        done < <(scan_acp_user_facing_text "$file")
      fi
    done < <(collect_typescript_files "$source")
  done
  
  # Process System Mark Literal Usage rules
  for source in "${system_mark_literal_guard_sources[@]}"; do
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        while IFS= read -r violation; do
          if [[ -n "$violation" ]]; then
            all_violations+=("$violation")
          fi
        done < <(scan_system_mark_literal_usage "$file")
      fi
    done < <(collect_typescript_files "$source")
  done
  
  # Output violations if any found
  if [[ ${#all_violations[@]} -gt 0 ]]; then
    echo "Found channel-specific references in channel-agnostic sources:" >&2
    for violation in "${all_violations[@]}"; do
      echo "- $violation" >&2
    done
    echo "Move channel-specific logic to channel adapters or add a justified allowlist entry." >&2
    exit 1
  fi
}

# Run main function
main "$@"
