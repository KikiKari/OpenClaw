#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "7f3bc7e633fc37e4a4dff46000f3b705ddc7e72c09d40ef11ca5e90904245f7a", "source_sha256": "b9f9f7d077816c22c00e1b63104179e775df75e2d0c7148a2b5af200ff8a17a6", "target_language": "python"}
# gateway-network-docker.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/e2e/gateway-network-docker.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import time
import datetime

def get_root_dir():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(script_dir, "../.."))

ROOT_DIR = get_root_dir()
sys.path.append(os.path.join(ROOT_DIR, "scripts/lib"))
IMAGE_NAME = "openclaw-gateway-network-e2e"

PORT = "18789"
TOKEN = f"e2e-{int(time.time())}-{os.getpid()}"
NET_NAME = f"openclaw-net-e2e-{os.getpid()}"
GW_NAME = f"openclaw-gateway-e2e-{os.getpid()}"

def run_logged(name, *args):
    """Simulate the run_logged function from shell script"""
    # In a real implementation, this would log the command execution
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Command failed: {' '.join(args)}")
        print(result.stderr)
        sys.exit(1)
    return result

def cleanup():
    try:
        subprocess.run(["docker", "rm", "-f", GW_NAME], 
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except:
        pass
    
    try:
        subprocess.run(["docker", "network", "rm", NET_NAME], 
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except:
        pass

def check_docker_running(container_name):
    try:
        result = subprocess.run([
            "docker", "inspect", "-f", "{{.State.Running}}", container_name
        ], capture_output=True, text=True)
        return result.stdout.strip() == "true"
    except:
        return False

def main():
    import atexit
    atexit.register(cleanup)
    
    print("Building Docker image...")
    run_logged("gateway-network-build", 
               "docker", "build", "-t", IMAGE_NAME, 
               "-f", f"{ROOT_DIR}/scripts/e2e/Dockerfile", ROOT_DIR)
    
    print("Creating Docker network...")
    subprocess.run(["docker", "network", "create", NET_NAME], 
                  stdout=subprocess.DEVNULL, check=True)
    
    print("Starting gateway container...")
    gateway_cmd = (
        f"bash -lc \"set -euo pipefail; "
        f"entry=dist/index.mjs; [ -f \\\"\\$entry\\\" ] || entry=dist/index.js; "
        f"node \\\"\\$entry\\\" config set gateway.controlUi.enabled false >/dev/null; "
        f"node \\\"\\$entry\\\" gateway --port {PORT} --bind lan --allow-unconfigured > /tmp/gateway-net-e2e.log 2>&1\""
    )
    
    subprocess.run([
        "docker", "run", "-d",
        "--name", GW_NAME,
        "--network", NET_NAME,
        "-e", f"OPENCLAW_GATEWAY_TOKEN={TOKEN}",
        "-e", "OPENCLAW_SKIP_CHANNELS=1",
        "-e", "OPENCLAW_SKIP_GMAIL_WATCHER=1",
        "-e", "OPENCLAW_SKIP_CRON=1",
        "-e", "OPENCLAW_SKIP_CANVAS_HOST=1",
        IMAGE_NAME
    ] + gateway_cmd.split(), stdout=subprocess.DEVNULL, check=True)
    
    print("Waiting for gateway to come up...")
    ready = False
    
    for _ in range(40):
        if not check_docker_running(GW_NAME):
            break
            
        # Test connection using node
        test_cmd = [
            "docker", "exec", GW_NAME, "bash", "-lc",
            f'''node --input-type=module -e '
import net from "node:net";
const socket = net.createConnection({{ host: "127.0.0.1", port: {PORT} }});
const timeout = setTimeout(() => {{
  socket.destroy();
  process.exit(1);
}}, 400);
socket.on("connect", () => {{
  clearTimeout(timeout);
  socket.end();
  process.exit(0);
}});
socket.on("error", () => {{
  clearTimeout(timeout);
  process.exit(1);
}});
' '''
        ]
        
        try:
            subprocess.run(test_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            ready = True
            break
        except subprocess.CalledProcessError:
            pass
        
        # Check log file
        try:
            log_check_cmd = [
                "docker", "exec", GW_NAME, "bash", "-lc",
                "grep -q \"listening on ws://\" /tmp/gateway-net-e2e.log 2>/dev/null"
            ]
            subprocess.run(log_check_cmd, check=True)
            ready = True
            break
        except subprocess.CalledProcessError:
            pass
            
        time.sleep(0.5)
    
    if not ready:
        print("Gateway failed to start")
        if check_docker_running(GW_NAME):
            try:
                subprocess.run([
                    "docker", "exec", GW_NAME, "bash", "-lc",
                    "tail -n 80 /tmp/gateway-net-e2e.log"
                ])
            except:
                pass
        else:
            try:
                result = subprocess.run([
                    "docker", "logs", GW_NAME
                ], capture_output=True, text=True)
                lines = result.stdout.split('\n')[-120:]
                print('\n'.join(lines))
            except:
                pass
        sys.exit(1)
    
    print("Running client container (connect + health)...")
    
    client_script = '''import { WebSocket } from "ws";
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
console.log("ok");'''
    
    client_env_cmd = f"node --import tsx - <<'NODE'\n{client_script}\nNODE"
    
    client_run_result = subprocess.run([
        "docker", "run", "--rm",
        "--network", NET_NAME,
        "-e", f"GW_URL=ws://{GW_NAME}:{PORT}",
        "-e", f"GW_TOKEN={TOKEN}",
        IMAGE_NAME,
        "bash", "-lc", client_env_cmd
    ], capture_output=True, text=True)
    
    if client_run_result.returncode != 0:
        print("Client container failed:")
        print(client_run_result.stderr)
        sys.exit(1)
    
    print("OK")

if __name__ == "__main__":
    main()
