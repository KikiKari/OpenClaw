#!/usr/bin/env bash
# OpenClaw read-only audit/diagnostic sweep
# Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE_STAMP="$(date +%Y-%m-%d)"
OUT="${SCRIPT_DIR}/openclaw-audit-${DATE_STAMP}.log"

OC=(openclaw --no-color)

{
  echo "================================================================"
  echo "OpenClaw audit run"
  echo "Started:  $(date --iso-8601=seconds)"
  echo "Host:     $(hostname)"
  echo "User:     $(whoami)"
  echo "Version:  $(openclaw --version 2>/dev/null || echo 'unknown')"
  echo "Output:   ${OUT}"
  echo "================================================================"
} > "${OUT}"

run_cmd() {
  local title="$1"; shift
  {
    echo
    echo "----------------------------------------------------------------"
    echo "### ${title}"
    echo "### \$ $*"
    echo "### $(date --iso-8601=seconds)"
    echo "----------------------------------------------------------------"
    "$@" 2>&1
    local rc=$?
    echo "[exit: ${rc}]"
  } >> "${OUT}"
}

run_cmd "tasks audit --severity error"  "${OC[@]}" tasks audit --severity error
run_cmd "secrets audit"                 "${OC[@]}" secrets audit
run_cmd "security audit"                "${OC[@]}" security audit
run_cmd "plugins doctor"                "${OC[@]}" plugins doctor
run_cmd "plugins deps"                  "${OC[@]}" plugins deps
run_cmd "plugins registry"              "${OC[@]}" plugins registry
run_cmd "skills check"                  "${OC[@]}" skills check
run_cmd "hooks check"                   "${OC[@]}" hooks check
run_cmd "gateway status --deep"         "${OC[@]}" gateway status --deep
run_cmd "channels status --probe"       "${OC[@]}" channels status --probe
run_cmd "memory status --deep"          "${OC[@]}" memory status --deep
run_cmd "sessions --all-agents"         "${OC[@]}" sessions --all-agents
run_cmd "tasks list"                    "${OC[@]}" tasks list
run_cmd "cron list"                     "${OC[@]}" cron list

{
  echo
  echo "================================================================"
  echo "Audit complete: $(date --iso-8601=seconds)"
  echo "================================================================"
} >> "${OUT}"

echo "Audit complete. Output: ${OUT}"
