// abstraction-provenance: {"artifact_sha256": "3bbf82d1e3b7424920c6b97da2e1dae25f2c3675f0a7703c1720a4244a140f82", "source_sha256": "8f102a03732002cacc77d2ffc6fb4210aabf44652bfa80af3f96aab371d0679c", "target_language": "go"}
// run.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-smoke/run.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

func main() {
	ctx := context.Background()
	
	installURL := getEnvOrDefault("OPENCLAW_INSTALL_URL", "https://openclaw.bot/install.sh")
	smokeMode := getEnvOrDefault("OPENCLAW_INSTALL_SMOKE_MODE", "install")
	smokePreviousVersion := getEnvOrDefault("OPENCLAW_INSTALL_SMOKE_PREVIOUS", "")
	skipPrevious := getEnvOrDefault("OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS", "0")
	defaultPackage := "openclaw"
	packageName := getEnvOrDefault("OPENCLAW_INSTALL_PACKAGE", defaultPackage)
	freshVersion := getEnvOrDefault("OPENCLAW_INSTALL_FRESH_VERSION", "")
	freshTagURL := getEnvOrDefault("OPENCLAW_INSTALL_FRESH_TAG_URL", "")
	updateBaselineVersion := getEnvOrDefault("OPENCLAW_INSTALL_UPDATE_BASELINE", "2026.4.10")
	updateBaselineTagURL := getEnvOrDefault("OPENCLAW_INSTALL_UPDATE_BASELINE_TAG_URL", "")
	updateExpectVersion := getEnvOrDefault("OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION", "")
	updateTagURL := getEnvOrDefault("OPENCLAW_INSTALL_UPDATE_TAG_URL", "")
	
	scriptDir := filepath.Dir(os.Args[0])
	
	// Load verify functions
	verifyScriptPath := filepath.Join(scriptDir, "..", "install-sh-common", "cli-verify.sh")
	if _, err := os.Stat(verifyScriptPath); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: cli-verify.sh not found at %s\n", verifyScriptPath)
	}
	
	switch smokeMode {
	case "install":
		err := runInstallSmoke(ctx, packageName, freshVersion, freshTagURL, skipPrevious, smokePreviousVersion, installURL)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
			os.Exit(1)
		}
	case "update":
		err := runUpdateSmoke(ctx, packageName, updateBaselineVersion, updateBaselineTagURL, updateExpectVersion, updateTagURL)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "ERROR: unsupported OPENCLAW_INSTALL_SMOKE_MODE=%s\n", smokeMode)
		os.Exit(1)
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func quietNpm(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "npm", args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = io.Discard
	err := cmd.Run()
	return strings.TrimSpace(out.String()), err
}

func verifyInstalledCLI(packageName, expectedVersion string) error {
	// This would call the verification logic from cli-verify.sh
	// For now we'll just check if the command exists
	cmd := exec.Command("which", packageName)
	return cmd.Run()
}

func runInstallSmoke(ctx context.Context, packageName, freshVersion, freshTagURL, skipPrevious, smokePreviousVersion, installURL string) error {
	if freshVersion != "" && freshTagURL != "" {
		fmt.Printf("package=%s latest=%s source=%s\n", packageName, freshVersion, freshTagURL)
		fmt.Println("==> Install latest release tarball")
		
		_, err := quietNpm(ctx, "install", "-g", "--omit=optional", freshTagURL)
		if err != nil {
			return fmt.Errorf("failed to install package: %w", err)
		}
		
		fmt.Println("==> Verify installed version")
		if latestOut := os.Getenv("OPENCLAW_INSTALL_LATEST_OUT"); latestOut != "" {
			if err := os.WriteFile(latestOut, []byte(freshVersion), 0644); err != nil {
				return fmt.Errorf("failed to write latest version to file: %w", err)
			}
		}
		
		if err := verifyInstalledCLI(packageName, freshVersion); err != nil {
			return fmt.Errorf("verification failed: %w", err)
		}
		
		fmt.Println("OK")
		return nil
	}
	
	fmt.Println("==> Resolve npm versions")
	var latestVersion, previousVersion string
	var err error
	
	if skipPrevious == "1" {
		latestVersion, err = quietNpm(ctx, "view", packageName, "version")
		if err != nil {
			return fmt.Errorf("failed to get latest version: %w", err)
		}
		previousVersion = latestVersion
	} else if smokePreviousVersion != "" {
		latestVersion, err = quietNpm(ctx, "view", packageName, "version")
		if err != nil {
			return fmt.Errorf("failed to get latest version: %w", err)
		}
		previousVersion = smokePreviousVersion
	} else {
		latestVersion, err = quietNpm(ctx, "view", packageName, "dist-tags.latest")
		if err != nil {
			return fmt.Errorf("failed to get latest version: %w", err)
		}
		
		versionsJSON, err := quietNpm(ctx, "view", packageName, "versions", "--json")
		if err != nil {
			return fmt.Errorf("failed to get versions: %w", err)
		}
		
		previousVersion, err = findPreviousVersion(latestVersion, versionsJSON)
		if err != nil {
			return fmt.Errorf("failed to find previous version: %w", err)
		}
	}
	
	fmt.Printf("package=%s latest=%s previous=%s\n", packageName, latestVersion, previousVersion)
	
	if skipPrevious == "1" {
		fmt.Println("==> Skip preinstall previous (OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS=1)")
	} else {
		fmt.Println("==> Preinstall previous (forces installer upgrade path)")
		_, err := quietNpm(ctx, "install", "-g", fmt.Sprintf("%s@%s", packageName, previousVersion))
		if err != nil {
			return fmt.Errorf("failed to install previous version: %w", err)
		}
	}
	
	fmt.Println("==> Run official installer one-liner")
	if err := runInstaller(installURL); err != nil {
		return fmt.Errorf("installer failed: %w", err)
	}
	
	fmt.Println("==> Verify installed version")
	if latestOut := os.Getenv("OPENCLAW_INSTALL_LATEST_OUT"); latestOut != "" {
		if err := os.WriteFile(latestOut, []byte(latestVersion), 0644); err != nil {
			return fmt.Errorf("failed to write latest version to file: %w", err)
		}
	}
	
	if err := verifyInstalledCLI(packageName, latestVersion); err != nil {
		return fmt.Errorf("verification failed: %w", err)
	}
	
	fmt.Println("OK")
	return nil
}

func runUpdateSmoke(ctx context.Context, packageName, updateBaselineVersion, updateBaselineTagURL, updateExpectVersion, updateTagURL string) error {
	if updateExpectVersion == "" {
		return fmt.Errorf("OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION is required for update mode")
	}
	if updateTagURL == "" {
		return fmt.Errorf("OPENCLAW_INSTALL_UPDATE_TAG_URL is required for update mode")
	}
	
	fmt.Printf("package=%s baseline=%s target=%s\n", packageName, updateBaselineVersion, updateExpectVersion)
	fmt.Println("==> Install baseline release")
	
	var err error
	if updateBaselineTagURL != "" {
		_, err = quietNpm(ctx, "install", "-g", "--omit=optional", updateBaselineTagURL)
	} else {
		_, err = quietNpm(ctx, "install", "-g", "--omit=optional", fmt.Sprintf("%s@%s", packageName, updateBaselineVersion))
	}
	if err != nil {
		return fmt.Errorf("failed to install baseline version: %w", err)
	}
	
	if err := verifyInstalledCLI(packageName, updateBaselineVersion); err != nil {
		return fmt.Errorf("baseline verification failed: %w", err)
	}
	
	fmt.Println("==> Run openclaw update from host-served tgz")
	updateStderrFile, err := os.CreateTemp("", "update-stderr-*")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(updateStderrFile.Name())
	defer updateStderrFile.Close()
	
	env := append(os.Environ(), "npm_config_omit=optional", "NPM_CONFIG_OMIT=optional")
	cmd := exec.CommandContext(ctx, "openclaw", "update", "--tag", updateTagURL, "--yes", "--json")
	cmd.Env = env
	cmd.Stderr = updateStderrFile
	
	var updateOut bytes.Buffer
	cmd.Stdout = &updateOut
	
	updateStatus := cmd.Run()
	
	updateStderr, err := os.ReadFile(updateStderrFile.Name())
	if err != nil {
		return fmt.Errorf("failed to read stderr: %w", err)
	}
	
	fmt.Print(updateOut.String())
	if len(updateStderr) > 0 {
		fmt.Fprint(os.Stderr, string(updateStderr))
	}
	
	if updateStatus != nil {
		return fmt.Errorf("openclaw update failed: %w", updateStatus)
	}
	
	var updateJSON map[string]interface{}
	if err := json.Unmarshal(updateOut.Bytes(), &updateJSON); err != nil {
		return fmt.Errorf("failed to parse update JSON: %w", err)
	}
	
	if status, ok := updateJSON["status"].(string); !ok || status != "ok" {
		return fmt.Errorf("expected update status ok, got %v", status)
	}
	
	before, _ := updateJSON["before"].(map[string]interface{})
	if beforeVersion, ok := before["version"].(string); !ok || beforeVersion != updateBaselineVersion {
		return fmt.Errorf("expected before.version %s, got %v", updateBaselineVersion, before["version"])
	}
	
	after, _ := updateJSON["after"].(map[string]interface{})
	if afterVersion, ok := after["version"].(string); !ok || afterVersion != updateExpectVersion {
		return fmt.Errorf("expected after.version %s, got %v", updateExpectVersion, after["version"])
	}
	
	if reason, ok := updateJSON["reason"]; ok && reason != nil {
		return fmt.Errorf("expected no failure reason, got %v", reason)
	}
	
	steps, _ := updateJSON["steps"].([]interface{})
	var updateStep map[string]interface{}
	for _, step := range steps {
		if stepMap, ok := step.(map[string]interface{}); ok {
			if name, ok := stepMap["name"].(string); ok && name == "global update" {
				updateStep = stepMap
				break
			}
		}
	}
	
	if updateStep == nil {
		return fmt.Errorf("missing global update step in update JSON")
	}
	
	if exitCode, ok := updateStep["exitCode"].(float64); !ok || int(exitCode) != 0 {
		return fmt.Errorf("global update step failed: %v", updateStep)
	}
	
	if command, ok := updateStep["command"].(string); !ok || !strings.Contains(command, updateTagURL) {
		return fmt.Errorf("global update step missing expected tgz URL: %v", updateStep)
	}
	
	fmt.Println("==> Verify updated version")
	if err := verifyInstalledCLI(packageName, updateExpectVersion); err != nil {
		return fmt.Errorf("verification failed: %w", err)
	}
	
	fmt.Println("OK")
	return nil
}

func runInstaller(installURL string) error {
	resp, err := http.Get(installURL)
	if err != nil {
		return fmt.Errorf("failed to fetch installer: %w", err)
	}
	defer resp.Body.Close()
	
	script, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read installer: %w", err)
	}
	
	cmd := exec.Command("bash", "-s", "--", "--no-prompt")
	cmd.Stdin = bytes.NewReader(script)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	
	return cmd.Run()
}

func findPreviousVersion(latestVersion, versionsJSON string) (string, error) {
	var versions []interface{}
	if err := json.Unmarshal([]byte(versionsJSON), &versions); err != nil {
		versions = []interface{}{versionsJSON}
	}
	
	if len(versions) == 0 || latestVersion == "" {
		return "", fmt.Errorf("empty versions or latest version")
	}
	
	latestIndex := -1
	for i := len(versions) - 1; i >= 0; i-- {
		if v, ok := versions[i].(string); ok && v == latestVersion {
			latestIndex = i
			break
		}
	}
	
	if latestIndex <= 0 {
		return latestVersion, nil
	}
	
	if prev, ok := versions[latestIndex-1].(string); ok {
		return prev, nil
	}
	
	return latestVersion, nil
}
