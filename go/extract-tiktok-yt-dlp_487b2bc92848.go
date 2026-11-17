// abstraction-provenance: {"artifact_sha256": "f6c0913d3136c3e821db4c41978887bd5eca1ace9f62e5c1052b8fa4f6eb28c7", "source_sha256": "b00f64d55d344bbcc351ae7ade12137f0d9293b556aa0881ede43bef5bcb778b", "target_language": "go"}
// extract-tiktok-yt-dlp.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
)

func emitJSON(success bool, method string, username string, url string, format string, errorStr string, timestamp string, status string) {
	payload := make(map[string]interface{})
	
	if success || !success { // always include success
		payload["success"] = success
	}
	if method != "" {
		payload["method"] = method
	}
	if username != "" {
		payload["username"] = username
	}
	if url != "" {
		payload["url"] = url
	}
	if format != "" {
		payload["format"] = format
	}
	if errorStr != "" {
		payload["error"] = errorStr
	}
	if timestamp != "" {
		payload["timestamp"] = timestamp
	}
	if status != "" {
		payload["status"] = status
	}
	
	jsonBytes, _ := json.Marshal(payload)
	fmt.Println(string(jsonBytes))
}

func getLoadPerCPU() (float64, error) {
	// Get system load average (1 minute)
	loadAvg, err := getLoadAverage()
	if err != nil {
		return 0, err
	}
	
	// Get CPU count
	cpuCount := float64(runtime.NumCPU())
	if cpuCount == 0 {
		cpuCount = 1
	}
	
	return loadAvg / cpuCount, nil
}

func getLoadAverage() (float64, error) {
	// This is a simplified implementation that returns the 1-minute load average
	// In a real implementation, you might want to read from /proc/loadavg on Linux
	// or use platform-specific APIs
	
	content, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		// Fallback: return 0 if we can't read load average
		return 0, nil
	}
	
	fields := strings.Fields(string(content))
	if len(fields) < 1 {
		return 0, fmt.Errorf("invalid loadavg format")
	}
	
	load, err := strconv.ParseFloat(fields[0], 64)
	if err != nil {
		return 0, err
	}
	
	return load, nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: program <username> [format] [--json]")
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
	
	// Validate username
	usernameRegex := regexp.MustCompile(`^[A-Za-z0-9._]{1,24}$`)
	if !usernameRegex.MatchString(username) {
		fmt.Fprintln(os.Stderr, "Invalid TikTok username")
		os.Exit(64)
	}
	
	// Validate format
	validFormats := map[string]bool{
		"hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld": true,
		"hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld":                                 true,
		"hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld":                                            true,
		"hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld":                                              true,
		"hls-sd/hls-ld/flv-sd/flv-ld":                                                            true,
		"hls-ld/flv-ld":                                                                          true,
		"hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld":                      true,
	}
	
	if !validFormats[format] {
		fmt.Fprintln(os.Stderr, "Invalid yt-dlp format")
		os.Exit(64)
	}
	
	// Check system load
	loadPerCPU, err := getLoadPerCPU()
	if err != nil {
		loadPerCPU = 0
	}
	
	maxLoadStr := os.Getenv("TIKTOK_MAX_LOAD_PER_CPU")
	if maxLoadStr == "" {
		maxLoadStr = "1.5"
	}
	maxLoad, _ := strconv.ParseFloat(maxLoadStr, 64)
	
	if loadPerCPU > maxLoad {
		emitJSON(false, "yt-dlp", username, "", format, "host overloaded", timestamp, "overloaded")
		os.Exit(75)
	}
	
	// Check if yt-dlp is installed
	_, err = exec.LookPath("yt-dlp")
	if err != nil {
		emitJSON(false, "yt-dlp", username, "", format, "yt-dlp not installed", timestamp, "dependency_missing")
		os.Exit(2)
	}
	
	// Create temporary directory
	tmpDir, err := os.MkdirTemp("", "tiktok-yt-dlp-*")
	if err != nil {
		emitJSON(false, "yt-dlp", username, "", format, "failed to create temp dir", timestamp, "technical_error")
		os.Exit(2)
	}
	defer os.RemoveAll(tmpDir)
	
	stdoutFile := tmpDir + "/stdout.json"
	stderrFile := tmpDir + "/stderr.log"
	
	// Run yt-dlp command
	liveURL := fmt.Sprintf("https://www.tiktok.com/@%s/live", username)
	cmd := exec.Command("yt-dlp", "--no-warnings", "--dump-single-json", "--skip-download", "--format", format, liveURL)
	
	stdout, err := os.Create(stdoutFile)
	if err != nil {
		emitJSON(false, "yt-dlp", username, "", format, "failed to create stdout file", timestamp, "technical_error")
		os.Exit(2)
	}
	defer stdout.Close()
	
	stderr, err := os.Create(stderrFile)
	if err != nil {
		emitJSON(false, "yt-dlp", username, "", format, "failed to create stderr file", timestamp, "technical_error")
		os.Exit(2)
	}
	defer stderr.Close()
	
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	
	err = cmd.Run()
	exitCode := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode = exitError.Sys().(syscall.WaitStatus).ExitStatus()
		} else {
			exitCode = 1
		}
	}
	
	if exitCode != 0 {
		// Read stderr content
		stderrContent, _ := os.ReadFile(stderrFile)
		errorMsg := string(stderrContent)
		if len(errorMsg) > 1000 {
			errorMsg = errorMsg[:1000]
		}
		
		status := "technical_error"
		code := 2
		
		lowerErrorMsg := strings.ToLower(errorMsg)
		if strings.Contains(lowerErrorMsg, "not currently live") ||
		   strings.Contains(lowerErrorMsg, "no live cdn found") ||
		   strings.Contains(lowerErrorMsg, "not available") ||
		   strings.Contains(lowerErrorMsg, "private video") {
			status = "offline"
			code = 1
		}
		
		emitJSON(false, "yt-dlp", username, "", format, errorMsg, timestamp, status)
		os.Exit(code)
	}
	
	// Parse JSON output to extract URL
	stdoutContent, err := os.ReadFile(stdoutFile)
	if err != nil {
		emitJSON(false, "yt-dlp", username, "", format, "failed to read stdout", timestamp, "technical_error")
		os.Exit(2)
	}
	
	var data map[string]interface{}
	err = json.Unmarshal(stdoutContent, &data)
	if err != nil {
		emitJSON(false, "yt-dlp", username, "", format, "failed to parse JSON", timestamp, "technical_error")
		os.Exit(2)
	}
	
	url := ""
	
	// Check direct URL field
	if urlString, ok := data["url"].(string); ok && urlString != "" {
		url = urlString
	}
	
	// Check formats array
	if url == "" {
		if formats, ok := data["formats"].([]interface{}); ok {
			for _, formatItem := range formats {
				if formatMap, ok := formatItem.(map[string]interface{}); ok {
					if urlString, ok := formatMap["url"].(string); ok && urlString != "" {
						lowerURL := strings.ToLower(urlString)
						if strings.HasPrefix(urlString, "https://") &&
						   (strings.Contains(lowerURL, ".m3u8") || strings.Contains(lowerURL, ".flv")) &&
						   !strings.Contains(urlString, "only_audio=1") {
							url = urlString
							break
						}
					}
				}
			}
		}
	}
	
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
