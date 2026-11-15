// abstraction-provenance: {"artifact_sha256": "50e02d5db212db292330b59dee5cb1d72ae8e523701a66f2bd046ae7a613b5ae", "source_sha256": "0cfda5c5495fad1eb8cbf8562ac3b851f251f1a3645890dc28e6f870336a28b5", "target_language": "go"}
// gateway_transport.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py


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
	"strconv"
	"strings"
	"time"

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
	save     func(map[string]interface{}) error
	url      string
	token    string
	timeout  time.Duration
	interval time.Duration
	client   *http.Client
	clock    func() time.Time
	sleep    func(time.Duration)
}

func NewGatewayTransport(state map[string]interface{}, save func(map[string]interface{}) error, 
	urlStr string, token string, timeout int, interval int) (*GatewayTransport, error) {
	
	parsed, err := url.Parse(urlStr)
	if err != nil {
		return nil, fmt.Errorf("invalid Gateway URL: %v", err)
	}
	
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return nil, fmt.Errorf("invalid Gateway URL")
	}
	
	if parsed.Scheme == "http" && parsed.Hostname() != "127.0.0.1" && parsed.Hostname() != "localhost" && parsed.Hostname() != "::1" {
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

func (gt *GatewayTransport) _request(node string, request map[string]interface{}, deviceID interface{}) (map[string]interface{}, error) {
	payloadData := map[string]interface{}{
		"node":      node,
		"device_id": deviceID,
		"request":   request,
	}
	
	payloadBytes, err := json.Marshal(payloadData)
	if err != nil {
		return nil, &TransportUnresolved{"failed to marshal request", err}
	}
	
	req, err := http.NewRequest("POST", gt.url, bytes.NewBuffer(payloadBytes))
	if err != nil {
		return nil, &TransportUnresolved{"failed to create request", err}
	}
	
	req.Header.Set("Authorization", "Bearer "+gt.token)
	req.Header.Set("Content-Type", "application/json")
	
	ctx, cancel := context.WithTimeout(context.Background(), 150*time.Second)
	defer cancel()
	
	if node == "node4" {
		ctx, cancel = context.WithTimeout(context.Background(), 150*time.Second)
		defer cancel()
	} else {
		ctx, cancel = context.WithTimeout(context.Background(), 40*time.Second)
		defer cancel()
	}
	
	req = req.WithContext(ctx)
	
	resp, err := gt.client.Do(req)
	if err != nil {
		return nil, &TransportUnresolved{"Gateway request failed", err}
	}
	defer resp.Body.Close()
	
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, &TransportUnresolved{"failed to read response", err}
	}
	
	if len(raw) > 4000000 {
		return nil, fmt.Errorf("response too large")
	}
	
	var data map[string]interface{}
	if err := json.Unmarshal(raw, &data); err != nil {
		return nil, fmt.Errorf("invalid gateway response: %v", err)
	}
	
	if _, ok := data["result"]; !ok {
		return nil, fmt.Errorf("invalid gateway response")
	}
	
	if deviceID != nil {
		if dataDeviceID, ok := data["device_id"]; !ok || dataDeviceID != deviceID {
			return nil, fmt.Errorf("gateway device identity mismatch")
		}
	}
	
	result, ok := data["result"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid result format")
	}
	
	return result, nil
}

func (gt *GatewayTransport) Available() (map[string]interface{}, error) {
	request := map[string]interface{}{
		"operation": "availability",
	}
	
	result, err := gt._request("node1", request, nil)
	if err != nil {
		return nil, &TransportUnresolved{"invalid node availability", err}
	}
	
	return result, nil
}

func (gt *GatewayTransport) _release(original map[string]interface{}, entry map[string]interface{}) {
	if released, ok := entry["released"].(bool); ok && released {
		return
	}
	
	jobID, _ := original["job_id"].(string)
	attemptID, _ := original["attempt_id"].(string)
	selectedNode, _ := original["selected_node"].(string)
	selectedDeviceID := original["selected_device_id"]
	targetLanguage, _ := original["target_language"].(string)
	
	request := map[string]interface{}{
		"operation":  "release",
		"job_id":     jobID,
		"attempt_id": attemptID,
	}
	
	_, err := gt._request(selectedNode, request, selectedDeviceID)
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
		if entry, ok := v.(map[string]interface{}); ok {
			status, hasStatus := entry["status"].(string)
			job, hasJob := entry["job"].(map[string]interface{})
			
			if hasStatus && (status == "completed" || status == "failed" || status == "unknown") && hasJob {
				gt._release(job, entry)
			}
		}
	}
}

func (gt *GatewayTransport) Call(job map[string]interface{}) (map[string]interface{}, error) {
	sourceSHA256, hasSourceSHA256 := job["source_sha256"].(string)
	targetLanguage, hasTargetLanguage := job["target_language"].(string)
	selectedDeviceID, hasSelectedDeviceID := job["selected_device_id"]
	
	if !hasSourceSHA256 || !hasTargetLanguage || !hasSelectedDeviceID {
		return nil, fmt.Errorf("missing source identity")
	}
	
	key := sourceSHA256 + ":" + targetLanguage
	
	auftraege, ok := gt.state["auftraege"].(map[string]interface{})
	if !ok {
		auftraege = make(map[string]interface{})
		gt.state["auftraege"] = auftraege
	}
	
	entry, exists := auftraege[key]
	fresh := !exists
	
	var original map[string]interface{}
	if fresh {
		original = make(map[string]interface{})
		for k, v := range job {
			original[k] = v
		}
		
		attemptID := uuid.New().String()
		original["attempt_id"] = attemptID
		
		entry = map[string]interface{}{
			"job":   original,
			"status": "submitted",
		}
		auftraege[key] = entry
		
		// If this write fails there must be no remote submission.
		if err := gt.save(gt.state); err != nil {
			return nil, err
		}
	} else {
		entryMap, ok := entry.(map[string]interface{})
		if !ok {
			return nil, fmt.Errorf("invalid entry type")
		}
		jobInterface, ok := entryMap["job"]
		if !ok {
			return nil, fmt.Errorf("missing job in entry")
		}
		original, ok = jobInterface.(map[string]interface{})
		if !ok {
			return nil, fmt.Errorf("invalid job type")
		}
	}
	
	// The dispatcher verifies the job object after transport returns.
	for k, v := range original {
		job[k] = v
	}
	
	entryMap := entry.(map[string]interface{})
	if response, hasResponse := entryMap["response"]; hasResponse {
		gt._release(original, entryMap)
		return response.(map[string]interface{}), nil
	}
	
	if status, hasStatus := entryMap["status"].(string); hasStatus && (status == "failed" || status == "unknown") {
		return nil, &TransportUnresolved{"attempt requires reconciliation", nil}
	}
	
	var status map[string]interface{}
	var statusErr error
	
	if fresh {
		jobID, _ := original["job_id"].(string)
		selectedNode, _ := original["selected_node"].(string)
		selectedDeviceID := original["selected_device_id"]
		
		request := map[string]interface{}{
			"operation": "execute",
			"job":       original,
		}
		
		status, statusErr = gt._request(selectedNode, request, selectedDeviceID)
		if statusErr != nil {
			// The request may have been accepted. Query, never resend.
		}
	}
	
	deadline := gt.clock().Add(gt.timeout)
	
	for {
		if status == nil {
			jobID, _ := original["job_id"].(string)
			attemptID, _ := original["attempt_id"].(string)
			selectedNode, _ := original["selected_node"].(string)
			selectedDeviceID := original["selected_device_id"]
			targetLanguage, _ := original["target_language"].(string)
			
			request := map[string]interface{}{
				"operation":  "status",
				"job_id":     jobID,
				"attempt_id": attemptID,
			}
			
			status, statusErr = gt._request(selectedNode, request, selectedDeviceID)
			if statusErr != nil {
				return nil, &TransportUnresolved{"attempt is not known by the node", statusErr}
			}
		}
		
		if _, ok := status["status"]; !ok {
			return nil, &TransportUnresolved{"attempt is not known by the node", nil}
		}
		
		jobIDMatch := status["job_id"] == original["job_id"]
		attemptIDMatch := status["attempt_id"] == original["attempt_id"]
		selectedNodeMatch := status["selected_node"] == original["selected_node"]
		targetLanguageMatch := status["target_language"] == original["target_language"]
		
		if !(jobIDMatch && attemptIDMatch && selectedNodeMatch && targetLanguageMatch) {
			return nil, &TransportUnresolved{"status identity mismatch", nil}
		}
		
		state, ok := status["status"].(string)
		if !ok {
			return nil, &TransportUnresolved{"invalid state", nil}
		}
		
		if state == "completed" {
			response, hasResponse := status["response"].(map[string]interface{})
			if !hasResponse {
				return nil, &TransportUnresolved{"invalid translation result", nil}
			}
			
			statusOk, hasStatus := response["status"].(string)
			if !hasStatus || statusOk != "ok" {
				return nil, &TransportUnresolved{"invalid translation result", nil}
			}
			
			jobIDMatch := response["job_id"] == original["job_id"]
			selectedNodeMatch := response["selected_node"] == original["selected_node"]
			targetLanguageMatch := response["target_language"] == original["target_language"]
			code, hasCode := response["code"].(string)
			
			if !(jobIDMatch && selectedNodeMatch && targetLanguageMatch && hasCode && strings.TrimSpace(code) != "") {
				return nil, &TransportUnresolved{"invalid translation result", nil}
			}
			
			entryMap["response"] = response
			entryMap["status"] = "completed"
			
			if err := gt.save(gt.state); err != nil {
				return nil, err
			}
			
			gt._release(original, entryMap)
			return response, nil
		}
		
		if state == "failed" || state == "unknown" {
			entryMap["status"] = state
			
			if err := gt.save(gt.state); err != nil {
				return nil, err
			}
			
			gt._release(original, entryMap)
			return nil, &TransportUnresolved{"attempt requires reconciliation", nil}
		}
		
		if state != "running" || gt.clock().After(deadline) {
			return nil, &TransportUnresolved{"attempt is unresolved", nil}
		}
		
		gt.sleep(gt.interval)
		status = nil
	}
}
