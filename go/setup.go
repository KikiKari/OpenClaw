// abstraction-provenance: {"artifact_sha256": "ad8ae74decac480722375bc19b3c8357c53ef4af68d9b6a8188b8047a69cf29f", "source_sha256": "53a6908a18055c2a46b63b5da3ddbf4ea5f6b1867c1482c1dcc8903c3ab7b89a", "target_language": "go"}
// setup.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/podman/setup.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

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
	"math/big"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
)

const (
	defaultImageName       = "openclaw:local"
	defaultContainerName   = "openclaw"
	defaultGatewayHostPort = "18789"
	quadletGatewayPort     = "18789"
)

type Config struct {
	RepoPath         string
	RunScriptSrc     string
	QuadletTemplate  string
	OpenclawUser     string
	OpenclawHome     string
	ConfigDir        string
	WorkspaceDir     string
	ImageName        string
	ContainerName    string
	PlatformName     string
	GatewayHostPort  string
	SeedGatewayPort  string
	InstallQuadlet   bool
	BuildArgs        []string
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	config, err := parseConfig()
	if err != nil {
		return err
	}

	if err := validateConfig(config); err != nil {
		return err
	}

	if err := setupDirectories(config); err != nil {
		return err
	}

	if err := buildOrPullImage(config); err != nil {
		return err
	}

	if err := setupEnvironment(config); err != nil {
		return err
	}

	if err := setupConfiguration(config); err != nil {
		return err
	}

	if config.InstallQuadlet {
		if err := installQuadlet(config); err != nil {
			return err
		}
	} else {
		fmt.Println("Container setup complete.")
	}

	printNextSteps(config)
	return nil
}

func parseConfig() (*Config, error) {
	repoPath := os.Getenv("OPENCLAW_REPO_PATH")
	if repoPath == "" {
		ex, err := os.Executable()
		if err != nil {
			return nil, fmt.Errorf("failed to get executable path: %w", err)
		}
		ex, err = filepath.EvalSymlinks(ex)
		if err != nil {
			return nil, fmt.Errorf("failed to resolve symlink: %w", err)
		}
		repoPath = filepath.Dir(filepath.Dir(filepath.Dir(ex)))
	}

	runScriptSrc := filepath.Join(repoPath, "scripts", "run-openclaw-podman.sh")
	quadletTemplate := filepath.Join(repoPath, "scripts", "podman", "openclaw.container.in")

	openclawUser := os.Getenv("USER")
	if openclawUser == "" {
		openclawUser = os.Getenv("USERNAME")
	}

	openclawHome := os.Getenv("HOME")
	if openclawHome == "" {
		openclawHome = os.Getenv("USERPROFILE") // Windows
	}

	configDir := os.Getenv("OPENCLAW_CONFIG_DIR")
	if configDir == "" {
		configDir = filepath.Join(openclawHome, ".openclaw")
	}

	workspaceDir := os.Getenv("OPENCLAW_WORKSPACE_DIR")
	if workspaceDir == "" {
		workspaceDir = filepath.Join(configDir, "workspace")
	}

	imageName := os.Getenv("OPENCLAW_PODMAN_IMAGE")
	if imageName == "" {
		imageName = os.Getenv("OPENCLAW_IMAGE")
		if imageName == "" {
			imageName = defaultImageName
		}
	}

	containerName := os.Getenv("OPENCLAW_PODMAN_CONTAINER")
	if containerName == "" {
		containerName = defaultContainerName
	}

	gatewayHostPort := os.Getenv("OPENCLAW_PODMAN_GATEWAY_HOST_PORT")
	if gatewayHostPort == "" {
		gatewayHostPort = os.Getenv("OPENCLAW_GATEWAY_PORT")
		if gatewayHostPort == "" {
			gatewayHostPort = defaultGatewayHostPort
		}
	}

	platformName := runtime.GOOS

	installQuadlet := false
	for _, arg := range os.Args[1:] {
		switch arg {
		case "--quadlet":
			installQuadlet = true
		case "--container":
			installQuadlet = false
		}
	}

	if quadletEnv := os.Getenv("OPENCLAW_PODMAN_QUADLET"); quadletEnv != "" {
		switch strings.ToLower(quadletEnv) {
		case "1", "yes", "true":
			installQuadlet = true
		case "0", "no", "false":
			installQuadlet = false
		}
	}

	seedGatewayPort := gatewayHostPort
	if installQuadlet {
		seedGatewayPort = quadletGatewayPort
	}

	buildArgs := []string{}
	if aptPackages := os.Getenv("OPENCLAW_DOCKER_APT_PACKAGES"); aptPackages != "" {
		buildArgs = append(buildArgs, "--build-arg", "OPENCLAW_DOCKER_APT_PACKAGES="+aptPackages)
	}
	if extensions := os.Getenv("OPENCLAW_EXTENSIONS"); extensions != "" {
		buildArgs = append(buildArgs, "--build-arg", "OPENCLAW_EXTENSIONS="+extensions)
	}

	return &Config{
		RepoPath:         repoPath,
		RunScriptSrc:     runScriptSrc,
		QuadletTemplate: quadletTemplate,
		OpenclawUser:     openclawUser,
		OpenclawHome:     openclawHome,
		ConfigDir:        configDir,
		WorkspaceDir:     workspaceDir,
		ImageName:        imageName,
		ContainerName:    containerName,
		PlatformName:     platformName,
		GatewayHostPort:  gatewayHostPort,
		SeedGatewayPort:  seedGatewayPort,
		InstallQuadlet:   installQuadlet,
		BuildArgs:        buildArgs,
	}, nil
}

func validateConfig(config *Config) error {
	if !commandExists("podman") {
		return fmt.Errorf("missing dependency: podman")
	}

	if isRoot() {
		return fmt.Errorf("run this script as your normal user so Podman stays rootless")
	}

	if config.ImageName == defaultImageName {
		dockerfilePath := filepath.Join(config.RepoPath, "Dockerfile")
		if _, err := os.Stat(dockerfilePath); os.IsNotExist(err) {
			return fmt.Errorf("Dockerfile not found at %s. Set OPENCLAW_REPO_PATH to the repo root", config.RepoPath)
		}
	}

	if _, err := os.Stat(config.RunScriptSrc); os.IsNotExist(err) {
		return fmt.Errorf("launch script not found at %s", config.RunScriptSrc)
	}

	if config.InstallQuadlet && config.PlatformName != "linux" {
		return fmt.Errorf("--quadlet is only supported on Linux with systemd user services")
	}

	if err := validateAbsolutePath("home directory", config.OpenclawHome); err != nil {
		return err
	}

	if err := validateMountSourcePath("config directory", config.ConfigDir); err != nil {
		return err
	}

	if err := validateMountSourcePath("workspace directory", config.WorkspaceDir); err != nil {
		return err
	}

	if err := validateContainerName(config.ContainerName); err != nil {
		return err
	}

	if err := validateImageName(config.ImageName); err != nil {
		return err
	}

	if err := validatePort("gateway host port", config.GatewayHostPort); err != nil {
		return err
	}

	if err := validatePort("seed gateway port", config.SeedGatewayPort); err != nil {
		return err
	}

	return nil
}

func setupDirectories(config *Config) error {
	if err := os.MkdirAll(config.ConfigDir, 0700); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}

	if err := os.MkdirAll(config.WorkspaceDir, 0700); err != nil {
		return fmt.Errorf("failed to create workspace directory: %w", err)
	}

	if err := ensurePrivateExistingDirOwnedByUser("config directory", config.ConfigDir); err != nil {
		return err
	}

	if err := ensurePrivateExistingDirOwnedByUser("workspace directory", config.WorkspaceDir); err != nil {
		return err
	}

	return nil
}

func buildOrPullImage(config *Config) error {
	if config.ImageName == defaultImageName {
		fmt.Printf("Building image %s ...\n", config.ImageName)
		args := []string{"build", "-t", config.ImageName, "-f", filepath.Join(config.RepoPath, "Dockerfile")}
		args = append(args, config.BuildArgs...)
		args = append(args, config.RepoPath)
		cmd := exec.Command("podman", args...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to build image: %w", err)
		}
	} else {
		existsCmd := exec.Command("podman", "image", "exists", config.ImageName)
		if err := existsCmd.Run(); err == nil {
			fmt.Printf("Using existing image %s\n", config.ImageName)
		} else {
			fmt.Printf("Pulling image %s ...\n", config.ImageName)
			cmd := exec.Command("podman", "pull", config.ImageName)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				return fmt.Errorf("failed to pull image: %w", err)
			}
		}
	}
	return nil
}

func setupEnvironment(config *Config) error {
	envFile := filepath.Join(config.ConfigDir, ".env")
	
	if _, err := os.Stat(envFile); os.IsNotExist(err) {
		token, err := generateTokenHex32()
		if err != nil {
			return fmt.Errorf("failed to generate token: %w", err)
		}
		
		content := fmt.Sprintf("OPENCLAW_GATEWAY_TOKEN=%s\n", token)
		if err := writeFileAtomically(envFile, content, 0600); err != nil {
			return fmt.Errorf("failed to write env file: %w", err)
		}
		fmt.Printf("Generated OPENCLAW_GATEWAY_TOKEN and wrote it to %s\n", envFile)
	}
	
	if err := upsertEnvVar(envFile, "OPENCLAW_PODMAN_CONTAINER", config.ContainerName); err != nil {
		return err
	}
	
	if err := upsertEnvVar(envFile, "OPENCLAW_PODMAN_IMAGE", config.ImageName); err != nil {
		return err
	}
	
	return nil
}

func setupConfiguration(config *Config) error {
	configJSON := filepath.Join(config.ConfigDir, "openclaw.json")
	
	if _, err := os.Stat(configJSON); os.IsNotExist(err) {
		content := fmt.Sprintf(`{
  "gateway": {
    "mode": "local",
    "controlUi": {
      "allowedOrigins": [
        "http://127.0.0.1:%s",
        "http://localhost:%s"
      ]
    }
  }
}`, config.SeedGatewayPort, config.SeedGatewayPort)
		
		if err := writeFileAtomically(configJSON, content, 0600); err != nil {
			return fmt.Errorf("failed to write config file: %w", err)
		}
		fmt.Printf("Wrote minimal config to %s\n", configJSON)
	}
	
	if err := seedLocalControlUIOrigins(configJSON, config.SeedGatewayPort); err != nil {
		return err
	}
	
	return nil
}

func installQuadlet(config *Config) error {
	quadletDir := filepath.Join(config.OpenclawHome, ".config", "containers", "systemd")
	quadletDst := filepath.Join(quadletDir, "openclaw.container")
	
	fmt.Printf("Installing Quadlet to %s ...\n", quadletDst)
	
	if err := os.MkdirAll(quadletDir, 0755); err != nil {
		return fmt.Errorf("failed to create quadlet directory: %w", err)
	}
	
	if err := ensureSafeExistingDir("quadlet directory", quadletDir); err != nil {
		return err
	}
	
	templateContent, err := os.ReadFile(config.QuadletTemplate)
	if err != nil {
		return fmt.Errorf("failed to read quadlet template: %w", err)
	}
	
	content := string(templateContent)
	content = strings.ReplaceAll(content, "{{OPENCLAW_HOME}}", escapeSedReplacementPipeDelim(config.OpenclawHome))
	content = strings.ReplaceAll(content, "{{OPENCLAW_CONFIG_DIR}}", escapeSedReplacementPipeDelim(config.ConfigDir))
	content = strings.ReplaceAll(content, "{{OPENCLAW_WORKSPACE_DIR}}", escapeSedReplacementPipeDelim(config.WorkspaceDir))
	content = strings.ReplaceAll(content, "{{IMAGE_NAME}}", escapeSedReplacementPipeDelim(config.ImageName))
	content = strings.ReplaceAll(content, "{{CONTAINER_NAME}}", escapeSedReplacementPipeDelim(config.ContainerName))
	
	if err := writeFileAtomically(quadletDst, content, 0644); err != nil {
		return fmt.Errorf("failed to write quadlet file: %w", err)
	}
	
	if commandExists("systemctl") {
		fmt.Println("Reloading and starting user service...")
		reloadCmd := exec.Command("systemctl", "--user", "daemon-reload")
		startCmd := exec.Command("systemctl", "--user", "start", "openclaw.service")
		
		if err := reloadCmd.Run(); err != nil {
			return fmt.Errorf("failed to reload systemd daemon: %w", err)
		}
		
		if err := startCmd.Run(); err != nil {
			fmt.Fprintln(os.Stderr, "Quadlet installed, but automatic start failed.")
			fmt.Fprintln(os.Stderr, "Try: systemctl --user daemon-reload && systemctl --user start openclaw.service")
			if commandExists("loginctl") {
				fmt.Fprintf(os.Stderr, "For boot persistence on headless hosts, you may also need: sudo loginctl enable-linger %s\n", config.OpenclawUser)
			}
			return nil
		}
		
		fmt.Println("Quadlet installed and service started.")
	} else {
		fmt.Fprintln(os.Stderr, "systemctl not found; Quadlet installed but not started.")
	}
	
	return nil
}

func printNextSteps(config *Config) {
	fmt.Println()
	fmt.Println("Next:")
	fmt.Println("  ./scripts/run-openclaw-podman.sh launch")
	fmt.Println("  ./scripts/run-openclaw-podman.sh launch setup")
	fmt.Printf("  openclaw --container %s dashboard --no-open\n", config.ContainerName)
}

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func isRoot() bool {
	return os.Getuid() == 0
}

func validateSingleLineValue(label, value string) error {
	if strings.Contains(value, "\n") || strings.Contains(value, "\r") {
		return fmt.Errorf("invalid %s: control characters are not allowed", label)
	}
	return nil
}

func validateAbsolutePath(label, value string) error {
	if err := validateSingleLineValue(label, value); err != nil {
		return err
	}
	
	if !filepath.IsAbs(value) {
		return fmt.Errorf("invalid %s: expected an absolute path", label)
	}
	
	if strings.Contains(value, "//") {
		return fmt.Errorf("invalid %s: repeated slashes are not allowed", label)
	}
	
	if strings.Contains(value, "/./") || strings.HasSuffix(value, "/.") ||
		strings.Contains(value, "/../") || strings.HasSuffix(value, "/..") {
		return fmt.Errorf("invalid %s: dot path segments are not allowed", label)
	}
	
	return nil
}

func validateMountSourcePath(label, value string) error {
	if err := validateAbsolutePath(label, value); err != nil {
		return err
	}
	
	if strings.Contains(value, ":") {
		return fmt.Errorf("invalid %s: ':' is not allowed in Podman bind-mount source paths", label)
	}
	
	return nil
}

func validateContainerName(value string) error {
	if err := validateSingleLineValue("container name", value); err != nil {
		return err
	}
	
	if !strings.HasPrefix(value, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") {
		return fmt.Errorf("invalid container name: must start with alphanumeric character")
	}
	
	for _, c := range value {
		if !strings.ContainsRune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-", c) {
			return fmt.Errorf("invalid container name: contains invalid character '%c'", c)
		}
	}
	
	return nil
}

func validateImageName(value string) error {
	if err := validateSingleLineValue("image name", value); err != nil {
		return err
	}
	
	prefixes := []string{"oci-archive:", "docker-archive:", "dir:", "oci:", "containers-storage:", "docker-daemon:", "archive:"}
	for _, prefix := range prefixes {
		if strings.HasPrefix(value, prefix) {
			return fmt.Errorf("invalid image name: transport prefixes are not allowed: %s", value)
		}
	}
	
	if !strings.HasPrefix(value, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") {
		return fmt.Errorf("invalid image name: must start with alphanumeric character")
	}
	
	validChars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/:@-"
	for _, c := range value {
		if !strings.ContainsRune(validChars, c) {
			return fmt.Errorf("invalid image name: contains invalid character '%c'", c)
		}
	}
	
	return nil
}

func ensureSafeExistingDir(label, dir string) error {
	if err := validateAbsolutePath(label, dir); err != nil {
		return err
	}
	
	info, err := os.Stat(dir)
	if os.IsNotExist(err) {
		return fmt.Errorf("missing %s: %s", label, dir)
	}
	
	if info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("unsafe %s: symlinks are not allowed (%s)", label, dir)
	}
	
	return nil
}

func ensurePrivateExistingDirOwnedByUser(label, dir string) error {
	if err := ensureSafeExistingDir(label, dir); err != nil {
		return err
	}
	
	info, err := os.Stat(dir)
	if err != nil {
		return fmt.Errorf("failed to stat directory: %w", err)
	}
	
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return fmt.Errorf("failed to get stat info")
	}
	
	if int(stat.Uid) != os.Getuid() {
		return fmt.Errorf("unsafe %s: not owned by current user (%s)", label, dir)
	}
	
	mode := info.Mode().Perm()
	if mode&0022 != 0 {
		return fmt.Errorf("unsafe %s: group/other writable (%s)", label, dir)
	}
	
	return nil
}

func ensureSafeWriteFilePath(label, file string) error {
	if err := validateAbsolutePath(label, file); err != nil {
		return err
	}
	
	if _, err := os.Stat(file); err == nil {
		info, err := os.Lstat(file)
		if err != nil {
			return fmt.Errorf("failed to lstat file: %w", err)
		}
		
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("unsafe %s: symlinks are not allowed (%s)", label, file)
		}
		
		if !info.Mode().IsRegular() {
			return fmt.Errorf("unsafe %s: expected a regular file (%s)", label, file)
		}
	}
	
	dir := filepath.Dir(file)
	return ensureSafeExistingDir(label+" parent directory", dir)
}

func writeFileAtomically(file, content string, mode fs.FileMode) error {
	if err := ensureSafeWriteFilePath("output file", file); err != nil {
		return err
	}
	
	dir := filepath.Dir(file)
	tmp, err := os.CreateTemp(dir, ".tmp.*")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmp.Name())
	
	if _, err := tmp.WriteString(content); err != nil {
		tmp.Close()
		return fmt.Errorf("failed to write to temp file: %w", err)
	}
	
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("failed to close temp file: %w", err)
	}
	
	if err := os.Chmod(tmp.Name(), mode); err != nil {
		return fmt.Errorf("failed to chmod temp file: %w", err)
	}
	
	if err := os.Rename(tmp.Name(), file); err != nil {
		return fmt.Errorf("failed to rename temp file: %w", err)
	}
	
	return nil
}

func validatePort(label, value string) error {
	if !isValidPort(value) {
		return fmt.Errorf("invalid %s: must be numeric between 1-65535", label)
	}
	return nil
}

func isValidPort(portStr string) bool {
	port, err := strconv.Atoi(portStr)
	if err != nil {
		return false
	}
	return port >= 1 && port <= 65535
}

func escapeSedReplacementPipeDelim(s string) string {
	var result strings.Builder
	for _, r := range s {
		switch r {
		case '\\', '&', '|':
			result.WriteRune('\\')
			fallthrough
		default:
			result.WriteRune(r)
		}
	}
	return result.String()
}

func generateTokenHex32() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("failed to generate random bytes: %w", err)
	}
	return hex.EncodeToString(bytes), nil
}

func seedLocalControlUIOrigins(file, port string) error {
	if _, err := os.Stat(file); os.IsNotExist(err) {
		return nil
	}
	
	content, err := os.ReadFile(file)
	if err != nil {
		return fmt.Errorf("failed to read config file: %w", err)
	}
	
	var data map[string]interface{}
	if err := json.Unmarshal(content, &data); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: unable to seed gateway.controlUi.allowedOrigins in %s: existing config is not strict JSON (%v). Leaving file unchanged.\n", file, err)
		return nil
	}
	
	if data == nil {
		data = make(map[string]interface{})
	}
	
	gateway, ok := data["gateway"].(map[string]interface{})
	if !ok {
		gateway = make(map[string]interface{})
		data["gateway"] = gateway
	}
	
	if mode, exists := gateway["mode"]; !exists || mode == "" {
		gateway["mode"] = "local"
	}
	
	controlUI, ok := gateway["controlUi"].(map[string]interface{})
	if !ok {
		controlUI = make(map[string]interface{})
		gateway["controlUi"] = controlUI
	}
	
	allowed, ok := controlUI["allowedOrigins"].([]interface{})
	if !ok {
		allowed = []interface{}{}
	}
	
	managedLocalhosts := map[string]bool{
		"127.0.0.1": true,
		"localhost": true,
	}
	
	desired := []string{
		fmt.Sprintf("http://127.0.0.1:%s", port),
		fmt.Sprintf("http://localhost:%s", port),
	}
	
	cleaned := []interface{}{}
	for _, origin := range allowed {
		if originStr, ok := origin.(string); ok {
			normalized := strings.TrimSpace(originStr)
			if normalized != "" {
				if strings.HasPrefix(normalized, "http://") {
					hostPort := strings.TrimPrefix(normalized, "http://")
					host := strings.Split(hostPort, ":")[0]
					if managedLocalhosts[host] {
						continue
					}
				}
				cleaned = append(cleaned, normalized)
			}
		}
	}
	
	for _, d := range desired {
		cleaned = append(cleaned, d)
	}
	
	controlUI["allowedOrigins"] = cleaned
	
	newContent, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal updated config: %w", err)
	}
	newContent = append(newContent, '\n')
	
	return writeFileAtomically(file, string(newContent), 0600)
}

func upsertEnvVar(file, key, value string) error {
	if err := ensureSafeWriteFilePath("env file", file); err != nil {
		return err
	}
	
	var lines []string
	
	if _, err := os.Stat(file); err == nil {
		content, err := os.ReadFile(file)
		if err != nil {
			return fmt.Errorf("failed to read env file: %w", err)
		}
		
		scanner := bufio.NewScanner(bytes.NewReader(content))
		found := false
		
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, key+"=") {
				lines = append(lines, key+"="+value)
				found = true
			} else {
				lines = append(lines, line)
			}
		}
		
		if !found {
			lines = append(lines, key+"="+value)
		}
	} else {
		lines = append(lines, key+"="+value)
	}
	
	content := strings.Join(lines, "\n") + "\n"
	return writeFileAtomically(file, content, 0600)
}
