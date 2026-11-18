// abstraction-provenance: {"artifact_sha256": "d2959789a7fc2be100183c7ddd2895ee1cd3f27b85d3680099bce7c5a6aef2cd", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "go"}
// collect_ist_gateway_b.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
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

	istFile := filepath.Join(outDir, "IST-ZUSTAND_GATEWAY-B_NODE7.md")
	invFile := filepath.Join(outDir, "ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md")
	cfgFile := filepath.Join(outDir, "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md")
	envFile := filepath.Join(outDir, "ENV-STATUS_GATEWAY-B_NODE7.md")
	runFile := filepath.Join(outDir, fmt.Sprintf("RUN-%s.md", ts))

	openclawJson := filepath.Join(baseDir, "openclaw.json")
	envDot := filepath.Join(baseDir, ".env")
	envSystemd := filepath.Join(baseDir, "gateway.systemd.env")
	vscodeDir := filepath.Join(baseDir, ".vscode")

	hostnameFQDN := execCommand("hostname", "-f")
	if hostnameFQDN == "" {
		hostnameFQDN = execCommand("hostname")
	}
	hostnameShort := execCommand("hostname")
	arch := execCommand("uname", "-m")
	kernel := execCommand("uname", "-r")
	osPretty := getOSPrettyName()
	ipv4All := execCommand("hostname", "-I")
	publicIP := execCommand("curl", "-4", "-s", "--max-time", "4", "ifconfig.me")
	tailscaleIP := execCommand("tailscale", "ip", "-4")
	openclawVer := execCommand("openclaw", "--version")
	nodeVer := execCommand("node", "-v")

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

	writeISTFile(istFile, nowLocal, nowUTC, hostnameShort, hostnameFQDN, arch, kernel, osPretty, ipv4All, publicIP, tailscaleIP, openclawVer, nodeVer, baseDir, vscodeDir, outDir, openclawJson, envDot, envSystemd)
	writeINVFile(invFile, nowLocal, baseDir, vscodeDir)
	writeCFGFile(cfgFile, nowLocal, openclawJson)
	writeENVFile(envFile, nowLocal, envDot, envSystemd)
	writeRUNFile(runFile, nowLocal, nowUTC, istFile, invFile, cfgFile, envFile)

	fmt.Println("OK: IST-Zustand erfasst.")
	fmt.Printf("Ausgabeordner: %s\n", outDir)
	fmt.Println("Dateien:")
	files, _ := ioutil.ReadDir(outDir)
	for _, file := range files {
		fmt.Printf("- %s\n", file.Name())
	}
}

func execCommand(name string, arg ...string) string {
	cmd := exec.Command(name, arg...)
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func getOSPrettyName() string {
	file, err := os.Open("/etc/os-release")
	if err != nil {
		return ""
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "PRETTY_NAME=") {
			return strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), "\"")
		}
	}
	return ""
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func writeISTFile(filename, nowLocal, nowUTC, hostnameShort, hostnameFQDN, arch, kernel, osPretty, ipv4All, publicIP, tailscaleIP, openclawVer, nodeVer, baseDir, vscodeDir, outDir, openclawJson, envDot, envSystemd string) {
	file, err := os.Create(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Erstellen der IST-Datei: %v\n", err)
		return
	}
	defer file.Close()

	openclawJsonExists := "fehlt"
	if fileExists(openclawJson) {
		openclawJsonExists = "vorhanden"
	}

	envDotExists := "fehlt"
	if fileExists(envDot) {
		envDotExists = "vorhanden"
	}

	envSystemdExists := "fehlt"
	if fileExists(envSystemd) {
		envSystemdExists = "vorhanden"
	}

	installsJsonExists := "fehlt"
	if fileExists(filepath.Join(baseDir, "plugins", "installs.json")) {
		installsJsonExists = "vorhanden"
	}

	pluginSkillsExists := "fehlt"
	if dirExists(filepath.Join(baseDir, "plugin-skills")) {
		pluginSkillsExists = "vorhanden"
	}

	fmt.Fprintf(file, `# IST-Zustand: Gateway B / Node 7

Stand (lokal): %s  
Stand (UTC): %s

## 1) Identität & System

- Gateway: **B**
- Node: **7**
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
- `+"`%s/plugins/installs.json`"+`: %s
- `+"`%s/plugin-skills`"+`: %s

## 4) Hinweis

Diese Datei wird bei jedem Lauf neu geschrieben.
Zusätzlich wird ein Laufprotokoll als `+"`RUN-*.md`"+` erzeugt.
`, nowLocal, nowUTC, hostnameShort, hostnameFQDN, arch, kernel, osPretty, ipv4All, publicIP, tailscaleIP, openclawVer, nodeVer, baseDir, vscodeDir, outDir, openclawJson, openclawJsonExists, envDot, envDotExists, envSystemd, envSystemdExists, baseDir, installsJsonExists, baseDir, pluginSkillsExists)
}

func writeINVFile(filename, nowLocal, baseDir, vscodeDir string) {
	file, err := os.Create(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Erstellen der INV-Datei: %v\n", err)
		return
	}
	defer file.Close()

	fmt.Fprintf(file, "# Artefakt-Inventar: Gateway B / Node 7\n\n")
	fmt.Fprintf(file, "Stand: %s\n\n", nowLocal)
	fmt.Fprintf(file, "## Top-Level in ~/.openclaw\n\n")
	fmt.Fprintf(file, "```text\n")
	files, _ := ioutil.ReadDir(baseDir)
	for _, fileInfo := range files {
		fmt.Fprintf(file, "%s\n", fileInfo.Name())
	}
	fmt.Fprintf(file, "```\n\n")
	fmt.Fprintf(file, "## ~/.openclaw/.vscode\n\n")
	fmt.Fprintf(file, "```text\n")
	if dirExists(vscodeDir) {
		files, _ := ioutil.ReadDir(vscodeDir)
		for _, fileInfo := range files {
			fmt.Fprintf(file, "%s\n", fileInfo.Name())
		}
	} else {
		fmt.Fprintf(file, "(nicht vorhanden)\n")
	}
	fmt.Fprintf(file, "```\n\n")
	fmt.Fprintf(file, "## plugin-skills/\n\n")
	fmt.Fprintf(file, "```text\n")
	pluginSkillsDir := filepath.Join(baseDir, "plugin-skills")
	if dirExists(pluginSkillsDir) {
		files, _ := ioutil.ReadDir(pluginSkillsDir)
		for _, fileInfo := range files {
			fmt.Fprintf(file, "%s\n", fileInfo.Name())
		}
	} else {
		fmt.Fprintf(file, "(nicht vorhanden)\n")
	}
	fmt.Fprintf(file, "```\n\n")
	fmt.Fprintf(file, "## openclaw.json Backups\n\n")
	fmt.Fprintf(file, "```text\n")
	backups, _ := filepath.Glob(filepath.Join(baseDir, "openclaw.json.bak*"))
	if len(backups) > 0 {
		for _, backup := range backups {
			fmt.Fprintf(file, "%s\n", filepath.Base(backup))
		}
	} else {
		fmt.Fprintf(file, "(keine gefunden)\n")
	}
	fmt.Fprintf(file, "```\n")
}

func writeCFGFile(filename, nowLocal, openclawJson string) {
	file, err := os.Create(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Erstellen der CFG-Datei: %v\n", err)
		return
	}
	defer file.Close()

	fmt.Fprintf(file, "# OpenClaw Config Snapshot: Gateway B / Node 7\n\n")
	fmt.Fprintf(file, "Stand: %s\n\n", nowLocal)
	fmt.Fprintf(file, "## Schlüsselpositionen (grep)\n\n")
	fmt.Fprintf(file, "```text\n")
	if fileExists(openclawJson) {
		content, err := ioutil.ReadFile(openclawJson)
		if err == nil {
			lines := strings.Split(string(content), "\n")
			for i, line := range lines {
				if strings.Contains(line, "\"gateway\"") || strings.Contains(line, "\"session\"") ||
					strings.Contains(line, "\"dmScope\"") || strings.Contains(line, "\"auth\"") ||
					strings.Contains(line, "\"secrets\"") || strings.Contains(line, "\"tools\"") ||
					strings.Contains(line, "\"plugins\"") || strings.Contains(line, "\"profile\"") ||
					strings.Contains(line, "\"alsoAllow\"") || strings.Contains(line, "\"denyCommands\"") {
					fmt.Fprintf(file, "%d:%s\n", i+1, line)
				}
			}
		}
	} else {
		fmt.Fprintf(file, "openclaw.json fehlt\n")
	}
	fmt.Fprintf(file, "```\n\n")
	fmt.Fprintf(file, "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)\n\n")
	fmt.Fprintf(file, "```json\n")
	if fileExists(openclawJson) {
		content, err := ioutil.ReadFile(openclawJson)
		if err == nil {
			lines := strings.Split(string(content), "\n")
			start := 579
			end := 779
			if len(lines) < end {
				end = len(lines)
			}
			if start < len(lines) {
				for i := start; i < end; i++ {
					fmt.Fprintf(file, "%s\n", lines[i])
				}
			}
		}
	} else {
		fmt.Fprintf(file, "{ \"error\": \"openclaw.json fehlt\" }\n")
	}
	fmt.Fprintf(file, "```\n")
}

func writeENVFile(filename, nowLocal, envDot, envSystemd string) {
	file, err := os.Create(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Erstellen der ENV-Datei: %v\n", err)
		return
	}
	defer file.Close()

	fmt.Fprintf(file, "# ENV-Status: Gateway B / Node 7\n\n")
	fmt.Fprintf(file, "Stand: %s\n\n", nowLocal)
	fmt.Fprintf(file, "## Dateien\n\n")
	fmt.Fprintf(file, "```text\n")
	if fileExists(envDot) {
		info, _ := os.Stat(envDot)
		fmt.Fprintf(file, "%s\n", info.Name())
	}
	if fileExists(envSystemd) {
		info, _ := os.Stat(envSystemd)
		fmt.Fprintf(file, "%s\n", info.Name())
	}
	fmt.Fprintf(file, "```\n\n")
	fmt.Fprintf(file, "## .env (vollständig, ungefiltert)\n\n")
	fmt.Fprintf(file, "```dotenv\n")
	if fileExists(envDot) {
		content, _ := ioutil.ReadFile(envDot)
		fmt.Fprintf(file, "%s", string(content))
	} else {
		fmt.Fprintf(file, "# .env fehlt\n")
	}
	fmt.Fprintf(file, "```\n\n")
	fmt.Fprintf(file, "## gateway.systemd.env (vollständig, ungefiltert)\n\n")
	fmt.Fprintf(file, "```dotenv\n")
	if fileExists(envSystemd) {
		content, _ := ioutil.ReadFile(envSystemd)
		fmt.Fprintf(file, "%s", string(content))
	} else {
		fmt.Fprintf(file, "# gateway.systemd.env fehlt\n")
	}
	fmt.Fprintf(file, "```\n")
}

func writeRUNFile(filename, nowLocal, nowUTC, istFile, invFile, cfgFile, envFile string) {
	file, err := os.Create(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fehler beim Erstellen der RUN-Datei: %v\n", err)
		return
	}
	defer file.Close()

	fmt.Fprintf(file, "# Laufprotokoll Gateway B / Node 7\n\n")
	fmt.Fprintf(file, "- Zeit (lokal): %s\n", nowLocal)
	fmt.Fprintf(file, "- Zeit (UTC): %s\n", nowUTC)
	fmt.Fprintf(file, "- Script: collect_ist_gateway_b.go\n\n")
	fmt.Fprintf(file, "## Erzeugte Dateien\n\n")
	fmt.Fprintf(file, "- %s\n", filepath.Base(istFile))
	fmt.Fprintf(file, "- %s\n", filepath.Base(invFile))
	fmt.Fprintf(file, "- %s\n", filepath.Base(cfgFile))
	fmt.Fprintf(file, "- %s\n", filepath.Base(envFile))
}
