#!/bin/bash
set -euo pipefail
WORKDIR="$(pwd)"
# use venv python if present
if [ -x "$WORKDIR/.venv/bin/python" ]; then
  exec "$WORKDIR/.venv/bin/python" "$WORKDIR/app.py"
fi
if [ -f "$WORKDIR/app.py" ]; then
  exec /usr/bin/python3 "$WORKDIR/app.py"
fi
if [ -f "$WORKDIR/server.js" ]; then
  exec /usr/bin/node "$WORKDIR/server.js"
fi
if [ -f "$WORKDIR/index.js" ]; then
  exec /usr/bin/node "$WORKDIR/index.js"
fi
echo "No entrypoint found (checked .venv/bin/python, app.py, server.js, index.js)" >&2
exit 2
