#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "c859183bc786e34ed004e0539735d92e74832858759a8e9d7bcec3ed46dc8bfe", "source_sha256": "b9f9f7d077816c22c00e1b63104179e775df75e2d0c7148a2b5af200ff8a17a6", "target_language": "lua"}
-- gateway-network-docker.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/e2e/gateway-network-docker.sh
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local ROOT_DIR = os.getenv("ROOT_DIR") or (function()
  local script_dir = arg[0]:match("(.*/)")
  return script_dir .. "../../"
end)()

package.path = package.path .. ";" .. ROOT_DIR .. "/scripts/lib/?.lua"

local IMAGE_NAME = "openclaw-gateway-network-e2e"
local PORT = "18789"
local TOKEN = "e2e-" .. os.time() .. "-" .. tostring(math.random(10000, 99999))
local NET_NAME = "openclaw-net-e2e-" .. tostring(math.random(10000, 99999))
local GW_NAME = "openclaw-gateway-e2e-" .. tostring(math.random(10000, 99999))

-- Cleanup function
local function cleanup()
  os.execute("docker rm -f " .. GW_NAME .. " > /dev/null 2>&1 || true")
  os.execute("docker network rm " .. NET_NAME .. " > /dev/null 2>&1 || true")
end

-- Set trap for cleanup on exit
local original_exit = os.exit
os.exit = function(code)
  cleanup()
  original_exit(code)
end

print("Building Docker image...")
local build_cmd = string.format(
  "docker build -t %s -f %s/scripts/e2e/Dockerfile %s",
  IMAGE_NAME, ROOT_DIR, ROOT_DIR
)
local success = os.execute(build_cmd)
if not success then
  print("Build failed")
  os.exit(1)
end

print("Creating Docker network...")
os.execute("docker network create " .. NET_NAME .. " > /dev/null")

print("Starting gateway container...")
local gateway_cmd = string.format([[
docker run -d \
  --name %s \
  --network %s \
  -e "OPENCLAW_GATEWAY_TOKEN=%s" \
  -e "OPENCLAW_SKIP_CHANNELS=1" \
  -e "OPENCLAW_SKIP_GMAIL_WATCHER=1" \
  -e "OPENCLAW_SKIP_CRON=1" \
  -e "OPENCLAW_SKIP_CANVAS_HOST=1" \
  %s \
  bash -lc "set -euo pipefail; entry=dist/index.mjs; [ -f \"\$entry\" ] || entry=dist/index.js; node \"\$entry\" config set gateway.controlUi.enabled false >/dev/null; node \"\$entry\" gateway --port %s --bind lan --allow-unconfigured > /tmp/gateway-net-e2e.log 2>&1" >/dev/null
]], GW_NAME, NET_NAME, TOKEN, IMAGE_NAME, PORT)

success = os.execute(gateway_cmd)
if not success then
  print("Failed to start gateway container")
  os.exit(1)
end

print("Waiting for gateway to come up...")
local ready = false
for i = 1, 40 do
  -- Check if container is running
  local handle = io.popen(string.format([[docker inspect -f '{{.State.Running}}' %s 2>/dev/null || echo false]], GW_NAME))
  local result = handle:read("*a"):gsub("%s+", "")
  handle:close()
  
  if result ~= "true" then
    break
  end
  
  -- Try connecting via TCP
  local test_connect = string.format([[
docker exec %s bash -lc "node --input-type=module -e '
  import net from \"node:net\";
  const socket = net.createConnection({ host: \"127.0.0.1\", port: %s });
  const timeout = setTimeout(() => {
    socket.destroy();
    process.exit(1);
  }, 400);
  socket.on(\"connect\", () => {
    clearTimeout(timeout);
    socket.end();
    process.exit(0);
  });
  socket.on(\"error\", () => {
    clearTimeout(timeout);
    process.exit(1);
  });
' >/dev/null 2>&1"
]], GW_NAME, PORT)
  
  if os.execute(test_connect) then
    ready = true
    break
  end
  
  -- Check log file for listening message
  local check_log = string.format([[
docker exec %s bash -lc "grep -q \"listening on ws://\" /tmp/gateway-net-e2e.log 2>/dev/null"
]], GW_NAME)
  
  if os.execute(check_log) then
    ready = true
    break
  end
  
  os.execute("sleep 0.5")
end

if not ready then
  print("Gateway failed to start")
  -- Check if still running and show logs
  local handle = io.popen(string.format([[docker inspect -f '{{.State.Running}}' %s 2>/dev/null || echo false]], GW_NAME))
  local running = handle:read("*a"):gsub("%s+", "") == "true"
  handle:close()
  
  if running then
    os.execute(string.format([[docker exec %s bash -lc "tail -n 80 /tmp/gateway-net-e2e.log" || true]], GW_NAME))
  else
    os.execute(string.format([[docker logs %s 2>&1 | tail -n 120 || true]], GW_NAME))
  end
  os.exit(1)
end

print("Running client container (connect + health)...")
local client_cmd = string.format([[
docker run --rm \
  --network %s \
  -e "GW_URL=ws://%s:%s" \
  -e "GW_TOKEN=%s" \
  %s \
  bash -lc "node --import tsx - <<'NODE'
import { WebSocket } from \"ws\";
import { PROTOCOL_VERSION } from \"./src/gateway/protocol/index.ts\";

const url = process.env.GW_URL;
const token = process.env.GW_TOKEN;
if (!url || !token) throw new Error(\"missing GW_URL/GW_TOKEN\");

const ws = new WebSocket(url);
await new Promise((resolve, reject) => {
  const t = setTimeout(() => reject(new Error(\"ws open timeout\")), 5000);
  ws.once(\"open\", () => {
    clearTimeout(t);
    resolve();
  });
});

function onceFrame(filter, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(\"timeout\")), timeoutMs);
    const handler = (data) => {
      const obj = JSON.parse(String(data));
      if (!filter(obj)) return;
      clearTimeout(t);
      ws.off(\"message\", handler);
      resolve(obj);
    };
    ws.on(\"message\", handler);
  });
}

ws.send(
  JSON.stringify({
    type: \"req\",
    id: \"c1\",
    method: \"connect\",
    params: {
      minProtocol: PROTOCOL_VERSION,
      maxProtocol: PROTOCOL_VERSION,
      client: {
        id: \"test\",
        displayName: \"docker-net-e2e\",
        version: \"dev\",
        platform: process.platform,
        mode: \"test\",
	      },
	      caps: [],
	      auth: { token },
	    },
	  }),
			);
		const connectRes = await onceFrame((o) => o?.type === \"res\" && o?.id === \"c1\");
		if (!connectRes.ok) throw new Error(\"connect failed: \" + (connectRes.error?.message ?? \"unknown\"));

		ws.close();
		console.log(\"ok\");
NODE"
]], NET_NAME, GW_NAME, PORT, TOKEN, IMAGE_NAME)

success = os.execute(client_cmd)
if not success then
  print("Client connection failed")
  os.exit(1)
end

print("OK")
