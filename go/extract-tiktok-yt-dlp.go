// abstraction-provenance: {"artifact_sha256": "74541e718b2b400045090a36a9d6097276d67c956564e2c50186ec7b21149239", "source_sha256": "b00f64d55d344bbcc351ae7ade12137f0d9293b556aa0881ede43bef5bcb778b", "target_language": "go"}
// extract-tiktok-yt-dlp.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Invalid TikTok username")
		os.Exit(64)
	}
	username := strings.TrimPrefix(os.Args[1], "@")
	format := "best"
	if len(os.Args) > 2 {
		format = os.Args[2]
	}
	jsonFlag := ""
	if len(os.Args) > 3 {
		jsonFlag = os.Args[3]
	}
	timestamp := time.Now().UTC().Format("2006-01-02T15:04:05Z")

	tmpDir, err := os.MkdirTemp("/tmp", "tiktok-yt-dlp.*")
	if err != nil {
		emitJSON(false, "yt-dlp", username, "", format, "failed to create temp dir", timestamp, "technical_error")
		os.Exit(2)
	}
	defer os.RemoveAll(tmpDir)

	validUsername := regexp.MustCompile(`^[A-Za-z0-9._]{1,24}$`)
	if !validUsername.MatchString(username) {
		fmt.Fprintln(os.Stderr, "Invalid TikTok username")
		os.Exit(64)
	}

	validFormats := map[string]bool{
		"hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld": true,
		"hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld":                                 true,
		"hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld":                                           true,
		"hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld":                                              true,
		"hls-sd/hls-ld/flv-sd/flv-ld":                                                            true,
		"hls-ld/flv-ld":                                                                          true,
		"hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld":                      true,
	}
	if !validFormats[format] {
		fmt.Fprintln(os.Stderr, "Invalid yt-dlp format")
		os.Exit(64)
	}

	loadPerCPU := getLoadPerCPU()
	maxLoadStr := os.Getenv("TIKTOK_MAX_LOAD_PER_CPU")
	if maxLoadStr == "" {
		maxLoadStr = "1.5"
	}
	maxLoad, _ := strconv.ParseFloat(maxLoadStr, 64)
	if loadPerCPU > maxLoad {
		emitJSON(false, "yt-dlp", username, "", format, "host overloaded", timestamp, "overloaded")
		os.Exit(75)
	}

	if _, err := exec.LookPath("yt-dlp"); err != nil {
		emitJSON(false, "yt-dlp", username, "", format, "yt-dlp not installed", timestamp, "dependency_missing")
		os.Exit(2)
	}

	liveURL := fmt.Sprintf("https://www.tiktok.com/@%s/live", username)
	stdoutFile := filepath.Join(tmpDir, "stdout.json")
	stderrFile := filepath.Join(tmpDir, "stderr.log")

	cmd := exec.Command("yt-dlp", "--no-warnings", "--dump-single-json", "--skip-download", "--format", format, liveURL)
	stdout, _ := os.Create(stdoutFile)
	stderr, _ := os.Create(stderrFile)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	err = cmd.Run()
	stdout.Close()
	stderr.Close()

	exitCode := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode = exitError.Sys().(syscall.WaitStatus).ExitStatus()
		} else {
			exitCode = 1
		}
	}

	if exitCode != 0 {
		status := "technical_error"
		code := 2
		errorBytes, _ := os.ReadFile(stderrFile)
		errorMsg := string(errorBytes)
		if len(errorMsg) > 1000 {
			errorMsg = errorMsg[:1000]
		}
		if strings.Contains(strings.ToLower(errorMsg), "not currently live") ||
			strings.Contains(strings.ToLower(errorMsg), "no live cdn found") ||
			strings.Contains(strings.ToLower(errorMsg), "not available") ||
			strings.Contains(strings.ToLower(errorMsg), "private video") {
			status = "offline"
			code = 1
		}
		emitJSON(false, "yt-dlp", username, "", format, errorMsg, timestamp, status)
		os.Exit(code)
	}

	url := extractURL(stdoutFile)
	if url == "" {
		emitJSON(false, "yt-dlp", username, "", format, "could not extract HTTPS video URL", timestamp, "offline")
		os.Exit(1)
	}

	if jsonFlag == "--json" {
		emitJSON(true, "yt-dlp", username, url, format, "", timestamp, "live")
	} else {
		fmt.Println(url)
	}
}

func emitJSON(success bool, method, username, url, format, error, timestamp, status string) {
	payload := make(map[string]interface{})
	if success {
		payload["success"] = success
	}
	payload["method"] = method
	payload["username"] = username
	if url != "" {
		payload["url"] = url
	}
	payload["format"] = format
	if error != "" {
		payload["error"] = error
	}
	payload["timestamp"] = timestamp
	if status != "" {
		payload["status"] = status
	}
	jsonData, _ := json.Marshal(payload)
	fmt.Fprintln(os.Stderr, string(jsonData))
}

func getLoadPerCPU() float64 {
	content, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return 0
	}
	fields := strings.Fields(string(content))
	if len(fields) < 1 {
		return 0
	}
	load, _ := strconv.ParseFloat(fields[0], 64)
	cpuCount := float64(getCPUCount())
	if cpuCount <= 0 {
		cpuCount = 1
	}
	return load / cpuCount
}

func getCPUCount() int {
	content, err := os.ReadFile("/proc/cpuinfo")
	if err != nil {
		return 1
	}
	scanner := bufio.NewScanner(strings.NewReader(string(content)))
	count := 0
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "processor") {
			count++
		}
	}
	if count == 0 {
		return 1
	}
	return count
}

func extractURL(filePath string) string {
	file, err := os.Open(filePath)
	if err != nil {
		return ""
	}
	defer file.Close()

	var data map[string]interface{}
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&data); err != nil {
		return ""
	}

	var candidates []string
	if url, ok := data["url"].(string); ok {
		candidates = append(candidates, url)
	}
	if formats, ok := data["formats"].([]interface{}); ok {
		for _, item := range formats {
			if formatMap, ok := item.(map[string]interface{}); ok {
				if url, ok := formatMap["url"].(string); ok {
					candidates = append(candidates, url)
				}
			}
		}
	}

	for _, value := range candidates {
		low := strings.ToLower(value)
		if strings.HasPrefix(value, "https://") && (strings.Contains(low, ".m3u8") || strings.Contains(low, ".flv")) && !strings.Contains(low, "only_audio=1") {
			return value
		}
	}
	return ""
}
