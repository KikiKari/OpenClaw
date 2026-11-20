// abstraction-provenance: {"artifact_sha256": "fe0c2edb669517425380ff82e58b6ff1f15f2ca5972a9a57355ab19854e6b010", "source_sha256": "4e253f02b715d7d8ae256f0b72f993ca4646b5e466c1f39a9d5e2d3864a4fe77", "target_language": "go"}
// gateway_transport.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
// auch in: workspace@local:skills/script-abstractions-manager/scripts/gateway_transport.py
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
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
	err error
}

func (e *TransportUnresolved) Error() string {
	return fmt.Sprintf("TransportUnresolved: %v", e.err)
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

func NewGatewayTransport(state map[string]interface{}, save func(map[string]interface{}), urlStr, token string, timeout, interval int) (*GatewayTransport, error) {
	parsed, err := url.Parse(urlStr)
	if err != nil {
		return nil, errors.New("invalid Gateway URL")
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return nil, errors.New("invalid Gateway URL")
	}
	if parsed.Hostname() == "" {
		return nil, errors.New("invalid Gateway URL")
	}
	if parsed.Scheme == "http" && parsed.Hostname() != "127.0.0.1" && parsed.Hostname() != "localhost" && parsed.Hostname() != "::1" {
		return nil, errors.New("unencrypted Gateway must use loopback")
	}
	if strings.TrimSpace(token) == "" || timeout <= 0 || interval <= 0 {
		return nil, errors.New("Gateway token and positive timeouts required")
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
	payload := map[string]interface{}{
		"node":      node,
		"device_id": deviceID,
		"request":   request,
	}
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, &TransportUnresolved{err: err}
	}
	req, err := http.NewRequest("POST", gt.url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, &TransportUnresolved{err: err}
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
		return nil, &TransportUnresolved{err: err}
	}
	defer resp.Body.Close()
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, &TransportUnresolved{err: err}
	}
	if len(body) > 4000000 {
		return nil, &TransportUnresolved{err: errors.New("response too large")}
	}
	
	var data map[string]interface{}
	if err := json.Unmarshal(body, &data); err != nil {
		return nil, &TransportUnresolved{err: errors.New("invalid gateway response")}
	}
	if _, ok := data["result"]; !ok {
		return nil, &TransportUnresolved{err: errors.New("invalid gateway response")}
	}
	
	if deviceID != nil {
		if dataDeviceID, ok := data["device_id"]; !ok || dataDeviceID != deviceID {
			return nil, &TransportUnresolved{err: errors.New("gateway device identity mismatch")}
		}
	}
	
	result, ok := data["result"].(map[string]interface{})
	if !ok {
		return nil, &TransportUnresolved{err: errors.New("invalid gateway response")}
	}
	return result, nil
}

func (gt *GatewayTransport) Available() (map[string]interface{}, error) {
	result, err := gt._request("node1", map[string]interface{}{"operation": "availability"}, nil)
	if err != nil {
		return nil, err
	}
	if _, ok := result.(map[string]interface{}); !ok {
		return nil, &TransportUnresolved{err: errors.New("invalid node availability")}
	}
	return result, nil
}

func (gt *GatewayTransport) _release(original map[string]interface{}, entry map[string]interface{}) {
	if _, ok := entry["released"]; ok {
		return
	}
	
	defer func() {
		if r := recover(); r != nil {
			// Retry cleanup later; the result is durable in manager state.
		}
	}()
	
	result, err := gt._request(
		original["selected_node"].(string),
		map[string]interface{}{
			"operation":   "release",
			"job_id":      original["job_id"],
			"attempt_id": original["attempt_id"],
		},
		original["selected_device_id"],
	)
	if err != nil {
		return // Retry cleanup later; the result is durable in manager state.
	}
	
	resultMap, ok := result.(map[string]interface{})
	if !ok {
		return
	}
	
	if status, ok := resultMap["status"]; ok && status == "released" {
		requiredKeys := []string{"job_id", "attempt_id", "selected_node", "target_language"}
		match := true
		for _, key := range requiredKeys {
			if resultMap[key] != original[key] {
				match = false
				break
			}
		}
		if match {
			entry["released"] = true
			gt.save(gt.state)
		}
	}
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
		
		status, ok := entry["status"].(string)
		if !ok || (status != "completed" && status != "rejected" && status != "failed") {
			continue
		}
		
		job, ok := entry["job"].(map[string]interface{})
		if !ok {
			continue
		}
		
		gt._release(job, entry)
	}
}

func (gt *GatewayTransport) Reject(job map[string]interface{}, reason string) {
	sourceSHA256, ok1 := job["source_sha256"].(string)
	targetLanguage, ok2 := job["target_language"].(string)
	if !ok1 || !ok2 {
		return
	}
	
	key := sourceSHA256 + ":" + targetLanguage
	auftraege, ok := gt.state["auftraege"].(map[string]interface{})
	if !ok {
		return
	}
	
	entry, ok := auftraege[key].(map[string]interface{})
	if !ok || entry["status"] != "completed" {
		return
	}
	
	entryJob, ok := entry["job"].(map[string]interface{})
	if !ok {
		return
	}
	
	if entryJob["attempt_id"] != job["attempt_id"] {
		panic(&TransportUnresolved{err: errors.New("rejected attempt identity mismatch")})
	}
	
	entry["status"] = "rejected"
	if len(reason) > 500 {
		reason = reason[:500]
	}
	entry["validation_error"] = reason
	gt.save(gt.state)
}

func (gt *GatewayTransport) Call(job map[string]interface{}) (map[string]interface{}, error) {
	sourceSHA256, ok1 := job["source_sha256"].(string)
	targetLanguage, ok2 := job["target_language"].(string)
	selectedDeviceID, ok3 := job["selected_device_id"]
	if !ok1 || !ok2 || !ok3 {
		return nil, errors.New("missing source identity")
	}
	
	key := sourceSHA256 + ":" + targetLanguage
	auftraege, ok := gt.state["auftraege"].(map[string]interface{})
	if !ok {
		auftraege = make(map[string]interface{})
		gt.state["auftraege"] = auftraege
	}
	
	var entry map[string]interface{}
	if val, exists := auftraege[key]; exists {
		entry, _ = val.(map[string]interface{})
	}
	
	var fresh bool
	if entry != nil && entry["status"] == "rejected" {
		gt._release(entry["job"].(map[string]interface{}), entry)
		if _, ok := entry["released"]; !ok {
			return nil, &TransportUnresolved{err: errors.New("rejected attempt release is unresolved")}
		}
		
		previous := entry
		attemptID := uuid.New().String()
		original := make(map[string]interface{})
		for k, v := range job {
			original[k] = v
		}
		original["attempt_id"] = attemptID
		
		newEntry := map[string]interface{}{
			"job":    original,
			"status": "submitted",
		}
		
		if prevAttempts, ok := previous["previous_attempts"].([]interface{}); ok {
			newEntry["previous_attempts"] = prevAttempts
		} else {
			newEntry["previous_attempts"] = []interface{}{}
		}
		
		prevAttempt := map[string]interface{}{
			"job_id":         previous["job"].(map[string]interface{})["job_id"],
			"attempt_id":     previous["job"].(map[string]interface{})["attempt_id"],
			"selected_node":  previous["job"].(map[string]interface{})["selected_node"],
			"validation_error": previous["validation_error"],
		}
		
		prevAttempts := newEntry["previous_attempts"].([]interface{})
		newEntry["previous_attempts"] = append(prevAttempts, prevAttempt)
		
		auftraege[key] = newEntry
		gt.save(gt.state)
		fresh = true
		entry = newEntry
	} else {
		fresh = entry == nil
	}
	
	if entry == nil {
		attemptID := uuid.New().String()
		original := make(map[string]interface{})
		for k, v := range job {
			original[k] = v
		}
		original["attempt_id"] = attemptID
		
		entry = map[string]interface{}{
			"job":    original,
			"status": "submitted",
		}
		auftraege[key] = entry
		gt.save(gt.state)
	}
	
	original := entry["job"].(map[string]interface{})
	for k, v := range original {
		job[k] = v
	}
	
	if response, ok := entry["response"]; ok {
		gt._release(original, entry)
		return response.(map[string]interface{}), nil
	}
	
	if status, ok := entry["status"]; ok && (status == "failed" || status == "unknown") {
		return nil, &TransportUnresolved{err: errors.New("attempt requires reconciliation")}
	}
	
	var status interface{}
	if fresh {
		var err error
		status, err = gt._request(
			original["selected_node"].(string),
			map[string]interface{}{
				"operation": "execute",
				"job":       original,
			},
			original["selected_device_id"],
		)
		if err != nil {
			// The request may have been accepted. Query, never resend.
			status = nil
		}
	}
	
	deadline := gt.clock().Add(gt.timeout)
	for {
		if status == nil {
			var err error
			status, err = gt._request(
				original["selected_node"].(string),
				map[string]interface{}{
					"operation":   "status",
					"job_id":       original["job_id"],
					"attempt_id":   original["attempt_id"],
				},
				original["selected_device_id"],
			)
			if err != nil {
				return nil, err
			}
		}
		
		statusMap, ok := status.(map[string]interface{})
		if !ok {
			return nil, &TransportUnresolved{err: errors.New("attempt is not known by the node")}
		}
		
		requiredKeys := []string{"job_id", "attempt_id", "selected_node", "target_language"}
		for _, key := range requiredKeys {
			if statusMap[key] != original[key] {
				return nil, &TransportUnresolved{err: errors.New("status identity mismatch")}
			}
		}
		
		state, ok := statusMap["status"].(string)
		if !ok {
			return nil, &TransportUnresolved{err: errors.New("attempt is not known by the node")}
		}
		
		if state == "completed" {
			response, ok := statusMap["response"].(map[string]interface{})
			if !ok {
				return nil, &TransportUnresolved{err: errors.New("invalid translation result")}
			}
			
			if statusVal, ok := response["status"].(string); !ok || statusVal != "ok" {
				return nil, &TransportUnresolved{err: errors.New("invalid translation result")}
			}
			
			requiredResponseKeys := []string{"job_id", "selected_node", "target_language"}
			for _, key := range requiredResponseKeys {
				if response[key] != original[key] {
					return nil, &TransportUnresolved{err: errors.New("invalid translation result")}
				}
			}
			
			code, ok := response["code"].(string)
			if !ok || strings.TrimSpace(code) == "" {
				return nil, &TransportUnresolved{err: errors.New("invalid translation result")}
			}
			
			entry["response"] = response
			entry["status"] = "completed"
			gt.save(gt.state)
			gt._release(original, entry)
			return response, nil
		}
		
		if state == "failed" || state == "unknown" {
			entry["status"] = state
			gt.save(gt.state)
			if state == "failed" {
				gt._release(original, entry)
			}
			return nil, &TransportUnresolved{err: errors.New("attempt requires reconciliation")}
		}
		
		if state != "running" || gt.clock().After(deadline) {
			return nil, &TransportUnresolved{err: errors.New("attempt is unresolved")}
		}
		
		gt.sleep(gt.interval)
		status = nil
	}
}

func main() {
	// This would be used as a library, so main is just a placeholder
	fmt.Println("GatewayTransport package")
}
