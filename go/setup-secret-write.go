// abstraction-provenance: {"artifact_sha256": "29155a0c15f35199ed8d734fee4ac5f7d5241267996b7a46ef4a01e36f31273e", "source_sha256": "eb329c9ad90fe7f2c211dd5d35aed9557a4387c1092c4569ebb4e3f4db2d3557", "target_language": "go"}
// setup-secret-write.sh — portiert nach go
// Quelle: shell, workspace@local:scripts/setup-secret-write.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	// Load environment variables from file
	envFile := "/home/openclaw/.config/openclaw/env"
	if err := loadEnv(envFile); err != nil {
		log.Fatalf("Failed to load environment: %v", err)
	}

	SECRETS_DIR := "/secret-store"
	YAML := "/home/openclaw/.openclaw/workspace/memory/model-pools.yaml"

	// Create secrets directory with appropriate permissions
	if err := createSecretsDir(SECRETS_DIR); err != nil {
		log.Fatalf("Failed to create secrets directory: %v", err)
	}

	// Write secret files
	if err := writeSecretFiles(SECRETS_DIR); err != nil {
		log.Fatalf("Failed to write secret files: %v", err)
	}

	// Write YAML configuration
	if err := writeYAMLConfig(YAML); err != nil {
		log.Fatalf("Failed to write YAML config: %v", err)
	}

	// Print completion message and list files
	printCompletion(SECRETS_DIR, YAML)
}

func loadEnv(filepath string) error {
	content, err := ioutil.ReadFile(filepath)
	if err != nil {
		return err
	}

	lines := strings.Split(string(content), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			os.Setenv(parts[0], parts[1])
		}
	}
	return nil
}

func createSecretsDir(dir string) error {
	cmd := exec.Command("sudo", "mkdir", "-p", dir)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create directory: %v", err)
	}

	cmd = exec.Command("sudo", "chmod", "750", dir)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to set directory permissions: %v", err)
	}

	cmd = exec.Command("sudo", "chown", "openclaw:openclaw", dir)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to change directory ownership: %v", err)
	}

	return nil
}

func writeSecretFiles(dir string) error {
	openrouterKey := os.Getenv("OPENROUTER_API_KEY")
	openaiKey := os.Getenv("OPENAI_API_KEY")

	defaultModelContent := fmt.Sprintf(`{ "provider": "openrouter", "token": "%s" }`, openrouterKey)
	proxyModelContent := fmt.Sprintf(`{ "provider": "openai", "token": "%s" }`, openaiKey)

	files := map[string]string{
		filepath.Join(dir, "default-model.json"): defaultModelContent,
		filepath.Join(dir, "proxy-model.json"):  proxyModelContent,
	}

	for path, content := range files {
		cmd := exec.Command("sudo", "tee", path)
		cmd.Stdin = strings.NewReader(content)
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to write file %s: %v", path, err)
		}
	}

	// Set file permissions
	paths := []string{
		filepath.Join(dir, "default-model.json"),
		filepath.Join(dir, "proxy-model.json"),
	}
	for _, path := range paths {
		cmd := exec.Command("sudo", "chmod", "600", path)
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to set permissions on %s: %v", path, err)
		}
	}

	return nil
}

func writeYAMLConfig(yamlPath string) error {
	yamlContent := `pools:
  - name: pool_default
    id: default
    model: openrouter/moonshotai/kimi-k3
    weight: 0.8
    secretsPath: /secret-store/default-model.json

  - name: pool_proxy
    id: proxy
    model: openrouter/auto
    weight: 0.2
    secretsPath: /secret-store/proxy-model.json

routing:
  - name: latency_and_error_based
    criteria:
      - latency_ms: "< 200"
      - error_rate_pct: "< 1"
    route_to: pool_default
  - name: fallback_if_issues
    criteria:
      - latency_ms: ">= 200"
      - error_rate_pct: ">= 1"
    route_to: pool_proxy

fallbacks:
  - model: openrouter/moonshotai/kimi-k3
  - model: openai/gpt-5.6-luna

logging:
  events:
    request_decisions: true
    memory_store_path: /memory/logs/model-routing.log
  retention_days: 14

security:
  secrets_encryption: true
  access_control:
    - role: model-operator
      allow: [read, write]
    - role: monitor
      allow: [read]
`

	return ioutil.WriteFile(yamlPath, []byte(yamlContent), 0644)
}

func printCompletion(secretsDir, yamlPath string) {
	fmt.Println("=== ERLEDIGT ===")
	fmt.Println("Secrets:")

	cmd := exec.Command("sudo", "ls", "-la", secretsDir)
	output, _ := cmd.Output()
	fmt.Print(string(output))

	fmt.Println("")
	fmt.Printf("YAML: %s\n", yamlPath)

	cmd = exec.Command("ls", "-la", yamlPath)
	output, _ = cmd.Output()
	fmt.Print(string(output))
}
