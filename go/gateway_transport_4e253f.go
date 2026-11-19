// abstraction-provenance: {"artifact_sha256": "bae8ce6c80e169ea7472ff32854ad061601eb171b348d9cb2e3a1666f3ff206e", "source_sha256": "4e253f02b715d7d8ae256f0b72f993ca4646b5e466c1f39a9d5e2d3864a4fe77", "target_language": "go"}
// gateway_transport.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

type TransportUnresolved struct {
	err error
}

func (e *TransportUnresolved) Error() string {
	if e.err != nil {
		return fmt.Sprintf("Gateway request failed: %v", e.err)
	}
	return "Gateway request failed"
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
	mu       sync.Mutex
}

func NewGatewayTransport(state map[string]interface{}, save func(map[string]interface{}) error,
	url, token string, timeout, interval int) (*GatewayTransport, error) {
	parsedURL, err := net/url.ParseRequestURI(url)
	if err != nil || (parsedURL.Scheme != "http" && parsedURL.Scheme != "https") || parsedURL.Hostname() == "" {
		return nil, errors.New("invalid Gateway URL")
	}
	if parsedURL.Scheme == "http" && !isLoopbackAddress(parsedURL.Hostname()) {
		return nil, errors.New("unencrypted Gateway must use loopback")
	}
	if strings.TrimSpace(token) == "" || timeout <= 0 || interval <= 0 {
		return nil, errors.New("Gateway token and positive timeouts required")
	}

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: false},
	}
	client := &http.Client{Transport: tr}

	return &GatewayTransport{
		state:    state,
		save:     save,
		url:      url,
		token:    strings.TrimSpace(token),
		timeout:  time.Duration(timeout) * time.Second,
		interval: time.Duration(interval) * time.Second,
		client:   client,
		clock:    time.Now,
		sleep:    time.Sleep,
	}, nil
}

func isLoopbackAddress(hostname string) bool {
	addrs, err := net.LookupHost(hostname)
	if err != nil {
		return hostname == "localhost" || hostname == "127.0.0.1" || hostname == "::1"
	}
	for _, addr := range addrs {
		ip := net.ParseIP(addr)
		if ip != nil && ip.IsLoopback() {
			return true
		}
	}
	return false
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
		return nil, &TransportUnresolved{err: err}
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, &TransportUnresolved{err: err}
	}
	if len(body) > 4_000_000 {
		return nil, &TransportUnresolved{err: errors.New("response too large")}
	}

	var data map[string]interface{}
	if err := json.Unmarshal(body, &data); err != nil {
		return nil, &TransportUnresolved{err: err}
	}
	if _, ok := data["result"]; !ok {
		return nil, &TransportUnresolved{err: errors.New("invalid gateway response")}
	}
	if deviceID != nil {
		if devID, ok := data["device_id"]; !ok || devID != deviceID {
			return nil, &TransportUnresolved{err: errors.New("gateway device identity mismatch")}
		}
	}
	result, ok := data["result"].(map[string]interface{})
	if !ok {
		return nil, &TransportUnresolved{err: errors.New("invalid gateway response format")}
	}
	return result, nil
}

func (gt *GatewayTransport) Available() (map[string]interface{}, error) {
	result, err := gt._request("node1", map[string]interface{}{"operation": "availability"}, nil)
	if err != nil {
		return nil, &TransportUnresolved{err: err}
	}
	return result, nil
}

func (gt *GatewayTransport) _release(original map[string]interface{}, entry map[string]interface{}) {
	if released, ok := entry["released"].(bool); ok && released {
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
			"attempt_id":  original["attempt_id"],
		},
		original["selected_device_id"],
	)
	if err != nil {
		return // Retry cleanup later; the result is durable in manager state.
	}
	
	if status, ok := result["status"].(string); ok && status == "released" {
		match := true
		for _, key := range []string{"job_id", "attempt_id", "selected_node", "target_language"} {
			if result[key] != original[key] {
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
	gt.mu.Lock()
	defer gt.mu.Unlock()
	
	auftraege, ok := gt.state["auftraege"].(map[string]interface{})
	if !ok {
		return
	}
	
	for _, v := range auftraege {
		if entry, ok := v.(map[string]interface{}); ok {
			status, statusOk := entry["status"].(string)
			job, jobOk := entry["job"].(map[string]interface{})
			
			if statusOk && jobOk && (status == "completed" || status == "rejected" || status == "failed") {
				gt._release(job, entry)
			}
		}
	}
}

func (gt *GatewayTransport) Reject(job map[string]interface{}, reason string) {
	gt.mu.Lock()
	defer gt.mu.Unlock()
	
	sourceSHA256, shaOk := job["source_sha256"].(string)
	targetLanguage, langOk := job["target_language"].(string)
	if !shaOk || !langOk {
		return
	}
	key := sourceSHA256 + ":" + targetLanguage
	
	auftraege, ok := gt.state["auftraege"].(map[string]interface{})
	if !ok {
		return
	}
	
	entry, entryOk := auftraege[key].(map[string]interface{})
	if !entryOk || entry["status"] != "completed" {
		return
	}
	
	jobAttemptID, jobAttemptOk := job["attempt_id"]
	entryJob, entryJobOk := entry["job"].(map[string]interface{})
	if !jobAttemptOk || !entryJobOk {
		return
	}
	
	entryAttemptID, entryAttemptOk := entryJob["attempt_id"]
	if !entryAttemptOk || entryAttemptID != jobAttemptID {
		panic(&TransportUnresolved{err: errors.New("rejected attempt identity mismatch")})
	}
	
	entry["status"] = "rejected"
	if len(reason) > 500 {
		entry["validation_error"] = reason[:500]
	} else {
		entry["validation_error"] = reason
	}
	gt.save(gt.state)
}

func (gt *GatewayTransport) Call(job map[string]interface{}) (map[string]interface{}, error) {
	gt.mu.Lock()
	defer gt.mu.Unlock()
	
	sourceSHA256, shaOk := job["source_sha256"].(string)
	targetLanguage, langOk := job["target_language"].(string)
	selectedDeviceID, devOk := job["selected_device_id"]
	
	if !shaOk || !langOk || !devOk {
		return nil, errors.New("missing source identity")
	}
	
	key := sourceSHA256 + ":" + targetLanguage
	auftraege, ok := gt.state["auftraege"].(map[string]interface{})
	if !ok {
		auftraege = make(map[string]interface{})
		gt.state["auftraege"] = auftraege
	}
	
	entry, entryExists := auftraege[key].(map[string]interface{})
	var fresh bool
	
	if entryExists && entry["status"] == "rejected" {
		jobEntry, jobOk := entry["job"].(map[string]interface{})
		if jobOk {
			gt._release(jobEntry, entry)
		}
		
		if released, releasedOk := entry["released"].(bool); !releasedOk || !released {
			return nil, &TransportUnresolved{err: errors.New("rejected attempt release is unresolved")}
		}
		
		previous := entry
		attemptID := uuid.New().String()
		original := make(map[string]interface{})
		for k, v := range job {
			original[k] = v
		}
		original["attempt_id"] = attemptID
		
		newEntry := make(map[string]interface{})
		newEntry["job"] = original
		newEntry["status"] = "submitted"
		
		prevAttempts, prevOk := previous["previous_attempts"].([]interface{})
		if !prevOk {
			prevAttempts = make([]interface{}, 0)
		}
		
		prevAttempt := make(map[string]interface{})
		if jobID, jobIDOk := previous["job"].(map[string]interface{})["job_id"]; jobIDOk {
			prevAttempt["job_id"] = jobID
		}
		if attemptID, attemptIDOk := previous["job"].(map[string]interface{})["attempt_id"]; attemptIDOk {
			prevAttempt["attempt_id"] = attemptID
		}
		if selectedNode, selectedNodeOk := previous["job"].(map[string]interface{})["selected_node"]; selectedNodeOk {
			prevAttempt["selected_node"] = selectedNode
		}
		if validationErr, validationErrOk := previous["validation_error"]; validationErrOk {
			prevAttempt["validation_error"] = validationErr
		}
		
		newEntry["previous_attempts"] = append(prevAttempts, prevAttempt)
		auftraege[key] = newEntry
		gt.save(gt.state)
		entry = newEntry
		fresh = true
	} else {
		fresh = !entryExists
	}
	
	if !entryExists {
		attemptID := uuid.New().String()
		original := make(map[string]interface{})
		for k, v := range job {
			original[k] = v
		}
		original["attempt_id"] = attemptID
		
		entry = make(map[string]interface{})
		entry["job"] = original
		entry["status"] = "submitted"
		auftraege[key] = entry
		gt.save(gt.state)
	}
	
	original := entry["job"].(map[string]interface{})
	for k, v := range original {
		job[k] = v
	}
	
	if response, responseOk := entry["response"]; responseOk {
		gt._release(original, entry)
		return response.(map[string]interface{}), nil
	}
	
	if status, statusOk := entry["status"].(string); statusOk && (status == "failed" || status == "unknown") {
		return nil, &TransportUnresolved{err: errors.New("attempt requires reconciliation")}
	}
	
	var status map[string]interface{}
	var statusErr error
	
	if fresh {
		status, statusErr = gt._request(
			original["selected_node"].(string),
			map[string]interface{}{
				"operation": "execute",
				"job":       original,
			},
			original["selected_device_id"],
		)
		if statusErr != nil {
			// The request may have been accepted. Query, never resend.
		}
	}
	
	deadline := gt.clock().Add(gt.timeout)
	
	for {
		if status == nil {
			status, statusErr = gt._request(
				original["selected_node"].(string),
				map[string]interface{}{
					"operation":  "status",
					"job_id":     original["job_id"],
					"attempt_id": original["attempt_id"],
				},
				original["selected_device_id"],
			)
			if statusErr != nil {
				return nil, &TransportUnresolved{err: statusErr}
			}
		}
		
		if _, ok := status["status"]; !ok {
			return nil, &TransportUnresolved{err: errors.New("attempt is not known by the node")}
		}
		
		mismatch := false
		for _, k := range []string{"job_id", "attempt_id", "selected_node", "target_language"} {
			if status[k] != original[k] {
				mismatch = true
				break
			}
		}
		if mismatch {
			return nil, &TransportUnresolved{err: errors.New("status identity mismatch")}
		}
		
		state := status["status"].(string)
		if state == "completed" {
			response, responseOk := status["response"].(map[string]interface{})
			if !responseOk {
				return nil, &TransportUnresolved{err: errors.New("invalid translation result")}
			}
			
			responseStatus, statusOk := response["status"].(string)
			if !statusOk || responseStatus != "ok" {
				return nil, &TransportUnresolved{err: errors.New("invalid translation result")}
			}
			
			mismatch = false
			for _, k := range []string{"job_id", "selected_node", "target_language"} {
				if response[k] != original[k] {
					mismatch = true
					break
				}
			}
			if mismatch {
				return nil, &TransportUnresolved{err: errors.New("invalid translation result")}
			}
			
			code, codeOk := response["code"].(string)
			if !codeOk || strings.TrimSpace(code) == "" {
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
