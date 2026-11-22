// abstraction-provenance: {"artifact_sha256": "9118684a5aff03059456b321c68b2ac29a0b2a85395d6ac2bb1a09e5f5592486", "source_sha256": "9b573d1d5f5751c3fe5bb1eb243725ffb174987da9e458632a295c541458b2a0", "target_language": "go"}
// run-openclaw-podman.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/run-openclaw-podman.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

const (
	defaultGatewayPort = "18789"
	defaultBridgePort  = "18790"
	defaultPublishHost = "127.0.0.1"
)

var (
	platformName = runtime.GOOS
)

func resolveUserHome(user string) string {
	if runtime.GOOS == "windows" {
		return filepath.Join("C:", "Users", user)
	}
	
	cmd := exec.Command("getent", "passwd", user)
	output, err := cmd.Output()
	if err == nil {
		parts := strings.Split(strings.TrimSpace(string(output)), ":")
		if len(parts) >= 6 {
			return parts[5]
		}
	}
	
	if passwd, err := os.ReadFile("/etc/passwd"); err == nil {
		scanner := bufio.NewScanner(bytes.NewReader(passwd))
		for scanner.Scan() {
			line := scanner.Text()
			parts := strings.Split(line, ":")
			if len(parts) >= 6 && parts[0] == user {
				return parts[5]
			}
		}
	}
	
	return filepath.Join("/home", user)
}

func fail(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}

func validateSingleLineValue(label, value string) {
	if strings.ContainsAny(value, "\n\r") {
		fail("Invalid %s: control characters are not allowed.", label)
	}
}

func validateAbsolutePath(label, value string) {
	validateSingleLineValue(label, value)
	if !filepath.IsAbs(value) {
		fail("Invalid %s: expected an absolute path.", label)
	}
	if strings.Contains(value, "//") {
		fail("Invalid %s: repeated slashes are not allowed.", label)
	}
	if strings.Contains(value, "/./") || strings.HasSuffix(value, "/.") ||
		strings.Contains(value, "/../") || strings.HasSuffix(value, "/..") {
		fail("Invalid %s: dot path segments are not allowed.", label)
	}
}

func validateMountSourcePath(label, value string) {
	validateAbsolutePath(label, value)
	if strings.Contains(value, ":") {
		fail("Invalid %s: ':' is not allowed in Podman bind-mount source paths.", label)
	}
}

func ensureSafeExistingRegularFile(label, file string) {
	validateAbsolutePath(label, file)
	if _, err := os.Stat(file); os.IsNotExist(err) {
		fail("Missing %s: %s", label, file)
	}
	if info, err := os.Lstat(file); err == nil && info.Mode()&os.ModeSymlink != 0 {
		fail("Unsafe %s: symlinks are not allowed (%s)", label, file)
	}
	if info, err := os.Stat(file); err != nil || info.IsDir() {
		fail("Unsafe %s: expected a regular file (%s)", label, file)
	}
}

func ensureSafeExistingDir(label, dir string) {
	validateAbsolutePath(label, dir)
	if info, err := os.Stat(dir); os.IsNotExist(err) {
		fail("Missing %s: %s", label, dir)
	} else if err != nil || !info.IsDir() {
		fail("Unsafe %s: expected a directory (%s)", label, dir)
	}
	if info, err := os.Lstat(dir); err == nil && info.Mode()&os.ModeSymlink != 0 {
		fail("Unsafe %s: symlinks are not allowed (%s)", label, dir)
	}
}

func statUid(path string) (uint32, error) {
	info, err := os.Stat(path)
	if err != nil {
		return 0, err
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return 0, errors.New("unable to get stat info")
	}
	return stat.Uid, nil
}

func statMode(path string) (uint32, error) {
	info, err := os.Stat(path)
	if err != nil {
		return 0, err
	}
	return uint32(info.Mode()), nil
}

func ensurePrivateExistingDirOwnedByUser(label, dir string) {
	ensureSafeExistingDir(label, dir)
	uid, err := statUid(dir)
	if err != nil {
		fail("Unable to check ownership of %s: %s", label, dir)
	}
	if uid != uint32(os.Getuid()) {
		fail("Unsafe %s: not owned by current user (%s)", label, dir)
	}
	mode, err := statMode(dir)
	if err != nil {
		fail("Unable to check permissions of %s: %s", label, dir)
	}
	if mode&0022 != 0 {
		fail("Unsafe %s: group/other writable (%s)", label, dir)
	}
}

func ensurePrivateExistingRegularFileOwnedByUser(label, file string) {
	ensureSafeExistingRegularFile(label, file)
	uid, err := statUid(file)
	if err != nil {
		fail("Unable to check ownership of %s: %s", label, file)
	}
	if uid != uint32(os.Getuid()) {
		fail("Unsafe %s: not owned by current user (%s)", label, file)
	}
	mode, err := statMode(file)
	if err != nil {
		fail("Unable to check permissions of %s: %s", label, file)
	}
	if mode&0077 != 0 {
		fail("Unsafe %s: expected owner-only permissions (%s)", label, file)
	}
}

func ensureSafeWriteFilePath(label, file string) {
	validateAbsolutePath(label, file)
	if info, err := os.Stat(file); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			fail("Unsafe %s: symlinks are not allowed (%s)", label, file)
		}
		if info.IsDir() {
			fail("Unsafe %s: expected a regular file (%s)", label, file)
		}
	}
	dir := filepath.Dir(file)
	ensureSafeExistingDir(label+" parent directory", dir)
}

func writeFileAtomically(file, mode string, content []byte) {
	ensureSafeWriteFilePath("output file", file)
	dir := filepath.Dir(file)
	tmp, err := os.CreateTemp(dir, ".tmp.*")
	if err != nil {
		fail("Unable to create temporary file: %v", err)
	}
	defer os.Remove(tmp.Name())
	
	if _, err := tmp.Write(content); err != nil {
		fail("Unable to write to temporary file: %v", err)
	}
	tmp.Close()
	
	if err := os.Chmod(tmp.Name(), fs.FileMode(parseMode(mode))); err != nil {
		fail("Unable to set permissions on temporary file: %v", err)
	}
	
	if err := os.Rename(tmp.Name(), file); err != nil {
		fail("Unable to rename temporary file: %v", err)
	}
}

func parseMode(modeStr string) os.FileMode {
	mode, err := strconv.ParseUint(modeStr, 8, 32)
	if err != nil {
		fail("Invalid mode: %s", modeStr)
	}
	return os.FileMode(mode)
}

func loadPodmanEnvFile(file string) {
	ensurePrivateExistingRegularFileOwnedByUser("Podman env file", file)
	dir := filepath.Dir(file)
	ensurePrivateExistingDirOwnedByUser("Podman env directory", dir)
	
	f, err := os.Open(file)
	if err != nil {
		fail("Unable to open Podman env file: %s", file)
	}
	defer f.Close()
	
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if !strings.Contains(line, "=") {
			continue
		}
		
		parts := strings.SplitN(line, "=", 2)
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		
		if !isValidEnvKey(key) {
			continue
		}
		
		switch key {
		case "OPENCLAW_GATEWAY_TOKEN", "OPENCLAW_PODMAN_CONTAINER", "OPENCLAW_PODMAN_IMAGE",
			"OPENCLAW_IMAGE", "OPENCLAW_PODMAN_PULL", "OPENCLAW_PODMAN_GATEWAY_HOST_PORT",
			"OPENCLAW_GATEWAY_PORT", "OPENCLAW_PODMAN_BRIDGE_HOST_PORT", "OPENCLAW_BRIDGE_PORT",
			"OPENCLAW_GATEWAY_BIND", "OPENCLAW_PODMAN_USERNS", "OPENCLAW_BIND_MOUNT_OPTIONS",
			"OPENCLAW_PODMAN_PUBLISH_HOST":
			// Valid keys
		default:
			continue
		}
		
		if (strings.HasPrefix(value, `"`) && strings.HasSuffix(value, `"`)) ||
			(strings.HasPrefix(value, `'`) && strings.HasSuffix(value, `'`)) {
			value = value[1 : len(value)-1]
		}
		
		os.Setenv(key, value)
	}
}

func isValidEnvKey(key string) bool {
	if len(key) == 0 {
		return false
	}
	if !((key[0] >= 'A' && key[0] <= 'Z') || key[0] == '_') {
		return false
	}
	for _, c := range key[1:] {
		if !((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_') {
			return false
		}
	}
	return true
}

func validatePort(label, value string) {
	if _, err := strconv.Atoi(value); err != nil {
		fail("Invalid %s: must be numeric.", label)
	}
	port, err := strconv.Atoi(value)
	if err != nil || port < 1 || port > 65535 {
		fail("Invalid %s: out of range.", label)
	}
}

func resolveConfigGatewayBind(configDir string) string {
	cmd := exec.Command("openclaw", "config", "get", "gateway.bind")
	cmd.Env = append(os.Environ(), "OPENCLAW_CONTAINER=", fmt.Sprintf("OPENCLAW_CONFIG_DIR=%s", configDir))
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func upsertEnvVar(file, key, value string) {
	ensureSafeWriteFilePath("env file", file)
	dir := filepath.Dir(file)
	tmp, err := os.CreateTemp(dir, ".env.tmp.*")
	if err != nil {
		fail("Unable to create temporary file: %v", err)
	}
	defer os.Remove(tmp.Name())
	
	found := false
	if content, err := os.ReadFile(file); err == nil {
		lines := strings.Split(string(content), "\n")
		for _, line := range lines {
			if strings.HasPrefix(line, key+"=") {
				fmt.Fprintf(tmp, "%s=%s\n", key, value)
				found = true
			} else {
				fmt.Fprintln(tmp, line)
			}
		}
	}
	
	if !found {
		fmt.Fprintf(tmp, "%s=%s\n", key, value)
	}
	
	tmp.Close()
	os.Rename(tmp.Name(), file)
	os.Chmod(file, 0600)
}

func generateTokenHex32() string {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		fail("Unable to generate random token: %v", err)
	}
	return hex.EncodeToString(bytes)
}

func createTokenEnvFile(file, token string) string {
	dir := filepath.Dir(file)
	ensurePrivateExistingDirOwnedByUser("token env directory", dir)
	tmp, err := os.CreateTemp(dir, ".token.env.*")
	if err != nil {
		fail("Unable to create temporary file: %v", err)
	}
	defer tmp.Close()
	
	os.Chmod(tmp.Name(), 0600)
	fmt.Fprintf(tmp, "OPENCLAW_GATEWAY_TOKEN=%s\n", token)
	return tmp.Name()
}

func syncLocalControlUiOriginsViaCLI(file, port string) {
	configDir := filepath.Dir(file)
	cmd := exec.Command("openclaw", "config", "set", "gateway.controlUi.allowedOrigins",
		fmt.Sprintf(`["http://127.0.0.1:%s","http://localhost:%s"]`, port, port), "--strict-json")
	cmd.Env = append(os.Environ(), "OPENCLAW_CONTAINER=", fmt.Sprintf("OPENCLAW_CONFIG_DIR=%s", configDir))
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: unable to sync gateway.controlUi.allowedOrigins via CLI: %v\n", err)
	}
}

func syncLocalControlUiOrigins(file, port string) {
	ensureSafeWriteFilePath("config file", file)
	
	if _, err := exec.LookPath("python3"); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: python3 not found; unable to sync gateway.controlUi.allowedOrigins in %s.\n", file)
		syncLocalControlUiOriginsViaCLI(file, port)
		return
	}
	
	dir := filepath.Dir(file)
	ensurePrivateExistingDirOwnedByUser("config file directory", dir)
	
	tmp, err := os.CreateTemp(dir, ".config.tmp.*")
	if err != nil {
		fail("Unable to create temporary file: %v", err)
	}
	defer os.Remove(tmp.Name())
	
	content, err := os.ReadFile(file)
	if err != nil {
		content = []byte("{}")
	}
	
	var data map[string]interface{}
	if err := json.Unmarshal(content, &data); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: unable to sync gateway.controlUi.allowedOrigins in %s: existing config is not strict JSON (%v). Leaving file unchanged.\n", file, err)
		syncLocalControlUiOriginsViaCLI(file, port)
		return
	}
	
	if data == nil {
		data = make(map[string]interface{})
	}
	
	gateway, ok := data["gateway"].(map[string]interface{})
	if !ok {
		gateway = make(map[string]interface{})
		data["gateway"] = gateway
	}
	
	gateway["mode"] = "local"
	
	controlUi, ok := gateway["controlUi"].(map[string]interface{})
	if !ok {
		controlUi = make(map[string]interface{})
		gateway["controlUi"] = controlUi
	}
	
	allowedOrigins, ok := controlUi["allowedOrigins"].([]interface{})
	if !ok {
		allowedOrigins = []interface{}{}
	}
	
	desired := []string{
		fmt.Sprintf("http://127.0.0.1:%s", port),
		fmt.Sprintf("http://localhost:%s", port),
	}
	
	cleaned := []string{}
	seen := make(map[string]bool)
	
	for _, origin := range allowedOrigins {
		if str, ok := origin.(string); ok {
			normalized := strings.TrimSpace(str)
			if normalized != "" && !seen[normalized] {
				cleaned = append(cleaned, normalized)
				seen[normalized] = true
			}
		}
	}
	
	for _, origin := range desired {
		if !seen[origin] {
			cleaned = append(cleaned, origin)
			seen[origin] = true
		}
	}
	
	controlUi["allowedOrigins"] = cleaned
	
	result, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		fail("Unable to marshal JSON: %v", err)
	}
	result = append(result, '\n')
	
	if err := os.WriteFile(tmp.Name(), result, 0600); err != nil {
		fail("Unable to write to temporary file: %v", err)
	}
	
	os.Rename(tmp.Name(), file)
}

func cleanupTokenEnvFile(tokenEnvFile string) {
	if tokenEnvFile != "" {
		os.Remove(tokenEnvFile)
	}
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "setup-host" {
		args := os.Args[2:]
		repoRoot := filepath.Join(filepath.Dir(os.Args[0]), "..")
		setupPodman := filepath.Join(repoRoot, "scripts", "podman", "setup.sh")
		if _, err := os.Stat(setupPodman); err == nil {
			cmd := exec.Command(setupPodman, args...)
			cmd.Stdin = os.Stdin
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				os.Exit(1)
			}
			os.Exit(0)
		}
		setupPodman = filepath.Join(repoRoot, "setup-podman.sh")
		if _, err := os.Stat(setupPodman); err == nil {
			cmd := exec.Command(setupPodman, args...)
			cmd.Stdin = os.Stdin
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				os.Exit(1)
			}
			os.Exit(0)
		}
		fail("Podman setup script not found. Run from repo root: ./scripts/podman/setup.sh")
	}
	
	runSetup := false
	args := os.Args[1:]
	if len(args) > 0 && (args[0] == "launch" || args[0] == "setup" || args[0] == "onboard") {
		if args[0] == "setup" || args[0] == "onboard" {
			runSetup = true
		}
		args = args[1:]
	}
	
	effectiveUser := os.Getenv("USER")
	if effectiveUser == "" {
		effectiveUser = os.Getenv("LOGNAME")
	}
	if effectiveUser == "" {
		effectiveUser = "unknown"
	}
	
	effectiveHome := os.Getenv("HOME")
	if effectiveHome == "" {
		effectiveHome = resolveUserHome(effectiveUser)
	}
	
	if os.Getuid() == 0 {
		fail("Run run-openclaw-podman.go as your normal user so Podman stays rootless.")
	}
	
	validateAbsolutePath("effective home", effectiveHome)
	
	configDir := os.Getenv("OPENCLAW_CONFIG_DIR")
	if configDir == "" {
		configDir = filepath.Join(effectiveHome, ".openclaw")
	}
	
	envFile := os.Getenv("OPENCLAW_PODMAN_ENV")
	if envFile == "" {
		envFile = filepath.Join(configDir, ".env")
	}
	
	if _, err := os.Stat(envFile); err == nil {
		loadPodmanEnvFile(envFile)
	}
	
	configDir = os.Getenv("OPENCLAW_CONFIG_DIR")
	if configDir == "" {
		configDir = filepath.Join(effectiveHome, ".openclaw")
	}
	
	envFile = os.Getenv("OPENCLAW_PODMAN_ENV")
	if envFile == "" {
		envFile = filepath.Join(configDir, ".env")
	}
	
	workspaceDir := os.Getenv("OPENCLAW_WORKSPACE_DIR")
	if workspaceDir == "" {
		workspaceDir = filepath.Join(configDir, "workspace")
	}
	
	containerName := os.Getenv("OPENCLAW_PODMAN_CONTAINER")
	if containerName == "" {
		containerName = "openclaw"
	}
	
	openclawImage := os.Getenv("OPENCLAW_PODMAN_IMAGE")
	if openclawImage == "" {
		openclawImage = os.Getenv("OPENCLAW_IMAGE")
		if openclawImage == "" {
			openclawImage = "openclaw:local"
		}
	}
	
	podmanPull := os.Getenv("OPENCLAW_PODMAN_PULL")
	if podmanPull == "" {
		podmanPull = "never"
	}
	
	hostGatewayPort := os.Getenv("OPENCLAW_PODMAN_GATEWAY_HOST_PORT")
	if hostGatewayPort == "" {
		hostGatewayPort = os.Getenv("OPENCLAW_GATEWAY_PORT")
		if hostGatewayPort == "" {
			hostGatewayPort = defaultGatewayPort
		}
	}
	
	hostBridgePort := os.Getenv("OPENCLAW_PODMAN_BRIDGE_HOST_PORT")
	if hostBridgePort == "" {
		hostBridgePort = os.Getenv("OPENCLAW_BRIDGE_PORT")
		if hostBridgePort == "" {
			hostBridgePort = defaultBridgePort
		}
	}
	
	publishHost := os.Getenv("OPENCLAW_PODMAN_PUBLISH_HOST")
	if publishHost == "" {
		publishHost = defaultPublishHost
	}
	
	validateMountSourcePath("config directory", configDir)
	validateMountSourcePath("workspace directory", workspaceDir)
	validateAbsolutePath("env file path", envFile)
	validateSingleLineValue("container name", containerName)
	validateSingleLineValue("image name", openclawImage)
	validateSingleLineValue("publish host", publishHost)
	validatePort("gateway host port", hostGatewayPort)
	validatePort("bridge host port", hostBridgePort)
	
	if err := os.Chdir(effectiveHome); err != nil {
		os.Chdir("/tmp")
	}
	
	os.MkdirAll(configDir, 0700)
	os.MkdirAll(workspaceDir, 0700)
	os.MkdirAll(filepath.Join(configDir, "canvas"), 0700)
	os.MkdirAll(filepath.Join(configDir, "cron"), 0700)
	os.Chmod(configDir, 0700)
	os.Chmod(workspaceDir, 0700)
	
	ensurePrivateExistingDirOwnedByUser("config directory", configDir)
	ensurePrivateExistingDirOwnedByUser("workspace directory", workspaceDir)
	
	configGatewayBind := resolveConfigGatewayBind(configDir)
	gatewayBind := os.Getenv("OPENCLAW_GATEWAY_BIND")
	if gatewayBind == "" {
		gatewayBind = configGatewayBind
		if gatewayBind == "" {
			gatewayBind = "lan"
		}
	}
	
	token := os.Getenv("OPENCLAW_GATEWAY_TOKEN")
	if token == "" {
		token = generateTokenHex32()
		os.Setenv("OPENCLAW_GATEWAY_TOKEN", token)
		os.MkdirAll(filepath.Dir(envFile), 0700)
		ensureSafeExistingDir("env file directory", filepath.Dir(envFile))
		upsertEnvVar(envFile, "OPENCLAW_GATEWAY_TOKEN", token)
		fmt.Fprintf(os.Stderr, "Generated OPENCLAW_GATEWAY_TOKEN and wrote it to %s.\n", envFile)
	}
	
	configJson := filepath.Join(configDir, "openclaw.json")
	if _, err := os.Stat(configJson); os.IsNotExist(err) {
		content := []byte("{ \"gateway\": { \"mode\": \"local\" } }\n")
		writeFileAtomically(configJson, "600", content)
		fmt.Fprintf(os.Stderr, "Created %s (minimal gateway.mode=local).\n", configJson)
	}
	
	syncLocalControlUiOrigins(configJson, hostGatewayPort)
	
	podmanUserns := os.Getenv("OPENCLAW_PODMAN_USERNS")
	if podmanUserns == "" {
		podmanUserns = "keep-id"
	}
	
	usernsArgs := []string{}
	runUserArgs := []string{}
	switch podmanUserns {
	case "", "auto":
		// No additional args
	case "keep-id":
		usernsArgs = append(usernsArgs, "--userns=keep-id")
	case "host":
		usernsArgs = append(usernsArgs, "--userns=host")
	default:
		fail("Unsupported OPENCLAW_PODMAN_USERNS=%s (expected: keep-id, auto, host).", podmanUserns)
	}
	
	runUID := fmt.Sprintf("%d", os.Getuid())
	runGID := fmt.Sprintf("%d", os.Getgid())
	if podmanUserns == "keep-id" {
		runUserArgs = append(runUserArgs, "--user", fmt.Sprintf("%s:%s", runUID, runGID))
	} else {
		fmt.Fprintf(os.Stderr, "Starting container without --user (OPENCLAW_PODMAN_USERNS=%s), mounts may require ownership fixes.\n", podmanUserns)
	}
	
	selinuxMountOpts := ""
	if openclawBindMountOptions := os.Getenv("OPENCLAW_BIND_MOUNT_OPTIONS"); openclawBindMountOptions == "" {
		if runtime.GOOS == "linux" {
			if cmd := exec.Command("getenforce"); cmd.Run() == nil {
				output, _ := cmd.Output()
				mode := strings.TrimSpace(string(output))
				if mode == "Enforcing" || mode == "Permissive" {
					selinuxMountOpts = ",Z"
				}
			}
		}
	} else {
		selinuxMountOpts = strings.TrimPrefix(openclawBindMountOptions, ":")
		if selinuxMountOpts != "" {
			selinuxMountOpts = "," + selinuxMountOpts
		}
	}
	
	tokenEnvFile := createTokenEnvFile(envFile, token)
	defer cleanupTokenEnvFile(tokenEnvFile)
	
	if runSetup {
		cmd := exec.Command("podman", "run", "--pull="+podmanPull, "--rm", "-it",
			"--init")
		cmd.Args = append(cmd.Args, usernsArgs...)
		cmd.Args = append(cmd.Args, runUserArgs...)
		cmd.Args = append(cmd.Args,
			"-e", "HOME=/home/node",
			"-e", "TERM=xterm-256color",
			"-e", "BROWSER=echo",
			"-e", "NPM_CONFIG_CACHE=/home/node/.openclaw/.npm",
			"-e", "OPENCLAW_NO_RESPAWN=1",
			"--env-file", tokenEnvFile,
			"-v", fmt.Sprintf("%s:/home/node/.openclaw:rw%s", configDir, selinuxMountOpts),
			"-v", fmt.Sprintf("%s:/home/node/.openclaw/workspace:rw%s", workspaceDir, selinuxMountOpts),
			openclawImage,
			"node", "dist/index.js", "onboard")
		cmd.Args = append(cmd.Args, args...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			os.Exit(1)
		}
		os.Exit(0)
	}
	
	cmd := exec.Command("podman", "run", "--pull="+podmanPull, "-d", "--replace",
		"--name", containerName,
		"--init")
	cmd.Args = append(cmd.Args, usernsArgs...)
	cmd.Args = append(cmd.Args, runUserArgs...)
	cmd.Args = append(cmd.Args,
		"-e", "HOME=/home/node",
		"-e", "TERM=xterm-256color",
		"-e", "NPM_CONFIG_CACHE=/home/node/.openclaw/.npm",
		"-e", "OPENCLAW_NO_RESPAWN=1",
		"--env-file", tokenEnvFile,
		"-v", fmt.Sprintf("%s:/home/node/.openclaw:rw%s", configDir, selinuxMountOpts),
		"-v", fmt.Sprintf("%s:/home/node/.openclaw/workspace:rw%s", workspaceDir, selinuxMountOpts),
		"-p", fmt.Sprintf("%s:%s:18789", publishHost, hostGatewayPort),
		"-p", fmt.Sprintf("%s:%s:18790", publishHost, hostBridgePort),
		openclawImage,
		"node", "dist/index.js", "gateway", "--bind", gatewayBind, "--port", "18789")
	cmd.Stdout = io.Discard
	if err := cmd.Run(); err != nil {
		fail("Failed to start container: %v", err)
	}
	
	fmt.Printf("Container %s started: http://127.0.0.1:%s/\n", containerName, hostGatewayPort)
	fmt.Printf("podman exec -it %s openclaw dashboard --no-open\n", containerName)
	fmt.Printf("podman exec -it %s openclaw devices approve --latest  # if pairing required\n", containerName)
	fmt.Printf("podman logs -f %s\n", containerName)
	if platformName == "linux" {
		fmt.Println("For auto-start/restarts, use: ./scripts/podman/setup.sh --quadlet (Quadlet + systemd user service).")
	}
}
