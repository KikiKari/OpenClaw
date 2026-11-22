// abstraction-provenance: {"artifact_sha256": "f35872f0d15c464a9b3f74b57dd43f516b464786dd791eea3ac9f0ecf709b31e", "source_sha256": "7b2c2cb6fd7efb0ae2db61fbe33805abf06e72ace6dee56ecc1c14b6e6bcf9cf", "target_language": "go"}
// sandbox-setup.sh — portiert nach go
// Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	skipHeavy := false
	if len(os.Args) > 1 && os.Args[1] == "--skip-heavy" {
		skipHeavy = true
	}

	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		log.Fatalf("FEHLER: Konnte Arbeitsverzeichnis nicht bestimmen: %v", err)
	}
	projectRoot := filepath.Join(dir, "..")
	if err := os.Chdir(projectRoot); err != nil {
		log.Fatalf("FEHLER: Konnte nicht ins Projektverzeichnis wechseln: %v", err)
	}

	fmt.Println("[sandbox-setup] Node-Dependencies (npm install) …")
	if err := runCmd("npm", "install", "--no-audit", "--no-fund"); err != nil {
		log.Fatal("FEHLER: npm install fehlgeschlagen")
	}

	fmt.Println("[sandbox-setup] Python-Dependencies (backend/requirements-dev.txt) …")
	if err := runCmd("pip3", "install", "--quiet", "-r", "backend/requirements-dev.txt"); err != nil {
		log.Fatal("FEHLER: pip install fehlgeschlagen")
	}

	aptUpdated := false
	aptInstall := func(pkg, bin string) {
		if _, err := exec.LookPath(bin); err == nil {
			versionOutput := getVersion(bin)
			fmt.Printf("[sandbox-setup] %s bereits vorhanden (%s)\n", pkg, strings.TrimSpace(versionOutput))
			return
		}
		fmt.Printf("[sandbox-setup] Installiere %s …\n", pkg)
		if !aptUpdated {
			if err := runQuietCmd("apt-get", "update", "-qq"); err != nil {
				fmt.Println("[sandbox-setup] WARNUNG: apt-get update fehlgeschlagen")
				return
			}
			aptUpdated = true
		}
		if err := runQuietCmd("apt-get", "install", "-y", "-qq", pkg); err != nil {
			fmt.Printf("[sandbox-setup] WARNUNG: %s konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt\n", pkg)
		}
	}

	aptInstall("ffmpeg", "ffmpeg")
	aptInstall("imagemagick", "convert")
	if !skipHeavy {
		aptInstall("gimp", "gimp")
		aptInstall("blender", "blender")
	}

	aptInstall("xvfb", "Xvfb")
	aptInstall("x11-utils", "xdpyinfo")
	aptInstall("libnss3-tools", "certutil")

	if _, err := exec.LookPath("google-chrome-stable"); err != nil {
		fmt.Println("[sandbox-setup] Installiere Google Chrome Stable …")
		tmpDeb := "/tmp/chrome.deb"
		downloadCmd := exec.Command("curl", "-fsSL", "-o", tmpDeb, "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb")
		if err := downloadCmd.Run(); err != nil {
			fmt.Println("[sandbox-setup] WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)")
		} else {
			defer os.Remove(tmpDeb)
			if err := runQuietCmd("apt-get", "install", "-y", "-qq", tmpDeb); err != nil {
				fmt.Println("[sandbox-setup] WARNUNG: Chrome-Installation fehlgeschlagen")
			} else {
				chromeVersion := getVersion("google-chrome-stable")
				fmt.Printf("[sandbox-setup] Chrome installiert: %s", chromeVersion)
			}
		}
	}

	if _, err := exec.LookPath("certutil"); err == nil {
		if caBundle, err := os.Stat("/root/.ccr/ca-bundle.crt"); err == nil && !caBundle.IsDir() {
			nssdbPath := filepath.Join(os.Getenv("HOME"), ".pki/nssdb")
			os.MkdirAll(nssdbPath, 0755)
			runQuietCmd("certutil", "-d", "sql:"+nssdbPath, "-N", "--empty-password")
			listCmd := exec.Command("certutil", "-d", "sql:"+nssdbPath, "-L")
			output, _ := listCmd.Output()
			if !strings.Contains(string(output), "ccr-proxy-ca") {
				importCmd := exec.Command("certutil", "-d", "sql:"+nssdbPath, "-A", "-t", "C,,", "-n", "ccr-proxy-ca", "-i", "/root/.ccr/ca-bundle.crt")
				if err := importCmd.Run(); err == nil {
					fmt.Println("[sandbox-setup] Proxy-CA in Chrome-NSS-Store importiert")
				}
			}
		}
	}

	if _, err := os.Stat("node_modules"); err == nil {
		if _, err := os.Stat("node_modules/playwright"); os.IsNotExist(err) {
			if _, lookErr := exec.LookPath("npm"); lookErr == nil {
				if err := runQuietCmd("npm", "install", "--no-audit", "--no-fund", "--no-save", "playwright"); err != nil {
					fmt.Println("[sandbox-setup] WARNUNG: Playwright-npm-Install fehlgeschlagen")
				} else {
					fmt.Println("[sandbox-setup] Playwright (Node) installiert")
				}
			}
		}
	}

	if isGitRepo() {
		credHelperScript := fmt.Sprintf("!%s/.claude/git-credential-pat.sh", projectRoot)
		runCmd("git", "config", "credential.https://x-access-token@github.com.helper", credHelperScript)
		runCmd("git", "remote", "set-url", "--push", "origin", "https://x-access-token@github.com/KikiKari/Onboarding.git")
		fmt.Println("[sandbox-setup] Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)")
	}

	if _, err := exec.LookPath("dockerd"); err == nil {
		dockerInfoCmd := exec.Command("docker", "info")
		if err := dockerInfoCmd.Run(); err != nil {
			fmt.Println("[sandbox-setup] Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …")
			daemonJsonPath := "/etc/docker/daemon.json"
			if _, statErr := os.Stat(daemonJsonPath); os.IsNotExist(statErr) {
				os.MkdirAll("/etc/docker", 0755)
				os.WriteFile(daemonJsonPath, []byte(`{"registry-mirrors":["https://mirror.gcr.io"]}`), 0644)
			}
			
			go func() {
				cmd := exec.Command("dockerd")
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				cmd.Run()
			}()
			
			time.Sleep(1 * time.Second)
			for i := 0; i < 15; i++ {
				if dockerInfoCmd.Run() == nil {
					break
				}
				time.Sleep(1 * time.Second)
			}
			
			if dockerInfoCmd.Run() == nil {
				fmt.Println("[sandbox-setup] Docker-Daemon laeuft")
			} else {
				fmt.Println("[sandbox-setup] WARNUNG: Docker-Daemon nicht gestartet")
			}
		}
	}

	fmt.Println("[sandbox-setup] Fertig. Versionen:")
	printVersion("node", "--version", "[sandbox-setup]   node ")
	printVersion("python3", "--version", "[sandbox-setup]   ")
	printVersion("ffmpeg", "-version", "[sandbox-setup]   ")
	printVersion("convert", "-version", "[sandbox-setup]   ")
	printVersion("gimp", "--version", "[sandbox-setup]   ")
	printVersion("blender", "--version", "[sandbox-setup]   ")
}

func runCmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runQuietCmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	return cmd.Run()
}

func getVersion(bin string) string {
	cmd := exec.Command(bin, "-version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return ""
	}
	
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	if scanner.Scan() {
		return scanner.Text()
	}
	return ""
}

func printVersion(bin, versionFlag, prefix string) {
	if _, err := exec.LookPath(bin); err == nil {
		cmd := exec.Command(bin, versionFlag)
		output, err := cmd.Output()
		if err == nil {
			scanner := bufio.NewScanner(strings.NewReader(string(output)))
			if scanner.Scan() {
				fmt.Printf("%s%s\n", prefix, scanner.Text())
			}
		}
	}
}

func isGitRepo() bool {
	cmd := exec.Command("git", "rev-parse", "--is-inside-work-tree")
	err := cmd.Run()
	return err == nil
}
