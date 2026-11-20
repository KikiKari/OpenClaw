// abstraction-provenance: {"artifact_sha256": "37eeee1623c44fd770b714b0caa6a46519cf87b864c115b74c1699ac06189d44", "source_sha256": "b9f9f7d077816c22c00e1b63104179e775df75e2d0c7148a2b5af200ff8a17a6", "target_language": "go"}
// gateway-network-docker.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/e2e/gateway-network-docker.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/network"
	"github.com/docker/docker/client"
	"github.com/docker/go-connections/nat"
)

const (
	imageName = "openclaw-gateway-network-e2e"
	port      = "18789"
)

var (
	token   string
	netName string
	gwName  string
	rootDir string
)

func init() {
	exe, err := os.Executable()
	if err != nil {
		log.Fatal(err)
	}
	dir := filepath.Dir(exe)
	for i := 0; i < 3; i++ {
		dir = filepath.Dir(dir)
	}
	rootDir = dir

	token = fmt.Sprintf("e2e-%d-%d", time.Now().Unix(), os.Getpid())
	netName = fmt.Sprintf("openclaw-net-e2e-%d", os.Getpid())
	gwName = fmt.Sprintf("openclaw-gateway-e2e-%d", os.Getpid())
}

func main() {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		log.Fatal(err)
	}
	defer cli.Close()

	cleanup := func() {
		cli.ContainerRemove(ctx, gwName, types.ContainerRemoveOptions{Force: true})
		cli.NetworkRemove(ctx, netName)
	}
	defer cleanup()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		cleanup()
		os.Exit(1)
	}()

	fmt.Println("Building Docker image...")
	buildCmd := exec.Command("docker", "build", "-t", imageName, "-f", filepath.Join(rootDir, "scripts/e2e/Dockerfile"), rootDir)
	buildCmd.Stdout = os.Stdout
	buildCmd.Stderr = os.Stderr
	if err := buildCmd.Run(); err != nil {
		log.Fatalf("Failed to build Docker image: %v", err)
	}

	fmt.Println("Creating Docker network...")
	_, err = cli.NetworkCreate(ctx, netName, types.NetworkCreate{})
	if err != nil {
		log.Fatalf("Failed to create network: %v", err)
	}

	fmt.Println("Starting gateway container...")
	entrypoint := []string{
		"bash", "-lc",
		fmt.Sprintf(`set -euo pipefail; entry=dist/index.mjs; [ -f "$entry" ] || entry=dist/index.js; node "$entry" config set gateway.controlUi.enabled false >/dev/null; node "$entry" gateway --port %s --bind lan --allow-unconfigured > /tmp/gateway-net-e2e.log 2>&1`, port),
	}

	containerConfig := &container.Config{
		Image: imageName,
		Env: []string{
			"OPENCLAW_GATEWAY_TOKEN=" + token,
			"OPENCLAW_SKIP_CHANNELS=1",
			"OPENCLAW_SKIP_GMAIL_WATCHER=1",
			"OPENCLAW_SKIP_CRON=1",
			"OPENCLAW_SKIP_CANVAS_HOST=1",
		},
		Entrypoint: entrypoint,
		Tty:        false,
	}

	hostConfig := &container.HostConfig{}
	networkingConfig := &network.NetworkingConfig{
		EndpointsConfig: map[string]*network.EndpointSettings{
			netName: {},
		},
	}

	resp, err := cli.ContainerCreate(ctx, containerConfig, hostConfig, networkingConfig, nil, gwName)
	if err != nil {
		log.Fatalf("Failed to create container: %v", err)
	}

	if err := cli.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
		log.Fatalf("Failed to start container: %v", err)
	}

	fmt.Println("Waiting for gateway to come up...")
	ready := false
	for i := 0; i < 40; i++ {
		inspect, err := cli.ContainerInspect(ctx, gwName)
		if err != nil || !inspect.State.Running {
			break
		}

		execConfig := types.ExecConfig{
			Cmd: []string{
				"bash", "-lc",
				fmt.Sprintf(`node --input-type=module -e '
import net from "node:net";
const socket = net.createConnection({ host: "127.0.0.1", port: %s });
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
});'`, port),
			},
			AttachStdout: true,
			AttachStderr: true,
		}

		execResp, err := cli.ContainerExecCreate(ctx, gwName, execConfig)
		if err == nil {
			execAttach, err := cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
			if err == nil {
				execAttach.Close()
				execInspect, err := cli.ContainerExecInspect(ctx, execResp.ID)
				if err == nil && execInspect.ExitCode == 0 {
					ready = true
					break
				}
			}
		}

		execConfig2 := types.ExecConfig{
			Cmd:          []string{"bash", "-lc", "grep -q \"listening on ws://\" /tmp/gateway-net-e2e.log 2>/dev/null"},
			AttachStdout: true,
			AttachStderr: true,
		}
		execResp2, err := cli.ContainerExecCreate(ctx, gwName, execConfig2)
		if err == nil {
			execAttach2, err := cli.ContainerExecAttach(ctx, execResp2.ID, types.ExecStartCheck{})
			if err == nil {
				execAttach2.Close()
				execInspect2, err := cli.ContainerExecInspect(ctx, execResp2.ID)
				if err == nil && execInspect2.ExitCode == 0 {
					ready = true
					break
				}
			}
		}

		time.Sleep(500 * time.Millisecond)
	}

	if !ready {
		fmt.Println("Gateway failed to start")
		inspect, err := cli.ContainerInspect(ctx, gwName)
		if err == nil && inspect.State.Running {
			execConfig := types.ExecConfig{
				Cmd:          []string{"bash", "-lc", "tail -n 80 /tmp/gateway-net-e2e.log"},
				AttachStdout: true,
				AttachStderr: true,
			}
			execResp, err := cli.ContainerExecCreate(ctx, gwName, execConfig)
			if err == nil {
				execAttach, err := cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
				if err == nil {
					io.Copy(os.Stdout, execAttach.Reader)
					execAttach.Close()
				}
			}
		} else {
			out, err := cli.ContainerLogs(ctx, gwName, types.ContainerLogsOptions{
				ShowStdout: true,
				ShowStderr: true,
				Tail:       "120",
			})
			if err == nil {
				io.Copy(os.Stdout, out)
			}
		}
		os.Exit(1)
	}

	fmt.Println("Running client container (connect + health)...")

	clientEntrypoint := fmt.Sprintf(`node --import tsx - <<'NODE'
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
  })
);
const connectRes = await onceFrame((o) => o?.type === "res" && o?.id === "c1");
if (!connectRes.ok) throw new Error("connect failed: " + (connectRes.error?.message ?? "unknown"));

ws.close();
console.log("ok");
NODE`)

	clientContainerConfig := &container.Config{
		Image: imageName,
		Env: []string{
			"GW_URL=ws://" + gwName + ":" + port,
			"GW_TOKEN=" + token,
		},
		Cmd: []string{"bash", "-lc", clientEntrypoint},
	}

	clientHostConfig := &container.HostConfig{}
	clientNetworkingConfig := &network.NetworkingConfig{
		EndpointsConfig: map[string]*network.EndpointSettings{
			netName: {},
		},
	}

	clientResp, err := cli.ContainerCreate(ctx, clientContainerConfig, clientHostConfig, clientNetworkingConfig, nil, "")
	if err != nil {
		log.Fatalf("Failed to create client container: %v", err)
	}

	if err := cli.ContainerStart(ctx, clientResp.ID, types.ContainerStartOptions{}); err != nil {
		log.Fatalf("Failed to start client container: %v", err)
	}

	statusCh, errCh := cli.ContainerWait(ctx, clientResp.ID, container.WaitConditionNotRunning)
	select {
	case err := <-errCh:
		if err != nil {
			log.Fatalf("Error waiting for client container: %v", err)
		}
	case status := <-statusCh:
		if status.StatusCode != 0 {
			log.Fatalf("Client container exited with status: %d", status.StatusCode)
		}
	}

	fmt.Println("OK")
}
