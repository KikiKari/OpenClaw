// abstraction-provenance: {"artifact_sha256": "d1fec8126f9a2b158285fedad989c1a83a6cb2ec1f5040f43eeed05b73a81297", "source_sha256": "26a823a8fe0d3b94a8c9958ec8cf150765ddf3654a8806c9cc62eae06d9632db", "target_language": "go"}
// tiktok-check-profile.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/chromedp/chromedp"
	"github.com/chromedp/cdproto/runtime"
)

// LiveIndicators holds the detected live indicators
type LiveIndicators struct {
	LiveIcon     bool `json:"liveIcon"`
	LiveBadge    bool `json:"liveBadge"`
	LiveBorder   bool `json:"liveBorder"`
	LiveLink     bool `json:"liveLink"`
	LiveIndicator bool `json:"liveIndicator"`
}

// Result represents the final result structure
type Result struct {
	Username    string          `json:"username"`
	IsLive      bool            `json:"isLive"`
	Timestamp   string          `json:"timestamp"`
	Indicators  LiveIndicators  `json:"indicators"`
}

// ErrorResult represents error output structure
type ErrorResult struct {
	Error     bool   `json:"error"`
	Status    string `json:"status"`
	Method    string `json:"method,omitempty"`
	Message   string `json:"message,omitempty"`
	Timestamp string `json:"timestamp"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: go run tiktok-check-profile.go <username>")
		os.Exit(64)
	}

	username := normalizeUsername(os.Args[1])
	if username == "" {
		errorResult := ErrorResult{
			Error:     true,
			Status:    "invalid_input",
			Message:   "Invalid username format",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}
		jsonData, _ := json.Marshal(errorResult)
		fmt.Fprintln(os.Stderr, string(jsonData))
		os.Exit(64)
	}

	enforceLoadLimit("playwright_basic")

	isLive, err := checkLiveStatus(username)
	if err != nil {
		errorResult := ErrorResult{
			Error:     true,
			Status:    "technical_error",
			Message:   err.Error(),
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}
		jsonData, _ := json.Marshal(errorResult)
		fmt.Fprintln(os.Stderr, string(jsonData))
		os.Exit(2)
	}

	if isLive == nil {
		os.Exit(2)
	}

	exitCode := 1
	if *isLive {
		exitCode = 0
	}
	os.Exit(exitCode)
}

func normalizeUsername(input string) string {
	if input == "" {
		return ""
	}
	
	// Remove @ prefix if present
	re := regexp.MustCompile(`^@`)
	username := re.ReplaceAllString(input, "")
	
	// Validate username format (alphanumeric, underscore, period, hyphen)
	validRe := regexp.MustCompile(`^[a-zA-Z0-9_.\-]+$`)
	if !validRe.MatchString(username) {
		return ""
	}
	
	return username
}

func enforceLoadLimit(method string) {
	// In Go implementation, we'll just check if chrome/chromium is available
	cmd := exec.Command("which", "google-chrome", "chromium-browser", "chromium")
	if err := cmd.Run(); err != nil {
		errorResult := ErrorResult{
			Error:     true,
			Status:    "dependency_missing",
			Method:    method,
			Message:   "Chrome/Chromium browser not found in PATH",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}
		jsonData, _ := json.Marshal(errorResult)
		fmt.Fprintln(os.Stderr, string(jsonData))
		os.Exit(2)
	}
}

func checkLiveStatus(username string) (*bool, error) {
	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Create chrome instance
	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.Flag("headless", true),
		chromedp.UserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"),
		chromedp.WindowSize(1920, 1080),
	)
	
	allocCtx, allocCancel := chromedp.NewExecAllocator(ctx, opts...)
	defer allocCancel()
	
	taskCtx, taskCancel := chromedp.NewContext(allocCtx)
	defer taskCancel()

	var (
		hasLiveLink       bool
		liveIconVisible   bool
		liveBadgeVisible  bool
		hasLiveBorder     bool
		liveIndicatorVisible bool
	)

	err := chromedp.Run(taskCtx,
		// Navigate to profile
		chromedp.Navigate(fmt.Sprintf("https://www.tiktok.com/@%s", username)),
		chromedp.WaitVisible("body", chromedp.ByQuery),
		
		// Wait for initial page build
		chromedp.Sleep(2*time.Second),
		
		// Close GDPR banner - try multiple variants
		chromedp.ActionFunc(func(ctx context.Context) error {
			// Try various cookie accept buttons
			selectors := []string{
				`button:has-text("Verstanden"), [data-e2e="cookie-banner-accept"], button:has-text("Accept")`,
				`button:has-text("Akzeptieren")`,
				`button:has-text("Alle akzeptieren")`,
				`button:has-text("Allow all")`,
				`button:has-text("Accept all")`,
				`button.TUXButton:has-text("Accept")`,
				`[data-testid="cookie-policy-banner-accept"]`,
			}
			
			for _, selector := range selectors {
				var nodes []*runtime.RemoteObject
				err := chromedp.Evaluate(fmt.Sprintf(`
					document.querySelectorAll('%s').forEach(el => el.click());
					true;
				`, selector), &nodes).Do(ctx)
				if err == nil {
					chromedp.Sleep(500 * time.Millisecond).Do(ctx)
					break
				}
			}
			return nil
		}),
		
		// Wait for complete loading
		chromedp.Sleep(3*time.Second),
		
		// Additional wait for API calls
		chromedp.ActionFunc(func(ctx context.Context) error {
			// Try to wait for network idle
			chromedp.Sleep(2 * time.Second).Do(ctx)
			return nil
		}),
		
		// Take screenshot if DEBUG=1
		chromedp.ActionFunc(func(ctx context.Context) error {
			if os.Getenv("DEBUG") == "1" {
				var buf []byte
				if err := chromedp.CaptureScreenshot(&buf).Do(ctx); err == nil {
					os.WriteFile(fmt.Sprintf("/tmp/tiktok-%s.png", username), buf, 0644)
				}
			}
			return nil
		}),
		
		// Check live link
		chromedp.Evaluate(`
			(function() {
				const selectors = [
					'a[href*="/@' + '`+username+`' + '/live"]',
					'[data-e2e="live-video"] a[href*="/@' + '`+username+`' + '"]',
					'a[href="/@' + '`+username+`' + '/live"]'
				];
				
				for (const selector of selectors) {
					const elements = document.querySelectorAll(selector);
					for (const el of elements) {
						if (el.offsetParent !== null) {
							return true;
						}
					}
				}
				return false;
			})()
		`, &hasLiveLink),
		
		// Check live icon
		chromedp.ActionFunc(func(ctx context.Context) error {
			if hasLiveLink {
				var visible bool
				err := chromedp.Evaluate(`
					(function() {
						const selectors = [
							'a[href*="/@' + '`+username+`' + '/live"]',
							'[data-e2e="live-video"] a[href*="/@' + '`+username+`' + '"]',
							'a[href="/@' + '`+username+`' + '/live"]'
						];
						
						for (const selector of selectors) {
							const elements = document.querySelectorAll(selector);
							for (const el of elements) {
								if (el.offsetParent === null) continue;
								
								const liveIcons = el.querySelectorAll(
									'[data-e2e="live-icon"], [class*="LiveBadge"], [class*="live-indicator"]'
								);
								for (const icon of liveIcons) {
									if (icon.offsetParent !== null) {
										return true;
									}
								}
							}
						}
						return false;
					})()
				`, &visible).Do(ctx)
				liveIconVisible = visible
			}
			return nil
		}),
		
		// Check live badge
		chromedp.ActionFunc(func(ctx context.Context) error {
			if hasLiveLink {
				var visible bool
				err := chromedp.Evaluate(`
					(function() {
						const selectors = [
							'a[href*="/@' + '`+username+`' + '/live"]',
							'[data-e2e="live-video"] a[href*="/@' + '`+username+`' + '"]',
							'a[href="/@' + '`+username+`' + '/live"]'
						];
						
						for (const selector of selectors) {
							const elements = document.querySelectorAll(selector);
							for (const el of elements) {
								if (el.offsetParent === null) continue;
								
								const badges = el.querySelectorAll('*');
								for (const badge of badges) {
									if ((badge.textContent || '').trim().match(/^LIVE$/i)) {
										return true;
									}
								}
							}
						}
						return false;
					})()
				`, &visible).Do(ctx)
				liveBadgeVisible = visible
			}
			return nil
		}),
		
		// Check live border around profile image
		chromedp.ActionFunc(func(ctx context.Context) error {
			selectors := []string{
				`[data-e2e="user-page"] img[data-e2e="avatar"]`,
				`[data-e2e="user-page"] div[data-e2e="profile-avatar"] img`,
				`main header img[data-e2e="avatar"]`,
				`main header [class*="avatar"] img`,
			}
			
			for _, selector := range selectors {
				var styles map[string]string
				err := chromedp.Evaluate(fmt.Sprintf(`
					(function() {
						const el = document.querySelector('%s');
						if (!el) return {};
						
						const computed = window.getComputedStyle(el);
						const parent = el.parentElement;
						const parentComputed = parent ? window.getComputedStyle(parent) : null;
						
						return {
							borderColor: computed.borderColor,
							borderStyle: computed.borderStyle,
							borderWidth: computed.borderWidth,
							outlineColor: computed.outlineColor,
							boxShadow: computed.boxShadow,
							parentBorderColor: parentComputed ? parentComputed.borderColor : null,
							parentBorderStyle: parentComputed ? parentComputed.borderStyle : null,
							parentBorderWidth: parentComputed ? parentComputed.borderWidth : null
						};
					})()
				`, selector), &styles).Do(ctx)
				
				if err == nil && styles != nil {
					redIndicators := []string{
						styles["borderColor"],
						styles["outlineColor"],
						styles["parentBorderColor"],
					}
					
					for _, color := range redIndicators {
						if strings.Contains(color, "255") || 
						   strings.Contains(color, "red") || 
						   strings.Contains(color, "rgb(254") || 
						   strings.Contains(color, "fe2c55") || 
						   strings.Contains(color, "#fe2c") {
							hasLiveBorder = true
							break
						}
					}
					
					if strings.Contains(styles["boxShadow"], "255") || 
					   strings.Contains(styles["boxShadow"], "254") {
						hasLiveBorder = true
					}
					
					if hasLiveBorder {
						break
					}
				}
			}
			return nil
		}),
		
		// Check live indicator
		chromedp.ActionFunc(func(ctx context.Context) error {
			if hasLiveLink {
				var visible bool
				err := chromedp.Evaluate(`
					(function() {
						const selectors = [
							'a[href*="/@' + '`+username+`' + '/live"]',
							'[data-e2e="live-video"] a[href*="/@' + '`+username+`' + '"]',
							'a[href="/@' + '`+username+`' + '/live"]'
						];
						
						for (const selector of selectors) {
							const elements = document.querySelectorAll(selector);
							for (const el of elements) {
								if (el.offsetParent === null) continue;
								
								const indicators = el.querySelectorAll(
									'[class*="live-indicator"], div[class*="LiveBadge"]'
								);
								for (const indicator of indicators) {
									if (indicator.offsetParent !== null) {
										return true;
									}
								}
							}
						}
						return false;
					})()
				`, &visible).Do(ctx)
				liveIndicatorVisible = visible
			}
			return nil
		}),
	)

	if err != nil {
		return nil, err
	}

	isLive := hasLiveLink || hasLiveBorder || liveIconVisible || liveIndicatorVisible || liveBadgeVisible
	
	result := Result{
		Username:  username,
		IsLive:    isLive,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Indicators: LiveIndicators{
			LiveIcon:     liveIconVisible,
			LiveBadge:    liveBadgeVisible,
			LiveBorder:   hasLiveBorder,
			LiveLink:     hasLiveLink,
			LiveIndicator: liveIndicatorVisible,
		},
	}
	
	jsonData, _ := json.MarshalIndent(result, "", "  ")
	fmt.Println(string(jsonData))
	
	return &isLive, nil
}
