// abstraction-provenance: {"artifact_sha256": "216f21be1230198318fc2d6bdc3a34b11cd2ba6eeb8e5f42e2e1d9428554ac0b", "source_sha256": "7d9c583822b7f56d89ce608cb8d469719c8a0d1dda7229ea2e4bbf717e511afe", "target_language": "go"}
// run.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-e2e/run.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/blang/semver/v4"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	scriptDir := filepath.Dir(os.Args[0])
	verifyHelperPath := "/usr/local/install-sh-common/version-parse.sh"
	if _, err := os.Stat(verifyHelperPath); os.IsNotExist(err) {
		verifyHelperPath = filepath.Join(scriptDir, "../install-sh-common/version-parse.sh")
	}

	// Load helper functions from shell script
	helperContent, err := os.ReadFile(verifyHelperPath)
	if err != nil {
		return fmt.Errorf("failed to read helper script: %w", err)
	}

	installURL := getEnvOrDefault("OPENCLAW_INSTALL_URL", "https://openclaw.bot/install.sh")
	modelsMode := getEnvOrDefault("OPENCLAW_E2E_MODELS", "both")
	installTag := getEnvOrDefault("OPENCLAW_INSTALL_TAG", "latest")
	e2ePreviousVersion := os.Getenv("OPENCLAW_INSTALL_E2E_PREVIOUS")
	skipPrevious := getEnvOrDefault("OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS", "0")
	openaiAPIKey := os.Getenv("OPENAI_API_KEY")
	anthropicAPIKey := os.Getenv("ANTHROPIC_API_KEY")
	anthropicAPIToken := os.Getenv("ANTHROPIC_API_TOKEN")

	// Set up npm config
	npmPrefix := getEnvOrDefault("NPM_CONFIG_PREFIX", filepath.Join(os.Getenv("HOME"), ".npm-global"))
	os.MkdirAll(npmPrefix, 0755)
	os.Setenv("PATH", npmPrefix+"/bin:"+os.Getenv("PATH"))

	// Validate models mode
	if modelsMode != "both" && modelsMode != "openai" && modelsMode != "anthropic" {
		return fmt.Errorf("OPENCLAW_E2E_MODELS must be one of: both|openai|anthropic")
	}

	// Validate API keys based on mode
	if modelsMode == "both" {
		if openaiAPIKey == "" {
			return fmt.Errorf("OPENCLAW_E2E_MODELS=both requires OPENAI_API_KEY")
		}
		if anthropicAPIKey == "" && anthropicAPIToken == "" {
			return fmt.Errorf("OPENCLAW_E2E_MODELS=both requires ANTHROPIC_API_TOKEN or ANTHROPIC_API_KEY")
		}
	} else if modelsMode == "openai" && openaiAPIKey == "" {
		return fmt.Errorf("OPENCLAW_E2E_MODELS=openai requires OPENAI_API_KEY")
	} else if modelsMode == "anthropic" && anthropicAPIKey == "" && anthropicAPIToken == "" {
		return fmt.Errorf("OPENCLAW_E2E_MODELS=anthropic requires ANTHROPIC_API_TOKEN or ANTHROPIC_API_KEY")
	}

	fmt.Println("==> Resolve npm versions")
	expectedVersion, err := quietNpmView(fmt.Sprintf("openclaw@%s", installTag), "version")
	if err != nil {
		return fmt.Errorf("unable to resolve openclaw@%s version: %w", installTag, err)
	}
	if expectedVersion == "" || expectedVersion == "undefined" || expectedVersion == "null" {
		return fmt.Errorf("unable to resolve openclaw@%s version", installTag)
	}

	var previousVersion string
	if e2ePreviousVersion != "" {
		previousVersion = e2ePreviousVersion
	} else {
		versionsJSON, err := quietNpmView("openclaw", "versions", "--json")
		if err != nil {
			return fmt.Errorf("failed to get versions: %w", err)
		}
		
		var versions []string
		if err := json.Unmarshal([]byte(versionsJSON), &versions); err != nil {
			return fmt.Errorf("failed to parse versions JSON: %w", err)
		}
		
		if len(versions) == 0 {
			return fmt.Errorf("no versions found")
		}
		
		if len(versions) >= 2 {
			previousVersion = versions[len(versions)-2]
		} else {
			previousVersion = versions[0]
		}
	}
	
	fmt.Printf("expected=%s previous=%s\n", expectedVersion, previousVersion)

	if skipPrevious == "1" {
		fmt.Println("==> Skip preinstall previous (OPENCLAW_INSTALL_E2E_SKIP_PREVIOUS=1)")
	} else {
		fmt.Println("==> Preinstall previous (forces installer upgrade path; avoids read() prompt)")
		if err := quietNpmInstall("-g", fmt.Sprintf("openclaw@%s", previousVersion)); err != nil {
			return fmt.Errorf("failed to install previous version: %w", err)
		}
	}

	fmt.Println("==> Run official installer one-liner")
	if err := runInstaller(installURL, installTag); err != nil {
		return fmt.Errorf("installer failed: %w", err)
	}

	fmt.Println("==> Verify installed version")
	installedVersion, err := getInstalledVersion()
	if err != nil {
		return fmt.Errorf("failed to get installed version: %w", err)
	}
	
	installedSemver := extractOpenclawSemver(installedVersion)
	fmt.Printf("installed=%s expected=%s\n", installedSemver, expectedVersion)
	
	if installedSemver != expectedVersion {
		return fmt.Errorf("expected openclaw@%s, got openclaw@%s", expectedVersion, installedSemver)
	}

	// Run profiles
	if modelsMode == "openai" || modelsMode == "both" {
		if err := runProfile("e2e-openai", "18789", "/tmp/openclaw-e2e-openai", "openai", openaiAPIKey, anthropicAPIKey, anthropicAPIToken); err != nil {
			return fmt.Errorf("openai profile failed: %w", err)
		}
	}

	if modelsMode == "anthropic" || modelsMode == "both" {
		if err := runProfile("e2e-anthropic", "18799", "/tmp/openclaw-e2e-anthropic", "anthropic", openaiAPIKey, anthropicAPIKey, anthropicAPIToken); err != nil {
			return fmt.Errorf("anthropic profile failed: %w", err)
		}
	}

	fmt.Println("OK")
	return nil
}

func getEnvOrDefault(key, defaultValue string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultValue
}

func quietNpmView(pkg string, field string, args ...string) (string, error) {
	cmdArgs := append([]string{"view", pkg, field}, args...)
	cmd := exec.Command("npm", cmdArgs...)
	cmd.Env = os.Environ()
	
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = io.Discard
	
	if err := cmd.Run(); err != nil {
		return "", err
	}
	
	return strings.TrimSpace(out.String()), nil
}

func quietNpmInstall(args ...string) error {
	cmd := exec.Command("npm", append([]string{"install"}, args...)...)
	cmd.Env = os.Environ()
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	return cmd.Run()
}

func runInstaller(installURL, installTag string) error {
	// Download installer script
	resp, err := http.Get(installURL)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	
	scriptBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	
	// Run installer with appropriate environment
	cmd := exec.Command("bash")
	cmd.Stdin = bytes.NewReader(scriptBody)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	// Set environment variables based on install tag
	env := os.Environ()
	if installTag == "beta" {
		env = append(env, "OPENCLAW_BETA=1")
	} else if installTag != "latest" {
		env = append(env, fmt.Sprintf("OPENCLAW_VERSION=%s", installTag))
	}
	cmd.Env = env
	
	return cmd.Run()
}

func getInstalledVersion() (string, error) {
	cmd := exec.Command("openclaw", "--version")
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = io.Discard
	
	if err := cmd.Run(); err != nil {
		return "", err
	}
	
	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	if len(lines) == 0 {
		return "", fmt.Errorf("no version output")
	}
	
	return strings.TrimRight(lines[0], "\r\n"), nil
}

func extractOpenclawSemver(version string) string {
	// Simple semver extraction - remove non-semver characters
	parts := strings.Split(version, " ")
	for _, part := range parts {
		if strings.Contains(part, ".") && !strings.Contains(part, " ") {
			// Try to parse as semver
			if _, err := semver.ParseTolerant(part); err == nil {
				return part
			}
		}
	}
	return version
}

func runProfile(profile, port, workspace, agentModelProvider, openaiAPIKey, anthropicAPIKey, anthropicAPIToken string) error {
	fmt.Printf("==> Onboard (%s)\n", profile)
	
	onboardArgs := []string{
		"--profile", profile, "onboard",
		"--non-interactive",
		"--accept-risk",
		"--flow", "quickstart",
		"--gateway-port", port,
		"--gateway-bind", "loopback",
		"--gateway-auth", "token",
		"--workspace", workspace,
		"--skip-health",
	}
	
	var cmd *exec.Cmd
	if agentModelProvider == "openai" {
		onboardArgs = append(onboardArgs, "--auth-choice", "openai-api-key", "--openai-api-key", openaiAPIKey)
		cmd = exec.Command("openclaw", onboardArgs...)
	} else if anthropicAPIKey != "" {
		onboardArgs = append(onboardArgs, "--auth-choice", "apiKey", "--anthropic-api-key", anthropicAPIKey)
		cmd = exec.Command("openclaw", onboardArgs...)
	} else if anthropicAPIToken != "" {
		onboardArgs = append(onboardArgs, "--auth-choice", "token", "--token-provider", "anthropic", "--token", anthropicAPIToken)
		cmd = exec.Command("openclaw", onboardArgs...)
	} else {
		onboardArgs = append(onboardArgs, "--auth-choice", "apiKey", "--anthropic-api-key", anthropicAPIKey)
		cmd = exec.Command("openclaw", onboardArgs...)
	}
	
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("onboard failed: %w", err)
	}

	fmt.Printf("==> Verify workspace identity files (%s)\n", profile)
	identityFiles := []string{
		"AGENTS.md",
		"IDENTITY.md",
		"USER.md",
		"SOUL.md",
		"TOOLS.md",
	}
	
	for _, file := range identityFiles {
		path := filepath.Join(workspace, file)
		if _, err := os.Stat(path); os.IsNotExist(err) {
			return fmt.Errorf("missing identity file: %s", path)
		}
	}

	fmt.Printf("==> Configure models (%s)\n", profile)
	var agentModel, imageModel string
	if agentModelProvider == "openai" {
		agentModel = setAgentModel(profile, "openai/gpt-5.4", "openai/gpt-4o-mini", "openai/gpt-4o")
		imageModel = setImageModel(profile, "openai/gpt-4o-mini", "openai/gpt-4o")
	} else {
		agentModel = setAgentModel(profile, "anthropic/claude-opus-4-6", "claude-opus-4-6")
		imageModel = setImageModel(profile, "anthropic/claude-opus-4-6", "claude-opus-4-6")
	}
	fmt.Printf("model=%s\n", agentModel)
	fmt.Printf("imageModel=%s\n", imageModel)

	fmt.Printf("==> Prepare tool fixtures (%s)\n", profile)
	proofTxt := filepath.Join(workspace, "proof.txt")
	proofCopy := filepath.Join(workspace, "copy.txt")
	hostnameTxt := filepath.Join(workspace, "hostname.txt")
	imagePng := filepath.Join(workspace, "proof.png")
	imageTxt := filepath.Join(workspace, "image.txt")
	sessionID := fmt.Sprintf("e2e-tools-%s", profile)
	sessionJsonl := filepath.Join(os.Getenv("HOME"), fmt.Sprintf(".openclaw-%s", profile), "agents/main/sessions", fmt.Sprintf("%s.jsonl", sessionID))

	proofValue := generateRandomHex(16)
	if err := os.WriteFile(proofTxt, []byte(proofValue), 0644); err != nil {
		return fmt.Errorf("failed to write proof.txt: %w", err)
	}
	
	if err := writePngLrRg(imagePng); err != nil {
		return fmt.Errorf("failed to create PNG: %w", err)
	}
	
	expectedHostname, err := os.Hostname()
	if err != nil {
		return fmt.Errorf("failed to get hostname: %w", err)
	}
	expectedHostname = strings.TrimRight(expectedHostname, "\r\n")

	fmt.Printf("==> Start gateway (%s)\n", profile)
	gatewayLog := filepath.Join(workspace, "gateway.log")
	gatewayLogfile, err := os.Create(gatewayLog)
	if err != nil {
		return fmt.Errorf("failed to create gateway log: %w", err)
	}
	
	gatewayCmd := exec.Command("openclaw", "--profile", profile, "gateway", "--port", port, "--bind", "loopback")
	gatewayCmd.Stdout = gatewayLogfile
	gatewayCmd.Stderr = gatewayLogfile
	
	if err := gatewayCmd.Start(); err != nil {
		gatewayLogfile.Close()
		return fmt.Errorf("failed to start gateway: %w", err)
	}
	
	gatewayPid := gatewayCmd.Process.Pid
	defer func() {
		if gatewayCmd.Process != nil {
			gatewayCmd.Process.Kill()
			gatewayCmd.Wait()
		}
		gatewayLogfile.Close()
	}()

	fmt.Printf("==> Wait for health (%s)\n", profile)
	healthCtx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	
	for i := 0; i < 240; i++ {
		select {
		case <-healthCtx.Done():
			return fmt.Errorf("gateway health check timeout")
		default:
			healthCmd := exec.Command("openclaw", "--profile", profile, "health", "--timeout", "5000", "--json")
			healthCmd.Stdout = io.Discard
			healthCmd.Stderr = io.Discard
			
			if healthCmd.Run() == nil {
				goto healthOk
			}
			time.Sleep(250 * time.Millisecond)
		}
	}
	return fmt.Errorf("gateway failed to become healthy")
	
healthOk:
	fmt.Printf("==> Agent turns (%s)\n", profile)
	turn1Json := fmt.Sprintf("/tmp/agent-%s-1.json", profile)
	turn2Json := fmt.Sprintf("/tmp/agent-%s-2.json", profile)
	turn2bJson := fmt.Sprintf("/tmp/agent-%s-2b.json", profile)
	turn3Json := fmt.Sprintf("/tmp/agent-%s-3.json", profile)
	turn3bJson := fmt.Sprintf("/tmp/agent-%s-3b.json", profile)
	turn4Json := fmt.Sprintf("/tmp/agent-%s-4.json", profile)

	// Turn 1: Read proof.txt
	if err := runAgentTurn(profile, sessionID, fmt.Sprintf("Use the read tool (not exec) to read %s. Reply with the exact contents only (no extra whitespace).", proofTxt), turn1Json); err != nil {
		return fmt.Errorf("turn 1 failed: %w", err)
	}
	
	if err := assertAgentJsonHasText(turn1Json); err != nil {
		return fmt.Errorf("turn 1 assertion failed: %w", err)
	}
	
	if err := assertAgentJsonOk(turn1Json, agentModelProvider); err != nil {
		return fmt.Errorf("turn 1 validation failed: %w", err)
	}
	
	reply1, err := extractMatchingText(turn1Json, proofValue)
	if err != nil {
		return fmt.Errorf("failed to extract reply 1: %w", err)
	}
	reply1 = strings.TrimRight(reply1, "\r\n")
	
	if reply1 != proofValue {
		return fmt.Errorf("agent did not read proof.txt correctly (%s): %s", profile, reply1)
	}

	// Turn 2: Write to copy.txt
	prompt2 := fmt.Sprintf("Use the write tool (not exec) to write exactly this string into %s:\n%s\nReply with exactly: WROTE", proofCopy, reply1)
	if err := runAgentTurn(profile, sessionID, prompt2, turn2Json); err != nil {
		return fmt.Errorf("turn 2 failed: %w", err)
	}
	
	if err := assertAgentJsonHasText(turn2Json); err != nil {
		return fmt.Errorf("turn 2 assertion failed: %w", err)
	}
	
	if err := assertAgentJsonOk(turn2Json, agentModelProvider); err != nil {
		return fmt.Errorf("turn 2 validation failed: %w", err)
	}
	
	copyData, err := os.ReadFile(proofCopy)
	if err != nil {
		return fmt.Errorf("failed to read copy.txt: %w", err)
	}
	copyValue := strings.TrimRight(string(copyData), "\r\n")
	
	if copyValue != proofValue {
		return fmt.Errorf("copy.txt did not match proof.txt (%s)", profile)
	}
	
	// Turn 2b: Read copy.txt
	if err := runAgentTurn(profile, sessionID, fmt.Sprintf("Use the read tool (not exec) to read %s. Reply with the exact contents only (no extra whitespace).", proofCopy), turn2bJson); err != nil {
		return fmt.Errorf("turn 2b failed: %w", err)
	}
	
	if err := assertAgentJsonHasText(turn2bJson); err != nil {
		return fmt.Errorf("turn 2b assertion failed: %w", err)
	}
	
	if err := assertAgentJsonOk(turn2bJson, agentModelProvider); err != nil {
		return fmt.Errorf("turn 2b validation failed: %w", err)
	}
	
	reply2, err := extractMatchingText(turn2bJson, proofValue)
	if err != nil {
		return fmt.Errorf("failed to extract reply 2: %w", err)
	}
	reply2 = strings.TrimRight(reply2, "\r\n")
	
	if reply2 != proofValue {
		return fmt.Errorf("agent did not read copy.txt correctly (%s): %s", profile, reply2)
	}

	// Turn 3: Run hostname
	if err := runAgentTurn(profile, sessionID, "Use the exec tool to run this command: hostname. Reply with the exact stdout only (trim trailing newline).", turn3Json); err != nil {
		return fmt.Errorf("turn 3 failed: %w", err)
	}
	
	if err := assertAgentJsonHasText(turn3Json); err != nil {
		return fmt.Errorf("turn 3 assertion failed: %w", err)
	}
	
	if err := assertAgentJsonOk(turn3Json, agentModelProvider); err != nil {
		return fmt.Errorf("turn 3 validation failed: %w", err)
	}
	
	reply3, err := extractMatchingText(turn3Json, expectedHostname)
	if err != nil {
		return fmt.Errorf("failed to extract reply 3: %w", err)
	}
	reply3 = strings.TrimRight(reply3, "\r\n")
	
	if reply3 != expectedHostname {
		return fmt.Errorf("agent did not run hostname correctly (%s): %s", profile, reply3)
	}
	
	// Turn 3b: Write hostname to file
	prompt3b := fmt.Sprintf("Use the write tool to write exactly this string into %s:\n%s\nReply with exactly: WROTE", hostnameTxt, reply3)
	if err := runAgentTurn(profile, sessionID, prompt3b, turn3bJson); err != nil {
		return fmt.Errorf("turn 3b failed: %w", err)
	}
	
	if err := assertAgentJsonHasText(turn3bJson); err != nil {
		return fmt.Errorf("turn 3b assertion failed: %w", err)
	}
	
	if err := assertAgentJsonOk(turn3bJson, agentModelProvider); err != nil {
		return fmt.Errorf("turn 3b validation failed: %w", err)
	}
	
	hostnameData, err := os.ReadFile(hostnameTxt)
	if err != nil {
		return fmt.Errorf("failed to read hostname.txt: %w", err)
	}
	hostnameValue := strings.TrimRight(string(hostnameData), "\r\n")
	
	if hostnameValue != expectedHostname {
		return fmt.Errorf("hostname.txt did not match hostname output (%s)", profile)
	}

	// Turn 4: Image analysis
	if err := runAgentTurn(profile, sessionID, fmt.Sprintf("Use the image tool on %s. Determine which color is on the left half and which is on the right half. Then use the write tool to write exactly: LEFT=RED RIGHT=GREEN into %s. Reply with exactly: LEFT=RED RIGHT=GREEN", imagePng, imageTxt), turn4Json); err != nil {
		return fmt.Errorf("turn 4 failed: %w", err)
	}
	
	if err := assertAgentJsonHasText(turn4Json); err != nil {
		return fmt.Errorf("turn 4 assertion failed: %w", err)
	}
	
	if err := assertAgentJsonOk(turn4Json, agentModelProvider); err != nil {
		return fmt.Errorf("turn 4 validation failed: %w", err)
	}
	
	imageData, err := os.ReadFile(imageTxt)
	if err != nil {
		return fmt.Errorf("failed to read image.txt: %w", err)
	}
	imageValue := strings.TrimRight(string(imageData), "\r\n")
	
	if imageValue != "LEFT=RED RIGHT=GREEN" {
		return fmt.Errorf("image.txt did not contain expected marker (%s)", profile)
	}
	
	reply4, err := extractMatchingText(turn4Json, "LEFT=RED RIGHT=GREEN")
	if err != nil {
		return fmt.Errorf("failed to extract reply 4: %w", err)
	}
	
	if reply4 != "LEFT=RED RIGHT=GREEN" {
		return fmt.Errorf("agent reply did not contain expected marker (%s): %s", profile, reply4)
	}

	fmt.Printf("==> Verify tool usage via session transcript (%s)\n", profile)
	time.Sleep(1 * time.Second) // Give gateway time to flush
	
	if _, err := os.Stat(sessionJsonl); os.IsNotExist(err) {
		return fmt.Errorf("missing session transcript (%s): %s", profile, sessionJsonl)
	}
	
	if err := assertSessionUsedTools(sessionJsonl, "read", "write", "exec", "image"); err != nil {
		return fmt.Errorf("session tool usage assertion failed: %w", err)
	}

	return nil
}

func setAgentModel(profile string, candidates ...string) string {
	for _, candidate := range candidates {
		cmd := exec.Command("openclaw", "--profile", profile, "models", "set", candidate)
		cmd.Stdout = io.Discard
		cmd.Stderr = io.Discard
		
		if cmd.Run() == nil {
			return candidate
		}
	}
	return ""
}

func setImageModel(profile string, candidates ...string) string {
	for _, candidate := range candidates {
		cmd := exec.Command("openclaw", "--profile", profile, "models", "set-image", candidate)
		cmd.Stdout = io.Discard
		cmd.Stderr = io.Discard
		
		if cmd.Run() == nil {
			return candidate
		}
	}
	return ""
}

func generateRandomHex(length int) string {
	bytes := make([]byte, length)
	rand.Read(bytes)
	return fmt.Sprintf("%x", bytes)
}

func writePngLrRg(out string) error {
	// Simplified PNG creation - in real implementation you'd want proper PNG encoding
	width, height := 96, 64
	
	// Create a simple header-only PNG for testing
	header := []byte{
		0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, // PNG signature
		0x00, 0x00, 0x00, 0x0d, // IHDR length
		0x49, 0x48, 0x44, 0x52, // IHDR chunk type
		byte(width >> 24), byte(width >> 16), byte(width >> 8), byte(width), // Width
		byte(height >> 24), byte(height >> 16), byte(height >> 8), byte(height), // Height
		0x08, 0x02, 0x00, 0x00, 0x00, // Bit depth, color type, compression, filter, interlace
		// CRC would normally be calculated here
	}
	
	return os.WriteFile(out, header, 0644)
}

func runAgentTurn(profile, sessionID, prompt, outJson string) error {
	cmd := exec.Command("openclaw", "--profile", profile, "agent",
		"--local",
		"--session-id", sessionID,
		"--message", prompt,
		"--thinking", "off",
		"--json")
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("agent command failed: %w, output: %s", err, string(output))
	}
	
	if err := os.WriteFile(outJson, output, 0644); err != nil {
		return fmt.Errorf("failed to write output: %w", err)
	}
	
	// Extract trailing JSON object (simplified)
	content := strings.TrimSpace(string(output))
	if content == "" {
		return fmt.Errorf("agent output was empty")
	}
	
	// Try to parse as JSON directly first
	var result interface{}
	if json.Unmarshal([]byte(content), &result) == nil {
		pretty, _ := json.MarshalIndent(result, "", "  ")
		return os.WriteFile(outJson, append(pretty, '\n'), 0644)
	}
	
	// Look for last JSON object in output
	lastBrace := strings.LastIndex(content, "{")
	if lastBrace >= 0 {
		candidate := content[lastBrace:]
		if json.Unmarshal([]byte(candidate), &result) == nil {
			pretty, _ := json.MarshalIndent(result, "", "  ")
			return os.WriteFile(outJson, append(pretty, '\n'), 0644)
		}
	}
	
	return fmt.Errorf("could not extract JSON payload from agent output")
}

func assertAgentJsonHasText(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	
	var p map[string]interface{}
	if err := json.Unmarshal(data, &p); err != nil {
		return err
	}
	
	var payloads []interface{}
	if result, ok := p["result"].(map[string]interface{}); ok {
		if pls, ok := result["payloads"].([]interface{}); ok {
			payloads = pls
		}
	} else if pls, ok := p["payloads"].([]interface{}); ok {
		payloads = pls
	}
	
	texts := make([]string, 0)
	for _, item := range payloads {
		if obj, ok := item.(map[string]interface{}); ok {
			if text, ok := obj["text"].(string); ok {
				trimmed := strings.TrimSpace(text)
				if trimmed != "" {
					texts = append(texts, trimmed)
				}
			}
		}
	}
	
	if len(texts) == 0 {
		return fmt.Errorf("no text found in payloads")
	}
	
	return nil
}

func assertAgentJsonOk(jsonPath, expectProvider string) error {
	data, err := os.ReadFile(jsonPath)
	if err != nil {
		return err
	}
	
	var p map[string]interface{}
	if err := json.Unmarshal(data, &p); err != nil {
		return err
	}
	
	status, hasStatus := p["status"].(string)
	if hasStatus && status != "ok" && status != "accepted" {
		return fmt.Errorf("gateway status=%s", status)
	}
	
	var result map[string]interface{}
	if res, ok := p["result"].(map[string]interface{}); ok {
		result = res
	} else {
		result = p
	}
	
	var payloads []interface{}
	if pls, ok := result["payloads"].([]interface{}); ok {
		payloads = pls
	}
	
	anyError := false
	combinedText := ""
	for _, item := range payloads {
		if obj, ok := item.(map[string]interface{}); ok {
			if isError, ok := obj["isError"].(bool); ok && isError {
				anyError = true
			}
			if text, ok := obj["text"].(string); ok {
				combinedText += text + "\n"
			}
		}
	}
	combinedText = strings.TrimSpace(combinedText)
	
	if anyError {
		return fmt.Errorf("agent returned error payload: %s", combinedText)
	}
	
	if strings.Contains(strings.ToLower(combinedText), "rate_limit_error") || strings.HasPrefix(combinedText, "429") {
		return fmt.Errorf("agent rate limited: %s", combinedText)
	}
	
	if meta, ok := result["meta"].(map[string]interface{}); ok {
		provider := ""
		if agentMeta, ok := meta["agentMeta"].(map[string]interface{}); ok {
			if prov, ok := agentMeta["provider"].(string); ok {
				provider = strings.TrimSpace(prov)
			}
		}
		if provider == "" {
			if prov, ok := meta["provider"].(string); ok {
				provider = strings.TrimSpace(prov)
			}
		}
		
		if expectProvider != "" && provider != "" && provider != expectProvider {
			return fmt.Errorf("expected provider=%s, got provider=%s", expectProvider, provider)
		}
	}
	
	return nil
}

func extractMatchingText(path, expected string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	
	var p map[string]interface{}
	if err := json.Unmarshal(data, &p); err != nil {
		return "", err
	}
	
	var payloads []interface{}
	if result, ok := p["result"].(map[string]interface{}); ok {
		if pls, ok := result["payloads"].([]interface{}); ok {
			payloads = pls
		}
	} else if pls, ok := p["payloads"].([]interface{}); ok {
		payloads = pls
	}
	
	texts := make([]string, 0)
	for _, item := range payloads {
		if obj, ok := item.(map[string]interface{}); ok {
			if text, ok := obj["text"].(string); ok {
				trimmed := strings.TrimSpace(text)
				if trimmed != "" {
					texts = append(texts, trimmed)
				}
			}
		}
	}
	
	for _, text := range texts {
		if text == expected {
			return text, nil
		}
	}
	
	if len(texts) > 0 {
		return texts[0], nil
	}
	
	return "", nil
}

func assertSessionUsedTools(jsonl string, requiredTools ...string) error {
	data, err := os.ReadFile(jsonl)
	if err != nil {
		return err
	}
	
	required := make(map[string]bool)
	for _, tool := range requiredTools {
		required[tool] = true
	}
	
	lines := strings.Split(string(data), "\n")
	seen := make(map[string]bool)
	
	toolTypes := map[string]bool{
		"tool_use": true, "tool_result": true, "tool": true,
		"tool-call": true, "tool_call": true, "tooluse": true,
		"tool-use": true, "toolresult": true, "tool-result": true,
	}
	
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		
		var entry map[string]interface{}
		if json.Unmarshal([]byte(line), &entry) != nil {
			continue
		}
		
		walk(entry, toolTypes, seen)
	}
	
	var missing []string
	for tool := range required {
		if !seen[tool] {
			missing = append(missing, tool)
		}
	}
	
	if len(missing) > 0 {
		return fmt.Errorf("missing tools in transcript: %s", strings.Join(missing, ", "))
	}
	
	return nil
}

func walk(node interface{}, toolTypes, seen map[string]bool) {
	if node == nil {
		return
	}
	
	switch v := node.(type) {
	case []interface{}:
		for _, item := range v {
			walk(item, toolTypes, seen)
		}
	case map[string]interface{}:
		// Check for tool types
		if t, ok := v["type"].(string); ok {
			if toolTypes[t] || strings.Contains(strings.ToLower(t), "tool") {
				// Extract tool name
				if name, ok := v["name"].(string); ok {
					seen[name] = true
				} else if toolName, ok := v["toolName"].(string); ok {
					seen[toolName] = true
				} else if toolName, ok := v["tool_name"].(string); ok {
					seen[toolName] = true
				} else if tool, ok := v["tool"].(map[string]interface{}); ok {
					if name, ok := tool["name"].(string); ok {
						seen[name] = true
					}
				}
			}
		}
		
		// Check for direct tool call patterns
		if name, ok := v["name"].(string); ok {
			if _, hasInput := v["input"]; hasInput {
				seen[name] = true
			}
		}
		
		// OpenAI-ish tool calls
		if toolCalls, ok := v["tool_calls"].([]interface{}); ok {
			for _, call := range toolCalls {
				if callMap, ok := call.(map[string]interface{}); ok {
					if fn, ok := callMap["function"].(map[string]interface{}); ok {
						if name, ok := fn["name"].(string); ok {
							seen[name] = true
						}
					}
				}
			}
		}
		
		// Function calls
		if fn, ok := v["function"].(map[string]interface{}); ok {
			if name, ok := fn["name"].(string); ok {
				seen[name] = true
			}
		}
		
		// Recursively walk all values
		for _, value := range v {
			walk(value, toolTypes, seen)
		}
	}
}
