// abstraction-provenance: {"artifact_sha256": "9ca4d8d2a3e2a8c38610eb6ef2327c5de029983a7372432fcb78449297e52179", "source_sha256": "a53191c31c8f3e0c2cf2f32b08da78e3ddf05a87beb8d40862645641631e7855", "target_language": "go"}
// tiktok-common.test.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"regexp"
	"strconv"
	"strings"
	"testing"

	"github.com/playwright-community/playwright-go"
)

func normalizeUsername(username string) string {
	username = strings.TrimSpace(username)
	if strings.HasPrefix(username, "@") {
		username = username[1:]
	}
	if strings.Contains(username, ";") {
		panic("Invalid character ';' in username")
	}
	return username
}

func liveHrefSelectors(username string) []string {
	normalized := normalizeUsername(username)
	return []string{
		fmt.Sprintf(`a[href="/@%s/live"]`, normalized),
		fmt.Sprintf(`a[href^="/@%s/live?"]`, normalized),
	}
}

type LoadState struct {
	Overloaded bool
}

func loadState(env map[string]string) LoadState {
	testLoadPerCPU := 1.0
	maxLoadPerCPU := 1.0

	if val, ok := env["TIKTOK_TEST_LOAD_PER_CPU"]; ok {
		if f, err := strconv.ParseFloat(val, 64); err == nil {
			testLoadPerCPU = f
		}
	}

	if val, ok := env["TIKTOK_MAX_LOAD_PER_CPU"]; ok {
		if f, err := strconv.ParseFloat(val, 64); err == nil {
			maxLoadPerCPU = f
		}
	}

	return LoadState{Overloaded: testLoadPerCPU > maxLoadPerCPU}
}

func isAllowedStreamUrl(url string) bool {
	pattern := regexp.MustCompile(`^https://[^/]*tiktokcdn\.com/.*\.flv(\?.*)?$`)
	return pattern.MatchString(url)
}

func isSuccessfulStreamResponse(status int, url string) bool {
	if !isAllowedStreamUrl(url) {
		return false
	}
	return status == 200 || status == 206
}

type ExtractorResult struct {
	Success bool   `json:"success"`
	Status  string `json:"status"`
	URL     string `json:"url,omitempty"`
}

func normalizeExtractorResult(result ExtractorResult, extractor string, username string) ExtractorResult {
	if result.Success && result.Status == "live" {
		if extractor != "streamlink" {
			result.Status = "technical_error"
		}
	} else if !result.Success && result.Status == "offline" {
		result.URL = ""
	}
	return result
}

func classifyFinalFailure(results []ExtractorResult) string {
	for _, result := range results {
		if result.Status == "offline" {
			return "offline"
		}
	}
	return "technical_error"
}

func exitCodeForResult(result ExtractorResult) int {
	switch result.Status {
	case "restricted":
		return 1
	case "technical_error":
		return 2
	default:
		return 0
	}
}

type LiveState struct {
	Username                string
	CurrentPath             string
	Title                   string
	BodyText                string
	SuccessfulStreamResponse bool
}

func classifyDirectLiveState(state LiveState) ExtractorResult {
	if state.CurrentPath != fmt.Sprintf("/@%s/live", normalizeUsername(state.Username)) {
		return ExtractorResult{Status: "offline"}
	}

	restrictedKeywords := []string{
		"unangemessen",
		"inappropriate",
		"Themen, die unangenehm sein könnten",
	}
	
	for _, keyword := range restrictedKeywords {
		if strings.Contains(state.BodyText, keyword) {
			return ExtractorResult{Status: "restricted"}
		}
	}

	if strings.Contains(state.BodyText, "LIVE has ended") {
		return ExtractorResult{Status: "offline"}
	}

	if state.SuccessfulStreamResponse {
		return ExtractorResult{Status: "live"}
	}

	return ExtractorResult{Status: "offline"}
}

func TestNormalizeUsername(t *testing.T) {
	if normalizeUsername("@example_creator") != "example_creator" {
		t.Error("Expected 'example_creator'")
	}
	if normalizeUsername(" example_creator ") != "example_creator" {
		t.Error("Expected 'example_creator'")
	}
	
	defer func() {
		if r := recover(); r == nil {
			t.Error("Expected panic for invalid character")
		}
	}()
	normalizeUsername("example_creator;id")
}

func TestLiveHrefSelectors(t *testing.T) {
	expected := []string{
		`a[href="/@example_creator/live"]`,
		`a[href^="/@example_creator/live?"]`,
	}
	actual := liveHrefSelectors("example_creator")
	
	if len(actual) != len(expected) {
		t.Errorf("Expected %d selectors, got %d", len(expected), len(actual))
	}
	
	for i, sel := range actual {
		if sel != expected[i] {
			t.Errorf("Expected '%s', got '%s'", expected[i], sel)
		}
	}
}

func TestLoadState(t *testing.T) {
	env := map[string]string{
		"TIKTOK_TEST_LOAD_PER_CPU":  "2",
		"TIKTOK_MAX_LOAD_PER_CPU":   "1.5",
	}
	state := loadState(env)
	if !state.Overloaded {
		t.Error("Expected overloaded=true")
	}
}

func TestIsAllowedStreamUrl(t *testing.T) {
	allowed := "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x"
	notAllowed1 := "https://attacker.example/path/tiktokcdn/video.flv"
	notAllowed2 := "http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv"
	
	if !isAllowedStreamUrl(allowed) {
		t.Error("Should allow TikTok CDN URL")
	}
	if isAllowedStreamUrl(notAllowed1) {
		t.Error("Should not allow external domain")
	}
	if isAllowedStreamUrl(notAllowed2) {
		t.Error("Should not allow HTTP")
	}
}

func TestIsSuccessfulStreamResponse(t *testing.T) {
	allowedUrl := "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x"
	
	if !isSuccessfulStreamResponse(200, allowedUrl) {
		t.Error("Should accept 200 response")
	}
	if !isSuccessfulStreamResponse(206, allowedUrl) {
		t.Error("Should accept 206 response")
	}
	if isSuccessfulStreamResponse(404, allowedUrl) {
		t.Error("Should reject 404 response")
	}
}

func TestNormalizeExtractorResult(t *testing.T) {
	allowedUrl := "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x"
	
	result1 := normalizeExtractorResult(ExtractorResult{Success: false, Status: "offline"}, "streamlink", "example_creator")
	if result1.Status != "offline" {
		t.Error("Expected status 'offline'")
	}
	
	result2 := normalizeExtractorResult(ExtractorResult{Success: true, Status: "live"}, "yt-dlp", "example_creator")
	if result2.Status != "technical_error" {
		t.Error("Expected status 'technical_error'")
	}
	
	result3 := normalizeExtractorResult(ExtractorResult{Success: false, Status: "offline", URL: allowedUrl}, "streamlink", "example_creator")
	if result3.URL != "" {
		t.Error("URL should be cleared for offline status")
	}
	
	result4 := normalizeExtractorResult(ExtractorResult{Success: true, Status: "live", URL: allowedUrl}, "streamlink", "example_creator")
	if result4.Status != "live" {
		t.Error("Expected status 'live'")
	}
}

func TestClassifyFinalFailure(t *testing.T) {
	results := []ExtractorResult{
		{Status: "offline"},
		{Status: "dependency_missing"},
	}
	if classifyFinalFailure(results) != "offline" {
		t.Error("Expected 'offline'")
	}
}

func TestExitCodeForResult(t *testing.T) {
	if exitCodeForResult(ExtractorResult{Status: "restricted"}) != 1 {
		t.Error("Expected exit code 1 for restricted")
	}
	if exitCodeForResult(ExtractorResult{Status: "technical_error"}) != 2 {
		t.Error("Expected exit code 2 for technical_error")
	}
}

func TestClassifyDirectLiveState(t *testing.T) {
	state1 := LiveState{
		Username: "example_creator",
		CurrentPath: "/@example_creator/live",
		Title: "Example (@example_creator) is LIVE - TikTok LIVE",
		BodyText: "Dieses LIVE enthält Themen, die unangenehm sein könnten.",
		SuccessfulStreamResponse: false,
	}
	if classifyDirectLiveState(state1).Status != "restricted" {
		t.Error("Expected 'restricted'")
	}
	
	state2 := LiveState{
		Username: "example_creator",
		CurrentPath: "/@example_creator/live",
		Title: "Example (@example_creator) is LIVE - TikTok LIVE",
		BodyText: "LIVE has ended",
		SuccessfulStreamResponse: false,
	}
	if classifyDirectLiveState(state2).Status != "offline" {
		t.Error("Expected 'offline'")
	}
	
	state3 := LiveState{
		Username: "example_creator",
		CurrentPath: "/@example_creator/live",
		Title: "Example (@example_creator) is LIVE - TikTok LIVE",
		BodyText: "Suggested LIVE creators",
		SuccessfulStreamResponse: true,
	}
	if classifyDirectLiveState(state3).Status != "live" {
		t.Error("Expected 'live'")
	}
}

func TestPlaywrightSelector(t *testing.T) {
	pw, err := playwright.Run()
	if err != nil {
		t.Fatal(err)
	}
	defer pw.Stop()

	browser, err := pw.Chromium.Launch(playwright.BrowserTypeLaunchOptions{
		Headless: playwright.Bool(true),
	})
	if err != nil {
		t.Fatal(err)
	}
	defer browser.Close()

	page, err := browser.NewPage()
	if err != nil {
		t.Fatal(err)
	}

	content := `
		<aside><a href="/@other_creator/live"><span>LIVE</span></a></aside>
		<main><header><h1>example_creator</h1></header></main>
	`
	err = page.SetContent(content)
	if err != nil {
		t.Fatal(err)
	}

	selectors := liveHrefSelectors("example_creator")
	selectorStr := strings.Join(selectors, ", ")
	element, err := page.QuerySelector(selectorStr)
	if err != nil {
		t.Fatal(err)
	}
	if element != nil {
		t.Error("sidebar LIVE for another account must not match")
	}
}

func main() {
	// Run all tests
	t := &testing.T{}
	
	TestNormalizeUsername(t)
	TestLiveHrefSelectors(t)
	TestLoadState(t)
	TestIsAllowedStreamUrl(t)
	TestIsSuccessfulStreamResponse(t)
	TestNormalizeExtractorResult(t)
	TestClassifyFinalFailure(t)
	TestExitCodeForResult(t)
	TestClassifyDirectLiveState(t)
	TestPlaywrightSelector(t)
	
	if t.Failed() {
		os.Exit(1)
	}
}
