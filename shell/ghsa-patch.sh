#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "16a5c076842c2a0bff9811bea222b5ce159cf64de4ca0c87c3a68eac5ce9108a", "source_sha256": "f198925e5c21dc828628def1707ba79512014dafa5a425580bbf80881a4b0ed7", "target_language": "shell"}
# ghsa-patch.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/ghsa-patch.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage:
  node scripts/ghsa-patch.mjs --ghsa <GHSA-id-or-url> [--repo owner/name]
    --summary <text> --severity <low|medium|high|critical>
    --description-file <path>
    --vulnerable-version-range <range>
    --patched-versions <range-or-null>
    [--package openclaw] [--ecosystem npm] [--cvss <vector>]
EOF
}

fail() {
  echo "$*" >&2
  exit 1
}

parse_args() {
  declare -gA args=()
  local i=0
  while (( i < $# )); do
    local arg="${!i}"
    if [[ ! $arg == --* ]]; then
      fail "Unexpected argument: $arg"
    fi
    local key="${arg#--}"
    local next=$((i+1))
    if (( next >= $# )) || [[ ${!next} == --* ]]; then
      fail "Missing value for --$key"
    fi
    args[$key]="${!next}"
    i=$((i+2))
  done
}

run_gh() {
  local output stderr status
  stderr=$(mktemp)
  output=$(gh "$@" 2>"$stderr") || {
    status=$?
    if [[ -s $stderr ]]; then
      cat "$stderr" >&2
    elif [[ -n $output ]]; then
      echo "$output" >&2
    else
      echo "gh $* failed" >&2
    fi
    rm -f "$stderr"
    exit "$status"
  }
  rm -f "$stderr"
  echo "$output"
}

derive_repo_from_origin() {
  local remote
  remote=$(git remote get-url origin) || fail "Failed to get git origin"
  if [[ $remote =~ github\.com[/:]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  else
    fail "Could not parse origin remote: $remote"
  fi
}

parse_ghsa_id() {
  local value="$1"
  if [[ $value =~ (GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    fail "Could not parse GHSA id from: $value"
  fi
}

write_temp_json() {
  local data="$1"
  local file
  file=$(mktemp -t "ghsa-patch-XXXXXXXXXX.json")
  echo "$data" > "$file"
  echo "$file"
}

main() {
  local -A args
  parse_args "$@"

  if [[ -z ${args[ghsa]:-} ]] || [[ -z ${args[summary]:-} ]] || [[ -z ${args[severity]:-} ]] || [[ -z ${args[description-file]:-} ]]; then
    usage
    exit 1
  fi

  local repo
  if [[ -n ${args[repo]:-} ]]; then
    repo="${args[repo]}"
  else
    repo=$(derive_repo_from_origin)
  fi

  local ghsa_id
  ghsa_id=$(parse_ghsa_id "${args[ghsa]}")
  local advisory_path="/repos/$repo/security-advisories/$ghsa_id"
  local description_path
  description_path=$(realpath "${args[description-file]}")

  if [[ ! -f $description_path ]]; then
    fail "Description file does not exist: $description_path"
  fi

  local current_json
  current_json=$(run_gh api -H "X-GitHub-Api-Version: 2022-11-28" "$advisory_path")
  local restored_cvss=""
  if [[ -n ${args[cvss]:-} ]]; then
    restored_cvss="${args[cvss]}"
  elif echo "$current_json" | jq -e '.cvss.vector_string' >/dev/null; then
    restored_cvss=$(echo "$current_json" | jq -r '.cvss.vector_string')
  fi

  local ecosystem="${args[ecosystem]:-npm}"
  local package_name="${args[package]:-openclaw}"
  local vulnerable_range="${args[vulnerable-version-range]:-}"
  local patched_versions_raw="${args[patched-versions]:-}"

  if [[ -z $vulnerable_range ]]; then
    fail "Missing --vulnerable-version-range"
  fi
  if [[ -z ${args[patched-versions]:-} ]]; then
    fail "Missing --patched-versions"
  fi

  local patched_versions
  if [[ $patched_versions_raw == "null" ]]; then
    patched_versions="null"
  else
    patched_versions="$patched_versions_raw"
  fi

  local description
  description=$(cat "$description_path")

  local payload
  payload=$(jq -n \
    --arg summary "${args[summary]}" \
    --arg severity "${args[severity]}" \
    --arg description "$description" \
    --arg ecosystem "$ecosystem" \
    --arg name "$package_name" \
    --arg vulnerable_range "$vulnerable_range" \
    --arg patched_versions "$patched_versions" \
    '{
      summary: $summary,
      severity: $severity,
      description: $description,
      vulnerabilities: [{
        package: {
          ecosystem: $ecosystem,
          name: $name
        },
        vulnerable_version_range: $vulnerable_range,
        patched_versions: ($patched_versions == "null" or $patched_versions == "" or $patched_versions == "null") and null or $patched_versions,
        vulnerable_functions: []
      }]
    }')

  local patch_file
  patch_file=$(write_temp_json "$payload")
  run_gh api -H "X-GitHub-Api-Version: 2022-11-28" -X PATCH "$advisory_path" --input "$patch_file"

  if [[ -n $restored_cvss ]]; then
    run_gh api -H "X-GitHub-Api-Version: 2022-11-28" -X PATCH "$advisory_path" -f "cvss_vector_string=$restored_cvss"
  fi

  local refreshed
  refreshed=$(run_gh api -H "X-GitHub-Api-Version: 2022-11-28" "$advisory_path")
  echo "$refreshed" | jq '{
    html_url: .html_url,
    state: .state,
    severity: .severity,
    summary: .summary,
    vulnerabilities: .vulnerabilities,
    cvss: .cvss,
    updated_at: .updated_at
  }'
}

main "$@"
