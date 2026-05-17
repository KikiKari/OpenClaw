#!/bin/bash
# Connect Node 10.10.0.2 to Gateway as Node Mode

NODE_IP="10.10.0.2"
GATEWAY_URL="ws://10.10.0.1:18789"
SETUP_CODE="eyJ1cmwiOiJ3czovLzEwLjEwLjAuMToxODc4OSIsImJvb3RzdHJhcFRva2VuIjoidG1ia1IzVWtYd3ljeENWOC1raU11SzBFVkxTejRWRlFhb2VBOHhnR1VNTSJ9"

echo "=== Connecting Node $NODE_IP to Gateway ==="

# Check if openclaw is installed on node
ssh "root@$NODE_IP" "which openclaw" || {
    echo "OpenClaw not installed on node $NODE_IP, installing..."
    ssh "root@$NODE_IP" "npm install -g openclaw"
}

# Install and start node service
ssh "root@$NODE_IP" "openclaw node install"

# Configure node to connect to gateway
ssh "root@$NODE_IP" "openclaw config set gateway.remote.url '$GATEWAY_URL'"
ssh "root@$NODE_IP" "openclaw config set gateway.mode remote"

# Start node
ssh "root@$NODE_IP" "openclaw node start"

echo "=== Node $NODE_IP should now be connecting to Gateway ==="
echo "Check pending approvals with: openclaw nodes pending"
