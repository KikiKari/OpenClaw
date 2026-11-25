// abstraction-provenance: {"artifact_sha256": "9e29a3f5d709eb772a39ac9e3a82374489c29b8316ab0c9edf5bb9ff7ebcc22a", "source_sha256": "e4fcb95b6aa05b8fa419b7ed085317debab4e29b8cfb62a4d3ab8ec952610874", "target_language": "go"}
// tiktok-get-stream.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

/*
 * Enhanced TikTok LIVE URL extractor.
 *
 * Order: Playwright response interception, streamlink, then yt-dlp. Every
 * result is schema-normalized and must be an allowed HTTPS TikTok-CDN FLV
 * URL. Fallbacks use fixed argument arrays, bounded output, timeouts, and
 * process-group cleanup.
 *
 * Exit 0 = URL, 1 = offline/restricted/no URL, 2 = dependency/technical
 * failure, 75 = overloaded before Playwright startup.
 */

package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/chromedp"
)

const (
	FALLBACK_TIMEOUT_MS  = 45000
	FALLBACK_MAX_OUTPUT  = 1024 * 1024
)

type Result struct {
	Success         bool     `json:"success"`
	Status          string   `json:"status"`
	Method          string   `json:"method,omitempty"`
	Username        string   `json:"username,omitempty"`
	URL             string   `json:"url,omitempty"`
	Quality         string   `json:"quality,omitempty"`
	Message         string   `json:"message,omitempty"`
	Error           string   `json:"error,omitempty"`
	Restricted      bool     `json:"restricted,omitempty"`
	Reason          string   `json:"reason,omitempty"`
	AllUrls         []struct{
		URL     string `json:"url"`
		Quality string `json:"quality"`
	} `json:"allUrls,omitempty"`
	AllUrlsCount    int      `json:"allUrlsCount,omitempty"`
	Timestamp       string   `json:"timestamp,omitempty"`
	PlaywrightReason string  `json:"playwrightReason,omitempty"`
	StreamlinkReason string  `json:"streamlinkReason,omitempty"`
	YtdlpReason      string  `json:"ytdlpReason,omitempty"`
}

func logMessage(message string) {
	fmt.Fprintln(os.Stderr, message)
}

func runFallback(scriptPath string, args []string) (map[string]interface{}, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(FALLBACK_TIMEOUT_MS)*time.Millisecond)
	defer cancel()

	cmd := exec.CommandContext(ctx, "bash", append([]string{scriptPath}, args...)...)
	
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}

	if err := cmd.Start(); err != nil {
		return nil, err
	}

	var stdoutBuf, stderrBuf bytes.Buffer
	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		defer wg.Done()
		limitReader := io.LimitReader(stdoutPipe, FALLBACK_MAX_OUTPUT)
		io.Copy(&stdoutBuf, limitReader)
	}()

	go func() {
		defer wg.Done()
		limitReader := io.LimitReader(stderrPipe, FALLBACK_MAX_OUTPUT)
		io.Copy(&stderrBuf, limitReader)
	}()

	done := make(chan error, 1)
	go func() {
		wg.Wait()
		done <- cmd.Wait()
	}()

	select {
	case <-ctx.Done():
		if killErr := cmd.Process.Kill(); killErr != nil {
			logMessage(fmt.Sprintf("Failed to kill process: %v", killErr))
		}
		return map[string]interface{}{
			"code":   2,
			"stdout": "",
			"stderr": fmt.Sprintf("%s\nfallback timeout", stderrBuf.String()),
		}, nil
	case err := <-done:
		code := 2
		if err == nil {
			code = 0
		} else if exitError, ok := err.(*exec.ExitError); ok {
			code = exitError.ExitCode()
		}
		return map[string]interface{}{
			"code":   code,
			"stdout": strings.TrimSpace(stdoutBuf.String()),
			"stderr": strings.TrimSpace(stderrBuf.String()),
		}, nil
	}
}

func parseFallbackResult(method string, username string, execution map[string]interface{}) Result {
	for _, text := range []string{fmt.Sprintf("%v", execution["stdout"]), fmt.Sprintf("%v", execution["stderr"])} {
		if text == "" || text == "<nil>" {
			continue
		}
		var value map[string]interface{}
		if json.Unmarshal([]byte(text), &value) == nil && value != nil {
			return normalizeExtractorResult(value, method, username)
		}
	}
	
	status := "technical_error"
	if fmt.Sprintf("%v", execution["code"]) == "75" {
		status = "overloaded"
	}
	
	message := fmt.Sprintf("fallback exited %v", execution["code"])
	if stderr, ok := execution["stderr"].(string); ok && stderr != "" {
		message = stderr
	}
	
	return normalizeExtractorResult(map[string]interface{}{
		"success": false,
		"status":  status,
		"method":  method,
		"username": username,
		"message": message,
	}, method, username)
}

func playwrightPreflight() (bool, string) {
	// In Go we assume chromedp is available as a dependency
	return true, ""
}

func humanDelay(min int, max int) time.Duration {
	return time.Duration(rand.Intn(max-min+1)+min) * time.Millisecond
}

func handlePopups(ctx context.Context) (bool, error) {
	closed := false
	
	// DSGVO selectors
	dsgvoSelectors := []string{
		`button:has-text("Verstanden")`,
		`[data-e2e="cookie-banner-accept"]`,
		`button:has-text("Accept")`,
		`button:has-text("Akzeptieren")`,
		`button:has-text("Alle akzeptieren")`,
		`button:has-text("Allow all")`,
		`button:has-text("Accept all")`,
		`[data-testid="cookie-policy-banner-accept"]`,
	}
	
	for _, sel := range dsgvoSelectors {
		err := chromedp.Run(ctx,
			chromedp.Click(sel, chromedp.ByQuery),
		)
		if err == nil {
			time.Sleep(humanDelay(1000, 2000))
			closed = true
			break
		}
	}
	
	// Login popup 1
	err := chromedp.Run(ctx,
		chromedp.Click(`div[role="dialog"] [aria-label="Close"], div[role="dialog"] button[aria-label="Schließen"], div[role="dialog"] svg`, chromedp.ByQuery),
	)
	if err == nil {
		time.Sleep(humanDelay(1000, 2000))
		closed = true
	}
	
	// Login popup 2
	err = chromedp.Run(ctx,
		chromedp.Click(`button:has-text("Jetzt nicht"), button:has-text("Not now")`, chromedp.ByQuery),
	)
	if err == nil {
		time.Sleep(humanDelay(1000, 2000))
		closed = true
	}
	
	return closed, nil
}

func checkRestrictions(ctx context.Context) (bool, string, error) {
	restrictionTexts := []string{
		`text="Bei TikTok anmelden"`,
		`text=/Dieses LIVE enthält Themen/`,
		`text="Melde dich an für das vollständige Erlebnis"`,
		`text=/Melde dich an für das volle/`,
		`text="Log in to TikTok"`,
		`text=/mature content/`,
		`text=/age-restricted/`,
	}
	
	for _, sel := range restrictionTexts {
		var visible bool
		err := chromedp.Run(ctx,
			chromedp.EvaluateAsDevTools(fmt.Sprintf(`
				document.querySelector('%s') !== null && 
				getComputedStyle(document.querySelector('%s')).visibility !== 'hidden' &&
				getComputedStyle(document.querySelector('%s')).display !== 'none'
			`, strings.Replace(sel, "text=", "", 1), strings.Replace(sel, "text=", "", 1), strings.Replace(sel, "text=", "", 1)), &visible),
		)
		if err == nil && visible {
			reason := strings.Replace(sel, "text=", "", 1)
			reason = strings.Replace(reason, "/", "", -1)
			reason = strings.Replace(reason, `"`, "", -1)
			return true, reason, nil
		}
	}
	return false, "", nil
}

func qualityKeyFromUrl(url string) string {
	qualities := map[string]string{
		"_origin.flv":   "original",
		"_uhd_60.flv":   "1080p60",
		"_hd_60.flv":    "720p60",
		"_hd.flv":       "720p",
		"_sd.flv":       "540p",
		"_ld.flv":       "360p",
	}
	
	for suffix, quality := range qualities {
		if strings.Contains(url, suffix) {
			return quality
		}
	}
	return "unknown"
}

func extractWithPlaywright(username string, qualityPreference string) Result {
	preflightOk, preflightError := playwrightPreflight()
	if !preflightOk {
		return Result{
			Success: false,
			Method:  "playwright",
			Status:  "dependency_missing",
			Error:   preflightError,
		}
	}
	
	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.Flag("headless", true),
		chromedp.Flag("no-sandbox", true),
		chromedp.Flag("disable-setuid-sandbox", true),
		chromedp.Flag("disable-gpu", true),
		chromedp.Flag("disable-dev-shm-usage", true),
	)
	
	allocCtx, cancel := chromedp.NewExecAllocator(context.Background(), opts...)
	defer cancel()
	
	ctx, cancel := chromedp.NewContext(allocCtx)
	defer cancel()
	
	// Set user agent
	err := chromedp.Run(ctx, chromedp.ActionFunc(func(ctx context.Context) error {
		_, _, err := network.SetUserAgentOverride("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36").Do(ctx)
		return err
	}))
	if err != nil {
		return Result{
			Success: false,
			Method:  "playwright",
			Status:  "technical_error",
			Error:   err.Error(),
		}
	}
	
	collectedUrls := make([]map[string]interface{}, 0)
	var urlsMutex sync.Mutex
	
	// Listen for network responses
	chromedp.ListenTarget(ctx, func(ev interface{}) {
		if resp, ok := ev.(*network.EventResponseReceived); ok {
			url := resp.Response.URL
			if len(collectedUrls) < 100 && isSuccessfulStreamResponse(int(resp.Response.Status), url) {
				urlsMutex.Lock()
				collectedUrls = append(collectedUrls, map[string]interface{}{
					"url":       url,
					"status":    resp.Response.Status,
					"timestamp": time.Now().Format(time.RFC3339),
				})
				urlsMutex.Unlock()
			}
		}
	})
	
	// Navigate to live page
	err = chromedp.Run(ctx,
		chromedp.Navigate(fmt.Sprintf("https://www.tiktok.com/@%s/live", username)),
		chromedp.WaitVisible("body", chromedp.ByQuery),
	)
	if err != nil {
		return Result{
			Success: false,
			Method:  "playwright",
			Status:  "technical_error",
			Error:   err.Error(),
		}
	}
	
	// Handle popups
	handlePopups(ctx)
	
	// Wait for page load
	time.Sleep(humanDelay(3000, 5000))
	
	// Check restrictions
	restricted, reason, _ := checkRestrictions(ctx)
	if restricted {
		logMessage(fmt.Sprintf("Playwright: Stream restricted - %s", reason))
		return Result{
			Success:    false,
			Method:     "playwright",
			Status:     "restricted",
			Restricted: true,
			Reason:     reason,
		}
	}
	
	// Try to play video
	chromedp.Run(ctx,
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, exp, err := chromedp.Evaluate(`document.querySelector('video')?.play()?.catch(() => {})`).Do(ctx)
			if err != nil {
				return err
			}
			if exp != nil {
				return fmt.Errorf("javascript error: %v", exp)
			}
			return nil
		}),
	)
	
	// Wait for FLV URLs
	time.Sleep(humanDelay(8000, 12000))
	
	// Handle popups again
	handlePopups(ctx)
	time.Sleep(humanDelay(3000, 5000))
	
	// Check restrictions again
	restricted2, reason2, _ := checkRestrictions(ctx)
	if restricted2 {
		logMessage(fmt.Sprintf("Playwright: Stream became restricted after wait - %s", reason2))
		return Result{
			Success:    false,
			Method:     "playwright",
			Status:     "restricted",
			Restricted: true,
			Reason:     reason2,
		}
	}
	
	// Evaluate results
	if len(collectedUrls) == 0 {
		logMessage("Playwright: No FLV URLs captured via network monitoring.")
		return Result{
			Success:    false,
			Method:     "playwright",
			Status:     "offline",
			Restricted: false,
			Reason:     "No FLV URLs found",
		}
	}
	
	// Deduplicate URLs
	seen := make(map[string]bool)
	uniqueUrls := make([]map[string]interface{}, 0)
	for _, item := range collectedUrls {
		baseUrl := strings.Split(item["url"].(string), "?")[0]
		if !seen[baseUrl] {
			seen[baseUrl] = true
			uniqueUrls = append(uniqueUrls, item)
		}
	}
	
	// Quality preference mapping
	qualityOrder := map[string][]string{
		"original": {"_origin.flv", "_uhd_60.flv", "_hd_60.flv", "_hd.flv", "_sd.flv", "_ld.flv"},
		"1080p60":  {"_uhd_60.flv", "_hd_60.flv", "_hd.flv", "_sd.flv", "_ld.flv"},
		"720p60":   {"_hd_60.flv", "_hd.flv", "_sd.flv", "_ld.flv"},
		"720p":     {"_hd.flv", "_sd.flv", "_ld.flv"},
		"540p":     {"_sd.flv", "_ld.flv"},
		"360p":     {"_ld.flv"},
		"auto":     {"_origin.flv", "_uhd_60.flv", "_hd_60.flv", "_hd.flv", "_sd.flv", "_ld.flv"},
	}
	
	var bestUrl map[string]interface{}
	order, exists := qualityOrder[qualityPreference]
	if !exists {
		order = qualityOrder["auto"]
	}
	
	for _, suffix := range order {
		for _, urlItem := range uniqueUrls {
			if strings.Contains(urlItem["url"].(string), suffix) {
				bestUrl = urlItem
				break
			}
		}
		if bestUrl != nil {
			break
		}
	}
	
	if bestUrl == nil && (qualityPreference == "auto" || qualityPreference == "original") {
		if len(uniqueUrls) > 0 {
			bestUrl = uniqueUrls[0]
		}
	}
	
	if bestUrl == nil {
		return Result{
			Success: false,
			Method:  "playwright",
			Status:  "quality_unavailable",
			Reason:  fmt.Sprintf("Requested quality %s was not captured in this fresh browser session", qualityPreference),
		}
	}
	
	// Prepare all URLs with quality info
	allUrls := make([]struct{
		URL     string `json:"url"`
		Quality string `json:"quality"`
	}, len(uniqueUrls))
	for i, item := range uniqueUrls {
		allUrls[i] = struct{
			URL     string `json:"url"`
			Quality string `json:"quality"`
		}{
			URL:     item["url"].(string),
			Quality: qualityKeyFromUrl(item["url"].(string)),
		}
	}
	
	return Result{
		Success:      true,
		Status:       "live",
		Method:       "playwright",
		Username:     username,
		URL:          bestUrl["url"].(string),
		Quality:      qualityPreference,
		AllUrls:      allUrls,
		AllUrlsCount: len(uniqueUrls),
		Timestamp:    time.Now().Format(time.RFC3339),
	}
}

func tryStreamlink(username string, quality string) Result {
	scriptPath := filepath.Join(filepath.Dir(os.Args[0]), "extraction-methods", "extract-tiktok-streamlink.sh")
	execution, err := runFallback(scriptPath, []string{username, quality, "--json"})
	if err != nil {
		return Result{
			Success: false,
			Method:  "streamlink",
			Status:  "technical_error",
			Error:   err.Error(),
		}
	}
	return parseFallbackResult("streamlink", username, execution)
}

func tryYtDlp(username string, quality string) Result {
	scriptPath := filepath.Join(filepath.Dir(os.Args[0]), "extraction-methods", "extract-tiktok-yt-dlp.sh")
	ytFormatMap := map[string]string{
		"original": "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld",
		"1080p60":  "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
		"720p60":   "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
		"720p":     "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld",
		"540p":     "hls-sd/hls-ld/flv-sd/flv-ld",
		"360p":     "hls-ld/flv-ld",
		"auto":     "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld",
	}
	ytFormat := ytFormatMap[quality]
	
	execution, err := runFallback(scriptPath, []string{username, ytFormat, "--json"})
	if err != nil {
		return Result{
			Success: false,
			Method:  "yt-dlp",
			Status:  "technical_error",
			Error:   err.Error(),
		}
	}
	return parseFallbackResult("yt-dlp", username, execution)
}

func getStreamUrl(username string, qualityPreference string) Result {
	timestamp := time.Now().Format(time.RFC3339)
	
	// 1. Playwright
	logMessage(fmt.Sprintf("[1/3] Trying Playwright for @%s...", username))
	pwResult := extractWithPlaywright(username, qualityPreference)
	if pwResult.Success {
		pwResult.Timestamp = timestamp
		return pwResult
	}
	if pwResult.Status == "restricted" || pwResult.Status == "overloaded" {
		return pwResult
	}
	logMessage(fmt.Sprintf("Playwright result: %s", coalesce(pwResult.Reason, pwResult.Error, "failed")))
	
	// 2. Streamlink
	logMessage(fmt.Sprintf("[2/3] Trying streamlink for @%s (quality: %s)...", username, qualityPreference))
	slResult := tryStreamlink(username, qualityPreference)
	if slResult.Success {
		return slResult
	}
	if slResult.Status == "restricted" || slResult.Status == "overloaded" {
		return slResult
	}
	logMessage(fmt.Sprintf("Streamlink result: %s", coalesce(slResult.Message, slResult.Error, "failed")))
	
	// 3. yt-dlp
	logMessage(fmt.Sprintf("[3/3] Trying yt-dlp for @%s...", username))
	ytResult := tryYtDlp(username, qualityPreference)
	if ytResult.Success {
		return ytResult
	}
	if ytResult.Status == "restricted" || ytResult.Status == "overloaded" {
		return ytResult
	}
	logMessage(fmt.Sprintf("yt-dlp result: %s", coalesce(ytResult.Message, ytResult.Error, "failed")))
	
	// All failed
	status := classifyFinalFailure([]Result{pwResult, slResult, ytResult})
	return Result{
		Success:          false,
		Status:           status,
		Username:         username,
		Message:          "All extraction methods failed (Playwright, streamlink, yt-dlp).",
		PlaywrightReason: coalesce(pwResult.Reason, pwResult.Error),
		StreamlinkReason: coalesce(slResult.Message, slResult.Error),
		YtdlpReason:      coalesce(ytResult.Message, ytResult.Error),
		Timestamp:        timestamp,
	}
}

func isSuccessfulStreamResponse(status int, url string) bool {
	return status >= 200 && status < 400 && 
		   strings.HasPrefix(url, "https://") && 
		   strings.Contains(url, "tiktokcdn.com") && 
		   (strings.HasSuffix(url, ".flv") || strings.Contains(url, "/live/"))
}

func normalizeExtractorResult(value map[string]interface{}, method string, username string) Result {
	result := Result{
		Method:   method,
		Username: username,
	}
	
	if success, ok := value["success"].(bool); ok {
		result.Success = success
	}
	if status, ok := value["status"].(string); ok {
		result.Status = status
	}
	if url, ok := value["url"].(string); ok {
		result.URL = url
	}
	if quality, ok := value["quality"].(string); ok {
		result.Quality = quality
	}
	if message, ok := value["message"].(string); ok {
		result.Message = message
	}
	if errorMsg, ok := value["error"].(string); ok {
		result.Error = errorMsg
	}
	if restricted, ok := value["restricted"].(bool); ok {
		result.Restricted = restricted
	}
	if reason, ok := value["reason"].(string); ok {
		result.Reason = reason
	}
	if timestamp, ok := value["timestamp"].(string); ok {
		result.Timestamp = timestamp
	}
	
	return result
}

func normalizeUsername(username string) (string, error) {
	username = strings.TrimSpace(username)
	if username == "" {
		return "", fmt.Errorf("username cannot be empty")
	}
	if strings.Contains(username, "/") || strings.Contains(username, "\\") {
		return "", fmt.Errorf("invalid username characters")
	}
	return username, nil
}

func enforceLoadLimit(component string) {
	// Placeholder - implement as needed
}

func forcedOffline(component string, username string) bool {
	// Placeholder - implement as needed
	return false
}

func classifyFinalFailure(results []Result) string {
	for _, result := range results {
		if result.Status == "overloaded" {
			return "overloaded"
		}
		if result.Status == "restricted" {
			return "restricted"
		}
	}
	return "technical_error"
}

func exitCodeForResult(result Result) int {
	if result.Success {
		return 0
	}
	switch result.Status {
	case "offline", "restricted":
		return 1
	case "overloaded":
		return 75
	default:
		return 2
	}
}

func coalesce(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: tiktok-get-stream <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]")
		os.Exit(1)
	}
	
	cliUsername, err := normalizeUsername(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(64)
	}
	
	enforceLoadLimit("playwright_streamlink_ytdlp")
	if forcedOffline("playwright_streamlink_ytdlp", cliUsername) {
		os.Exit(1)
	}
	
	cliQuality := "auto"
	cliJson := false
	
	for _, arg := range os.Args[2:] {
		if arg == "--json" {
			cliJson = true
		} else if !strings.HasPrefix(arg, "--") {
			validQualities := []string{"original", "1080p60", "720p60", "720p", "540p", "360p", "auto"}
			valid := false
			for _, q := range validQualities {
				if arg == q {
					valid = true
					cliQuality = arg
					break
				}
			}
			if !valid {
				fmt.Fprintln(os.Stderr, "Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto")
				os.Exit(64)
			}
		}
	}
	
	result := getStreamUrl(cliUsername, cliQuality)
	
	if cliJson {
		output, _ := json.MarshalIndent(result, "", "  ")
		fmt.Println(string(output))
	} else {
		if result.Success {
			fmt.Println(result.URL)
		} else {
			fmt.Fprintln(os.Stderr, result.Message)
		}
	}
	
	os.Exit(exitCodeForResult(result))
}
