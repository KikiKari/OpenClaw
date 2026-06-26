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
    exec python3 "$core" "$@"
    ;;
  help|--help|-h)
    exec python3 "$core" --help
    ;;
  *)
    echo "error: unknown subcommand: ${1:-}" >&2
    exit 2
    ;;
esac
