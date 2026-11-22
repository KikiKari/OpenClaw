// abstraction-provenance: {"artifact_sha256": "71547ff30e169cf4934df838a5dae315d9cb71f29627d76fee22bfe71b882f38", "source_sha256": "b31f1bce542d41c8328b88079d7d58fa9d018f246f3f05fa532df8fe4ef6e153", "target_language": "go"}
// sandbox-common-setup.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-common-setup.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func main() {
	baseImage := getEnv("BASE_IMAGE", "openclaw-sandbox:bookworm-slim")
	targetImage := getEnv("TARGET_IMAGE", "openclaw-sandbox-common:bookworm-slim")
	packages := getEnv("PACKAGES", "curl wget jq coreutils grep nodejs npm python3 git ca-certificates golang-go rustc cargo unzip pkg-config libasound2-dev build-essential file")
	installPnpm := getEnv("INSTALL_PNPM", "1")
	installBun := getEnv("INSTALL_BUN", "1")
	bunInstallDir := getEnv("BUN_INSTALL_DIR", "/opt/bun")
	installBrew := getEnv("INSTALL_BREW", "1")
	brewInstallDir := getEnv("BREW_INSTALL_DIR", "/home/linuxbrew/.linuxbrew")
	finalUser := getEnv("FINAL_USER", "sandbox")
	useBuildx := getEnv("OPENCLAW_DOCKER_BUILD_USE_BUILDX", "0")
	cacheFrom := getEnv("OPENCLAW_DOCKER_BUILD_CACHE_FROM", "")
	cacheTo := getEnv("OPENCLAW_DOCKER_BUILD_CACHE_TO", "")

	// Check if base image exists
	if !imageExists(baseImage) {
		fmt.Printf("Base image missing: %s\n", baseImage)
		fmt.Println("Building base image via scripts/sandbox-setup.sh...")
		runCommand("scripts/sandbox-setup.sh")
	}

	fmt.Printf("Building %s with: %s\n", targetImage, packages)

	var buildCmd []string
	if useBuildx == "1" {
		buildCmd = []string{"docker", "buildx", "build", "--load"}
		if cacheFrom != "" {
			buildCmd = append(buildCmd, "--cache-from", cacheFrom)
		}
		if cacheTo != "" {
			buildCmd = append(buildCmd, "--cache-to", cacheTo)
		}
	} else {
		buildCmd = []string{"docker", "build"}
	}

	buildCmd = append(buildCmd,
		"-t", targetImage,
		"-f", "Dockerfile.sandbox-common",
		"--build-arg", "BASE_IMAGE="+baseImage,
		"--build-arg", "PACKAGES="+packages,
		"--build-arg", "INSTALL_PNPM="+installPnpm,
		"--build-arg", "INSTALL_BUN="+installBun,
		"--build-arg", "BUN_INSTALL_DIR="+bunInstallDir,
		"--build-arg", "INSTALL_BREW="+installBrew,
		"--build-arg", "BREW_INSTALL_DIR="+brewInstallDir,
		"--build-arg", "FINAL_USER="+finalUser,
		".",
	)

	runCommand(buildCmd...)

	note := fmt.Sprintf(`
Built %s.
To use it, set agents.defaults.sandbox.docker.image to "%s" and restart.
If you want a clean re-create, remove old sandbox containers:
  docker rm -f $(docker ps -aq --filter label=openclaw.sandbox=1)
`, targetImage, targetImage)

	fmt.Print(note)
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func imageExists(imageName string) bool {
	cmd := exec.Command("docker", "image", "inspect", imageName)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	return err == nil
}

func runCommand(command ...string) {
	cmd := exec.Command(command[0], command[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	
	err := cmd.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Command failed: %s\n", strings.Join(command, " "))
		os.Exit(1)
	}
}
