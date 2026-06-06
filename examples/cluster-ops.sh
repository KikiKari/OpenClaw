#!/usr/bin/env bash
# OpenClaw cluster operations — health check, restart, log tail

set -euo pipefail

NODES=("${OPENCLAW_NODES:-localhost:8080 localhost:8081}")
TIMEOUT=5

usage() { echo "Usage: $0 [health|restart|logs]"; exit 1; }

health() {
  local ok=0 fail=0
  for node in "${NODES[@]}"; do
    if curl -sf --max-time "$TIMEOUT" "http://$node/health" > /dev/null; then
      echo "  OK    $node"
      ((ok++))
    else
      echo "  FAIL  $node"
      ((fail++))
    fi
  done
  echo "--- $ok OK / $fail FAIL"
  [[ $fail -eq 0 ]]
}

restart() {
  for node in "${NODES[@]}"; do
    echo "Restarting $node..."
    curl -sf -X POST "http://$node/admin/restart" || echo "  WARNING: $node did not respond"
  done
}

logs() {
  local node="${1:-${NODES[0]}}"
  echo "Streaming logs from $node (Ctrl+C to stop)..."
  curl -sN "http://$node/logs/stream"
}

case "${1:-health}" in
  health)  health ;;
  restart) restart ;;
  logs)    logs "${2:-}" ;;
  *)       usage ;;
esac