#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CORE="$SCRIPT_DIR/tt_live.py"
readonly DEFAULT_HOURS=24
readonly MIN_POLL_MINUTES=10

usage() {
  cat <<'EOF'
Usage:
  tiktok-monitorctl.sh start @handle [--hours N] [--poll-min N]
  tiktok-monitorctl.sh status @handle
  tiktok-monitorctl.sh stop @handle

Defaults: --hours 24 --poll-min 10
EOF
}

die_usage() {
  printf 'error: %s\n' "$1" >&2
  exit 64
}

normalize_handle() {
  local handle="${1#@}"
  handle="${handle,,}"
  [[ "$handle" =~ ^[A-Za-z0-9._]{1,24}$ ]] || die_usage "invalid TikTok handle"
  printf '%s' "$handle"
}

positive_integer() {
  [[ "$2" =~ ^[1-9][0-9]*$ ]] || die_usage "$1 must be a positive integer"
}

unit_base_for_handle() {
  printf 'tiktok-live-monitor-%s' "$(systemd-escape -- "$1")"
}

action="${1:-}"
raw_handle="${2:-}"
[[ -n "$action" && -n "$raw_handle" ]] || { usage >&2; exit 64; }
shift 2

handle="$(normalize_handle "$raw_handle")"
unit_base="$(unit_base_for_handle "$handle")"
service_unit="$unit_base.service"
timer_unit="$unit_base.timer"

case "$action" in
  start)
    hours=$DEFAULT_HOURS
    poll_min=$MIN_POLL_MINUTES
    while (($#)); do
      case "$1" in
        --hours)
          [[ $# -ge 2 ]] || die_usage "--hours requires a value"
          hours="$2"
          shift 2
          ;;
        --poll-min)
          [[ $# -ge 2 ]] || die_usage "--poll-min requires a value"
          poll_min="$2"
          shift 2
          ;;
        *) die_usage "unknown argument: $1" ;;
      esac
    done
    positive_integer hours "$hours"
    positive_integer poll-min "$poll_min"
    ((poll_min >= MIN_POLL_MINUTES)) || die_usage "--poll-min must be at least $MIN_POLL_MINUTES"
    [[ -f "$CORE" ]] || { printf 'error: monitor core not found: %s\n' "$CORE" >&2; exit 2; }
    if systemctl --user is-active --quiet "$service_unit" || \
       systemctl --user is-active --quiet "$timer_unit"; then
      printf 'error: monitor already active for @%s\n' "$handle" >&2
      exit 3
    fi
    systemd-run --user \
      --unit="$unit_base" \
      --on-active=1s \
      --timer-property=AccuracySec=1s \
      --collect \
      --property=Type=exec \
      --property=KillSignal=SIGINT \
      --property=TimeoutStopSec=30s \
      /usr/bin/python3 "$CORE" daemon "$handle" \
      --hours "$hours" --poll-min "$poll_min" >/dev/null
    printf '{"status":"scheduled","handle":"%s","hours":%s,"poll_min":%s,"timer":"%s","service":"%s"}\n' \
      "$handle" "$hours" "$poll_min" "$timer_unit" "$service_unit"
    ;;
  status)
    (($# == 0)) || die_usage "status takes only a handle"
    service_state="$(systemctl --user show "$service_unit" --property=ActiveState --value 2>/dev/null || true)"
    timer_state="$(systemctl --user show "$timer_unit" --property=ActiveState --value 2>/dev/null || true)"
    printf '{"handle":"%s","timer_state":"%s","service_state":"%s","timer":"%s","service":"%s"}\n' \
      "$handle" "${timer_state:-not-found}" "${service_state:-not-found}" "$timer_unit" "$service_unit"
    ;;
  stop)
    (($# == 0)) || die_usage "stop takes only a handle"
    systemctl --user stop "$timer_unit" 2>/dev/null || true
    systemctl --user stop "$service_unit" 2>/dev/null || true
    systemctl --user reset-failed "$timer_unit" "$service_unit" 2>/dev/null || true
    printf '{"status":"stopped","handle":"%s","timer":"%s","service":"%s"}\n' \
      "$handle" "$timer_unit" "$service_unit"
    ;;
  *) usage >&2; exit 64 ;;
esac
