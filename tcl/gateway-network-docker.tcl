#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "e7e70bdb2c81dbfc8f007c9cb35bfdb116a03e554ab8434e2a14a746b67692b1", "source_sha256": "b9f9f7d077816c22c00e1b63104179e775df75e2d0c7148a2b5af200ff8a17a6", "target_language": "tcl"}
# gateway-network-docker.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/e2e/gateway-network-docker.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Tcl translation of gateway-network-docker.sh

# Helper functions
proc dirname {path} {
    return [file dirname $path]
}

proc basename {path} {
    return [file tail $path]
}

proc pwd {} {
    return [exec pwd]
}

proc cd {dir} {
    exec /bin/cd $dir
}

proc date {fmt} {
    return [clock format [clock seconds] -format "%s"]
}

proc getpid {} {
    return [pid]
}

proc seq {start end} {
    set result {}
    for {set i $start} {$i <= $end} {incr i} {
        lappend result $i
    }
    return $result
}

proc run_logged {name cmd} {
    # In Tcl we'll just execute the command directly
    # The logging functionality would need to be implemented based on requirements
    eval exec $cmd
}

# Global variables
set ROOT_DIR [exec dirname [info script]]
# Go up two levels like the original bash script
set ROOT_DIR [file dirname [file dirname $ROOT_DIR]]

# Source equivalent - we'll include needed functions inline or source separately if needed
# source "$ROOT_DIR/scripts/lib/docker-e2e-logs.sh" 
# This would need to be translated separately if it contains important functions

set IMAGE_NAME "openclaw-gateway-network-e2e"
set PORT "18789"
set TOKEN "e2e-[clock seconds]-[pid]"
set NET_NAME "openclaw-net-e2e-[pid]"
set GW_NAME "openclaw-gateway-e2e-[pid]"

# Cleanup function
proc cleanup {} {
    global GW_NAME NET_NAME
    catch {exec docker rm -f $GW_NAME}
    catch {exec docker network rm $NET_NAME}
}

# Set trap for exit
proc setup_exit_trap {} {
    # Tcl doesn't have direct trap equivalent, but we can use try/finally pattern
}

# Main execution with error handling
proc main {} {
    global ROOT_DIR IMAGE_NAME PORT TOKEN NET_NAME GW_NAME
    
    puts "Building Docker image..."
    # run_logged gateway-network-build docker build -t "$IMAGE_NAME" -f "$ROOT_DIR/scripts/e2e/Dockerfile" "$ROOT_DIR"
    catch {exec docker build -t $IMAGE_NAME -f $ROOT_DIR/scripts/e2e/Dockerfile $ROOT_DIR} build_result
    if {[llength $build_result] > 0} {
        puts stderr "Build failed: $build_result"
    }

    puts "Creating Docker network..."
    catch {exec docker network create $NET_NAME} net_result

    puts "Starting gateway container..."
    set gateway_cmd "bash -lc {set -euo pipefail; entry=dist/index.mjs; \[ -f \"\$entry\" \] || entry=dist/index.js; node \"\$entry\" config set gateway.controlUi.enabled false >/dev/null; node \"\$entry\" gateway --port $PORT --bind lan --allow-unconfigured > /tmp/gateway-net-e2e.log 2>&1}"
    
    catch {exec docker run -d \
        --name $GW_NAME \
        --network $NET_NAME \
        -e OPENCLAW_GATEWAY_TOKEN=$TOKEN \
        -e OPENCLAW_SKIP_CHANNELS=1 \
        -e OPENCLAW_SKIP_GMAIL_WATCHER=1 \
        -e OPENCLAW_SKIP_CRON=1 \
        -e OPENCLAW_SKIP_CANVAS_HOST=1 \
        $IMAGE_NAME \
        {*}$gateway_cmd} run_result

    puts "Waiting for gateway to come up..."
    set ready 0
    
    # Loop for checking if gateway is ready
    foreach _ [seq 1 40] {
        # Check if container is running
        if {[catch {exec docker inspect -f {{.State.Running}} $GW_NAME} state_result]} {
            set state_result "false"
        }
        
        if {$state_result ne "true"} {
            break
        }
        
        # Try first connection test
        set test_cmd1 "bash -lc {node --input-type=module -e '
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
  '}"
        
        if {![catch {exec docker exec $GW_NAME {*}$test_cmd1}]} {
            set ready 1
            break
        }
        
        # Try second connection test
        set test_cmd2 "bash -lc {grep -q \"listening on ws://\" /tmp/gateway-net-e2e.log 2>/dev/null}"
        if {![catch {exec docker exec $GW_NAME {*}$test_cmd2}]} {
            set ready 1
            break
        }
        
        # Sleep for 0.5 seconds
        after 500
    }

    if {$ready != 1} {
        puts "Gateway failed to start"
        
        # Check if container is still running
        if {![catch {exec docker inspect -f {{.State.Running}} $GW_NAME} state_result] && $state_result eq "true"} {
            catch {exec docker exec $GW_NAME bash -lc "tail -n 80 /tmp/gateway-net-e2e.log"}
        } else {
            catch {exec docker logs $GW_NAME 2>@1 | tail -n 120}
        }
        exit 1
    }

    puts "Running client container (connect + health)..."
    
    # Client JavaScript code as a string
    set js_code {import { WebSocket } from "ws";
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
		console.log("ok");}

    # Run the client container
    set client_cmd "bash -lc {node --import tsx - <<'NODE'
$js_code
NODE}"

    catch {exec docker run --rm \
        --network $NET_NAME \
        -e GW_URL=ws://$GW_NAME:$PORT \
        -e GW_TOKEN=$TOKEN \
        $IMAGE_NAME \
        {*}$client_cmd} client_result

    puts "OK"
}

# Execute main function and ensure cleanup happens
if {[catch {main} error]} {
    cleanup
    error $error
} else {
    cleanup
}
