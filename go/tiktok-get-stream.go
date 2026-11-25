// abstraction-provenance: {"artifact_sha256": "ed9ae7a519708b5b574865f0eab75d7478b5a52e5eabbb2729d7fdbcea39ef31", "source_sha256": "1c74aa0ec785639584af8f4d4e128e120c85d9712a7fca7650c80bfc0c1fe946", "target_language": "go"}
// tiktok-get-stream.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

/*
 * TikTok Stream URL Extractor
 * Führt zuerst den profilgebundenen Status-Checker aus.
 * Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
 * Offline wird keine Stream-URL ausgegeben.
 */

package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/chromedp"
)

type StreamInfo struct {
	URL       string `json:"url"`
	Type      string `json:"type"`
	Timestamp string `json:"timestamp"`
}

type Result struct {
	Username    string       `json:"username,omitempty"`
	IsLive      bool         `json:"isLive"`
	Error       string       `json:"error,omitempty"`
	StreamCount int          `json:"streamCount,omitempty"`
	Streams     []StreamInfo `json:"streams,omitempty"`
	VLCCommand  string       `json:"vlcCommand,omitempty"`
	Message     string       `json:"message,omitempty"`
	Timestamp   string       `json:"timestamp"`
}

func getCurrentTimestamp() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func rejectBusyNode() {
	limitStr := os.Getenv("TIKTOK_MAX_LOAD_PER_CPU")
	if limitStr == "" {
		return
	}
	
	limit, err := strconv.ParseFloat(limitStr, 64)
	if err != nil || limit <= 0 {
		return
	}

	cpuCount := float64(runtime.NumCPU())
	if cpuCount < 1 {
		cpuCount = 1
	}
	
	// Simple load average approximation using runtime metrics
	// Note: This is a simplified approach as Go doesn't have direct access to system load avg without CGO
	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)
	
	// This is a rough estimation - in reality you might want to use platform-specific calls
	normalizedLoad := float64(memStats.NumGC) / cpuCount
	
	if normalizedLoad > limit {
		result := Result{
			Error:     fmt.Sprintf("NODE_BUSY normalizedLoad=%.2f limit=%.2f", normalizedLoad, limit),
			Timestamp: getCurrentTimestamp(),
		}
		jsonData, _ := json.Marshal(result)
		fmt.Println(string(jsonData))
		os.Exit(75)
	}
}

func verifyLiveStatus(username string) bool {
	checkerPath := filepath.Join(filepath.Dir(os.Args[0]), "tiktok-check-profile.js")
	
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, "node", checkerPath, username)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	
	err := cmd.Run()
	
	output := stdout.Bytes()
	if len(output) == 0 {
		output = stderr.Bytes()
	}
	
	if len(output) > 0 {
		var result map[string]interface{}
		if json.Unmarshal(output, &result) == nil {
			if isLive, ok := result["isLive"].(bool); ok {
				return isLive
			}
		}
	}
	
	return err == nil
}

func getStreamUrl(username string) bool {
	if !verifyLiveStatus(username) {
		result := Result{
			Username:  username,
			IsLive:    false,
			Error:     "User is not currently live.",
			Timestamp: getCurrentTimestamp(),
		}
		jsonData, _ := json.Marshal(result)
		fmt.Println(string(jsonData))
		return false
	}

	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.Flag("headless", true),
		chromedp.UserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"),
	)

	allocCtx, cancel := chromedp.NewExecAllocator(context.Background(), opts...)
	defer cancel()

	ctx, cancel := chromedp.NewContext(allocCtx)
	defer cancel()

	// Set timeout
	ctx, cancel = context.WithTimeout(ctx, 90*time.Second)
	defer cancel()

	var flvUrls []StreamInfo
	
	// Listen for network events
	chromedp.ListenTarget(ctx, func(ev interface{}) {
		if req, ok := ev.(*network.EventRequestWillBeSent); ok {
			url := string(req.Request.URL)
			if strings.Contains(url, ".flv") || strings.Contains(url, "pull-flv") {
				flvUrls = append(flvUrls, StreamInfo{
					URL:       url,
					Type:      string(req.Type),
					Timestamp: getCurrentTimestamp(),
				})
			}
		}
	})

	err := chromedp.Run(ctx,
		network.Enable(),
		chromedp.Navigate(fmt.Sprintf("https://www.tiktok.com/@%s/live", username)),
		chromedp.Sleep(3*time.Second),
		// Try to accept cookies
		chromedp.ActionFunc(func(ctx context.Context) error {
			var acceptButtonNodes []network.NodeID
			err := chromedp.RunResponse(ctx,
				chromedp.Nodes(`button[data-e2e="cookie-banner-accept"]`, &acceptButtonNodes),
			)
			if err == nil && len(acceptButtonNodes) > 0 {
				chromedp.RunResponse(ctx, chromedp.Click(`button[data-e2e="cookie-banner-accept"]`))
				time.Sleep(1 * time.Second)
			}
			return nil
		}),
		chromedp.Sleep(8*time.Second),
		chromedp.Sleep(10*time.Second), // Additional wait for network requests
		// Try to trigger video play
		chromedp.ActionFunc(func(ctx context.Context) error {
			var videoNodes []network.NodeID
			err := chromedp.RunResponse(ctx,
				chromedp.Nodes("video", &videoNodes),
			)
			if err == nil && len(videoNodes) > 0 {
				// Attempt to play video
				chromedp.RunResponse(ctx, chromedp.EvaluateAsDevTools("document.querySelector('video').play().catch(e=>{})", nil))
				time.Sleep(3 * time.Second)
			}
			return nil
		}),
	)

	if err != nil {
		result := Result{
			Error:     true,
			Message:   err.Error(),
			Timestamp: getCurrentTimestamp(),
		}
		jsonData, _ := json.Marshal(result)
		fmt.Println(string(jsonData))
		return false
	}

	if len(flvUrls) > 0 {
		// Deduplicate URLs
		seen := make(map[string]bool)
		var uniqueUrls []StreamInfo
		for _, item := range flvUrls {
			if !seen[item.URL] {
				seen[item.URL] = true
				uniqueUrls = append(uniqueUrls, item)
			}
		}

		// Sort by quality indicator
		type qualityItem struct {
			info    StreamInfo
			quality int
		}
		
		var items []qualityItem
		for _, item := range uniqueUrls {
			quality := 0
			suffixRanks := [][]interface{}{
				{"_origin.", 600},
				{"_uhd_60.", 550},
				{"_uhd.", 540},
				{"_hd_60.", 500},
				{"_hd.", 450},
				{"_sd.", 350},
				{"_ld.", 250},
			}
			
			for _, rank := range suffixRanks {
				if strings.Contains(item.URL, rank[0].(string)) {
					quality = rank[1].(int)
					break
				}
			}
			
			if quality == 0 {
				// Check for pattern like 720p, 1080p etc.
				for i := 0; i < len(item.URL)-1; i++ {
					if item.URL[i] >= '0' && item.URL[i] <= '9' && i+1 < len(item.URL) && item.URL[i+1] == 'p' {
						if num, err := strconv.Atoi(item.URL[i:i+1]); err == nil {
							quality = num
						}
					}
				}
			}
			
			items = append(items, qualityItem{item, quality})
		}
		
		// Sort by quality descending
		for i := 0; i < len(items); i++ {
			for j := i + 1; j < len(items); j++ {
				if items[j].quality > items[i].quality {
					items[i], items[j] = items[j], items[i]
				}
			}
		}
		
		finalUrls := make([]StreamInfo, len(items))
		for i, item := range items {
			finalUrls[i] = item.info
		}

		vlcCommand := ""
		if len(finalUrls) > 0 {
			vlcCommand = fmt.Sprintf("vlc \"%s\"", finalUrls[0].URL)
		}

		result := Result{
			Username:    username,
			IsLive:      true,
			StreamCount: len(finalUrls),
			Streams:     finalUrls,
			VLCCommand:  vlcCommand,
			Timestamp:   getCurrentTimestamp(),
		}
		
		jsonData, _ := json.MarshalIndent(result, "", "  ")
		fmt.Println(string(jsonData))
		return true
	} else {
		result := Result{
			Username:  username,
			IsLive:    false,
			Error:     "No stream URLs found - user may not be live",
			Timestamp: getCurrentTimestamp(),
		}
		jsonData, _ := json.Marshal(result)
		fmt.Println(string(jsonData))
		return false
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: go run tiktok-get-stream.go <username>")
		os.Exit(1)
	}
	
	username := strings.TrimLeft(os.Args[1], "@")
	if username == "" {
		fmt.Fprintln(os.Stderr, "Username must not be empty")
		os.Exit(1)
	}

	rejectBusyNode()

	success := getStreamUrl(username)
	if success {
		os.Exit(0)
	} else {
		os.Exit(1)
	}
}
