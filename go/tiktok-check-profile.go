// abstraction-provenance: {"artifact_sha256": "8867136c522cb53c66999c23dc25eec7d7c95b6ca126aa76880b1dfa0d1cedfd", "source_sha256": "e90219318254f9b20057962724b153b7476a0511846415f2cc0a38bd9baa14f5", "target_language": "go"}
// tiktok-check-profile.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

/*
 * TikTok Live Status Checker
 * Prüft ausschließlich profilgebundene Live-Indikatoren.
 * Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
 * Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
 * via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).
 */

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/chromedp/cdproto/runtime"
	"github.com/chromedp/chromedp"
)

type Result struct {
	Username    string            `json:"username"`
	IsLive      bool              `json:"isLive"`
	Timestamp   string            `json:"timestamp"`
	Indicators  map[string]bool   `json:"indicators"`
}

type ErrorResult struct {
	Error     bool   `json:"error"`
	Message   string `json:"message"`
	Stack     string `json:"stack,omitempty"`
	Timestamp string `json:"timestamp"`
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: tiktok-check-profile.go <username>")
	}
	
	rawUsername := os.Args[1]
	re := regexp.MustCompile(`^@+`)
	username := re.ReplaceAllString(rawUsername, "")
	
	if username == "" {
		log.Fatal("Username must not be empty")
	}
	
	rejectBusyNode()
	
	isLive, err := checkLiveStatus(username)
	if err != nil {
		errorResult := ErrorResult{
			Error:     true,
			Message:   err.Error(),
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}
		jsonData, _ := json.MarshalIndent(errorResult, "", "  ")
		fmt.Fprintln(os.Stderr, string(jsonData))
		os.Exit(1)
	}
	
	if isLive {
		os.Exit(0)
	} else {
		os.Exit(1)
	}
}

func getLoadAvg() (float64, error) {
	// Linux/Unix way
	data, err := os.ReadFile("/proc/loadavg")
	if err == nil {
		parts := strings.Fields(string(data))
		if len(parts) > 0 {
			load, err := strconv.ParseFloat(parts[0], 64)
			return load, err
		}
	}
	
	// Fallback: try uptime command
	cmd := exec.Command("uptime")
	output, err := cmd.Output()
	if err != nil {
		return 0, err
	}
	
	// Parse output like " 14:32:15 up 2 days,  1:23,  1 user,  load average: 0.12, 0.15, 0.11"
	re := regexp.MustCompile(`load average:\s*([0-9.]+)`)
	matches := re.FindStringSubmatch(string(output))
	if len(matches) > 1 {
		return strconv.ParseFloat(matches[1], 64)
	}
	
	return 0, fmt.Errorf("could not determine load average")
}

func getCpuCount() int {
	cmd := exec.Command("nproc")
	output, err := cmd.Output()
	if err != nil {
		// Fallback to runtime.NumCPU()
		return runtime.NumCPU()
	}
	
	count, err := strconv.Atoi(strings.TrimSpace(string(output)))
	if err != nil {
		return runtime.NumCPU()
	}
	
	return count
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
	
	cpuCount := math.Max(1, float64(getCpuCount()))
	loadAvg, err := getLoadAvg()
	if err != nil {
		return
	}
	
	normalizedLoad := loadAvg / cpuCount
	if normalizedLoad > limit {
		fmt.Fprintf(os.Stderr, "NODE_BUSY normalizedLoad=%.2f limit=%.2f\n", normalizedLoad, limit)
		os.Exit(75)
	}
}

func checkLiveStatus(username string) (bool, error) {
	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	
	// Create chrome instance
	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.UserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"),
		chromedp.WindowSize(1920, 1080),
	)
	
	allocCtx, allocCancel := chromedp.NewExecAllocator(ctx, opts...)
	defer allocCancel()
	
	taskCtx, taskCancel := chromedp.NewContext(allocCtx)
	defer taskCancel()
	
	// Variables to store results
	var (
		liveIconVisible      bool
		liveBadgeVisible    bool
		hasLiveBorder        bool
		hasLiveLink          bool
		liveIndicatorVisible bool
		pageHTML             string
	)
	
	err := chromedp.Run(taskCtx,
		// Navigate to profile
		chromedp.Navigate(fmt.Sprintf("https://www.tiktok.com/@%s", username)),
		chromedp.WaitVisible("body", chromedp.ByQuery),
		
		// Wait for initial page build
		chromedp.Sleep(2*time.Second),
		
		// Close GDPR banner - try multiple variants
		chromedp.ActionFunc(func(ctx context.Context) error {
			// Try "Verstanden" button (german)
			selectors := []string{
				`button:has-text("Verstanden")`,
				`[data-e2e="cookie-banner-accept"]`,
				`button:has-text("Accept")`,
				`button:has-text("Akzeptieren")`,
				`button:has-text("Alle akzeptieren")`,
				`button:has-text("Allow all")`,
				`button:has-text("Accept all")`,
				`button.TUXButton:has-text("Accept")`,
				`[data-testid="cookie-policy-banner-accept"]`,
			}
			
			for _, selector := range selectors {
				err := chromedp.Click(selector, chromedp.ByQuery).Do(ctx)
				if err == nil {
					chromedp.Sleep(1*time.Second).Do(ctx)
					break
				}
			}
			return nil
		}),
		
		// Wait for complete loading
		chromedp.Sleep(3*time.Second),
		
		// Additional wait for API calls
		chromedp.ActionFunc(func(ctx context.Context) error {
			// Wait for network idle (best effort)
			chromedp.Sleep(2*time.Second).Do(ctx)
			return nil
		}),
		
		// Additional wait for Live status check by TikTok
		chromedp.Sleep(2*time.Second),
		
		// Take screenshot for debugging if needed
		chromedp.ActionFunc(func(ctx context.Context) error {
			if os.Getenv("DEBUG") == "1" {
				var buf []byte
				if err := chromedp.CaptureScreenshot().Do(ctx, &buf); err == nil {
					os.WriteFile(fmt.Sprintf("/tmp/tiktok-%s.png", username), buf, 0644)
				}
			}
			return nil
		}),
		
		// Get page HTML for analysis
		chromedp.OuterHTML("html", &pageHTML),
		
		// Check for LIVE indicators
		
		// Method 1: data-e2e="live-icon"
		chromedp.Evaluate(`
			(() => {
				const profileScope = document.querySelector('[data-e2e="creator-page-header"], [data-e2e="profile-avatar"]');
				if (!profileScope) return false;
				const liveIcon = profileScope.querySelector('[data-e2e="live-icon"]');
				return liveIcon ? liveIcon.offsetParent !== null : false;
			})()
		`, &liveIconVisible),
		
		// Method 2: LIVE text/badge
		chromedp.Evaluate(`
			(() => {
				const profileScope = document.querySelector('[data-e2e="creator-page-header"], [data-e2e="profile-avatar"]');
				if (!profileScope) return false;
				const liveElements = profileScope.querySelectorAll('*');
				for (let el of liveElements) {
					if (el.textContent && /^LIVE$/i.test(el.textContent.trim())) {
						return el.offsetParent !== null;
					}
				}
				return false;
			})()
		`, &liveBadgeVisible),
		
		// Method 3: Red border around profile image
		chromedp.Evaluate(`
			(() => {
				const selectors = [
					'img[data-e2e="avatar"]',
					'div[data-e2e="profile-avatar"] img',
					'[data-e2e="creator-page-header"] img[alt*="profile"]'
				];
				
				for (let selector of selectors) {
					const img = document.querySelector(selector);
					if (img) {
						const computed = window.getComputedStyle(img);
						const parent = img.parentElement;
						const parentComputed = parent ? window.getComputedStyle(parent) : null;
						
						const styles = {
							borderColor: computed.borderColor,
							outlineColor: computed.outlineColor,
							parentBorderColor: parentComputed ? parentComputed.borderColor : null,
							boxShadow: computed.boxShadow
						};
						
						const redIndicators = [
							styles.borderColor,
							styles.outlineColor,
							styles.parentBorderColor
						];
						
						for (let color of redIndicators) {
							if (color && (color.includes('255') || color.includes('red') || color.includes('rgb(254') || color.includes('fe2c55') || color.includes('#fe2c'))) {
								return true;
							}
						}
						
						if (styles.boxShadow && (styles.boxShadow.includes('255') || styles.boxShadow.includes('254'))) {
							return true;
						}
					}
				}
				return false;
			})()
		`, &hasLiveBorder),
		
		// Method 4: Check for Live link
		chromedp.Evaluate(fmt.Sprintf(`
			(() => {
				const liveLink = document.querySelector('a[href*="/@%s/live"]');
				return liveLink !== null;
			})()
		`, username), &hasLiveLink),
		
		// Method 5: Check for pulsing red dot (Live indicator)
		chromedp.Evaluate(`
			(() => {
				const profileScope = document.querySelector('[data-e2e="creator-page-header"], [data-e2e="profile-avatar"]');
				if (!profileScope) return false;
				const liveIndicator = profileScope.querySelector('[class*="live-indicator"], div[class*="LiveBadge"]');
				return liveIndicator ? liveIndicator.offsetParent !== null : false;
			})()
		`, &liveIndicatorVisible),
	)
	
	if err != nil {
		return false, err
	}
	
	isLive := liveIconVisible || liveBadgeVisible || hasLiveBorder || hasLiveLink || liveIndicatorVisible
	
	result := Result{
		Username:  username,
		IsLive:    isLive,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Indicators: map[string]bool{
			"liveIcon":      liveIconVisible,
			"liveBadge":     liveBadgeVisible,
			"liveBorder":    hasLiveBorder,
			"liveLink":      hasLiveLink,
			"liveIndicator": liveIndicatorVisible,
		},
	}
	
	jsonData, _ := json.MarshalIndent(result, "", "  ")
	fmt.Println(string(jsonData))
	
	return isLive, nil
}
