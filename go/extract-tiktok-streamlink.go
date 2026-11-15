// abstraction-provenance: {"artifact_sha256": "32d9009c2e0fa08ab43450cf4b5d9b88413a6d6d49aa52ff2b5ee5e0e85301a9", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "go"}
// extract-tiktok-streamlink.sh — portiert nach go
// Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

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

const (
	ExitSuccess           = 0
	ExitInvalidArgument   = 64
	ExitDependencyMissing = 2
	ExitFailure           = 1
	ExitOverloaded        = 75
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

func emitJSON(fields ...string) string {
	keys := []string{"success", "method", "username", "url", "quality", "author", "title", "error", "timestamp", "status"}
	payload := make(map[string]interface{})
	
	for i, key := range keys {
		if i < len(fields) && fields[i] != "" {
			if key == "success" {
				payload[key] = strings.ToLower(fields[i]) == "true"
			} else {
				payload[key] = fields[i]
			}
		}
	}
	
	jsonData, _ := json.Marshal(payload)
	return string(jsonData)
}

func getLoadPerCPU() (float64, error) {
	// Get load average (similar to getloadavg)
	cmd := exec.Command("uptime")
	output, err := cmd.Output()
	if err != nil {
		return 0, err
	}
	
	outStr := string(output)
	// Parse load average from uptime output
	fields := strings.Fields(outStr)
	var loadAvg float64
	
	// Find load average in output (format varies by system)
	for i, field := range fields {
		if strings.Contains(field, "load") && i+1 < len(fields) {
			loadStr := strings.TrimRight(fields[i+1], ",")
			loadAvg, err = strconv.ParseFloat(loadStr, 64)
			if err != nil {
				return 0, err
			}
			break
		}
		if strings.Contains(field, "average:") && i+1 < len(fields) {
			loadStr := strings.TrimRight(fields[i+1], ",")
			loadAvg, err = strconv.ParseFloat(loadStr, 64)
			if err != nil {
				return 0, err
			}
			break
		}
	}
	
	// Divide by CPU count
	numCPU := float64(runtime.NumCPU())
	if numCPU == 0 {
		numCPU = 1
	}
	
	return loadAvg / numCPU, nil
}

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func streamlink(args ...string) (string, int, error) {
	cmd := exec.Command("streamlink", args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = io.Discard
	err := cmd.Run()
	
	exitCode := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode = exitError.ExitCode()
		} else {
			exitCode = 1
		}
	}
	
	return out.String(), exitCode, err
}

func parseStreamlinkJSON(jsonStr string) (map[string]string, error) {
	var data map[string]interface{}
	if err := json.Unmarshal([]byte(jsonStr), &data); err != nil {
		return nil, err
	}
	
	result := make(map[string]string)
	
	// Extract URL
	if url, ok := data["url"].(string); ok {
		result["url"] = url
	}
	
	// Extract streams
	if streams, ok := data["streams"].(map[string]interface{}); ok {
		if result["url"] == "" {
			// Try to find URL in streams
			priorityKeys := []string{"best", "worst"}
			for key := range streams {
				if key != "best" && key != "worst" {
					priorityKeys = append(priorityKeys, key)
				}
			}
			
			for _, key := range priorityKeys {
				if stream, ok := streams[key].(map[string]interface{}); ok {
					if url, ok := stream["url"].(string); ok && url != "" {
						result["url"] = url
						break
					}
				}
			}
		}
	}
	
	// Extract metadata
	if metadata, ok := data["metadata"].(map[string]interface{}); ok {
		if author, ok := metadata["author"].(string); ok {
			result["author"] = author
		}
		if title, ok := metadata["title"].(string); ok {
			result["title"] = title
		}
	}
	
	return result, nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: program <username> [quality] [--json]")
		os.Exit(ExitInvalidArgument)
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
		os.Exit(ExitInvalidArgument)
	}
	
	// Validate quality
	validQualities := map[string]bool{
		"best": true, "worst": true, "original": true,
		"1080p60": true, "720p60": true, "720p": true,
		"540p": true, "360p": true, "auto": true,
	}
	if !validQualities[quality] {
		fmt.Fprintln(os.Stderr, "Invalid stream quality")
		os.Exit(ExitInvalidArgument)
	}
	
	// Check system load
	maxLoadStr := os.Getenv("TIKTOK_MAX_LOAD_PER_CPU")
	if maxLoadStr == "" {
		maxLoadStr = "1.5"
	}
	maxLoad, _ := strconv.ParseFloat(maxLoadStr, 64)
	
	loadPerCPU, err := getLoadPerCPU()
	if err == nil && loadPerCPU > maxLoad {
		payload := emitJSON("false", "streamlink", username, "", quality, "", "", 
			"host overloaded", timestamp, "overloaded")
		fmt.Fprintln(os.Stderr, payload)
		os.Exit(ExitOverloaded)
	}
	
	// Check if streamlink exists
	if !commandExists("streamlink") {
		payload := emitJSON("false", "streamlink", username, "", quality, "", "", 
			"streamlink not installed", timestamp, "dependency_missing")
		fmt.Fprintln(os.Stderr, payload)
		os.Exit(ExitDependencyMissing)
	}
	
	liveURL := fmt.Sprintf("https://www.tiktok.com/@%s/live", username)
	
	// Set selector based on quality
	var selector string
	switch quality {
	case "original":
		selector = "origin,uhd_60,hd_60,hd,sd,ld,best,worst"
	case "auto":
		selector = "best,origin,uhd_60,hd_60,hd,sd,ld,worst"
	case "1080p60":
		selector = "uhd_60,hd_60,hd,sd,ld,worst"
	case "720p60":
		selector = "hd_60,hd,sd,ld,worst"
	case "720p":
		selector = "hd,sd,ld,worst"
	case "540p":
		selector = "sd,ld,worst"
	case "360p":
		selector = "ld,worst"
	default:
		selector = quality
	}
	
	// Try streamlink with --json first
	output, exitCode, _ := streamlink("--json", liveURL, selector)
	if exitCode != 0 || output == "" {
		// Fallback to --stream-url
		url, _, _ := streamlink("--stream-url", liveURL, selector)
		url = strings.TrimSpace(url)
		
		if url == "" {
			payload := emitJSON("false", "streamlink", username, "", quality, "", "", 
				"streamlink failed or no stream found", timestamp, "offline")
			fmt.Fprintln(os.Stderr, payload)
			os.Exit(ExitFailure)
		}
		
		if jsonFlag == "--json" {
			payload := emitJSON("true", "streamlink", username, url, quality, "", "", 
				"", timestamp, "live")
			fmt.Println(payload)
		} else {
			fmt.Println(url)
		}
		os.Exit(ExitSuccess)
	}
	
	// Parse JSON output
	parsedData, err := parseStreamlinkJSON(output)
	if err != nil {
		payload := emitJSON("false", "streamlink", username, "", quality, "", "", 
			"invalid streamlink JSON", timestamp, "technical_error")
		fmt.Fprintln(os.Stderr, payload)
		os.Exit(ExitDependencyMissing)
	}
	
	url := parsedData["url"]
	author := parsedData["author"]
	title := parsedData["title"]
	
	if url == "" {
		payload := emitJSON("false", "streamlink", username, "", quality, author, title, 
			"could not extract stream URL", timestamp, "offline")
		fmt.Fprintln(os.Stderr, payload)
		os.Exit(ExitFailure)
	}
	
	if jsonFlag == "--json" {
		payload := emitJSON("true", "streamlink", username, url, quality, author, title, 
			"", timestamp, "live")
		fmt.Println(payload)
	} else {
		fmt.Println(url)
	}
	
	os.Exit(ExitSuccess)
}
