#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "311a41ea7317c49f2d1970bb90fa30cd113e63c73d0c79b048b70b3b1f4920b6", "source_sha256": "b9f9f7d077816c22c00e1b63104179e775df75e2d0c7148a2b5af200ff8a17a6", "target_language": "perl5"}
# gateway-network-docker.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/e2e/gateway-network-docker.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use File::Basename qw(dirname);
use POSIX qw(strftime);

my $ROOT_DIR = dirname(dirname(dirname(abs_path(__FILE__)))) . "";
do "$ROOT_DIR/scripts/lib/docker-e2e-logs.pl";
die "Could not load docker-e2e-logs.pl: $@" if $@;

my $IMAGE_NAME = "openclaw-gateway-network-e2e";
my $PORT = "18789";
my $TOKEN = "e2e-" . time() . "-" . $$;
my $NET_NAME = "openclaw-net-e2e-" . $$;
my $GW_NAME = "openclaw-gateway-e2e-" . $$;

sub cleanup {
    system("docker", "rm", "-f", $GW_NAME) == 0 or warn "Failed to remove container\n";
    system("docker", "network", "rm", $NET_NAME) == 0 or warn "Failed to remove network\n";
}

$SIG{INT} = \&cleanup;
$SIG{TERM} = \&cleanup;
END { cleanup(); }

print "Building Docker image...\n";
run_logged("gateway-network-build", "docker", "build", "-t", $IMAGE_NAME, "-f", "$ROOT_DIR/scripts/e2e/Dockerfile", $ROOT_DIR);

print "Creating Docker network...\n";
system("docker", "network", "create", $NET_NAME) == 0 or die "Failed to create network";

print "Starting gateway container...\n";
system("docker", "run", "-d",
       "--name", $GW_NAME,
       "--network", $NET_NAME,
       "-e", "OPENCLAW_GATEWAY_TOKEN=$TOKEN",
       "-e", "OPENCLAW_SKIP_CHANNELS=1",
       "-e", "OPENCLAW_SKIP_GMAIL_WATCHER=1",
       "-e", "OPENCLAW_SKIP_CRON=1",
       "-e", "OPENCLAW_SKIP_CANVAS_HOST=1",
       $IMAGE_NAME,
       "bash", "-lc", "set -euo pipefail; entry=dist/index.mjs; [ -f \"\$entry\" ] || entry=dist/index.js; node \"\$entry\" config set gateway.controlUi.enabled false >/dev/null; node \"\$entry\" gateway --port $PORT --bind lan --allow-unconfigured > /tmp/gateway-net-e2e.log 2>&1") == 0 or die "Failed to start gateway container";

print "Waiting for gateway to come up...\n";
my $ready = 0;
for my $i (1..40) {
    my $running = `docker inspect -f '{{.State.Running}}' "$GW_NAME" 2>/dev/null`;
    chomp($running);
    if ($running ne "true") {
        last;
    }
    
    my $cmd1 = qq(docker exec "$GW_NAME" bash -lc "node --input-type=module -e '
    import net from \"node:net\";
    const socket = net.createConnection({ host: \"127.0.0.1\", port: $PORT });
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
  ' >/dev/null 2>&1");
    
    if (system($cmd1) == 0) {
        $ready = 1;
        last;
    }
    
    my $cmd2 = qq(docker exec "$GW_NAME" bash -lc "grep -q \"listening on ws://\" /tmp/gateway-net-e2e.log 2>/dev/null");
    if (system($cmd2) == 0) {
        $ready = 1;
        last;
    }
    
    sleep(0.5);
}

if ($ready != 1) {
    print "Gateway failed to start\n";
    my $running = `docker inspect -f '{{.State.Running}}' "$GW_NAME" 2>/dev/null`;
    chomp($running);
    if ($running eq "true") {
        system("docker", "exec", $GW_NAME, "bash", "-lc", "tail -n 80 /tmp/gateway-net-e2e.log");
    } else {
        system("docker", "logs", $GW_NAME, "2>&1", "|", "tail", "-n", "120");
    }
    exit(1);
}

print "Running client container (connect + health)...\n";
my $client_cmd = qq(docker run --rm \\
  --network "$NET_NAME" \\
  -e "GW_URL=ws://$GW_NAME:$PORT" \\
  -e "GW_TOKEN=$TOKEN" \\
  "$IMAGE_NAME" \\
  bash -lc "node --import tsx - <<'NODE'
import { WebSocket } from \\\"ws\\\";
import { PROTOCOL_VERSION } from \\\"./src/gateway/protocol/index.ts\\\";

const url = process.env.GW_URL;
const token = process.env.GW_TOKEN;
if (!url || !token) throw new Error(\\\"missing GW_URL/GW_TOKEN\\\");

const ws = new WebSocket(url);
await new Promise((resolve, reject) => {
  const t = setTimeout(() => reject(new Error(\\\"ws open timeout\\\")), 5000);
  ws.once(\\\"open\\\", () => {
    clearTimeout(t);
    resolve();
  });
});

function onceFrame(filter, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(\\\"timeout\\\")), timeoutMs);
    const handler = (data) => {
      const obj = JSON.parse(String(data));
      if (!filter(obj)) return;
      clearTimeout(t);
      ws.off(\\\"message\\\", handler);
      resolve(obj);
    };
    ws.on(\\\"message\\\", handler);
  });
}

ws.send(
  JSON.stringify({
    type: \\\"req\\\",
    id: \\\"c1\\\",
    method: \\\"connect\\\",
    params: {
      minProtocol: PROTOCOL_VERSION,
      maxProtocol: PROTOCOL_VERSION,
      client: {
        id: \\\"test\\\",
        displayName: \\\"docker-net-e2e\\\",
        version: \\\"dev\\\",
        platform: process.platform,
        mode: \\\"test\\\",
	      },
	      caps: [],
	      auth: { token },
	    },
	  }),
			);
		const connectRes = await onceFrame((o) => o?.type === \\\"res\\\" && o?.id === \\\"c1\\\");
		if (!connectRes.ok) throw new Error(\\\"connect failed: \\\" + (connectRes.error?.message ?? \\\"unknown\\\"));

		ws.close();
		console.log(\\\"ok\\\");
NODE");

system($client_cmd) == 0 or die "Client container failed";
print "OK\n";
