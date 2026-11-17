// abstraction-provenance: {"artifact_sha256": "e7c627faba9f9a8f242e414ac99f76aee9dcbb16d067a16a00b03d5bfbe2f1e3", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "go"}
// openclaw-audit.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	scriptDir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		scriptDir = "."
	}
	
	dateStamp := time.Now().Format("2006-01-02")
	outFile := fmt.Sprintf("%s/openclaw-audit-%s.log", scriptDir, dateStamp)
	
	oc := []string{"openclaw", "--no-color"}
	
	// Write header
	header := fmt.Sprintf("================================================================\n"+
		"OpenClaw audit run\n"+
		"Started:  %s\n"+
		"Host:     %s\n"+
		"User:     %s\n"+
		"Version:  %s\n"+
		"Output:   %s\n"+
		"================================================================\n",
		time.Now().Format("2006-01-02T15:04:05-07:00"),
		getHostname(),
		getCurrentUser(),
		getOpenClawVersion(),
		outFile)
	
	writeToFile(outFile, header, false)
	
	// Run all commands
	runCmd(outFile, "tasks audit --severity error", append(oc, "tasks", "audit", "--severity", "error")...)
	runCmd(outFile, "secrets audit", append(oc, "secrets", "audit")...)
	runCmd(outFile, "security audit", append(oc, "security", "audit")...)
	runCmd(outFile, "plugins doctor", append(oc, "plugins", "doctor")...)
	runCmd(outFile, "plugins deps", append(oc, "plugins", "deps")...)
	runCmd(outFile, "plugins registry", append(oc, "plugins", "registry")...)
	runCmd(outFile, "skills check", append(oc, "skills", "check")...)
	runCmd(outFile, "hooks check", append(oc, "hooks", "check")...)
	runCmd(outFile, "gateway status --deep", append(oc, "gateway", "status", "--deep")...)
	runCmd(outFile, "channels status --probe", append(oc, "channels", "status", "--probe")...)
	runCmd(outFile, "memory status --deep", append(oc, "memory", "status", "--deep")...)
	runCmd(outFile, "sessions --all-agents", append(oc, "sessions", "--all-agents")...)
	runCmd(outFile, "tasks list", append(oc, "tasks", "list")...)
	runCmd(outFile, "cron list", append(oc, "cron", "list")...)
	
	// Write footer
	footer := fmt.Sprintf("\n================================================================\n"+
		"Audit complete: %s\n"+
		"================================================================\n",
		time.Now().Format("2006-01-02T15:04:05-07:00"))
	
	writeToFile(outFile, footer, true)
	
	fmt.Printf("Audit complete. Output: %s\n", outFile)
}

func runCmd(outFile, title string, cmd ...string) {
	header := fmt.Sprintf("\n----------------------------------------------------------------\n"+
		"### %s\n"+
		"### $ %s\n"+
		"### %s\n"+
		"----------------------------------------------------------------\n",
		title,
		strings.Join(cmd, " "),
		time.Now().Format("2006-01-02T15:04:05-07:00"))
	
	writeToFile(outFile, header, true)
	
	command := exec.Command(cmd[0], cmd[1:]...)
	output, err := command.CombinedOutput()
	
	result := string(output)
	if err != nil {
		result += fmt.Sprintf("[exit: %d]\n", command.ProcessState.ExitCode())
	} else {
		result += "[exit: 0]\n"
	}
	
	writeToFile(outFile, result, true)
}

func writeToFile(filename, content string, appendMode bool) {
	var file *os.File
	var err error
	
	if appendMode {
		file, err = os.OpenFile(filename, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	} else {
		file, err = os.Create(filename)
	}
	
	if err != nil {
		panic(err)
	}
	defer file.Close()
	
	_, err = file.WriteString(content)
	if err != nil {
		panic(err)
	}
}

func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return hostname
}

func getCurrentUser() string {
	user := os.Getenv("USER")
	if user == "" {
		user = os.Getenv("USERNAME")
	}
	if user == "" {
		return "unknown"
	}
	return user
}

func getOpenClawVersion() string {
	cmd := exec.Command("openclaw", "--version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "unknown"
	}
	return strings.TrimSpace(string(output))
}
