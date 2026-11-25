// abstraction-provenance: {"artifact_sha256": "c3551a78caa6cdf8eebe3728a625092324542691311153d64d5e2f72a0ff6908", "source_sha256": "936c6e8c471f328a11317781bf628366871738b72e1e4ece900691507231dd15", "target_language": "go"}
// tiktok-get-stream.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/chromedp/chromedp"
	"github.com/chromedp/chromedp/runner"
)

// StreamResponse represents a captured stream URL with metadata
type StreamResponse struct {
	URL       string `json:"url"`
	Status    int    `json:"status"`
	Timestamp string `json:"timestamp"`
	Quality   string `json:"quality,omitempty"`
}

// Result represents the final output structure
type Result struct {
	Success     bool             `json:"success"`
	Status      string           `json:"status"`
	Method      string           `json:"method"`
	Username    string           `json:"username"`
	IsLive      bool             `json:"isLive"`
	StreamCount int              `json:"streamCount,omitempty"`
	Streams     []StreamResponse `json:"streams,omitempty"`
	URL         string           `json:"url,omitempty"`
	Error       string           `json:"error,omitempty"`
	Message     string           `json:"message,omitempty"`
	Timestamp   string           `json:"timestamp"`
}

// Config holds configuration values
type Config struct {
	MaxCollectedUrls int
	UserAgent        string
}

var config = Config{
	MaxCollectedUrls: 100,
	UserAgent:        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
}

func main() {
	var jsonOutput bool
	flag.BoolVar(&jsonOutput, "json", false, "Output as JSON")
	flag.Parse()

	if len(flag.Args()) < 1 {
		fmt.Fprintln(os.Stderr, "Usage: go run tiktok-get-stream.go <username>")
		os.Exit(64)
	}

	username := normalizeUsername(flag.Arg(0))
	if username == "" {
		fmt.Fprintln(os.Stderr, "Invalid username")
		os.Exit(64)
	}

	enforceLoadLimit("playwright_network_basic")

	if forcedOffline("playwright_network_basic", username) {
		os.Exit(1)
	}

	code := getStreamUrl(username, jsonOutput)
	os.Exit(code)
}

func normalizeUsername(input string) string {
	if input == "" {
		return ""
	}
	
	// Remove @ symbol if present
	username := strings.TrimPrefix(input, "@")
	
	// Validate username format (alphanumeric, underscore, period)
	valid := regexp.MustCompile(`^[a-zA-Z0-9_.]+$`)
	if !valid.MatchString(username) {
		return ""
	}
	
	return username
}

func enforceLoadLimit(method string) {
	// In Go implementation, we'll just check if chrome is available
	if _, err := runner.LookChrome(); err != nil {
		result := Result{
			Error:   true,
			Status:  "dependency_missing",
			Method:  method,
			Message: fmt.Sprintf("Chrome/Chromium unavailable: %v", err),
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}
		json.NewEncoder(os.Stderr).Encode(result)
		os.Exit(2)
	}
}

func forcedOffline(method, username string) bool {
	// Check environment variable for offline mode
	if os.Getenv("FORCED_OFFLINE") != "" {
		return true
	}
	return false
}

func isSuccessfulStreamResponse(statusCode int, url string) bool {
	return statusCode >= 200 && statusCode < 300 && strings.HasSuffix(url, ".flv")
}

func qualityKeyFromUrl(url string) string {
	// Extract quality information from URL (e.g., 720p, 1080p)
	re := regexp.MustCompile(`(\d+)p`)
	matches := re.FindStringSubmatch(url)
	if len(matches) > 1 {
		return matches[1] + "p"
	}
	return "unknown"
}

func getStreamUrl(username string, jsonOutput bool) int {
	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Create chrome instance
	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.UserAgent(config.UserAgent),
		chromedp.WindowSize(1920, 1080),
	)

	allocCtx, cancelAlloc := context.WithCancel(ctx)
	defer cancelAlloc()

	execAllocator, err := chromedp.NewExecAllocator(allocCtx, opts...)
	if err != nil {
		errorResult := Result{
			Error:     true,
			Status:    "technical_error",
			Method:    "playwright",
			Message:   err.Error(),
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}
		json.NewEncoder(os.Stderr).Encode(errorResult)
		return 2
	}

	// Create context
	chromeCtx, cancelChrome := context.WithCancel(execAllocator)
	defer cancelChrome()

	// Create tab context
	tabCtx, cancelTab := context.WithCancel(chromeCtx)
	defer cancelTab()

	// Collect FLV URLs
	var flvUrls []StreamResponse
	var mu sync.Mutex // For thread-safe access to flvUrls

	// Listen for network events
	chromedp.ListenTarget(tabCtx, func(ev interface{}) {
		if response, ok := ev.(*network.EventResponseReceived); ok {
			url := response.Response.URL
			status := int(response.Response.Status)
			
			mu.Lock()
			defer mu.Unlock()
			
			if len(flvUrls) < config.MaxCollectedUrls && isSuccessfulStreamResponse(status, url) {
				flvUrls = append(flvUrls, StreamResponse{
					URL:       url,
					Status:    status,
					Timestamp: time.Now().UTC().Format(time.RFC3339),
				})
			}
		}
	})

	// Navigate to live page
	err = chromedp.Run(tabCtx,
		chromedp.Navigate(fmt.Sprintf("https://www.tiktok.com/@%s/live", username)),
		chromedp.WaitVisible("body", chromedp.ByQuery),
	)
	
	if err != nil {
		errorResult := Result{
			Error:     true,
			Status:    "technical_error",
			Method:    "playwright",
			Message:   err.Error(),
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}
		json.NewEncoder(os.Stderr).Encode(errorResult)
		return 2
	}

	// Wait for potential consent dialogs
	time.Sleep(3 * time.Second)

	// Accept cookies if present
	_ = chromedp.Run(tabCtx,
		chromedp.Click("button[data-e2e='cookie-banner-accept']", chromedp.ByQuery),
	)

	// Wait for stream to load
	time.Sleep(8 * time.Second)

	// Try to trigger video play
	_ = chromedp.Run(tabCtx,
		chromedp.EvaluateAsDevTools(`document.querySelector('video')?.play()?.catch(() => {})`, nil),
	)

	// Wait a bit more for playback
	time.Sleep(3 * time.Second)

	// Process collected URLs
	mu.Lock()
	defer mu.Unlock()

	if len(flvUrls) > 0 {
		// Deduplicate URLs
		uniqueMap := make(map[string]StreamResponse)
		for _, item := range flvUrls {
			uniqueMap[item.URL] = item
		}

		// Convert map back to slice
		uniqueUrls := make([]StreamResponse, 0, len(uniqueMap))
		for _, item := range uniqueMap {
			item.Quality = qualityKeyFromUrl(item.URL)
			uniqueUrls = append(uniqueUrls, item)
		}

		// Sort by quality indicator
		sort.Slice(uniqueUrls, func(i, j int) bool {
			getQuality := func(url string) int {
				re := regexp.MustCompile(`(\d+)p`)
				matches := re.FindStringSubmatch(url)
				if len(matches) > 1 {
					if val, err := strconv.Atoi(matches[1]); err == nil {
						return val
					}
				}
				return 0
			}
			return getQuality(uniqueUrls[j].URL) < getQuality(uniqueUrls[i].URL)
		})

		// Limit to first 10 streams
		streamsToShow := uniqueUrls
		if len(streamsToShow) > 10 {
			streamsToShow = streamsToShow[:10]
		}

		result := Result{
			Success:     true,
			Status:      "live",
			Method:      "playwright",
			Username:    username,
			IsLive:      true,
			StreamCount: len(uniqueUrls),
			Streams:     streamsToShow,
			URL:         uniqueUrls[0].URL,
			Timestamp:   time.Now().UTC().Format(time.RFC3339),
		}

		if jsonOutput {
			encoder := json.NewEncoder(os.Stdout)
			encoder.SetIndent("", "  ")
			encoder.Encode(result)
		} else {
			fmt.Println(result.URL)
		}
		return 0
	} else {
		result := Result{
			Success:   false,
			Status:    "offline",
			Method:    "playwright",
			Username:  username,
			IsLive:    false,
			Error:     "No stream URLs found - user may not be live",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}
		json.NewEncoder(os.Stderr).Encode(result)
		return 1
	}
}
