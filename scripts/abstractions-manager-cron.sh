#!/usr/bin/env bash
set -eo pipefail

export PATH="/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin"

set -a
. /home/openclaw/.openclaw/.env
set +a

: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY fehlt}"
export GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-${GH_ACCESS_TOKEN:-}}}"

exec /usr/bin/flock --nonblock \
  /home/openclaw/.openclaw/locks/abstractions-manager.lock \
  /usr/bin/python3 \
  /home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py \
  "$@"
