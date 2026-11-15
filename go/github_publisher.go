// abstraction-provenance: {"artifact_sha256": "7553d46240a2ca57963ec4e67c6abcd962e96181a30f87313d3647b937740173", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "go"}
// github_publisher.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py


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

// queueArtifact queues an artifact for publishing
func queueArtifact(state map[string]interface{}, root string, path string) error {
	rootAbs, err := filepath.Abs(root)
	if err != nil {
		return err
	}

	pathAbs, err := filepath.Abs(path)
	if err != nil {
		return err
	}

	// Check if path is a symlink
 fileInfo, err := os.Lstat(pathAbs)
	if err != nil {
		return err
	}
	if fileInfo.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("artifact must not be a symlink")
	}

	// Get relative path
	relPath, err := filepath.Rel(rootAbs, pathAbs)
	if err != nil {
		return err
	}

	// Validate that artifact is in a language directory
	parts := strings.Split(relPath, string(filepath.Separator))
	if len(parts) == 0 || parts[0] == "" {
		return fmt.Errorf("artifact is outside a language directory")
	}

	validLangDirs := map[string]bool{
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

	if !validLangDirs[parts[0]] {
		return fmt.Errorf("artifact is outside a language directory")
	}

	// Read file content and calculate SHA256 hash
	content, err := os.ReadFile(pathAbs)
	if err != nil {
		return err
	}

	hash := sha256.Sum256(content)
	hashStr := fmt.Sprintf("%x", hash)

	// Initialize pending publications map if needed
	if _, exists := state["ausstehende_veroeffentlichungen"]; !exists {
		state["ausstehende_veroeffentlichungen"] = make(map[string]interface{})
	}

	pending := state["ausstehende_veroeffentlichungen"].(map[string]interface{})
	pending[filepath.ToSlash(relPath)] = hashStr

	return nil
}

// publishPending publishes queued artifacts to GitHub
func publishPending(root string, state map[string]interface{}, save func(map[string]interface{}) error, token string) bool {
	pendingRaw, exists := state["ausstehende_veroeffentlichungen"]
	if !exists {
		return true
	}

	pending, ok := pendingRaw.(map[string]interface{})
	if !ok {
		fmt.Println("invalid publication queue")
		return false
	}

	if len(pending) == 0 {
		return true
	}

	if token == "" || strings.TrimSpace(token) == "" {
		return false
	}

	rootAbs, err := filepath.Abs(root)
	if err != nil {
		fmt.Printf("Error resolving root path: %v\n", err)
		return false
	}

	headers := map[string]string{
		"Authorization":           "Bearer " + strings.TrimSpace(token),
		"Accept":                 "application/vnd.github+json",
		"X-GitHub-Api-Version":   "2022-11-28",
		"User-Agent":             "abstractions-manager",
		"Content-Type":          "application/json",
	}

	success := true

	// Create HTTP client with timeout
	client := &http.Client{
		Timeout: 60 * time.Second,
	}

	for name, expected := range pending {
		func() {
			defer func() {
				if r := recover(); r != nil {
					success = false
				}
			}()

			path := filepath.Join(rootAbs, filepath.FromSlash(name))

			// Check if path is a symlink
			fileInfo, err := os.Lstat(path)
			if err != nil {
				success = false
				return
			}
			if fileInfo.Mode()&os.ModeSymlink != 0 {
				fmt.Println("invalid queued path")
				success = false
				return
			}

			// Verify relative path matches
			pathAbs, err := filepath.Abs(path)
			if err != nil {
				success = false
				return
			}
			relPath, err := filepath.Rel(rootAbs, pathAbs)
			if err != nil || filepath.ToSlash(relPath) != name {
				fmt.Println("invalid queued path")
				success = false
				return
			}

			// Read file content and verify hash
			data, err := os.ReadFile(path)
			if err != nil {
				success = false
				return
			}

			hash := sha256.Sum256(data)
			hashStr := fmt.Sprintf("%x", hash)
			if hashStr != expected {
				fmt.Println("queued artifact changed")
				success = false
				return
			}

			// lookup function to check if file exists on GitHub
			lookup := func(remoteName string) (string, map[string]interface{}, error) {
				endpoint := "https://api.github.com/repos/KikiKari/OpenClaw/contents/" + remoteName
				req, err := http.NewRequest("GET", endpoint+"?ref=gateway1-abstractions", nil)
				if err != nil {
					return "", nil, err
				}

				for key, value := range headers {
					if key != "Content-Type" { // Don't add Content-Type to GET requests
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
					return "", nil, fmt.Errorf("HTTP error: %d", resp.StatusCode)
				}

				var result map[string]interface{}
				body, err := io.ReadAll(resp.Body)
				if err != nil {
					return "", nil, err
				}

				err = json.Unmarshal(body, &result)
				if err != nil {
					return "", nil, err
				}

				return endpoint, result, nil
			}

			// same function to compare existing file content
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
				return
			}

			if existing != nil && !same(existing) {
				// Handle conflicts by creating alternate filename
				candidate := strings.TrimSuffix(name, filepath.Ext(name))
				expectedStr, _ := expected.(string)
				alternate := candidate + "_" + expectedStr[:12] + filepath.Ext(name)
				
				endpoint, existing, err = lookup(alternate)
				if err != nil {
					success = false
					return
				}
				
				if existing != nil && !same(existing) {
					fmt.Println("remote artifact conflict")
					success = false
					return
				}
			}

			if existing == nil {
				// Prepare PUT request to create/update file
				content := map[string]interface{}{
					"message": "Publish script abstraction",
					"branch":  "gateway1-abstractions",
					"content": base64.StdEncoding.EncodeToString(data),
				}
				
				jsonBody, err := json.Marshal(content)
				if err != nil {
					success = false
					return
				}
				
				req, err := http.NewRequest("PUT", endpoint, bytes.NewBuffer(jsonBody))
				if err != nil {
					success = false
					return
				}
				
				for key, value := range headers {
					req.Header.Set(key, value)
				}
				
				resp, err := client.Do(req)
				if err != nil {
					success = false
					return
				}
				defer resp.Body.Close()
				
				if resp.StatusCode < 200 || resp.StatusCode >= 300 {
					success = false
					return
				}
				
				// Read response to complete request
				_, err = io.ReadAll(resp.Body)
				if err != nil {
					success = false
					return
				}
			}

			// Remove from pending list
			delete(pending, name)
			err = save(state)
			if err != nil {
				success = false
				return
			}
		}()
	}

	return success
}
