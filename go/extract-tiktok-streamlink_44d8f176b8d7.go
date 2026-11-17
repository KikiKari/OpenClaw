// abstraction-provenance: {"artifact_sha256": "d2fb3bab3ecbbb06113f66c043e7bba1818fee1e1f0416e1c7b14e38ed004e2f", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "go"}
// extract-tiktok-streamlink.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
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
	"time"
)

type Payload struct {
	Success   bool   `json:"success,omitempty"`
	Method    string `json:"method,omitempty"`
	Username  string `json:"username,omitempty"`
	URL       string `json:"url,omitempty"`
	Quality   string `json:"quality,omitempty"`
	Author    string `json:"author,omitempty"`
	Title     string `json:"title,omitempty"`
	Error     string `json:"error,omitempty"`
	Timestamp string `json:"timestamp,omitempty"`
	Status    string `json:"status,omitempty"`
}

func emitJSON(success bool, method, username, url, quality, author, title, errorStr, timestamp, status string) {
	payload := Payload{
		Success:   success,
		Method:    method,
		Username:  username,
		URL:       url,
		Quality:   quality,
		Author:    author,
		Title:     title,
		Error:     errorStr,
		Timestamp: timestamp,
		Status:    status,
	}
	
	// Remove empty fields
	payloadMap := make(map[string]interface{})
	if success || errorStr != "" {
		payloadMap["success"] = success
	}
	if method != "" {
		payloadMap["method"] = method
	}
	if username != "" {
		payloadMap["username"] = username
	}
	if url != "" {
		payloadMap["url"] = url
	}
	if quality != "" {
		payloadMap["quality"] = quality
	}
	if author != "" {
		payloadMap["author"] = author
	}
	if title != "" {
		payloadMap["title"] = title
	}
	if errorStr != "" {
		payloadMap["error"] = errorStr
	}
	if timestamp != "" {
		payloadMap["timestamp"] = timestamp
	}
	if status != "" {
		payloadMap["status"] = status
	}
	
	jsonData, _ := json.Marshal(payloadMap)
	fmt.Println(string(jsonData))
}

func getLoadAvg() (float64, error) {
	// Try to get load average from /proc/loadavg on Linux
	if data, err := os.ReadFile("/proc/loadavg"); err == nil {
		fields := strings.Fields(string(data))
		if len(fields) > 0 {
			load, err := strconv.ParseFloat(fields[0], 64)
			return load, err
		}
	}
	
	// Fallback: return 0.0
	return 0.0, nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: program <username> [quality] [json_flag]")
		os.Exit(64)
	}
	
	username := strings.TrimPrefix(os.Args[1], "@")
	quality := "best"
	if len(os.Args) > 2 {
		quality = os.Args[2]
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
	
	// Validate quality
	validQualities := map[string]bool{
		"best": true, "worst": true, "original": true, "1080p60": true,
		"720p60": true, "720p": true, "540p": true, "360p": true, "auto": true,
	}
	if !validQualities[quality] {
		fmt.Fprintln(os.Stderr, "Invalid stream quality")
		os.Exit(64)
	}
	
	// Check system load
	loadAvg, err := getLoadAvg()
	if err != nil {
		loadAvg = 0.0
	}
	cpuCount := float64(runtime.NumCPU())
	if cpuCount == 0 {
		cpuCount = 1
	}
	loadPerCPU := loadAvg / cpuCount
	maxLoadStr := os.Getenv("TIKTOK_MAX_LOAD_PER_CPU")
	if maxLoadStr == "" {
		maxLoadStr = "1.5"
	}
	maxLoad, err := strconv.ParseFloat(maxLoadStr, 64)
	if err != nil {
		maxLoad = 1.5
	}
	
	if loadPerCPU > maxLoad {
		emitJSON(false, "streamlink", username, "", quality, "", "", "host overloaded", timestamp, "overloaded")
		os.Exit(75)
	}
	
	// Check if streamlink exists
	_, err = exec.LookPath("streamlink")
	if err != nil {
		emitJSON(false, "streamlink", username, "", quality, "", "", "streamlink not installed", timestamp, "dependency_missing")
		os.Exit(2)
	}
	
	liveURL := fmt.Sprintf("https://www.tiktok.com/@%s/live", username)
	
	// Quality selector mapping
	selectors := map[string]string{
		"original": "origin,uhd_60,hd_60,hd,sd,ld,best,worst",
		"auto":     "best,origin,uhd_60,hd_60,hd,sd,ld,worst",
		"1080p60":  "uhd_60,hd_60,hd,sd,ld,worst",
		"720p60":   "hd_60,hd,sd,ld,worst",
		"720p":     "hd,sd,ld,worst",
		"540p":     "sd,ld,worst",
		"360p":     "ld,worst",
	}
	selector := selectors[quality]
	if selector == "" {
		selector = quality
	}
	
	// Try streamlink with --json first
	cmd := exec.Command("streamlink", "--json", liveURL, selector)
	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	err = cmd.Run()
	exitCode := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode = exitError.ExitCode()
		} else {
			exitCode = 1
		}
	}
	output := out.String()
	
	if exitCode != 0 || output == "" {
		// Fallback to --stream-url
		cmd = exec.Command("streamlink", "--stream-url", liveURL, selector)
		cmd.Stdout = &out
		cmd.Stderr = &stderr
		err = cmd.Run()
		url := strings.TrimSpace(out.String())
		
		if err != nil || url == "" {
			emitJSON(false, "streamlink", username, "", quality, "", "", "streamlink failed or no stream found", timestamp, "offline")
			os.Exit(1)
		}
		
		if jsonFlag == "--json" {
			emitJSON(true, "streamlink", username, url, quality, "", "", "", timestamp, "live")
		} else {
			fmt.Println(url)
		}
		os.Exit(0)
	}
	
	// Parse JSON output
	var streamData map[string]interface{}
	err = json.Unmarshal([]byte(output), &streamData)
	if err != nil {
		emitJSON(false, "streamlink", username, "", quality, "", "", "invalid streamlink JSON", timestamp, "technical_error")
		os.Exit(2)
	}
	
	url := ""
	if u, ok := streamData["url"].(string); ok {
		url = u
	}
	
	streams, streamsOk := streamData["streams"].(map[string]interface{})
	if url == "" && streamsOk {
		priorityKeys := []string{"best", "worst"}
		for key := range streams {
			priorityKeys = append(priorityKeys, key)
		}
		
		for _, key := range priorityKeys {
			if stream, ok := streams[key].(map[string]interface{}); ok {
				if u, ok := stream["url"].(string); ok && u != "" {
					url = u
					break
				}
			}
		}
	}
	
	author := ""
	title := ""
	if metadata, ok := streamData["metadata"].(map[string]interface{}); ok {
		if a, ok := metadata["author"].(string); ok {
			author = a
		}
		if t, ok := metadata["title"].(string); ok {
			title = t
		}
	}
	
	if url == "" {
		emitJSON(false, "streamlink", username, "", quality, author, title, "could not extract stream URL", timestamp, "offline")
		os.Exit(1)
	}
	
	if jsonFlag == "--json" {
		emitJSON(true, "streamlink", username, url, quality, author, title, "", timestamp, "live")
	} else {
		fmt.Println(url)
	}
}
