// abstraction-provenance: {"artifact_sha256": "c7186c2d10ab7e23a4dfda66f3fba9c75218b9e16149c943ac3b3c6f419041e8", "source_sha256": "eb08e6ac444b7c9611c2c56d0b5b99c5f3d6c627dce5fb23dd375d732ee39a65", "target_language": "go"}
// tiktok-check-profile.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/chromedp"
)

type LiveIndicators struct {
	LiveIcon       bool `json:"liveIcon"`
	LiveBadge      bool `json:"liveBadge"`
	LiveBorder     bool `json:"liveBorder"`
	LiveLink       bool `json:"liveLink"`
	LiveIndicator  bool `json:"liveIndicator"`
}

type Result struct {
	Username             string          `json:"username"`
	Status               string          `json:"status"`
	IsLive               bool            `json:"isLive"`
	DetectionMethod      string          `json:"detectionMethod"`
	IsAgeRestricted      bool            `json:"isAgeRestricted"`
	AgeRestrictionReason *string         `json:"ageRestrictionReason,omitempty"`
	Indicators           LiveIndicators  `json:"indicators"`
	BannerClosed         bool            `json:"bannerClosed"`
	PageFullyLoaded      bool            `json:"pageFullyLoaded"`
	Timestamp            string          `json:"timestamp"`
	Version              string          `json:"version"`
	Error                string          `json:"error,omitempty"`
}

func normalizeUsername(input string) (string, error) {
	if input == "" {
		return "", fmt.Errorf("username cannot be empty")
	}
	
	username := strings.TrimSpace(input)
	username = strings.TrimPrefix(username, "@")
	
	// Entferne unzulässige Zeichen (nur alphanumerisch, Unterstrich, Punkt)
	re := regexp.MustCompile(`[^a-zA-Z0-9_.]`)
	username = re.ReplaceAllString(username, "")
	
	if username == "" {
		return "", fmt.Errorf("invalid username after normalization")
	}
	
	return username, nil
}

func enforceLoadLimit(method string) {
	// In Go könnte dies durch Semaphore oder ähnliches implementiert werden
	// Für dieses Beispiel belassen wir es bei einem leeren Stub
}

func humanDelay(min, max int) time.Duration {
	delay := rand.Intn(max-min+1) + min
	return time.Duration(delay) * time.Millisecond
}

func closeDSGVOBanner(ctx context.Context) (bool, error) {
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
		err := chromedp.Run(ctx,
			chromedp.Click(selector, chromedp.ByQuery),
		)
		if err == nil {
			time.Sleep(humanDelay(1000, 2000))
			return true, nil
		}
	}
	return false, nil
}

func waitForPageReady(ctx context.Context) (bool, error) {
	// Phase 1: Initiales Laden abwarten
	time.Sleep(humanDelay(2000, 3000))
	
	// Phase 2: Warte explizit auf "Erneute Veröffentlichungen" Tab
	pageReady := false
	err := chromedp.Run(ctx,
		chromedp.WaitVisible(`text="Erneute Veröffentlichungen"`, chromedp.ByText, chromedp.WithWaitOptions(chromedp.WaitVisible, chromedp.WaitTimeout(25*time.Second))),
	)
	if err == nil {
		pageReady = true
	} else {
		// Fallback: englische Version probieren
		err = chromedp.Run(ctx,
			chromedp.WaitVisible(`text="Reposts"`, chromedp.ByText, chromedp.WithWaitOptions(chromedp.WaitVisible, chromedp.WaitTimeout(5*time.Second))),
		)
		if err == nil {
			pageReady = true
		} else {
			// Letzter Fallback: einfach auf networkidle warten
			_ = chromedp.Run(ctx,
				chromedp.WaitReady("body", chromedp.WaitTimeout(10*time.Second)),
			)
		}
	}
	
	// Phase 3: Nach dem Erscheinen des Menübands noch kurz warten
	time.Sleep(humanDelay(2000, 3000))
	
	return pageReady, nil
}

func liveHrefSelectors(username string) []string {
	return []string{
		fmt.Sprintf(`a[href="/@%s/live"]`, username),
		fmt.Sprintf(`a[href="https://www.tiktok.com/@%s/live"]`, username),
		fmt.Sprintf(`div[data-e2e="user-live"] a[href="/@%s/live"]`, username),
		fmt.Sprintf(`div[data-e2e="user-live"] a[href="https://www.tiktok.com/@%s/live"]`, username),
	}
}

func detectLiveStatus(ctx context.Context, username string) (map[string]interface{}, error) {
	indicators := LiveIndicators{}
	detectionMethod := "none"
	isLive := false
	
	selectors := liveHrefSelectors(username)
	selectorStr := strings.Join(selectors, ", ")
	
	// Priorität 1: LIVE-Icon innerhalb des exakten Account-LIVE-Links
	err := chromedp.Run(ctx,
		chromedp.WaitVisible(selectorStr, chromedp.ByQuery),
	)
	if err == nil {
		var liveIconVisible bool
		iconSelectors := `[data-e2e="live-icon"], [class*="LiveBadge"], [class*="live-indicator"]`
		err = chromedp.Run(ctx,
			chromedp.Evaluate(fmt.Sprintf(`
				document.querySelector('%s')?.querySelector('%s')?.offsetParent !== null
			`, selectorStr, iconSelectors), &liveIconVisible),
		)
		if err == nil && liveIconVisible {
			indicators.LiveIcon = true
			detectionMethod = "live-icon"
			isLive = true
			return map[string]interface{}{
				"isLive":           isLive,
				"detectionMethod":  detectionMethod,
				"indicators":       indicators,
			}, nil
		}
	}
	
	// Priorität 2: exaktes LIVE-Badge innerhalb desselben Account-Links
	var liveBadgeVisible bool
	err = chromedp.Run(ctx,
		chromedp.Evaluate(fmt.Sprintf(`
			(() => {
				const link = document.querySelector('%s');
				if (!link) return false;
				const badge = Array.from(link.querySelectorAll('*')).find(el => 
					el.textContent && /^LIVE$/i.test(el.textContent.trim())
				);
				return badge && badge.offsetParent !== null;
			})()
		`, selectorStr), &liveBadgeVisible),
	)
	if err == nil && liveBadgeVisible {
		indicators.LiveBadge = true
		detectionMethod = "live-badge"
		isLive = true
		return map[string]interface{}{
			"isLive":           isLive,
			"detectionMethod":  detectionMethod,
			"indicators":       indicators,
		}, nil
	}
	
	// Priorität 3: Live-Rahmen am Profilkopf/Avatar des Accounts
	profileSelectors := []string{
		`[data-e2e="user-page"] img[data-e2e="avatar"]`,
		`[data-e2e="user-page"] div[data-e2e="profile-avatar"] img`,
		`main header img[data-e2e="avatar"]`,
		`main header [class*="avatar"] img`,
	}
	
	for _, selector := range profileSelectors {
		var styles map[string]string
		err = chromedp.Run(ctx,
			chromedp.Evaluate(fmt.Sprintf(`
				(() => {
					const el = document.querySelector('%s');
					if (!el) return {};
					const computed = window.getComputedStyle(el);
					const parent = el.parentElement;
					const parentComputed = parent ? window.getComputedStyle(parent) : null;
					const grandParent = parent ? parent.parentElement : null;
					const grandParentComputed = grandParent ? window.getComputedStyle(grandParent) : null;
					return {
						borderColor: computed.borderColor,
						outlineColor: computed.outlineColor,
						boxShadow: computed.boxShadow,
						parentBorderColor: parentComputed ? parentComputed.borderColor : null,
						parentBoxShadow: parentComputed ? parentComputed.boxShadow : null,
						grandParentBorderColor: grandParentComputed ? grandParentComputed.borderColor : null,
						grandParentBoxShadow: grandParentComputed ? grandParentComputed.boxShadow : null
					};
				})()
			`, selector), &styles),
		)
		
		if err == nil && len(styles) > 0 {
			allColors := []string{
				styles["borderColor"],
				styles["outlineColor"],
				styles["parentBorderColor"],
				styles["grandParentBorderColor"],
			}
			
			allShadows := []string{
				styles["boxShadow"],
				styles["parentBoxShadow"],
				styles["grandParentBoxShadow"],
			}
			
			isRed := func(color string) bool {
				if color == "" || color == "none" {
					return false
				}
				return strings.Contains(color, "255") || strings.Contains(color, "red") ||
					strings.Contains(color, "rgb(254") || strings.Contains(color, "fe2c55") ||
					strings.Contains(color, "#fe2c") || strings.Contains(color, "rgb(255, 0") ||
					strings.Contains(color, "rgb(255, 44")
			}
			
			hasRed := false
			for _, color := range allColors {
				if isRed(color) {
					hasRed = true
					break
				}
			}
			
			if !hasRed {
				for _, shadow := range allShadows {
					if shadow != "" && isRed(shadow) {
						hasRed = true
						break
					}
				}
			}
			
			if hasRed {
				indicators.LiveBorder = true
				detectionMethod = "live-border"
				isLive = true
				return map[string]interface{}{
					"isLive":           isLive,
					"detectionMethod":  detectionMethod,
					"indicators":       indicators,
				}, nil
			}
		}
	}
	
	// Priorität 4: Live-Indikator innerhalb des exakten Account-Links
	var liveIndicatorVisible bool
	indicatorSelectors := `[class*="live-indicator"], div[class*="LiveBadge"]`
	err = chromedp.Run(ctx,
		chromedp.Evaluate(fmt.Sprintf(`
			(() => {
				const link = document.querySelector('%s');
				if (!link) return false;
				const indicator = link.querySelector('%s');
				return indicator && indicator.offsetParent !== null;
			})()
		`, selectorStr, indicatorSelectors), &liveIndicatorVisible),
	)
	if err == nil && liveIndicatorVisible {
		indicators.LiveIndicator = true
		detectionMethod = "live-indicator"
		isLive = true
		return map[string]interface{}{
			"isLive":           isLive,
			"detectionMethod":  detectionMethod,
			"indicators":       indicators,
		}, nil
	}
	
	// Priorität 5: sichtbarer exakter /@username/live-Link
	var liveLinkVisible bool
	err = chromedp.Run(ctx,
		chromedp.Evaluate(fmt.Sprintf(`
			(() => {
				const link = document.querySelector('%s');
				return link && link.offsetParent !== null;
			})()
		`, selectorStr), &liveLinkVisible),
	)
	if err == nil && liveLinkVisible {
		indicators.LiveLink = true
		detectionMethod = "live-link"
		isLive = true
		return map[string]interface{}{
			"isLive":           isLive,
			"detectionMethod":  detectionMethod,
			"indicators":       indicators,
		}, nil
	}
	
	return map[string]interface{}{
		"isLive":           isLive,
		"detectionMethod":  detectionMethod,
		"indicators":       indicators,
	}, nil
}

func isSuccessfulStreamResponse(status int, urlStr string) bool {
	if status >= 200 && status < 300 {
		u, err := url.Parse(urlStr)
		if err != nil {
			return false
		}
		return strings.Contains(u.Host, "tiktokcdn") && strings.HasSuffix(u.Path, ".flv")
	}
	return false
}

func classifyDirectLiveState(data map[string]interface{}) map[string]interface{} {
	username := data["username"].(string)
	currentPath := data["currentPath"].(string)
	title := data["title"].(string)
	bodyText := data["bodyText"].(string)
	successfulStreamResponse := data["successfulStreamResponse"].(bool)
	
	// Prüfe ob der Benutzer existiert (kein 404)
	if strings.Contains(title, "Couldn't find this account") || 
	   strings.Contains(bodyText, "This account is private") ||
	   strings.Contains(bodyText, "Dieser Account ist privat") {
		reason := "Account not found or private"
		if strings.Contains(bodyText, "private") || strings.Contains(bodyText, "privat") {
			reason = "Account is private"
		}
		return map[string]interface{}{
			"status": "restricted",
			"reason": reason,
		}
	}
	
	// Prüfe auf Altersbeschränkungen
	if strings.Contains(title, "Age verification") ||
	   strings.Contains(bodyText, "Altersbeschränkung") ||
	   strings.Contains(bodyText, "Age restriction") {
		return map[string]interface{}{
			"status": "restricted",
			"reason": "Age verification required",
		}
	}
	
	// Prüfe ob es sich um eine Live-Seite handelt
	if strings.Contains(currentPath, "/live") {
		if successfulStreamResponse {
			return map[string]interface{}{
				"status": "live",
			}
		}
		
		// Wenn keine erfolgreiche Stream-Antwort, aber auf /live-Seite -> offline
		if strings.Contains(bodyText, "offline") || 
		   strings.Contains(bodyText, "beendet") ||
		   strings.Contains(title, "Offline") {
			return map[string]interface{}{
				"status": "offline",
			}
		}
		
		// Standardmäßig live, wenn auf /live-Seite
		return map[string]interface{}{
			"status": "live",
		}
	}
	
	// Nicht auf /live-Seite -> offline
	return map[string]interface{}{
		"status": "offline",
	}
}

func inspectDirectLiveState(ctx context.Context, username string) map[string]interface{} {
	var successfulStreamResponse bool
	var responses []*network.Response
	
	// Response Handler registrieren
	chromedp.ListenTarget(ctx, func(ev interface{}) {
		if resp, ok := ev.(*network.EventResponseReceived); ok {
			responses = append(responses, resp.Response)
			if isSuccessfulStreamResponse(int(resp.Response.Status), resp.Response.URL) {
				successfulStreamResponse = true
			}
		}
	})
	
	// Gehe zur Live-Seite
	err := chromedp.Run(ctx,
		chromedp.Navigate(fmt.Sprintf("https://www.tiktok.com/@%s/live", username)),
		chromedp.WaitVisible("body", chromedp.WaitTimeout(30*time.Second)),
	)
	
	if err != nil {
		return map[string]interface{}{
			"status": "technical_error",
			"reason": err.Error(),
		}
	}
	
	// Warte auf das Laden
	time.Sleep(humanDelay(8000, 10000))
	
	// Hole aktuelle URL und Titel
	var currentURL, title, bodyText string
	err = chromedp.Run(ctx,
		chromedp.Location(&currentURL),
		chromedp.Title(&title),
		chromedp.Text("body", &bodyText, chromedp.ByQuery),
	)
	
	if err != nil {
		return map[string]interface{}{
			"status": "technical_error",
			"reason": err.Error(),
		}
	}
	
	currentPath := "/"
	parsedURL, err := url.Parse(currentURL)
	if err == nil {
		currentPath = parsedURL.Path
	}
	
	return classifyDirectLiveState(map[string]interface{}{
		"username":                username,
		"currentPath":             currentPath,
		"title":                   title,
		"bodyText":                bodyText,
		"successfulStreamResponse": successfulStreamResponse,
	})
}

func checkLiveStatus(username string) string {
	// Prüfe ob Chrome verfügbar ist
	execPath := os.Getenv("CHROME_PATH")
	if execPath == "" {
		execPath = "/usr/bin/google-chrome"
		if _, err := os.Stat(execPath); os.IsNotExist(err) {
			execPath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
		}
	}
	
	if _, err := os.Stat(execPath); os.IsNotExist(err) {
		result := Result{
			Error:       true,
			Status:      "dependency_missing",
			Method:      "chromedp",
			Message:     fmt.Sprintf("Chrome unavailable: %v", err),
			Timestamp:   time.Now().UTC().Format(time.RFC3339),
		}
		jsonData, _ := json.Marshal(result)
		fmt.Println(string(jsonData))
		os.Exit(2)
		return "dependency_missing"
	}
	
	// Erstelle ChromeDP Kontext
	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.ExecPath(execPath),
		chromedp.Headless(true),
		chromedp.UserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"),
		chromedp.WindowSize(1920, 1080),
	)
	
	allocCtx, cancel := chromedp.NewExecAllocator(context.Background(), opts...)
	defer cancel()
	
	ctx, cancel := chromedp.NewContext(allocCtx)
	defer cancel()
	
	// Setze Timeout
	ctx, cancel = context.WithTimeout(ctx, 60*time.Second)
	defer cancel()
	
	var finalResult Result
	finalResult.Username = username
	finalResult.Timestamp = time.Now().UTC().Format(time.RFC3339)
	finalResult.Version = "2.1"
	
	// Navigiere zum Profil
	err := chromedp.Run(ctx,
		chromedp.Navigate(fmt.Sprintf("https://www.tiktok.com/@%s", username)),
		chromedp.WaitVisible("body", chromedp.WaitTimeout(30*time.Second)),
	)
	
	if err != nil {
		finalResult.Status = "technical_error"
		finalResult.DetectionMethod = "error"
		finalResult.Error = err.Error()
		jsonData, _ := json.Marshal(finalResult)
		fmt.Fprintln(os.Stderr, string(jsonData))
		return "technical_error"
	}
	
	// Schließe DSGVO Banner
	bannerClosed, _ := closeDSGVOBanner(ctx)
	finalResult.BannerClosed = bannerClosed
	
	// Warte auf vollständigen Seitenaufbau
	pageReady, _ := waitForPageReady(ctx)
	finalResult.PageFullyLoaded = pageReady
	
	// Debug-Screenshot
	if os.Getenv("DEBUG") == "1" {
		var buf []byte
		if err := chromedp.Run(ctx, chromedp.CaptureScreenshot(&buf)); err == nil {
			filename := fmt.Sprintf("/tmp/tiktok-%s-v2.png", username)
			if err := os.WriteFile(filename, buf, 0644); err != nil {
				// Ignoriere Fehler beim Screenshot
			}
		}
	}
	
	// Prüfe Live-Status
	liveResult, err := detectLiveStatus(ctx, username)
	if err != nil {
		finalResult.Status = "technical_error"
		finalResult.DetectionMethod = "error"
		finalResult.Error = err.Error()
		jsonData, _ := json.Marshal(finalResult)
		fmt.Fprintln(os.Stderr, string(jsonData))
		return "technical_error"
	}
	
	// Prüfe direkte Live-Seite
	directResult := inspectDirectLiveState(ctx, username)
	
	finalStatus := ""
	if directResult["status"] == "restricted" {
		finalStatus = "restricted"
	} else if liveResult["isLive"].(bool) || directResult["status"] == "live" {
		finalStatus = "live"
	} else {
		finalStatus = directResult["status"].(string)
	}
	
	finalResult.Status = finalStatus
	finalResult.IsLive = (finalStatus == "live" || finalStatus == "restricted")
	finalResult.DetectionMethod = ""
	if directResult["status"] == "restricted" {
		finalResult.DetectionMethod = "account-live-restricted"
	} else {
		finalResult.DetectionMethod = liveResult["detectionMethod"].(string)
	}
	finalResult.IsAgeRestricted = (finalStatus == "restricted")
	if finalStatus == "restricted" {
		reason := directResult["reason"].(string)
		finalResult.AgeRestrictionReason = &reason
	}
	finalResult.Indicators = liveResult["indicators"].(LiveIndicators)
	
	jsonData, _ := json.MarshalIndent(finalResult, "", "  ")
	fmt.Println(string(jsonData))
	
	return finalStatus
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: go run tiktok-check-profile.go <username>")
		fmt.Fprintln(os.Stderr, "username cannot be empty")
		os.Exit(64)
	}
	
	username, err := normalizeUsername(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, "Usage: go run tiktok-check-profile.go <username>")
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(64)
	}
	
	enforceLoadLimit("chromedp_enhanced")
	
	status := checkLiveStatus(username)
	
	switch status {
	case "live":
		os.Exit(0)
	case "offline", "restricted":
		os.Exit(1)
	default:
		os.Exit(2)
	}
}
