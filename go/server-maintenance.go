// abstraction-provenance: {"artifact_sha256": "2c48a197d992654e2461f1f2c28956fde1c9ea181f83283cefd549e3b38aa00b", "source_sha256": "38390e5c16266050829f3193f79ca05d8ec898095dc834f407431d87ecfadeb8", "target_language": "go"}
// server-maintenance.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway1:scripts/server-maintenance.sh
// auch in: OpenClaw@gateway2:scripts/server-maintenance.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Server Maintenance Script
// RAM: 8GB, Uhr: Europe/Berlin

const LOG_FILE = "/var/log/server-maintenance.log"
const RAM_TOTAL = 8192 // 8GB in MB

func main() {
	// Farben für Terminal
	red := "\033[0;31m"
	green := "\033[0;32m"
	yellow := "\033[1;33m"
	nc := "\033[0m"

	date := time.Now().Format("2006-01-02 15:04:05")
	host, _ := os.Hostname()

	logFile, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatal(err)
	}
	defer logFile.Close()

	writer := bufio.NewWriter(logFile)
	defer writer.Flush()

	output := func(msg string) {
		fmt.Println(msg)
		writer.WriteString(msg + "\n")
	}

	output(fmt.Sprintf("[%s] === Server Maintenance Check ===", date))

	// 1. APT Update Check
	output(fmt.Sprintf("[%s] Checking for updates...", date))
	cmd := exec.Command("apt", "update", "-qq")
	cmd.Stderr = os.Stderr
	out, _ := cmd.Output()
	lines := strings.Split(string(out), "\n")
	for i := len(lines) - 6; i < len(lines)-1; i++ {
		if i >= 0 && lines[i] != "" {
			output(lines[i])
		}
	}

	cmd = exec.Command("apt", "list", "--upgradable")
	out, _ = cmd.Output()
	upgrades := strings.Count(string(out), "\n") - 1 // Subtract header line
	if upgrades > 0 {
		output(fmt.Sprintf("[%s] ⚠️ %d packages can be upgraded", date, upgrades))
	}

	// 2. RAM Check (8GB total)
	output(fmt.Sprintf("[%s] Checking RAM usage...", date))
	cmd = exec.Command("free", "-m")
	out, _ = cmd.Output()
	scanner := bufio.NewScanner(strings.NewReader(string(out)))
	var ramUsed int
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "Mem:") {
			fields := strings.Fields(line)
			ramUsed, _ = strconv.Atoi(fields[2])
			break
		}
	}
	ramPercent := (ramUsed * 100) / RAM_TOTAL
	output(fmt.Sprintf("[%s] RAM: %dMB / %dMB (%d%%)", date, ramUsed, RAM_TOTAL, ramPercent))
	if ramPercent > 90 {
		output(fmt.Sprintf("[%s] 🔴 WARNING: RAM usage > 90%%!", date))
	} else if ramPercent > 80 {
		output(fmt.Sprintf("[%s] 🟡 WARNING: RAM usage > 80%%", date))
	}

	// 3. Disk Space Check
	output(fmt.Sprintf("[%s] Checking disk space...", date))
	cmd = exec.Command("df", "-h", "/")
	out, _ = cmd.Output()
	scanner = bufio.NewScanner(strings.NewReader(string(out)))
	scanner.Scan() // Skip header
	scanner.Scan()
	line := scanner.Text()
	fields := strings.Fields(line)
	diskUsed := fields[2]
	diskTotal := fields[1]
	diskPercentStr := fields[4]
	output(fmt.Sprintf("Disk: %s / %s (%s used)", diskUsed, diskTotal, diskPercentStr))

	re := regexp.MustCompile(`(\d+)%`)
	matches := re.FindStringSubmatch(diskPercentStr)
	if len(matches) > 1 {
		diskPercent, _ := strconv.Atoi(matches[1])
		if diskPercent > 90 {
			output(fmt.Sprintf("[%s] 🔴 WARNING: Disk > 90%%!", date))
		} else if diskPercent > 80 {
			output(fmt.Sprintf("[%s] 🟡 WARNING: Disk > 80%%", date))
		}
	}

	// 4. NTP Check
	output(fmt.Sprintf("[%s] Checking NTP sync...", date))
	cmd = exec.Command("timedatectl", "status")
	out, _ = cmd.Output()
	if strings.Contains(string(out), "NTP synchronized: yes") {
		output(fmt.Sprintf("[%s] ✅ NTP synchronized", date))
	} else {
		output(fmt.Sprintf("[%s] ⚠️ NTP not synchronized", date))
	}

	// 5. OpenClaw Gateway Status
	output(fmt.Sprintf("[%s] Checking OpenClaw Gateway...", date))
	cmd = exec.Command("systemctl", "is-active", "--quiet", "openclaw-gateway")
	err = cmd.Run()
	if err == nil {
		output(fmt.Sprintf("[%s] ✅ OpenClaw Gateway running", date))
	} else {
		output(fmt.Sprintf("[%s] 🔴 OpenClaw Gateway NOT running!", date))
		cmd = exec.Command("systemctl", "restart", "openclaw-gateway")
		cmd.Run()
	}

	// 6. Load Average
	cmd = exec.Command("uptime")
	out, _ = cmd.Output()
	loadFields := strings.Fields(string(out))
	loadAvg := loadFields[len(loadFields)-3]
	loadAvg = strings.TrimSuffix(loadAvg, ",")

	output(fmt.Sprintf("[%s] Load Average: %s", date, loadAvg))
	output(fmt.Sprintf("[%s] === Maintenance Complete ===", date))
	output("")
}
