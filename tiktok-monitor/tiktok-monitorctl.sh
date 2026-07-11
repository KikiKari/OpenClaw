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

normalize_handle() {
  local handle="${1#@}"
  if [[ ! "$handle" =~ ^[A-Za-z0-9._]{1,24}$ ]]; then
    echo "error: invalid TikTok handle" >&2
    exit 64
  fi
  printf '%s' "$handle"
}

require_positive_integer() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: $name must be a positive integer" >&2
    exit 64
  fi
}

unit_base_for_handle() {
  local escaped
  escaped="$(systemd-escape -- "$1")"
  printf 'tiktok-live-monitor-%s' "$escaped"
}

action="${1:-}"
raw_handle="${2:-}"
if [[ -z "$action" || -z "$raw_handle" ]]; then
  usage >&2
  exit 64
fi
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
          [[ $# -ge 2 ]] || { echo "error: --hours requires a value" >&2; exit 64; }
          hours="$2"
          shift 2
          ;;
        --poll-min)
          [[ $# -ge 2 ]] || { echo "error: --poll-min requires a value" >&2; exit 64; }
          poll_min="$2"
          shift 2
          ;;
        *)
          echo "error: unknown argument: $1" >&2
          exit 64
          ;;
      esac
    done

    require_positive_integer hours "$hours"
    require_positive_integer poll_min "$poll_min"
    if ((poll_min < MIN_POLL_MINUTES)); then
      echo "error: --poll-min must be at least $MIN_POLL_MINUTES" >&2
      exit 64
    fi
    if [[ ! -f "$CORE" ]]; then
      echo "error: monitor core not found: $CORE" >&2
      exit 2
    fi
    if systemctl --user is-active --quiet "$service_unit" || \
       systemctl --user is-active --quiet "$timer_unit"; then
      echo "error: monitor already active for @$handle" >&2
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
    (($# == 0)) || { echo "error: status takes only a handle" >&2; exit 64; }
    service_state="$(systemctl --user show "$service_unit" --property=ActiveState --value 2>/dev/null || true)"
    timer_state="$(systemctl --user show "$timer_unit" --property=ActiveState --value 2>/dev/null || true)"
    printf '{"handle":"%s","timer_state":"%s","service_state":"%s","timer":"%s","service":"%s"}\n' \
      "$handle" "${timer_state:-not-found}" "${service_state:-not-found}" "$timer_unit" "$service_unit"
    ;;
  stop)
    (($# == 0)) || { echo "error: stop takes only a handle" >&2; exit 64; }
    systemctl --user stop "$timer_unit" 2>/dev/null || true
    systemctl --user stop "$service_unit" 2>/dev/null || true
    systemctl --user reset-failed "$timer_unit" "$service_unit" 2>/dev/null || true
    printf '{"status":"stopped","handle":"%s","timer":"%s","service":"%s"}\n' \
      "$handle" "$timer_unit" "$service_unit"
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
