#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "03582d3df86a221ef5b10e3865ca201935ba636e49894e0b48e8c96b3ed95553", "source_sha256": "b9f9f7d077816c22c00e1b63104179e775df75e2d0c7148a2b5af200ff8a17a6", "target_language": "ruby"}
# gateway-network-docker.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/e2e/gateway-network-docker.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'fileutils'
require 'securerandom'

ROOT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '../..'))
IMAGE_NAME = 'openclaw-gateway-network-e2e'
PORT = '18789'
TOKEN = "e2e-#{Time.now.to_i}-#{$$}"
NET_NAME = "openclaw-net-e2e-#{$$}"
GW_NAME = "openclaw-gateway-e2e-#{$$}"

def run_logged(name, *cmd)
  puts "Running #{name}..."
  Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
    stdin.close
    stdout_thread = Thread.new { stdout.read }
    stderr_thread = Thread.new { stderr.read }
    stdout_content = stdout_thread.value
    stderr_content = stderr_thread.value
    exit_status = wait_thr.value
    
    if !exit_status.success?
      puts "Command failed: #{cmd.join(' ')}"
      puts "STDOUT: #{stdout_content}" unless stdout_content.empty?
      puts "STDERR: #{stderr_content}" unless stderr_content.empty?
      exit exit_status.to_i
    end
  end
end

def cleanup
  system("docker", "rm", "-f", GW_NAME, out: File::NULL, err: File::NULL) rescue nil
  system("docker", "network", "rm", NET_NAME, out: File::NULL, err: File::NULL) rescue nil
end

at_exit { cleanup }

puts 'Building Docker image...'
run_logged('gateway-network-build', 'docker', 'build', '-t', IMAGE_NAME, '-f', "#{ROOT_DIR}/scripts/e2e/Dockerfile", ROOT_DIR)

puts 'Creating Docker network...'
system('docker', 'network', 'create', NET_NAME, out: File::NULL) or exit 1

puts 'Starting gateway container...'
system('docker', 'run', '-d',
       '--name', GW_NAME,
       '--network', NET_NAME,
       '-e', "OPENCLAW_GATEWAY_TOKEN=#{TOKEN}",
       '-e', 'OPENCLAW_SKIP_CHANNELS=1',
       '-e', 'OPENCLAW_SKIP_GMAIL_WATCHER=1',
       '-e', 'OPENCLAW_SKIP_CRON=1',
       '-e', 'OPENCLAW_SKIP_CANVAS_HOST=1',
       IMAGE_NAME,
       'bash', '-lc', 
       'set -euo pipefail; entry=dist/index.mjs; [ -f "$entry" ] || entry=dist/index.js; node "$entry" config set gateway.controlUi.enabled false >/dev/null; node "$entry" gateway --port ' + PORT + ' --bind lan --allow-unconfigured > /tmp/gateway-net-e2e.log 2>&1',
       out: File::NULL) or exit 1

puts 'Waiting for gateway to come up...'
ready = false
40.times do
  running_output, _, status = Open3.capture3('docker', 'inspect', '-f', '{{.State.Running}}', GW_NAME)
  break if status.success? && running_output.strip != 'true'
  
  check_cmd = <<-CMD
    node --input-type=module -e '
      import net from "node:net";
      const socket = net.createConnection({ host: "127.0.0.1", port: #{PORT} });
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
    '
  CMD
  
  if system("docker", "exec", GW_NAME, "bash", "-lc", check_cmd, out: File::NULL, err: File::NULL)
    ready = true
    break
  end
  
  if system("docker", "exec", GW_NAME, "bash", "-lc", "grep -q \"listening on ws://\" /tmp/gateway-net-e2e.log 2>/dev/null", out: File::NULL, err: File::NULL)
    ready = true
    break
  end
  
  sleep 0.5
end

unless ready
  puts 'Gateway failed to start'
  running_output, _, status = Open3.capture3('docker', 'inspect', '-f', '{{.State.Running}}', GW_NAME)
  if status.success? && running_output.strip == 'true'
    system("docker", "exec", GW_NAME, "bash", "-lc", "tail -n 80 /tmp/gateway-net-e2e.log") rescue nil
  else
    system("docker", "logs", GW_NAME, err: [:child, :out]) rescue nil
  end
  exit 1
end

puts 'Running client container (connect + health)...'
client_script = <<~NODE
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
NODE

result = system('docker', 'run', '--rm',
                '--network', NET_NAME,
                '-e', "GW_URL=ws://#{GW_NAME}:#{PORT}",
                '-e', "GW_TOKEN=#{TOKEN}",
                IMAGE_NAME,
                'bash', '-lc', "node --import tsx - <<'NODE'\n#{client_script}\nNODE")

unless result
  puts 'Client connection failed'
  exit 1
end

puts 'OK'
