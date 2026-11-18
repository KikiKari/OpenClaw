// abstraction-provenance: {"artifact_sha256": "2d9da1af31c895513e84e962cdc03424742129bd46ca2fb791cfd5410119cd0a", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "go"}
// github_publisher.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// QueueArtifact queues an artifact for publishing
func QueueArtifact(state map[string]interface{}, root, path string) error {
	rootAbs, err := filepath.Abs(root)
	if err != nil {
		return err
	}

	pathAbs, err := filepath.Abs(path)
	if err != nil {
		return err
	}

	// Check if path is a symlink
	if info, err := os.Lstat(path); err == nil && info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("artifact must not be a symlink")
	}

	relPath, err := filepath.Rel(rootAbs, pathAbs)
	if err != nil {
		return err
	}

	parts := strings.Split(filepath.ToSlash(relPath), "/")
	if len(parts) == 0 || parts[0] == "" {
		return fmt.Errorf("artifact is outside a language directory")
	}

	validDirs := map[string]bool{
		"perl5":      true,
		"powershell": true,
		"perl6":      true,
		"tcl":        true,
		"javascript": true,
		"ruby":       true,
		"python":     true,
		"lua":        true,
		"shell":      true,
		"go":         true,
	}

	if !validDirs[parts[0]] {
		return fmt.Errorf("artifact is outside a language directory")
	}

	content, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	hash := sha256.Sum256(content)
	hashStr := fmt.Sprintf("%x", hash)

	if _, exists := state["ausstehende_veroeffentlichungen"]; !exists {
		state["ausstehende_veroeffentlichungen"] = make(map[string]interface{})
	}

	state["ausstehende_veroeffentlichungen"].(map[string]interface{})[relPath] = hashStr
	return nil
}

// PublishPending publishes queued artifacts to GitHub
func PublishPending(root string, state map[string]interface{}, save func(map[string]interface{}) error, token string) bool {
	pending, exists := state["ausstehende_veroeffentlichungen"]
	if !exists {
		pending = make(map[string]interface{})
		state["ausstehende_veroeffentlichungen"] = pending
	}

	pendingMap, ok := pending.(map[string]interface{})
	if !ok {
		fmt.Println("invalid publication queue")
		return false
	}

	if len(pendingMap) == 0 {
		return true
	}

	if token == "" || strings.TrimSpace(token) == "" {
		return false
	}

	rootAbs, err := filepath.Abs(root)
	if err != nil {
		return false
	}

	headers := map[string]string{
		"Authorization":           "Bearer " + strings.TrimSpace(token),
		"Accept":                  "application/vnd.github+json",
		"X-GitHub-Api-Version":    "2022-11-28",
		"User-Agent":              "abstractions-manager",
		"Content-Type":            "application/json",
	}

	client := &http.Client{Timeout: 60 * time.Second}
	success := true

	for name, expected := range pendingMap {
		expectedStr, ok := expected.(string)
		if !ok {
			success = false
			continue
		}

		fullPath := filepath.Join(rootAbs, filepath.FromSlash(name))

		// Check if path is a symlink
		if info, err := os.Lstat(fullPath); err == nil && info.Mode()&os.ModeSymlink != 0 {
			success = false
			continue
		}

		// Verify path is within root
		pathAbs, err := filepath.Abs(fullPath)
		if err != nil {
			success = false
			continue
		}

		relPath, err := filepath.Rel(rootAbs, pathAbs)
		if err != nil || filepath.ToSlash(relPath) != name {
			success = false
			continue
		}

		data, err := os.ReadFile(fullPath)
		if err != nil {
			success = false
			continue
		}

		// Verify hash hasn't changed
		hash := sha256.Sum256(data)
		hashStr := fmt.Sprintf("%x", hash)
		if hashStr != expectedStr {
			success = false
			continue
		}

		lookup := func(remoteName string) (string, map[string]interface{}, error) {
			endpoint := "https://api.github.com/repos/KikiKari/OpenClaw/contents/" + remoteName
			req, err := http.NewRequest("GET", endpoint+"?ref=gateway1-abstractions", nil)
			if err != nil {
				return "", nil, err
			}

			for key, value := range headers {
				if key != "Content-Type" { // Don't set Content-Type for GET
					req.Header.Set(key, value)
				}
			}

			resp, err := client.Do(req)
			if err != nil {
				return "", nil, err
			}
			defer resp.Body.Close()

			if resp.StatusCode == 404 {
				return endpoint, nil, nil
			}

			if resp.StatusCode < 200 || resp.StatusCode >= 300 {
				return "", nil, fmt.Errorf("HTTP error %d", resp.StatusCode)
			}

			var result map[string]interface{}
			body, err := io.ReadAll(resp.Body)
			if err != nil {
				return "", nil, err
			}

			if err := json.Unmarshal(body, &result); err != nil {
				return "", nil, err
			}

			return endpoint, result, nil
		}

		same := func(existing map[string]interface{}) bool {
			if existing == nil {
				return false
			}
			
			encoding, _ := existing["encoding"].(string)
			content, _ := existing["content"].(string)
			
			if encoding != "base64" {
				return false
			}
			
			decoded, err := base64.StdEncoding.DecodeString(content)
			if err != nil {
				return false
			}
			
			return bytes.Equal(decoded, data)
		}

		endpoint, existing, err := lookup(name)
		if err != nil {
			success = false
			continue
		}

		if existing != nil && !same(existing) {
			candidate := strings.TrimSuffix(name, filepath.Ext(name))
			alternate := candidate + "_" + expectedStr[:12] + filepath.Ext(name)
			
			endpoint, existing, err = lookup(alternate)
			if err != nil {
				success = false
				continue
			}
			
			if existing != nil && !same(existing) {
				success = false
				continue
			}
		}

		if existing == nil {
			payload := map[string]interface{}{
				"message": "Publish script abstraction",
				"branch":  "gateway1-abstractions",
				"content": base64.StdEncoding.EncodeToString(data),
			}
			
			jsonPayload, err := json.Marshal(payload)
			if err != nil {
				success = false
				continue
			}

			req, err := http.NewRequest("PUT", endpoint, bytes.NewBuffer(jsonPayload))
			if err != nil {
				success = false
				continue
			}

			for key, value := range headers {
				req.Header.Set(key, value)
			}

			resp, err := client.Do(req)
			if err != nil {
				success = false
				continue
			}
			
			io.ReadAll(resp.Body)
			resp.Body.Close()
			
			if resp.StatusCode < 200 || resp.StatusCode >= 300 {
				success = false
				continue
			}
		}

		delete(pendingMap, name)
		if err := save(state); err != nil {
			success = false
		}
	}

	return success
}
