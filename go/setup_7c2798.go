// abstraction-provenance: {"artifact_sha256": "e182d51b7a32427240cbe2b868b2195f73d02520a515c5a89c8eff4fbf749110", "source_sha256": "7c279836c2c2bf7bf1f0cd8868a320423a0e69387a65cec698db01e1d888a57a", "target_language": "go"}
// setup.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/setup.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"math/big"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
)

var (
	rootDir           string
	composeFile       string
	extraComposeFile   string
	imageName         string
	extraMounts       string
	homeVolumeName    string
	rawSandboxSetting string
	sandboxEnabled    string
	dockerSocketPath  string
	timezone          string
)

func fail(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
	os.Exit(1)
}

func requireCmd(name string) {
	if _, err := exec.LookPath(name); err != nil {
		fail("Missing dependency: %s", name)
	}
}

func runDockerBuild(args ...string) error {
	cmd := exec.Command("docker", append([]string{"build"}, args...)...)
	cmd.Env = append(os.Environ(), "DOCKER_BUILDKIT=1")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func isTruthyValue(raw string) bool {
	lower := strings.ToLower(strings.TrimSpace(raw))
	switch lower {
	case "1", "true", "yes", "on":
		return true
	default:
		return false
	}
}

func readConfigGatewayToken() (string, error) {
	configPath := filepath.Join(os.Getenv("OPENCLAW_CONFIG_DIR"), "openclaw.json")
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return "", nil
	}

	if _, err := exec.LookPath("python3"); err == nil {
		script := `
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
except Exception:
    raise SystemExit(0)

gateway = cfg.get("gateway")
if not isinstance(gateway, dict):
    raise SystemExit(0)
auth = gateway.get("auth")
if not isinstance(auth, dict):
    raise SystemExit(0)
token = auth.get("token")
if isinstance(token, str):
    token = token.strip()
    if token:
        print(token)
`
		cmd := exec.Command("python3", "-", configPath)
		cmd.Stdin = strings.NewReader(script)
		output, err := cmd.Output()
		if err == nil {
			return strings.TrimSpace(string(output)), nil
		}
	}

	if _, err := exec.LookPath("node"); err == nil {
		script := `
const fs = require("node:fs");
const configPath = process.argv[2];
try {
  const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const token = cfg?.gateway?.auth?.token;
  if (typeof token === "string" && token.trim().length > 0) {
    process.stdout.write(token.trim());
  }
} catch {
  // Keep docker-setup resilient when config parsing fails.
}`
		cmd := exec.Command("node", "-", configPath)
		cmd.Stdin = strings.NewReader(script)
		output, err := cmd.Output()
		if err == nil {
			return strings.TrimSpace(string(output)), nil
		}
	}

	return "", nil
}

func readEnvGatewayToken(envPath string) (string, error) {
	if _, err := os.Stat(envPath); os.IsNotExist(err) {
		return "", nil
	}

	file, err := os.Open(envPath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimRight(scanner.Text(), "\r")
		if strings.HasPrefix(line, "OPENCLAW_GATEWAY_TOKEN=") {
			return strings.TrimPrefix(line, "OPENCLAW_GATEWAY_TOKEN="), nil
		}
	}

	return "", scanner.Err()
}

func syncGatewayConfig(composeArgs []string) error {
	var allowedOriginJSON string
	var currentAllowedOrigins string

	if os.Getenv("OPENCLAW_GATEWAY_BIND") != "loopback" {
		port := os.Getenv("OPENCLAW_GATEWAY_PORT")
		allowedOriginJSON = fmt.Sprintf(`["http://localhost:%s","http://127.0.0.1:%s"]`, port, port)
		currentAllowedOriginsBytes, _ := runPrestartCli(composeArgs, "config", "get", "gateway.controlUi.allowedOrigins")
		currentAllowedOrigins = strings.ReplaceAll(strings.TrimSpace(string(currentAllowedOriginsBytes)), "\r", "")
	}

	batchJSON := fmt.Sprintf(`[{"path":"gateway.mode","value":"local"},{"path":"gateway.bind","value":"%s"}`, os.Getenv("OPENCLAW_GATEWAY_BIND"))
	if allowedOriginJSON != "" {
		if currentAllowedOrigins != "" && currentAllowedOrigins != "null" && currentAllowedOrigins != "[]" {
			fmt.Println("Control UI allowlist already configured; leaving gateway.controlUi.allowedOrigins unchanged.")
		} else {
			batchJSON += fmt.Sprintf(`,{"path":"gateway.controlUi.allowedOrigins","value":%s}`, allowedOriginJSON)
		}
	}
	batchJSON += "]"

	_, err := runPrestartCli(composeArgs, "config", "set", "--batch-json", batchJSON)
	if err != nil {
		return err
	}

	fmt.Printf("Pinned gateway.mode=local and gateway.bind=%s for Docker setup.\n", os.Getenv("OPENCLAW_GATEWAY_BIND"))
	if allowedOriginJSON != "" {
		if currentAllowedOrigins == "" || currentAllowedOrigins == "null" || currentAllowedOrigins == "[]" {
			fmt.Printf("Set gateway.controlUi.allowedOrigins to %s for non-loopback bind.\n", allowedOriginJSON)
		}
	}

	return nil
}

func runPrestartGateway(composeArgs []string, args ...string) ([]byte, error) {
	finalArgs := append([]string{"compose"}, composeArgs...)
	finalArgs = append(finalArgs, "run", "--rm", "--no-deps")
	finalArgs = append(finalArgs, args...)
	cmd := exec.Command("docker", finalArgs...)
	return cmd.Output()
}

func runPrestartCli(composeArgs []string, args ...string) ([]byte, error) {
	allArgs := append([]string{"--entrypoint", "node", "openclaw-gateway", "dist/index.js"}, args...)
	return runPrestartGateway(composeArgs, allArgs...)
}

func runRuntimeCli(composeArgs []string, composeScope, depsMode string, args ...string) ([]byte, error) {
	var composeScopeArgs []string
	switch composeScope {
	case "current":
		composeScopeArgs = composeArgs
	case "base":
		composeScopeArgs = getBaseComposeArgs(composeArgs)
	default:
		fail("Unknown runtime CLI compose scope: %s", composeScope)
	}

	var runArgs []string
	switch depsMode {
	case "with-deps":
	case "no-deps":
		runArgs = append(runArgs, "--no-deps")
	default:
		fail("Unknown runtime CLI deps mode: %s", depsMode)
	}

	finalArgs := append([]string{"compose"}, composeScopeArgs...)
	finalArgs = append(finalArgs, append(runArgs, append([]string{"run", "--rm"}, args...)...)...)
	cmd := exec.Command("docker", finalArgs...)
	return cmd.Output()
}

func containsDisallowedChars(value string) bool {
	return strings.ContainsAny(value, "\n\r\t")
}

func isValidTimezone(value string) bool {
	path := filepath.Join("/usr/share/zoneinfo", value)
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func validateMountPathValue(label, value string) {
	if value == "" {
		fail("%s cannot be empty.", label)
	}
	if containsDisallowedChars(value) {
		fail("%s contains unsupported control characters.", label)
	}
	if strings.Contains(value, " ") {
		fail("%s cannot contain whitespace.", label)
	}
}

func validateNamedVolume(value string) {
	re := regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_.-]*$`)
	if !re.MatchString(value) {
		fail("OPENCLAW_HOME_VOLUME must match [A-Za-z0-9][A-Za-z0-9_.-]* when using a named volume.")
	}
}

func validateMountSpec(mount string) {
	if containsDisallowedChars(mount) {
		fail("OPENCLAW_EXTRA_MOUNTS entries cannot contain control characters.")
	}
	re := regexp.MustCompile(`^[^[:space:],:]+:[^[:space:],:]+(:[^[:space:],:]+)?$`)
	if !re.MatchString(mount) {
		fail("Invalid mount format '%s'. Expected source:target[:options] without spaces.", mount)
	}
}

func getBaseComposeArgs(composeArgs []string) []string {
	baseArgs := make([]string, len(composeArgs))
	copy(baseArgs, composeArgs)
	return baseArgs
}

func writeExtraCompose(homeVolume string, mounts ...string) error {
	file, err := os.Create(extraComposeFile)
	if err != nil {
		return err
	}
	defer file.Close()

	writer := bufio.NewWriter(file)
	defer writer.Flush()

	writer.WriteString("services:\n  openclaw-gateway:\n    volumes:\n")

	var gatewayHomeMount, gatewayConfigMount, gatewayWorkspaceMount string
	if homeVolume != "" {
		gatewayHomeMount = fmt.Sprintf("%s:/home/node", homeVolume)
		gatewayConfigMount = fmt.Sprintf("%s:/home/node/.openclaw", os.Getenv("OPENCLAW_CONFIG_DIR"))
		gatewayWorkspaceMount = fmt.Sprintf("%s:/home/node/.openclaw/workspace", os.Getenv("OPENCLAW_WORKSPACE_DIR"))
		validateMountSpec(gatewayHomeMount)
		validateMountSpec(gatewayConfigMount)
		validateMountSpec(gatewayWorkspaceMount)
		fmt.Fprintf(writer, "      - %s\n", gatewayHomeMount)
		fmt.Fprintf(writer, "      - %s\n", gatewayConfigMount)
		fmt.Fprintf(writer, "      - %s\n", gatewayWorkspaceMount)
	}

	for _, mount := range mounts {
		validateMountSpec(mount)
		fmt.Fprintf(writer, "      - %s\n", mount)
	}

	writer.WriteString("  openclaw-cli:\n    volumes:\n")

	if homeVolume != "" {
		fmt.Fprintf(writer, "      - %s\n", gatewayHomeMount)
		fmt.Fprintf(writer, "      - %s\n", gatewayConfigMount)
		fmt.Fprintf(writer, "      - %s\n", gatewayWorkspaceMount)
	}

	for _, mount := range mounts {
		validateMountSpec(mount)
		fmt.Fprintf(writer, "      - %s\n", mount)
	}

	if homeVolume != "" && !strings.Contains(homeVolume, "/") {
		validateNamedVolume(homeVolume)
		fmt.Fprintf(writer, "volumes:\n  %s:\n", homeVolume)
	}

	return nil
}

func upsertEnv(file string, keys ...string) error {
	tmpFile, err := ioutil.TempFile("", "env-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmpFile.Name())

	seen := make(map[string]bool)
	var lines []string

	if content, err := ioutil.ReadFile(file); err == nil {
		scanner := bufio.NewScanner(bytes.NewReader(content))
		for scanner.Scan() {
			line := scanner.Text()
			parts := strings.SplitN(line, "=", 2)
			key := parts[0]
			replaced := false
			for _, k := range keys {
				if key == k {
					fmt.Fprintf(tmpFile, "%s=%s\n", k, os.Getenv(k))
					seen[k] = true
					replaced = true
					break
				}
			}
			if !replaced {
				lines = append(lines, line)
			}
		}
	}

	for _, line := range lines {
		fmt.Fprintln(tmpFile, line)
	}

	for _, k := range keys {
		if !seen[k] {
			fmt.Fprintf(tmpFile, "%s=%s\n", k, os.Getenv(k))
		}
	}

	tmpFile.Close()
	return os.Rename(tmpFile.Name(), file)
}

func main() {
	var err error
	rootDir, err = filepath.Abs(filepath.Join(filepath.Dir(os.Args[0]), "../.."))
	if err != nil {
		fail("Failed to determine root directory: %v", err)
	}

	composeFile = filepath.Join(rootDir, "docker-compose.yml")
	extraComposeFile = filepath.Join(rootDir, "docker-compose.extra.yml")
	imageName = getEnvOrDefault("OPENCLAW_IMAGE", "openclaw:local")
	extraMounts = getEnvOrDefault("OPENCLAW_EXTRA_MOUNTS", "")
	homeVolumeName = getEnvOrDefault("OPENCLAW_HOME_VOLUME", "")
	rawSandboxSetting = getEnvOrDefault("OPENCLAW_SANDBOX", "")
	dockerSocketPath = getEnvOrDefault("OPENCLAW_DOCKER_SOCKET", "")
	timezone = getEnvOrDefault("OPENCLAW_TZ", "")

	requireCmd("docker")
	if _, err := exec.Command("docker", "compose", "version").Output(); err != nil {
		fail("Docker Compose not available (try: docker compose version)")
	}

	if dockerSocketPath == "" && strings.HasPrefix(os.Getenv("DOCKER_HOST"), "unix://") {
		dockerSocketPath = strings.TrimPrefix(os.Getenv("DOCKER_HOST"), "unix://")
	}
	if dockerSocketPath == "" {
		dockerSocketPath = "/var/run/docker.sock"
	}
	if isTruthyValue(rawSandboxSetting) {
		sandboxEnabled = "1"
	}

	os.Setenv("OPENCLAW_CONFIG_DIR", getEnvOrDefault("OPENCLAW_CONFIG_DIR", filepath.Join(os.Getenv("HOME"), ".openclaw")))
	os.Setenv("OPENCLAW_WORKSPACE_DIR", getEnvOrDefault("OPENCLAW_WORKSPACE_DIR", filepath.Join(os.Getenv("HOME"), ".openclaw", "workspace")))

	validateMountPathValue("OPENCLAW_CONFIG_DIR", os.Getenv("OPENCLAW_CONFIG_DIR"))
	validateMountPathValue("OPENCLAW_WORKSPACE_DIR", os.Getenv("OPENCLAW_WORKSPACE_DIR"))
	if homeVolumeName != "" {
		if strings.Contains(homeVolumeName, "/") {
			validateMountPathValue("OPENCLAW_HOME_VOLUME", homeVolumeName)
		} else {
			validateNamedVolume(homeVolumeName)
		}
	}
	if containsDisallowedChars(extraMounts) {
		fail("OPENCLAW_EXTRA_MOUNTS cannot contain control characters.")
	}
	if sandboxEnabled != "" {
		validateMountPathValue("OPENCLAW_DOCKER_SOCKET", dockerSocketPath)
	}
	if timezone != "" {
		if containsDisallowedChars(timezone) {
			fail("OPENCLAW_TZ contains unsupported control characters.")
		}
		re := regexp.MustCompile(`^[A-Za-z0-9/_+\-]+$`)
		if !re.MatchString(timezone) {
			fail("OPENCLAW_TZ must be a valid IANA timezone string (e.g. Asia/Shanghai).")
		}
		if !isValidTimezone(timezone) {
			fail("OPENCLAW_TZ must match a timezone in /usr/share/zoneinfo (e.g. Asia/Shanghai).")
		}
	}

	os.MkdirAll(os.Getenv("OPENCLAW_CONFIG_DIR"), 0755)
	os.MkdirAll(os.Getenv("OPENCLAW_WORKSPACE_DIR"), 0755)
	os.MkdirAll(filepath.Join(os.Getenv("OPENCLAW_CONFIG_DIR"), "identity"), 0755)
	os.MkdirAll(filepath.Join(os.Getenv("OPENCLAW_CONFIG_DIR"), "agents", "main", "agent"), 0755)
	os.MkdirAll(filepath.Join(os.Getenv("OPENCLAW_CONFIG_DIR"), "agents", "main", "sessions"), 0755)

	os.Setenv("OPENCLAW_GATEWAY_PORT", getEnvOrDefault("OPENCLAW_GATEWAY_PORT", "18789"))
	os.Setenv("OPENCLAW_BRIDGE_PORT", getEnvOrDefault("OPENCLAW_BRIDGE_PORT", "18790"))
	os.Setenv("OPENCLAW_GATEWAY_BIND", getEnvOrDefault("OPENCLAW_GATEWAY_BIND", "lan"))
	os.Setenv("OPENCLAW_IMAGE", imageName)
	os.Setenv("OPENCLAW_DOCKER_APT_PACKAGES", getEnvOrDefault("OPENCLAW_DOCKER_APT_PACKAGES", ""))
	os.Setenv("OPENCLAW_EXTENSIONS", getEnvOrDefault("OPENCLAW_EXTENSIONS", ""))
	os.Setenv("OPENCLAW_EXTRA_MOUNTS", extraMounts)
	os.Setenv("OPENCLAW_HOME_VOLUME", homeVolumeName)
	os.Setenv("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS", getEnvOrDefault("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS", ""))
	os.Setenv("OPENCLAW_SANDBOX", sandboxEnabled)
	os.Setenv("OPENCLAW_DOCKER_SOCKET", dockerSocketPath)
	os.Setenv("OPENCLAW_TZ", timezone)

	var dockerGID string
	if sandboxEnabled != "" {
		if info, err := os.Stat(dockerSocketPath); err == nil && info.Mode()&os.ModeSocket != 0 {
			stat, ok := info.Sys().(*syscall.Stat_t)
			if ok {
				dockerGID = strconv.FormatUint(uint64(stat.Gid), 10)
			}
		}
	}
	os.Setenv("DOCKER_GID", dockerGID)

	if os.Getenv("OPENCLAW_GATEWAY_TOKEN") == "" {
		existingConfigToken, _ := readConfigGatewayToken()
		if existingConfigToken != "" {
			os.Setenv("OPENCLAW_GATEWAY_TOKEN", existingConfigToken)
			fmt.Printf("Reusing gateway token from %s\n", filepath.Join(os.Getenv("OPENCLAW_CONFIG_DIR"), "openclaw.json"))
		} else {
			dotenvGatewayToken, _ := readEnvGatewayToken(filepath.Join(rootDir, ".env"))
			if dotenvGatewayToken != "" {
				os.Setenv("OPENCLAW_GATEWAY_TOKEN", dotenvGatewayToken)
				fmt.Printf("Reusing gateway token from %s\n", filepath.Join(rootDir, ".env"))
			} else if _, err := exec.LookPath("openssl"); err == nil {
				bytes := make([]byte, 32)
				rand.Read(bytes)
				os.Setenv("OPENCLAW_GATEWAY_TOKEN", hex.EncodeToString(bytes))
			} else {
				token := make([]byte, 32)
				rand.Read(token)
				os.Setenv("OPENCLAW_GATEWAY_TOKEN", hex.EncodeToString(token))
			}
		}
	}

	composeFiles := []string{composeFile}
	var composeArgs []string

	validMounts := []string{}
	if extraMounts != "" {
		mounts := strings.Split(extraMounts, ",")
		for _, mount := range mounts {
			trimmed := strings.TrimSpace(mount)
			if trimmed != "" {
				validMounts = append(validMounts, trimmed)
			}
		}
	}

	if homeVolumeName != "" || len(validMounts) > 0 {
		if len(validMounts) > 0 {
			writeExtraCompose(homeVolumeName, validMounts...)
		} else {
			writeExtraCompose(homeVolumeName)
		}
		composeFiles = append(composeFiles, extraComposeFile)
	}

	for _, composeFile := range composeFiles {
		composeArgs = append(composeArgs, "-f", composeFile)
	}

	baseComposeArgs := getBaseComposeArgs(composeArgs)
	envFile := filepath.Join(rootDir, ".env")

	upsertEnv(envFile,
		"OPENCLAW_CONFIG_DIR",
		"OPENCLAW_WORKSPACE_DIR",
		"OPENCLAW_GATEWAY_PORT",
		"OPENCLAW_BRIDGE_PORT",
		"OPENCLAW_GATEWAY_BIND",
		"OPENCLAW_GATEWAY_TOKEN",
		"OPENCLAW_IMAGE",
		"OPENCLAW_EXTRA_MOUNTS",
		"OPENCLAW_HOME_VOLUME",
		"OPENCLAW_DOCKER_APT_PACKAGES",
		"OPENCLAW_EXTENSIONS",
		"OPENCLAW_SANDBOX",
		"OPENCLAW_DOCKER_SOCKET",
		"DOCKER_GID",
		"OPENCLAW_INSTALL_DOCKER_CLI",
		"OPENCLAW_ALLOW_INSECURE_PRIVATE_WS",
		"OPENCLAW_TZ")

	if imageName == "openclaw:local" {
		fmt.Printf("==> Building Docker image: %s\n", imageName)
		err := runDockerBuild(
			"--build-arg", fmt.Sprintf("OPENCLAW_DOCKER_APT_PACKAGES=%s", os.Getenv("OPENCLAW_DOCKER_APT_PACKAGES")),
			"--build-arg", fmt.Sprintf("OPENCLAW_EXTENSIONS=%s", os.Getenv("OPENCLAW_EXTENSIONS")),
			"--build-arg", fmt.Sprintf("OPENCLAW_INSTALL_DOCKER_CLI=%s", getEnvOrDefault("OPENCLAW_INSTALL_DOCKER_CLI", "")),
			"-t", imageName,
			"-f", filepath.Join(rootDir, "Dockerfile"),
			rootDir)
		if err != nil {
			fail("Failed to build Docker image: %v", err)
		}
	} else {
		fmt.Printf("==> Pulling Docker image: %s\n", imageName)
		cmd := exec.Command("docker", "pull", imageName)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fail("Failed to pull image %s. Please check the image name and your access permissions.", imageName)
		}
	}

	fmt.Println("")
	fmt.Println("==> Fixing data-directory permissions")
	prestartGatewayArgs := []string{"--user", "root", "--entrypoint", "sh", "openclaw-gateway", "-c"}
	prestartGatewayCmd := append(prestartGatewayArgs, `find /home/node/.openclaw -xdev -exec chown node:node {} +; [ -d /home/node/.openclaw/workspace/.openclaw ] && chown -R node:node /home/node/.openclaw/workspace/.openclaw || true`)
	runPrestartGateway(composeArgs, prestartGatewayCmd...)

	fmt.Println("")
	fmt.Println("==> Onboarding (interactive)")
	fmt.Println("Docker setup pins Gateway mode to local.")
	fmt.Println("Gateway runtime bind comes from OPENCLAW_GATEWAY_BIND (default: lan).")
	fmt.Printf("Current runtime bind: %s\n", os.Getenv("OPENCLAW_GATEWAY_BIND"))
	fmt.Printf("Gateway token: %s\n", os.Getenv("OPENCLAW_GATEWAY_TOKEN"))
	fmt.Println("Tailscale exposure: Off (use host-level tailnet/Tailscale setup separately).")
	fmt.Println("Install Gateway daemon: No (managed by Docker Compose)")
	fmt.Println("")

	_, err = runPrestartCli(composeArgs, "onboard", "--mode", "local", "--no-install-daemon")
	if err != nil {
		fail("Onboarding failed: %v", err)
	}

	fmt.Println("")
	fmt.Println("==> Docker gateway defaults")
	syncGatewayConfig(composeArgs)

	fmt.Println("")
	fmt.Println("==> Provider setup (optional)")
	fmt.Println("WhatsApp (QR):")
	fmt.Printf("  docker compose %s run --rm openclaw-cli channels login\n", strings.Join(composeArgs, " "))
	fmt.Println("Telegram (bot token):")
	fmt.Printf("  docker compose %s run --rm openclaw-cli channels add --channel telegram --token <token>\n", strings.Join(composeArgs, " "))
	fmt.Println("Discord (bot token):")
	fmt.Printf("  docker compose %s run --rm openclaw-cli channels add --channel discord --token <token>\n", strings.Join(composeArgs, " "))
	fmt.Println("Docs: https://docs.openclaw.ai/channels")

	fmt.Println("")
	fmt.Println("==> Starting gateway")
	startCmd := exec.Command("docker", append([]string{"compose"}, append(composeArgs, "up", "-d", "openclaw-gateway")...)...)
	startCmd.Stdout = os.Stdout
	startCmd.Stderr = os.Stderr
	if err := startCmd.Run(); err != nil {
		fail("Failed to start gateway: %v", err)
	}

	if sandboxEnabled != "" {
		fmt.Println("")
		fmt.Println("==> Sandbox setup")

		sandboxDockerfile := filepath.Join(rootDir, "Dockerfile.sandbox")
		if _, err := os.Stat(sandboxDockerfile); err == nil {
			fmt.Println("Building sandbox image: openclaw-sandbox:bookworm-slim")
			err := runDockerBuild(
				"-t", "openclaw-sandbox:bookworm-slim",
				"-f", sandboxDockerfile,
				rootDir)
			if err != nil {
				fmt.Fprintf(os.Stderr, "WARNING: Failed to build sandbox image: %v\n", err)
			}
		} else {
			fmt.Fprintln(os.Stderr, "WARNING: Dockerfile.sandbox not found in", rootDir)
			fmt.Fprintln(os.Stderr, "  Sandbox config will be applied but no sandbox image will be built.")
			fmt.Fprintln(os.Stderr, "  Agent exec may fail if the configured sandbox image does not exist.")
		}

		testCmd := exec.Command("docker", append([]string{"compose"}, append(composeArgs, "run", "--rm", "--entrypoint", "docker", "openclaw-gateway", "--version")...)...)
		if err := testCmd.Run(); err != nil {
			fmt.Fprintln(os.Stderr, "WARNING: Docker CLI not found inside the container image.")
			fmt.Fprintln(os.Stderr, "  Sandbox requires Docker CLI. Rebuild with --build-arg OPENCLAW_INSTALL_DOCKER_CLI=1")
			fmt.Fprintln(os.Stderr, "  or use a local build (OPENCLAW_IMAGE=openclaw:local). Skipping sandbox setup.")
			sandboxEnabled = ""
		}
	}

	if sandboxEnabled != "" {
		sandboxComposeFile := filepath.Join(rootDir, "docker-compose.sandbox.yml")
		if _, err := os.Stat(dockerSocketPath); err == nil {
			file, err := os.Create(sandboxComposeFile)
			if err != nil {
				fail("Failed to create sandbox compose file: %v", err)
			}
			defer file.Close()

			writer := bufio.NewWriter(file)
			fmt.Fprintf(writer, "services:\n  openclaw-gateway:\n    volumes:\n      - %s:/var/run/docker.sock\n", dockerSocketPath)
			if dockerGID != "" {
				fmt.Fprintf(writer, "    group_add:\n      - \"%s\"\n", dockerGID)
			}
			writer.Flush()

			composeArgs = append(composeArgs, "-f", sandboxComposeFile)
			fmt.Println("==> Sandbox: added Docker socket mount")
		} else {
			fmt.Fprintf(os.Stderr, "WARNING: OPENCLAW_SANDBOX enabled but Docker socket not found at %s.\n", dockerSocketPath)
			fmt.Fprintln(os.Stderr, "  Sandbox requires Docker socket access. Skipping sandbox setup.")
			sandboxEnabled = ""
		}
	}

	if sandboxEnabled != "" {
		sandboxConfigOK := true
		if _, err := runRuntimeCli(composeArgs, "current", "no-deps", "config", "set", "agents.defaults.sandbox.mode", "non-main"); err != nil {
			fmt.Fprintln(os.Stderr, "WARNING: Failed to set agents.defaults.sandbox.mode")
			sandboxConfigOK = false
		}
		if _, err := runRuntimeCli(composeArgs, "current", "no-deps", "config", "set", "agents.defaults.sandbox.scope", "agent"); err != nil {
			fmt.Fprintln(os.Stderr, "WARNING: Failed to set agents.defaults.sandbox.scope")
			sandboxConfigOK = false
		}
		if _, err := runRuntimeCli(composeArgs, "current", "no-deps", "config", "set", "agents.defaults.sandbox.workspaceAccess", "none"); err != nil {
			fmt.Fprintln(os.Stderr, "WARNING: Failed to set agents.defaults.sandbox.workspaceAccess")
			sandboxConfigOK = false
		}

		if sandboxConfigOK {
			fmt.Println("Sandbox enabled: mode=non-main, scope=agent, workspaceAccess=none")
			fmt.Println("Docs: https://docs.openclaw.ai/gateway/sandboxing")
			restartCmd := exec.Command("docker", append([]string{"compose"}, append(composeArgs, "up", "-d", "openclaw-gateway")...)...)
			restartCmd.Stdout = os.Stdout
			restartCmd.Stderr = os.Stderr
			if err := restartCmd.Run(); err != nil {
				fail("Failed to restart gateway with sandbox: %v", err)
			}
		} else {
			fmt.Fprintln(os.Stderr, "WARNING: Sandbox config was partially applied. Check errors above.")
			fmt.Fprintln(os.Stderr, "  Skipping gateway restart to avoid exposing Docker socket without a full sandbox policy.")
			if _, err := runRuntimeCli(baseComposeArgs, "base", "no-deps", "config", "set", "agents.defaults.sandbox.mode", "off"); err != nil {
				fmt.Fprintln(os.Stderr, "WARNING: Failed to roll back agents.defaults.sandbox.mode to off")
			} else {
				fmt.Println("Sandbox mode rolled back to off due to partial sandbox config failure.")
			}
			if _, err := os.Stat(filepath.Join(rootDir, "docker-compose.sandbox.yml")); err == nil {
				os.Remove(filepath.Join(rootDir, "docker-compose.sandbox.yml"))
			}
			resetCmd := exec.Command("docker", append([]string{"compose"}, append(baseComposeArgs, "up", "-d", "--force-recreate", "openclaw-gateway")...)...)
			resetCmd.Stdout = os.Stdout
			resetCmd.Stderr = os.Stderr
			if err := resetCmd.Run(); err != nil {
				fail("Failed to reset gateway: %v", err)
			}
		}
	} else {
		if _, err := runRuntimeCli(composeArgs, "current", "with-deps", "config", "set", "agents.defaults.sandbox.mode", "off"); err != nil {
			fmt.Fprintln(os.Stderr, "WARNING: Failed to reset agents.defaults.sandbox.mode to off")
		}
		if _, err := os.Stat(filepath.Join(rootDir, "docker-compose.sandbox.yml")); err == nil {
			os.Remove(filepath.Join(rootDir, "docker-compose.sandbox.yml"))
		}
	}

	fmt.Println("")
	fmt.Println("Gateway running with host port mapping.")
	fmt.Println("Access from tailnet devices via the host's tailnet IP.")
	fmt.Printf("Config: %s\n", os.Getenv("OPENCLAW_CONFIG_DIR"))
	fmt.Printf("Workspace: %s\n", os.Getenv("OPENCLAW_WORKSPACE_DIR"))
	fmt.Printf("Token: %s\n", os.Getenv("OPENCLAW_GATEWAY_TOKEN"))
	fmt.Println("")
	fmt.Printf("Commands:\n")
	fmt.Printf("  docker compose %s logs -f openclaw-gateway\n", strings.Join(composeArgs, " "))
	fmt.Printf("  docker compose %s exec openclaw-gateway node dist/index.js health --token \"%s\"\n", strings.Join(composeArgs, " "), os.Getenv("OPENCLAW_GATEWAY_TOKEN"))
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
