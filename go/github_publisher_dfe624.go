// abstraction-provenance: {"artifact_sha256": "8c3bdc849b5f53bf8bcc92324f4e2ec2f6efd2824a9acb0a43c309d5322c3c5c", "source_sha256": "dfe62418dcbef9ea8aa7f18ada4f57d0ef73593432b7c7cefd85ee87eee622b4", "target_language": "go"}
// github_publisher.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

var LANGUAGES = map[string]bool{
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
	"java":       true,
	"c":          true,
	"cpp":        true,
	"php":        true,
	"fsharp":     true,
	"css":        true,
}

func synchronizeCheckout(root string, remote string, branch string) (string, map[string]int, error) {
	if remote == "" {
		remote = "https://github.com/KikiKari/OpenClaw.git"
	}
	if branch == "" {
		branch = "gateway1-abstractions"
	}

	rootAbs, err := filepath.Abs(root)
	if err != nil {
		return "", nil, err
	}

	tmpDir, err := ioutil.TempDir("", "abstractions-snapshot-*")
	if err != nil {
		return "", nil, err
	}
	defer os.RemoveAll(tmpDir)

	snapshot := filepath.Join(tmpDir, "repo")

	ctx, cancel := timeoutContext(300 * time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "git", "clone", "--quiet", "--depth=1", "--single-branch",
		"--branch", branch, "--", remote, snapshot)
	cmd.Stdout = os.DevNull
	cmd.Stderr = os.DevNull
	if err := cmd.Run(); err != nil {
		return "", nil, err
	}

	revisionBytes, err := exec.Command("git", "-C", snapshot, "rev-parse", "HEAD").Output()
	if err != nil {
		return "", nil, err
	}
	revision := strings.TrimSpace(string(revisionBytes))

	counts := make(map[string]int)

	for _, language := range sortedLanguages() {
		source := filepath.Join(snapshot, language)
		target := filepath.Join(rootAbs, language)

		if info, err := os.Lstat(source); err == nil && info.Mode()&os.ModeSymlink != 0 {
			return "", nil, fmt.Errorf("language directory is a symlink")
		}
		if info, err := os.Lstat(target); err == nil && info.Mode()&os.ModeSymlink != 0 {
			return "", nil, fmt.Errorf("language directory is a symlink")
		}

		if _, err := os.Stat(source); err == nil {
			if !isDir(source) {
				return "", nil, fmt.Errorf("invalid remote language directory")
			}
		}

		if err := os.MkdirAll(target, 0755); err != nil {
			return "", nil, err
		}

		known := make(map[string]bool)
		targetFiles, err := ioutil.ReadDir(target)
		if err != nil {
			return "", nil, err
		}
		for _, file := range targetFiles {
			if file.Mode().IsRegular() {
				filePath := filepath.Join(target, file.Name())
				if info, err := os.Lstat(filePath); err == nil && info.Mode()&os.ModeSymlink == 0 {
					data, err := ioutil.ReadFile(filePath)
					if err == nil {
						hash := fmt.Sprintf("%x", sha256.Sum256(data))
						known[hash] = true
					}
				}
			}
		}

		var files []string
		if _, err := os.Stat(source); err == nil {
			sourceFiles, err := ioutil.ReadDir(source)
			if err != nil {
				return "", nil, err
			}
			for _, file := range sourceFiles {
				filePath := filepath.Join(source, file.Name())
				if info, err := os.Lstat(filePath); err == nil {
					if info.Mode()&os.ModeSymlink != 0 || !info.Mode().IsRegular() {
						return "", nil, fmt.Errorf("invalid remote abstraction")
					}
				}
				files = append(files, filePath)
			}
		}
		sort.Strings(files)

		counts[language] = len(files)

		for _, item := range files {
			data, err := ioutil.ReadFile(item)
			if err != nil {
				return "", nil, err
			}
			digest := fmt.Sprintf("%x", sha256.Sum256(data))
			if known[digest] {
				continue
			}

			itemName := filepath.Base(item)
			destination := filepath.Join(target, itemName)
			if _, err := os.Stat(destination); err == nil {
				ext := filepath.Ext(itemName)
				stem := strings.TrimSuffix(itemName, ext)
				destination = filepath.Join(target, stem+"_pool_"+digest+ext)
			}

			if _, err := os.Lstat(destination); err == nil {
				existingData, err := ioutil.ReadFile(destination)
				if err != nil || !bytes.Equal(existingData, data) {
					return "", nil, fmt.Errorf("local abstraction conflict")
				}
			} else {
				if err := ioutil.WriteFile(destination, data, 0644); err != nil {
					return "", nil, err
				}
			}
			known[digest] = true
		}
	}

	return revision, counts, nil
}

func updateStatusCounts(path string, revision string, counts map[string]int) error {
	content, err := ioutil.ReadFile(path)
	if err != nil {
		return err
	}
	text := string(content)

	rows := []string{"## Bestand", "", fmt.Sprintf("GitHub-Stand: `%s`", revision), ""}
	rows = append(rows, "| Zielsprache | Dateien |")
	rows = append(rows, "|---|---:|")

	languages := sortedLanguages()
	for _, language := range languages {
		if count, exists := counts[language]; exists {
			rows = append(rows, fmt.Sprintf("| %s | %d |", language, count))
		}
	}

	total := 0
	for _, count := range counts {
		total += count
	}
	rows = append(rows, fmt.Sprintf("| **gesamt** | **%d** |", total))
	rows = append(rows, "")

	re := regexp.MustCompile(`(?m)^## Bestand\n.*?(?=^## Quellen\n)`)
	newText := re.ReplaceAllStringFunc(text, func(match string) string {
		return strings.Join(rows, "\n")
	})

	if newText == text {
		return fmt.Errorf("status inventory section missing")
	}

	return ioutil.WriteFile(path, []byte(newText), 0644)
}

func queueArtifact(state map[string]interface{}, root string, path string) error {
	rootAbs, err := filepath.Abs(root)
	if err != nil {
		return err
	}

	pathInfo, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if pathInfo.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("artifact must not be a symlink")
	}

	pathAbs, err := filepath.Abs(path)
	if err != nil {
		return err
	}

	relPath, err := filepath.Rel(rootAbs, pathAbs)
	if err != nil {
		return err
	}

	if relPath != "STATUS.md" {
		parts := strings.Split(relPath, string(filepath.Separator))
		if len(parts) == 0 || !LANGUAGES[parts[0]] {
			return fmt.Errorf("artifact is outside a language directory")
		}
	}

	data, err := ioutil.ReadFile(path)
	if err != nil {
		return err
	}
	hash := fmt.Sprintf("%x", sha256.Sum256(data))

	if state["ausstehende_veroeffentlichungen"] == nil {
		state["ausstehende_veroeffentlichungen"] = make(map[string]interface{})
	}
	state["ausstehende_veroeffentlichungen"].(map[string]interface{})[relPath] = hash

	return nil
}

func publishPending(root string, state map[string]interface{}, save func(map[string]interface{}) error, token string, opener func(*http.Request) (*http.Response, error), sync func(string) (string, map[string]int, error)) (bool, error) {
	pendingInterface, exists := state["ausstehende_veroeffentlichungen"]
	pending := make(map[string]string)
	
	if exists {
		if pendingMap, ok := pendingInterface.(map[string]interface{}); ok {
			for k, v := range pendingMap {
				if vStr, ok := v.(string); ok {
					pending[k] = vStr
				}
			}
		} else {
			return false, fmt.Errorf("invalid publication queue")
		}
	}

	if len(pending) == 0 && sync == nil {
		return true, nil
	}

	if token == "" || strings.TrimSpace(token) == "" {
		return false, nil
	}

	rootAbs, err := filepath.Abs(root)
	if err != nil {
		return false, err
	}

	headers := map[string]string{
		"Authorization":           "Bearer " + strings.TrimSpace(token),
		"Accept":                 "application/vnd.github+json",
		"X-GitHub-Api-Version":  "2022-11-28",
		"User-Agent":             "abstractions-manager",
	}

	success := true
	
	entries := make([][2]string, 0, len(pending))
	for k, v := range pending {
		entries = append(entries, [2]string{k, v})
	}
	
	sort.Slice(entries, func(i, j int) bool {
		return (entries[i][0] == "STATUS.md") && (entries[j][0] != "STATUS.md")
	})

	synced := false

	for _, entry := range entries {
		name := entry[0]
		expected := entry[1]

		func() {
			defer func() {
				if r := recover(); r != nil {
					success = false
				}
			}()

			path := filepath.Join(rootAbs, name)
			
			if info, err := os.Lstat(path); err == nil && info.Mode()&os.ModeSymlink != 0 {
				panic(fmt.Errorf("invalid queued path"))
			}
			
			pathAbs, err := filepath.Abs(path)
			if err != nil {
				panic(err)
			}
			
			relPath, err := filepath.Rel(rootAbs, pathAbs)
			if err != nil || relPath != name {
				panic(fmt.Errorf("invalid queued path"))
			}

			data, err := ioutil.ReadFile(path)
			if err != nil {
				panic(err)
			}
			
			actualHash := fmt.Sprintf("%x", sha256.Sum256(data))
			if actualHash != expected {
				panic(fmt.Errorf("queued artifact changed"))
			}

			if name == "STATUS.md" && sync != nil {
				if !success {
					panic(fmt.Errorf("artifact publication incomplete"))
				}
				
				revision, counts, err := sync(rootAbs)
				if err != nil {
					panic(err)
				}
				synced = true
				
				err = updateStatusCounts(path, revision, counts)
				if err != nil {
					panic(err)
				}
				
				data, err = ioutil.ReadFile(path)
				if err != nil {
					panic(err)
				}
				
				newExpected := fmt.Sprintf("%x", sha256.Sum256(data))
				pending[name] = newExpected
				state["ausstehende_veroeffentlichungen"].(map[string]interface{})[name] = newExpected
				err = save(state)
				if err != nil {
					panic(err)
				}
			}

			lookup := func(remoteName string) (string, map[string]interface{}, error) {
				endpoint := "https://api.github.com/repos/KikiKari/OpenClaw/contents/" + url.PathEscape(remoteName)
				req, err := http.NewRequest("GET", endpoint+"?ref=gateway1-abstractions", nil)
				if err != nil {
					return "", nil, err
				}
				
				for k, v := range headers {
					req.Header.Set(k, v)
				}
				
				resp, err := opener(req)
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
				err = json.NewDecoder(resp.Body).Decode(&result)
				if err != nil {
					return "", nil, err
				}
				
				return endpoint, result, nil
			}

			same := func(existing map[string]interface{}) bool {
				if existing == nil {
					return false
				}
				if encoding, ok := existing["encoding"].(string); !ok || encoding != "base64" {
					return false
				}
				if content, ok := existing["content"].(string); ok {
					decoded, err := base64.StdEncoding.DecodeString(content)
					if err != nil {
						return false
					}
					return bytes.Equal(decoded, data)
				}
				return false
			}

			endpoint, existing, err := lookup(name)
			if err != nil {
				panic(err)
			}

			if name == "STATUS.md" && existing != nil && !same(existing) {
				sha, ok := existing["sha"].(string)
				if !ok || sha == "" {
					panic(fmt.Errorf("missing remote status version"))
				}
				
				bodyData := map[string]interface{}{
					"message": "Update abstraction status",
					"branch":  "gateway1-abstractions",
					"content": base64.StdEncoding.EncodeToString(data),
					"sha":     sha,
				}
				
				jsonBody, err := json.Marshal(bodyData)
				if err != nil {
					panic(err)
				}
				
				req, err := http.NewRequest("PUT", endpoint, bytes.NewBuffer(jsonBody))
				if err != nil {
					panic(err)
				}
				
				for k, v := range headers {
					req.Header.Set(k, v)
				}
				req.Header.Set("Content-Type", "application/json")
				
				resp, err := opener(req)
				if err != nil {
					panic(err)
				}
				defer resp.Body.Close()
				
				if resp.StatusCode < 200 || resp.StatusCode >= 300 {
					panic(fmt.Errorf("HTTP error: %d", resp.StatusCode))
				}
				
				_, err = io.ReadAll(resp.Body)
				if err != nil {
					panic(err)
				}
			} else if existing != nil && !same(existing) {
				candidate := strings.Split(name, string(filepath.Separator))
				var alternate string
				if len(candidate) > 1 {
					dir := filepath.Join(candidate[:len(candidate)-1]...)
					base := candidate[len(candidate)-1]
					ext := filepath.Ext(base)
					stem := strings.TrimSuffix(base, ext)
					alternate = filepath.Join(dir, stem+"_"+expected[:12]+ext)
				} else {
					base := candidate[0]
					ext := filepath.Ext(base)
					stem := strings.TrimSuffix(base, ext)
					alternate = stem + "_" + expected[:12] + ext
				}
				
				_, existingAlt, err := lookup(alternate)
				if err != nil {
					panic(err)
				}
				
				if existingAlt != nil && !same(existingAlt) {
					panic(fmt.Errorf("remote artifact conflict"))
				}
			}

			if existing == nil {
				bodyData := map[string]interface{}{
					"message": "Publish script abstraction",
					"branch":  "gateway1-abstractions",
					"content": base64.StdEncoding.EncodeToString(data),
				}
				
				jsonBody, err := json.Marshal(bodyData)
				if err != nil {
					panic(err)
				}
				
				req, err := http.NewRequest("PUT", endpoint, bytes.NewBuffer(jsonBody))
				if err != nil {
					panic(err)
				}
				
				for k, v := range headers {
					req.Header.Set(k, v)
				}
				req.Header.Set("Content-Type", "application/json")
				
				resp, err := opener(req)
				if err != nil {
					panic(err)
				}
				defer resp.Body.Close()
				
				if resp.StatusCode < 200 || resp.StatusCode >= 300 {
					panic(fmt.Errorf("HTTP error: %d", resp.StatusCode))
				}
				
				_, err = io.ReadAll(resp.Body)
				if err != nil {
					panic(err)
				}
			}

			delete(pending, name)
			if pendingInterfaceMap, ok := state["ausstehende_veroeffentlichungen"].(map[string]interface{}); ok {
				delete(pendingInterfaceMap, name)
			}
			err = save(state)
			if err != nil {
				panic(err)
			}
		}()
		
		if !success {
			break
		}
	}

	if sync != nil && !synced {
		func() {
			defer func() {
				if r := recover(); r != nil {
					success = false
				}
			}()
			
			_, _, err := sync(rootAbs)
			if err != nil {
				panic(err)
			}
		}()
	}

	return success, nil
}

// Helper functions
func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func sortedLanguages() []string {
	keys := make([]string, 0, len(LANGUAGES))
	for k := range LANGUAGES {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func timeoutContext(duration time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), duration)
}
