// abstraction-provenance: {"artifact_sha256": "b1ccc61011d45e1934a28475129e489fe505c44286f4b1023faae1123861c2d2", "source_sha256": "23879e22856f8bcfb0ddda7c9b1d7b0d7f3af474cea8620c1f7c10511ef03ed5", "target_language": "go"}
// tiktok-common.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"regexp"
	"runtime"
	"strconv"
	"strings"
)

const (
	DEFAULT_MAX_LOAD_PER_CPU = 1.5
)

var (
	USERNAME_PATTERN         = regexp.MustCompile(`^[A-Za-z0-9._]{1,24}$`)
	FAILURE_STATUSES         = map[string]bool{
		"offline":           true,
		"restricted":        true,
		"overloaded":        true,
		"dependency_missing": true,
		"technical_error":   true,
	}
	QUALITY_URL_PATTERN      = regexp.MustCompile(`_(uhd_60|hd_60|origin|hd|sd|ld|ao)\.(?:flv|m3u8)`)
	TIKTOK_CDN_PATTERN       = regexp.MustCompile(`(^|\.)tiktokcdn(?:-[a-z0-9-]+)?\.com$`)
)

type LoadState struct {
	Overloaded  bool
	LoadPerCpu  float64
	Maximum     float64
}

type ExtractorResult struct {
	Success bool   `json:"success"`
	Status  string `json:"status"`
	Method  string `json:"method"`
	Username string `json:"username"`
	URL     string `json:"url,omitempty"`
	Message string `json:"message,omitempty"`
}

type DirectLiveState struct {
	Username                string
	CurrentPath             string
	Title                   string
	BodyText                string
	SuccessfulStreamResponse bool
}

type LiveStateResult struct {
	Status string `json:"status"`
	Reason string `json:"reason"`
}

func normalizeUsername(raw string) (string, error) {
	username := strings.TrimLeft(strings.TrimSpace(raw), "@")
	if !USERNAME_PATTERN.MatchString(username) {
		return "", fmt.Errorf("Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores")
	}
	return username, nil
}

func loadState() (*LoadState, error) {
	cpuCount := runtime.NumCPU()
	if cpuCount < 1 {
		cpuCount = 1
	}

	var observed float64
	if val := os.Getenv("TIKTOK_TEST_LOAD_PER_CPU"); val != "" {
		parsed, err := strconv.ParseFloat(val, 64)
		if err != nil {
			return nil, fmt.Errorf("Invalid TIKTOK_TEST_LOAD_PER_CPU value")
		}
		observed = parsed
	} else {
		// Simulate load average - in real implementation you'd need to get system load
		observed = 0.0 // Placeholder - would need platform-specific implementation
	}

	maximum := DEFAULT_MAX_LOAD_PER_CPU
	if val := os.Getenv("TIKTOK_MAX_LOAD_PER_CPU"); val != "" {
		parsed, err := strconv.ParseFloat(val, 64)
		if err != nil {
			return nil, fmt.Errorf("Invalid TIKTOK_MAX_LOAD_PER_CPU value")
		}
		maximum = parsed
	}

	if !math.IsFinite(observed) || !math.IsFinite(maximum) || maximum <= 0 {
		return nil, fmt.Errorf("Invalid TikTok load configuration")
	}

	return &LoadState{
		Overloaded: observed > maximum,
		LoadPerCpu: observed,
		Maximum:    maximum,
	}, nil
}

func enforceLoadLimit(method string) {
	state, err := loadState()
	if err != nil {
		fmt.Fprintf(os.Stderr, "{\"status\":\"technical_error\",\"method\":\"%s\",\"message\":\"%s\"}\n", method, err.Error())
		os.Exit(2)
	}
	
	if !state.Overloaded {
		return
	}
	
	result := map[string]interface{}{
		"status":      "overloaded",
		"method":      method,
		"loadPerCpu":  math.Round(state.LoadPerCpu*1000) / 1000,
		"maximum":     state.Maximum,
		"message":     "Host is overloaded; retry on another node or later",
	}
	
	jsonData, _ := json.Marshal(result)
	fmt.Fprintf(os.Stderr, "%s\n", jsonData)
	os.Exit(75)
}

func liveHrefSelectors(username string) []string {
	href := "/@" + username + "/live"
	return []string{fmt.Sprintf("a[href=\"%s\"]", href), fmt.Sprintf("a[href^=\"%s?\"]", href)}
}

func isAllowedStreamUrl(value string) bool {
	// Simplified URL parsing - in real implementation you'd use net/url
	if !strings.HasPrefix(value, "https://") {
		return false
	}
	
	// Extract hostname from URL (simplified)
	parts := strings.Split(strings.TrimPrefix(value, "https://"), "/")
	if len(parts) == 0 {
		return false
	}
	hostname := strings.ToLower(parts[0])
	path := strings.ToLower(strings.Join(parts[1:], "/"))
	
	return strings.Contains(path, ".flv") && 
		   TIKTOK_CDN_PATTERN.MatchString(hostname)
}

func isSuccessfulStreamResponse(status int, value string) bool {
	return status >= 200 && status < 300 && isAllowedStreamUrl(value)
}

func qualityKeyFromUrl(value string) string {
	// Simplified URL parsing
	parts := strings.Split(strings.TrimPrefix(value, "https://"), "/")
	if len(parts) == 0 {
		return ""
	}
	path := strings.ToLower(strings.Join(parts[1:], "/"))
	
	matches := QUALITY_URL_PATTERN.FindStringSubmatch(path)
	if len(matches) > 1 {
		return matches[1]
	}
	return ""
}

func normalizeExtractorResult(value *ExtractorResult, method string, username string) *ExtractorResult {
	technicalError := &ExtractorResult{
		Success: false,
		Status:  "technical_error",
		Method:  method,
		Username: username,
		Message: "invalid extractor result",
	}
	
	if value == nil {
		return technicalError
	}
	
	if value.Success {
		if value.Status != "live" || !isAllowedStreamUrl(value.URL) {
			return technicalError
		}
		return &ExtractorResult{
			Success: true,
			Status:  "live",
			Method:  value.Method,
			Username: value.Username,
			URL:     value.URL,
		}
	}
	
	status := value.Status
	if !FAILURE_STATUSES[status] {
		status = "technical_error"
	}
	
	return &ExtractorResult{
		Success: false,
		Status:  status,
		Method:  value.Method,
		Username: value.Username,
		Message: value.Message,
	}
}

func classifyFinalFailure(results []*ExtractorResult) string {
	statuses := make(map[string]bool)
	for _, result := range results {
		if result != nil && FAILURE_STATUSES[result.Status] {
			statuses[result.Status] = true
		}
	}
	
	if statuses["overloaded"] {
		return "overloaded"
	}
	if statuses["restricted"] {
		return "restricted"
	}
	if statuses["technical_error"] {
		return "technical_error"
	}
	if statuses["offline"] {
		return "offline"
	}
	if statuses["dependency_missing"] {
		return "dependency_missing"
	}
	return "technical_error"
}

func exitCodeForResult(result *ExtractorResult) int {
	if result != nil && result.Success && result.Status == "live" {
		return 0
	}
	if result != nil && result.Status == "overloaded" {
		return 75
	}
	if result != nil && (result.Status == "offline" || result.Status == "restricted") {
		return 1
	}
	return 2
}

func classifyDirectLiveState(params DirectLiveState) *LiveStateResult {
	expectedPath := "/@" + params.Username + "/live"
	if params.CurrentPath != expectedPath {
		return &LiveStateResult{Status: "offline", Reason: "target live page redirected"}
	}
	
	if params.SuccessfulStreamResponse {
		return &LiveStateResult{Status: "live", Reason: "successful TikTok CDN stream response"}
	}
	
	normalizedBody := strings.ToLower(regexp.MustCompile(`\s+`).ReplaceAllString(params.BodyText, " "))
	normalizedTitle := strings.ToLower(params.Title)
	accountLiveTitle := strings.Contains(normalizedTitle, "(@"+strings.ToLower(params.Username)+") is live")
	
	endedMarkers := []string{
		"live has ended",
		"das live ist beendet",
		"live wurde beendet",
		"dieses live ist beendet",
		"stream has ended",
	}
	
	for _, marker := range endedMarkers {
		if strings.Contains(normalizedBody, marker) {
			return &LiveStateResult{Status: "offline", Reason: "target live page reports ended stream"}
		}
	}
	
	restrictionMarkers := []string{
		"dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten",
		"melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen",
		"bei tiktok anmelden",
		"melde dich an für das volle live-erlebnis",
		"melde dich an für das vollständige erlebnis",
		"this live may contain content that could be uncomfortable",
		"log in to tiktok",
		"log in for the full live experience",
		"mature content",
		"age-restricted",
		"viewer discretion",
	}
	
	if accountLiveTitle {
		for _, marker := range restrictionMarkers {
			if strings.Contains(normalizedBody, marker) {
				return &LiveStateResult{Status: "restricted", Reason: "target live page requires authentication"}
			}
		}
		return &LiveStateResult{Status: "restricted", Reason: "target is live but no accessible media response was available"}
	}
	
	return &LiveStateResult{Status: "offline", Reason: "no account-specific live signal"}
}

func forcedOffline(method string, username string) bool {
	if os.Getenv("TIKTOK_TEST_OFFLINE") != "1" {
		return false
	}
	
	result := map[string]interface{}{
		"success": false,
		"status":  "offline",
		"method":  method,
		"username": username,
		"message": "forced offline test mode",
	}
	
	jsonData, _ := json.Marshal(result)
	fmt.Fprintf(os.Stderr, "%s\n", jsonData)
	return true
}
