// abstraction-provenance: {"artifact_sha256": "1b8a292477c9290288393478ecd7c03960f61fe1ff2299a20f187100f85bb6ca", "source_sha256": "0cfda5c5495fad1eb8cbf8562ac3b851f251f1a3645890dc28e6f870336a28b5", "target_language": "go"}
// gateway_transport.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
)

type TransportUnresolved struct {
	message string
	err     error
}

func (e *TransportUnresolved) Error() string {
	if e.err != nil {
		return fmt.Sprintf("%s: %v", e.message, e.err)
	}
	return e.message
}

func (e *TransportUnresolved) Unwrap() error {
	return e.err
}

func gatewayToken() string {
	token := strings.TrimSpace(os.Getenv("OPENCLAW_GATEWAY_TOKEN"))
	if token != "" {
		return token
	}
	configPath := os.Getenv("OPENCLAW_CONFIG_PATH")
	if configPath == "" {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return ""
		}
		configPath = filepath.Join(homeDir, ".openclaw", "openclaw.json")
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		return ""
	}
	var config map[string]interface{}
	if err := json.Unmarshal(data, &config); err != nil {
		return ""
	}
	gateway, ok := config["gateway"].(map[string]interface{})
	if !ok {
		return ""
	}
	auth, ok := gateway["auth"].(map[string]interface{})
	if !ok {
		return ""
	}
	tokenVal, ok := auth["token"].(string)
	if !ok || strings.HasPrefix(tokenVal, "${") {
		return ""
	}
	return strings.TrimSpace(tokenVal)
}

type GatewayTransport struct {
	state    map[string]interface{}
	save     func(map[string]interface{})
	url      string
	token    string
	timeout  time.Duration
	interval time.Duration
	client   *http.Client
	clock    func() time.Time
	sleep    func(time.Duration)
}

func NewGatewayTransport(state map[string]interface{}, save func(map[string]interface{}), 
	urlStr string, token string, timeout int, interval int) (*GatewayTransport, error) {
	
	parsedURL, err := url.Parse(urlStr)
	if err != nil {
		return nil, fmt.Errorf("invalid Gateway URL: %v", err)
	}
	if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		return nil, fmt.Errorf("invalid Gateway URL")
	}
	if parsedURL.Hostname() == "" {
		return nil, fmt.Errorf("invalid Gateway URL")
	}
	if parsedURL.Scheme == "http" && 
	   parsedURL.Hostname() != "127.0.0.1" && 
	   parsedURL.Hostname() != "localhost" && 
	   parsedURL.Hostname() != "::1" {
		return nil, fmt.Errorf("unencrypted Gateway must use loopback")
	}
	if strings.TrimSpace(token) == "" || timeout <= 0 || interval <= 0 {
		return nil, fmt.Errorf("Gateway token and positive timeouts required")
	}

	return &GatewayTransport{
		state:    state,
		save:     save,
		url:      urlStr,
		token:    strings.TrimSpace(token),
		timeout:  time.Duration(timeout) * time.Second,
		interval: time.Duration(interval) * time.Second,
		client:   &http.Client{},
		clock:    time.Now,
		sleep:    time.Sleep,
	}, nil
}

func (gt *GatewayTransport) request(node string, request map[string]interface{}, deviceID interface{}) (map[string]interface{}, error) {
	payloadData := map[string]interface{}{
		"node":      node,
		"device_id": deviceID,
		"request":   request,
	}
	payloadBytes, err := json.Marshal(payloadData)
	if err != nil {
		return nil, &TransportUnresolved{"Failed to marshal request", err}
	}

	req, err := http.NewRequest("POST", gt.url, bytes.NewBuffer(payloadBytes))
	if err != nil {
		return nil, &TransportUnresolved{"Failed to create HTTP request", err}
	}
	req.Header.Set("Authorization", "Bearer "+gt.token)
	req.Header.Set("Content-Type", "application/json")

	timeout := 40 * time.Second
	if node == "node4" {
		timeout = 150 * time.Second
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	req = req.WithContext(ctx)

	resp, err := gt.client.Do(req)
	if err != nil {
		return nil, &TransportUnresolved{"Gateway request failed", err}
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(io.LimitReader(resp.Body, 4000001))
	if err != nil {
		return nil, &TransportUnresolved{"Failed to read response", err}
	}
	if len(raw) > 4000000 {
		return nil, &TransportUnresolved{"response too large", nil}
	}

	var data map[string]interface{}
	if err := json.Unmarshal(raw, &data); err != nil {
		return nil, &TransportUnresolved{"invalid gateway response", err}
	}
	if _, ok := data["result"]; !ok {
		return nil, &TransportUnresolved{"invalid gateway response", nil}
	}

	if deviceID != nil {
		if respDeviceID, ok := data["device_id"]; !ok || respDeviceID != deviceID {
			return nil, &TransportUnresolved{"gateway device identity mismatch", nil}
		}
	}

	result, ok := data["result"].(map[string]interface{})
	if !ok {
		return nil, &TransportUnresolved{"invalid gateway response format", nil}
	}
	return result, nil
}

func (gt *GatewayTransport) Available() (map[string]interface{}, error) {
	request := map[string]interface{}{
		"operation": "availability",
	}
	result, err := gt.request("node1", request, nil)
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (gt *GatewayTransport) release(original map[string]interface{}, entry map[string]interface{}) {
	if entry["released"] != nil && entry["released"].(bool) {
		return
	}
	
	request := map[string]interface{}{
		"operation":  "release",
		"job_id":     original["job_id"],
		"attempt_id": original["attempt_id"],
	}
	
	_, err := gt.request(original["selected_node"].(string), request, original["selected_device_id"])
	if err != nil {
		return // Retry cleanup later; the result is durable in manager state.
	}
	
	entry["released"] = true
	gt.save(gt.state)
}

func (gt *GatewayTransport) ReleasePending() {
	auftraege, ok := gt.state["auftraege"].(map[string]interface{})
	if !ok {
		return
	}
	
	for _, v := range auftraege {
		entry, ok := v.(map[string]interface{})
		if !ok {
			continue
		}
		
		status, hasStatus := entry["status"]
		job, hasJob := entry["job"].(map[string]interface{})
		
		if hasStatus && hasJob {
			statusStr, ok := status.(string)
			if ok && (statusStr == "completed" || statusStr == "failed" || statusStr == "unknown") {
				gt.release(job, entry)
			}
		}
	}
}

func (gt *GatewayTransport) Call(job map[string]interface{}) (map[string]interface{}, error) {
	sourceSHA256, hasSource := job["source_sha256"].(string)
	targetLang, hasTarget := job["target_language"].(string)
	deviceID, hasDevice := job["selected_device_id"]
	
	if !hasSource || !hasTarget || !hasDevice {
		return nil, fmt.Errorf("missing source identity")
	}
	
	key := sourceSHA256 + ":" + targetLang
	
	auftraege, ok := gt.state["auftraege"].(map[string]interface{})
	if !ok {
		auftraege = make(map[string]interface{})
		gt.state["auftraege"] = auftraege
	}
	
	entry, exists := auftraege[key]
	fresh := !exists
	
	if fresh {
		// Create a copy of job with new attempt_id
		original := make(map[string]interface{})
		for k, v := range job {
			original[k] = v
		}
		original["attempt_id"] = uuid.New().String()
		
		entry = map[string]interface{}{
			"job":    original,
			"status": "submitted",
		}
		auftraege[key] = entry
		
		// If this write fails there must be no remote submission.
		gt.save(gt.state)
	}
	
	originalMap := entry.(map[string]interface{})["job"].(map[string]interface{})
	
	// The dispatcher verifies the job object after transport returns.
	for k, v := range originalMap {
		job[k] = v
	}
	
	entryMap := entry.(map[string]interface{})
	if entryMap["response"] != nil {
		gt.release(originalMap, entryMap)
		return entryMap["response"].(map[string]interface{}), nil
	}
	
	if status, ok := entryMap["status"].(string); ok && (status == "failed" || status == "unknown") {
		return nil, &TransportUnresolved{"attempt requires reconciliation", nil}
	}
	
	var status map[string]interface{}
	if fresh {
		request := map[string]interface{}{
			"operation": "execute",
			"job":       originalMap,
		}
		
		var err error
		status, err = gt.request(originalMap["selected_node"].(string), request, originalMap["selected_device_id"])
		if err != nil {
			// The request may have been accepted. Query, never resend.
			status = nil
		}
	}
	
	deadline := gt.clock().Add(gt.timeout)
	for {
		if status == nil {
			request := map[string]interface{}{
				"operation":  "status",
				"job_id":     originalMap["job_id"],
				"attempt_id": originalMap["attempt_id"],
			}
			
			var err error
			status, err = gt.request(originalMap["selected_node"].(string), request, originalMap["selected_device_id"])
			if err != nil {
				return nil, &TransportUnresolved{"attempt is not known by the node", err}
			}
		}
		
		if statusMap, ok := status["status"]; !ok {
			return nil, &TransportUnresolved{"attempt is not known by the node", nil}
		} else {
			if anyMismatch(status, originalMap, []string{"job_id", "attempt_id", "selected_node", "target_language"}) {
				return nil, &TransportUnresolved{"status identity mismatch", nil}
			}
			
			state := statusMap.(string)
			if state == "completed" {
				response, hasResponse := status["response"].(map[string]interface{})
				if !hasResponse {
					return nil, &TransportUnresolved{"invalid translation result", nil}
				}
				
				statusField, hasStatus := response["status"].(string)
				if !hasStatus || statusField != "ok" {
					return nil, &TransportUnresolved{"invalid translation result", nil}
				}
				
				if anyMismatch(response, originalMap, []string{"job_id", "selected_node", "target_language"}) {
					return nil, &TransportUnresolved{"invalid translation result", nil}
				}
				
				code, hasCode := response["code"].(string)
				if !hasCode || strings.TrimSpace(code) == "" {
					return nil, &TransportUnresolved{"invalid translation result", nil}
				}
				
				entryMap["response"] = response
				entryMap["status"] = "completed"
				gt.save(gt.state)
				gt.release(originalMap, entryMap)
				return response, nil
			}
			
			if state == "failed" || state == "unknown" {
				entryMap["status"] = state
				gt.save(gt.state)
				gt.release(originalMap, entryMap)
				return nil, &TransportUnresolved{"attempt requires reconciliation", nil}
			}
			
			if state != "running" || gt.clock().After(deadline) {
				return nil, &TransportUnresolved{"attempt is unresolved", nil}
			}
			
			gt.sleep(gt.interval)
			status = nil
		}
	}
}

func anyMismatch(status map[string]interface{}, original map[string]interface{}, keys []string) bool {
	for _, k := range keys {
		if status[k] != original[k] {
			return true
		}
	}
	return false
}

func main() {
	// This would be the entry point if this were a standalone program
	// Since this is a library module, main is just a placeholder
	fmt.Println("GatewayTransport package loaded")
}
