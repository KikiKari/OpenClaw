#!/bin/bash
# Test Node 3 Connection
export OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1
echo "Starting node connection test..."
timeout 15 /usr/local/bin/openclaw node run --host 152.53.145.65 --port 18789 2>&1
echo "Exit code: $?"
