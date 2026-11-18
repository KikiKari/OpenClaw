// abstraction-provenance: {"artifact_sha256": "96375ecff3c88bba5df2fbbbd760bf01d6e196c52e991e50af1cab1121bd2f55", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "go"}
// collect_ist_gateway_a.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Ermitteln des Home-Verzeichnisses: %v\n", err)
		os.Exit(1)
	}

	baseDir := filepath.Join(homeDir, ".openclaw")
	outDir := filepath.Join(baseDir, "workspace", "vscode")
	nowUTC := time.Now().UTC().Format("2006-01-02T15:04:05Z")
	nowLocal := time.Now().Format("2006-01-02 15:04:05 MST")
	ts := time.Now().Format("20060102-150405")

	if err := os.MkdirAll(outDir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Erstellen des Ausgabeverzeichnisses: %v\n", err)
		os.Exit(1)
	}

	istFile := filepath.Join(outDir, "IST-ZUSTAND_GATEWAY-A_NODE1.md")
	invFile := filepath.Join(outDir, "ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md")
	cfgFile := filepath.Join(outDir, "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md")
	envFile := filepath.Join(outDir, "ENV-STATUS_GATEWAY-A_NODE1.md")
	runFile := filepath.Join(outDir, fmt.Sprintf("RUN-%s.md", ts))

	openclawJSON := filepath.Join(baseDir, "openclaw.json")
	envDot := filepath.Join(baseDir, ".env")
	envSystemd := filepath.Join(baseDir, "gateway.systemd.env")
	vscodeDir := filepath.Join(baseDir, ".vscode")

	hostnameFQDN := getHostname("-f")
	hostnameShort := getHostname("")
	arch := getUname("-m")
	kernel := getUname("-r")
	osPretty := getOSPrettyName()
	ipv4All := getHostnameI()
	publicIP := getPublicIP()
	tailscaleIP := getTailscaleIP()
	openclawVer := getOpenclawVersion()
	nodeVer := getNodeVersion()

	if publicIP == "" {
		publicIP = "(nicht ermittelt)"
	}
	if tailscaleIP == "" {
		tailscaleIP = "(nicht ermittelt)"
	}
	if openclawVer == "" {
		openclawVer = "(nicht ermittelt)"
	}
	if nodeVer == "" {
		nodeVer = "(nicht ermittelt)"
	}

	istContent := fmt.Sprintf(`# IST-Zustand: Gateway A / Node 1

Stand (lokal): %s  
Stand (UTC): %s

## 1) Identitaet & System

- Gateway: **A**
- Node: **1**
- Hostname (short): `+"`%s`"+`
- Hostname (FQDN): `+"`%s`"+`
- Architektur: `+"`%s`"+`
- Kernel: `+"`%s`"+`
- OS: `+"`%s`"+`
- IPv4 (lokal): `+"`%s`"+`
- Public IPv4: `+"`%s`"+`
- Tailscale IPv4: `+"`%s`"+`
- OpenClaw Version: `+"`%s`"+`
- Node.js Version: `+"`%s`"+`

## 2) Arbeitsverzeichnisse

- Basis: `+"`%s`"+`
- Funktionell VSCode: `+"`%s`"+`
- Workspace Doku: `+"`%s`"+`

## 3) Kernartefakte (Existenz)

- `+"`%s`"+`: %s
- `+"`%s`"+`: %s
- `+"`%s`"+`: %s
- `+"`%s`"+`: %s
- `+"`%s`"+`: %s`,
		nowLocal, nowUTC,
		hostnameShort, hostnameFQDN, arch, kernel, osPretty, ipv4All, publicIP, tailscaleIP, openclawVer, nodeVer,
		baseDir, vscodeDir, outDir,
		openclawJSON, fileExists(openclawJSON),
		envDot, fileExists(envDot),
		envSystemd, fileExists(envSystemd),
		filepath.Join(baseDir, "plugins", "installs.json"), fileExists(filepath.Join(baseDir, "plugins", "installs.json")),
		filepath.Join(baseDir, "plugin-skills"), dirExists(filepath.Join(baseDir, "plugin-skills")),
	)

	if err := ioutil.WriteFile(istFile, []byte(istContent), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Schreiben der IST-Datei: %v\n", err)
		os.Exit(1)
	}

	invContent := buildInventoryContent(baseDir, vscodeDir, nowLocal)
	if err := ioutil.WriteFile(invFile, []byte(invContent), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Schreiben der Inventardatei: %v\n", err)
		os.Exit(1)
	}

	cfgContent := buildConfigContent(openclawJSON, nowLocal)
	if err := ioutil.WriteFile(cfgFile, []byte(cfgContent), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Schreiben der Konfigurationsdatei: %v\n", err)
		os.Exit(1)
	}

	envContent := buildEnvContent(envDot, envSystemd, nowLocal)
	if err := ioutil.WriteFile(envFile, []byte(envContent), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Schreiben der ENV-Datei: %v\n", err)
		os.Exit(1)
	}

	runContent := fmt.Sprintf(`# Laufprotokoll Gateway A / Node 1

- Zeit (lokal): %s
- Zeit (UTC): %s
- Script: %s

## Erzeugte Dateien

- %s
- %s
- %s
- %s`,
		nowLocal, nowUTC, getExecutablePath(),
		filepath.Base(istFile),
		filepath.Base(invFile),
		filepath.Base(cfgFile),
		filepath.Base(envFile),
	)

	if err := ioutil.WriteFile(runFile, []byte(runContent), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Schreiben der Laufprotokolldatei: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("OK: IST-Zustand erfasst.")
	files, err := ioutil.ReadDir(outDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Lesen des Ausgabeverzeichnisses: %v\n", err)
		os.Exit(1)
	}
	for _, file := range files {
		fmt.Printf("- %s\n", file.Name())
	}
}

func getHostname(arg string) string {
	cmd := exec.Command("hostname")
	if arg != "" {
		cmd = exec.Command("hostname", arg)
	}
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func getUname(arg string) string {
	cmd := exec.Command("uname", arg)
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func getOSPrettyName() string {
	content, err := ioutil.ReadFile("/etc/os-release")
	if err != nil {
		return ""
	}
	scanner := bufio.NewScanner(strings.NewReader(string(content)))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "PRETTY_NAME=") {
			return strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), "\"")
		}
	}
	return ""
}

func getHostnameI() string {
	cmd := exec.Command("hostname", "-I")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func getPublicIP() string {
	cmd := exec.Command("curl", "-4", "-s", "--max-time", "4", "ifconfig.me")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func getTailscaleIP() string {
	cmd := exec.Command("tailscale", "ip", "-4")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) > 0 {
		return lines[0]
	}
	return ""
}

func getOpenclawVersion() string {
	cmd := exec.Command("openclaw", "--version")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func getNodeVersion() string {
	cmd := exec.Command("node", "-v")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func fileExists(path string) string {
	if _, err := os.Stat(path); err == nil {
		return "vorhanden"
	}
	return "fehlt"
}

func dirExists(path string) string {
	if stat, err := os.Stat(path); err == nil && stat.IsDir() {
		return "vorhanden"
	}
	return "fehlt"
}

func buildInventoryContent(baseDir, vscodeDir, nowLocal string) string {
	var sb strings.Builder
	sb.WriteString("# Artefakt-Inventar: Gateway A / Node 1\n\n")
	sb.WriteString(fmt.Sprintf("Stand: %s\n\n", nowLocal))
	sb.WriteString("## Top-Level in ~/.openclaw\n\n")
	sb.WriteString("```text\n")
	files, err := ioutil.ReadDir(baseDir)
	if err == nil {
		for _, file := range files {
			sb.WriteString(file.Name() + "\n")
		}
	}
	sb.WriteString("```\n\n")
	sb.WriteString("## ~/.openclaw/.vscode\n\n")
	sb.WriteString("```text\n")
	if stat, err := os.Stat(vscodeDir); err == nil && stat.IsDir() {
		files, err := ioutil.ReadDir(vscodeDir)
		if err == nil {
			for _, file := range files {
				sb.WriteString(fmt.Sprintf("%s %s %s %s\n", file.Mode(), file.ModTime().Format("Jan _2 15:04"), file.Size(), file.Name()))
			}
		}
	} else {
		sb.WriteString("(nicht vorhanden)\n")
	}
	sb.WriteString("```\n\n")
	sb.WriteString("## plugin-skills/\n\n")
	sb.WriteString("```text\n")
	pluginSkillsDir := filepath.Join(baseDir, "plugin-skills")
	if stat, err := os.Stat(pluginSkillsDir); err == nil && stat.IsDir() {
		files, err := ioutil.ReadDir(pluginSkillsDir)
		if err == nil {
			for _, file := range files {
				sb.WriteString(file.Name() + "\n")
			}
		}
	} else {
		sb.WriteString("(nicht vorhanden)\n")
	}
	sb.WriteString("```\n\n")
	sb.WriteString("## openclaw.json Backups\n\n")
	sb.WriteString("```text\n")
	backups, _ := filepath.Glob(filepath.Join(baseDir, "openclaw.json.bak*"))
	if len(backups) > 0 {
		for _, backup := range backups {
			sb.WriteString(filepath.Base(backup) + "\n")
		}
	} else {
		sb.WriteString("(keine gefunden)\n")
	}
	sb.WriteString("```\n")
	return sb.String()
}

func buildConfigContent(openclawJSON, nowLocal string) string {
	var sb strings.Builder
	sb.WriteString("# OpenClaw Config Snapshot: Gateway A / Node 1\n\n")
	sb.WriteString(fmt.Sprintf("Stand: %s\n\n", nowLocal))
	sb.WriteString("## Schluesselpositionen (grep)\n\n")
	sb.WriteString("```text\n")
	if content, err := ioutil.ReadFile(openclawJSON); err == nil {
		lines := strings.Split(string(content), "\n")
		keywords := []string{"gateway", "session", "dmScope", "auth", "secrets", "tools", "plugins", "profile", "alsoAllow", "denyCommands"}
		for i, line := range lines {
			for _, keyword := range keywords {
				if strings.Contains(line, `"`+keyword+`"`) {
					sb.WriteString(fmt.Sprintf("%d:%s\n", i+1, line))
					break
				}
			}
		}
	} else {
		sb.WriteString("openclaw.json fehlt\n")
	}
	sb.WriteString("```\n\n")
	sb.WriteString("## Ausschnitt gateway/session/auth\n\n")
	sb.WriteString("```json\n")
	if content, err := ioutil.ReadFile(openclawJSON); err == nil {
		lines := strings.Split(string(content), "\n")
		start := 579
		end := 779
		if start < len(lines) {
			if end > len(lines) {
				end = len(lines)
			}
			for i := start; i < end; i++ {
				sb.WriteString(lines[i] + "\n")
			}
		}
	} else {
		sb.WriteString(`{ "error": "openclaw.json fehlt" }` + "\n")
	}
	sb.WriteString("```\n")
	return sb.String()
}

func buildEnvContent(envDot, envSystemd, nowLocal string) string {
	var sb strings.Builder
	sb.WriteString("# ENV-Status: Gateway A / Node 1\n\n")
	sb.WriteString(fmt.Sprintf("Stand: %s\n\n", nowLocal))
	sb.WriteString("## Dateien\n\n")
	sb.WriteString("```text\n")
	if stat, err := os.Stat(envDot); err == nil {
		sb.WriteString(fmt.Sprintf("%s %s %d %s\n", stat.Mode(), stat.ModTime().Format("Jan _2 15:04"), stat.Size(), envDot))
	}
	if stat, err := os.Stat(envSystemd); err == nil {
		sb.WriteString(fmt.Sprintf("%s %s %d %s\n", stat.Mode(), stat.ModTime().Format("Jan _2 15:04"), stat.Size(), envSystemd))
	}
	sb.WriteString("```\n\n")
	sb.WriteString("## .env (vollstaendig)\n\n")
	sb.WriteString("```dotenv\n")
	if content, err := ioutil.ReadFile(envDot); err == nil {
		sb.WriteString(string(content))
	} else {
		sb.WriteString("# .env fehlt\n")
	}
	sb.WriteString("```\n\n")
	sb.WriteString("## gateway.systemd.env (vollstaendig)\n\n")
	sb.WriteString("```dotenv\n")
	if content, err := ioutil.ReadFile(envSystemd); err == nil {
		sb.WriteString(string(content))
	} else {
		sb.WriteString("# gateway.systemd.env fehlt\n")
	}
	sb.WriteString("```\n")
	return sb.String()
}

func getExecutablePath() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	return exe
}
