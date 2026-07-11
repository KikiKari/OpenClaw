#!/bin/bash
set -e
WORKDIR="/home/openclaw/.openclaw/workspace/tiktok-live-app"
cd "$WORKDIR" || { echo "Working dir $WORKDIR not found"; exit 1; }
# Prefer Python app.py, else try common Node entrypoints
if [ -f "app.py" ]; then
  exec /usr/bin/python3 "app.py"
elif [ -f "server.js" ]; then
  exec /usr/bin/node "server.js"
elif [ -f "index.js" ]; then
  exec /usr/bin/node "index.js"
else
  echo "No supported entrypoint (app.py, server.js, index.js) found in $WORKDIR" >&2
  exit 2
fi
