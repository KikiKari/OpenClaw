#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "a6ad3a777efaf2896a071d34028042998e7b91e86cb7f7642701d0c981b88aa9", "source_sha256": "b9f9f7d077816c22c00e1b63104179e775df75e2d0c7148a2b5af200ff8a17a6", "target_language": "javascript"}
// gateway-network-docker.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/e2e/gateway-network-docker.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

'use strict';

const fs = require('fs');
const path = require('path');
const { spawn, spawnSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '../..');
const IMAGE_NAME = 'openclaw-gateway-network-e2e';
const PORT = '18789';
const TOKEN = `e2e-${Date.now()}-${process.pid}`;
const NET_NAME = `openclaw-net-e2e-${process.pid}`;
const GW_NAME = `openclaw-gateway-e2e-${process.pid}`;

function runLogged(name, command, args = [], options = {}) {
  console.log(`Running ${name}...`);
  const proc = spawn(command, args, { ...options, stdio: 'inherit' });
  return new Promise((resolve, reject) => {
    proc.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${command} exited with code ${code}`));
      }
    });
  });
}

function cleanup() {
  spawnSync('docker', ['rm', '-f', GW_NAME], { stdio: 'ignore' });
  spawnSync('docker', ['network', 'rm', NET_NAME], { stdio: 'ignore' });
}

process.on('exit', cleanup);
process.on('SIGINT', () => {
  cleanup();
  process.exit(1);
});
process.on('SIGTERM', () => {
  cleanup();
  process.exit(1);
});

async function main() {
  try {
    console.log('Building Docker image...');
    await runLogged('gateway-network-build', 'docker', [
      'build',
      '-t',
      IMAGE_NAME,
      '-f',
      path.join(ROOT_DIR, 'scripts/e2e/Dockerfile'),
      ROOT_DIR
    ]);

    console.log('Creating Docker network...');
    spawnSync('docker', ['network', 'create', NET_NAME], {
      stdio: 'pipe'
    });

    console.log('Starting gateway container...');
    const gatewayProcess = spawn(
      'docker',
      [
        'run',
        '-d',
        '--name',
        GW_NAME,
        '--network',
        NET_NAME,
        '-e',
        `OPENCLAW_GATEWAY_TOKEN=${TOKEN}`,
        '-e',
        'OPENCLAW_SKIP_CHANNELS=1',
        '-e',
        'OPENCLAW_SKIP_GMAIL_WATCHER=1',
        '-e',
        'OPENCLAW_SKIP_CRON=1',
        '-e',
        'OPENCLAW_SKIP_CANVAS_HOST=1',
        IMAGE_NAME,
        'bash',
        '-lc',
        `set -euo pipefail; entry=dist/index.mjs; [ -f "\\$entry" ] || entry=dist/index.js; node "\\$entry" config set gateway.controlUi.enabled false >/dev/null; node "\\$entry" gateway --port ${PORT} --bind lan --allow-unconfigured > /tmp/gateway-net-e2e.log 2>&1`
      ],
      { stdio: 'ignore' }
    );

    console.log('Waiting for gateway to come up...');
    let ready = false;

    for (let i = 0; i < 40; i++) {
      const inspectResult = spawnSync(
        'docker',
        ['inspect', '-f', '{{.State.Running}}', GW_NAME],
        { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
      );
      
      if ((inspectResult.stdout || '').trim() !== 'true') {
        break;
      }

      const testConnection = spawnSync(
        'docker',
        [
          'exec',
          GW_NAME,
          'bash',
          '-lc',
          `node --input-type=module -e '
    import net from "node:net";
    const socket = net.createConnection({ host: "127.0.0.1", port: ${PORT} });
    const timeout = setTimeout(() => {
      socket.destroy();
      process.exit(1);
    }, 400);
    socket.on("connect", () => {
      clearTimeout(timeout);
      socket.end();
      process.exit(0);
    });
    socket.on("error", () => {
      clearTimeout(timeout);
      process.exit(1);
    });
  '`
        ],
        { stdio: 'ignore' }
      );

      if (testConnection.status === 0) {
        ready = true;
        break;
      }

      const grepResult = spawnSync(
        'docker',
        [
          'exec',
          GW_NAME,
          'bash',
          '-lc',
          'grep -q "listening on ws://" /tmp/gateway-net-e2e.log 2>/dev/null'
        ],
        { stdio: 'ignore' }
      );

      if (grepResult.status === 0) {
        ready = true;
        break;
      }

      await new Promise(resolve => setTimeout(resolve, 500));
    }

    if (!ready) {
      console.error('Gateway failed to start');
      
      const inspectResult = spawnSync(
        'docker',
        ['inspect', '-f', '{{.State.Running}}', GW_NAME],
        { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
      );
      
      if ((inspectResult.stdout || '').trim() === 'true') {
        spawnSync(
          'docker',
          [
            'exec',
            GW_NAME,
            'bash',
            '-lc',
            'tail -n 80 /tmp/gateway-net-e2e.log'
          ],
          { stdio: 'inherit' }
        );
      } else {
        spawnSync('docker', ['logs', GW_NAME], { stdio: 'inherit' });
      }
      
      process.exit(1);
    }

    console.log('Running client container (connect + health)...');
    
    const clientCode = `
import { WebSocket } from "ws";
import { PROTOCOL_VERSION } from "./src/gateway/protocol/index.ts";

const url = process.env.GW_URL;
const token = process.env.GW_TOKEN;
if (!url || !token) throw new Error("missing GW_URL/GW_TOKEN");

const ws = new WebSocket(url);
await new Promise((resolve, reject) => {
  const t = setTimeout(() => reject(new Error("ws open timeout")), 5000);
  ws.once("open", () => {
    clearTimeout(t);
    resolve();
  });
});

function onceFrame(filter, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error("timeout")), timeoutMs);
    const handler = (data) => {
      const obj = JSON.parse(String(data));
      if (!filter(obj)) return;
      clearTimeout(t);
      ws.off("message", handler);
      resolve(obj);
    };
    ws.on("message", handler);
  });
}

ws.send(
  JSON.stringify({
    type: "req",
    id: "c1",
    method: "connect",
    params: {
      minProtocol: PROTOCOL_VERSION,
      maxProtocol: PROTOCOL_VERSION,
      client: {
        id: "test",
        displayName: "docker-net-e2e",
        version: "dev",
        platform: process.platform,
        mode: "test",
      },
      caps: [],
      auth: { token },
    },
  }),
);
const connectRes = await onceFrame((o) => o?.type === "res" && o?.id === "c1");
if (!connectRes.ok) throw new Error("connect failed: " + (connectRes.error?.message ?? "unknown"));

ws.close();
console.log("ok");
`;

    await runLogged('gateway-network-client', 'docker', [
      'run',
      '--rm',
      '--network',
      NET_NAME,
      '-e',
      `GW_URL=ws://${GW_NAME}:${PORT}`,
      '-e',
      `GW_TOKEN=${TOKEN}`,
      IMAGE_NAME,
      'bash',
      '-lc',
      `node --import tsx - <<'NODE'\n${clientCode}\nNODE`
    ]);

    console.log('OK');
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

main();
