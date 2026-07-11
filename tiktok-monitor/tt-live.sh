#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
core="$script_dir/tt_live.py"

if [[ ! -f "$core" ]]; then
  echo "error: tt_live.py not found at: $core" >&2
  exit 2
fi

case "${1:-help}" in
  check|url)
    exec python3 "$core" "$@"
    ;;
  daemon)
    username="${2:-}"
    normalized="${username#@}"
    if [[ ! "$normalized" =~ ^[A-Za-z0-9._]{1,24}$ ]]; then
      echo "error: daemon requires a valid TikTok username" >&2
      exit 2
    fi

    workspace="${TT_LIVE_WORKSPACE:-$HOME/.openclaw/workspace/tiktok-monitor}"
    log_dir="$workspace/logs"
    mkdir -p "$log_dir"
    timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
    log_file="$log_dir/daemon-$normalized-$timestamp.log"

    nohup python3 "$core" "$@" >>"$log_file" 2>&1 &
    daemon_pid=$!
    sleep 1
    if ! kill -0 "$daemon_pid" 2>/dev/null; then
      echo "error: daemon exited immediately. Check log: $log_file" >&2
      exit 2
    fi

    printf 'pid=%s\n' "$daemon_pid"
    printf 'username=%s\n' "$normalized"
    printf 'workspace=%s\n' "$workspace"
    printf 'log=%s\n' "$log_file"
    printf 'events_dir=%s\n' "$workspace/state/tt-live"
    ;;
  help|--help|-h)
    exec python3 "$core" --help
    ;;
  *)
    echo "error: unknown subcommand: ${1:-}" >&2
    exit 2
    ;;
esac
