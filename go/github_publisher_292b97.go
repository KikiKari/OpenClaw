// abstraction-provenance: {"artifact_sha256": "bacabf7a4ce5678597a27281e3375795be17ec523196169689dc9cf68c0c9c82", "source_sha256": "292b977dd14f55e08a3852eccaf235d04d5f7e909ab6139a9ab2e379ae2305a1", "target_language": "go"}
// github_publisher.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py


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
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

var LANGUAGES = map[string]bool{
	"perl5":     true,
	"powershell": true,
	"perl6":     true,
	"tcl":       true,
	"javascript": true,
	"ruby":      true,
	"python":    true,
	"lua":       true,
	"shell":     true,
	"go":        true,
}

func synchronizeCheckout(root string, remote string, branch string) (string, map[string]int, error) {
	if remote == "" {
		remote = "https://github.com/KikiKari/OpenClaw.git"
	}
	if branch == "" {
		branch = "gateway1-abstractions"
	}

	rootPath, err := filepath.Abs(root)
	if err != nil {
		return "", nil, err
	}

	tmpDir, err := os.MkdirTemp("", "abstractions-snapshot-*")
	if err != nil {
		return "", nil, err
	}
	defer os.RemoveAll(tmpDir)

	snapshot := filepath.Join(tmpDir, "repo")

	cmd := exec.Command("git", "clone", "--quiet", "--depth=1", "--single-branch",
		"--branch", branch, "--", remote, snapshot)
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmdTimeout, cancel := context.WithTimeout(context.Background(), 300*time.Second)
	defer cancel()
	if err := cmd.Run(); err != nil {
		return "", nil, err
	}

	revisionCmd := exec.Command("git", "-C", snapshot, "rev-parse", "HEAD")
	revisionCmd.Timeout = 30 * time.Second
	revisionOutput, err := revisionCmd.Output()
	if err != nil {
		return "", nil, err
	}
	revision := strings.TrimSpace(string(revisionOutput))

	counts := make(map[string]int)

	for _, language := range getSortedLanguages() {
		source := filepath.Join(snapshot, language)
		target := filepath.Join(rootPath, language)

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
		targetEntries, err := os.ReadDir(target)
		if err != nil {
			return "", nil, err
		}
		for _, entry := range targetEntries {
			if entry.IsDir() {
				continue
			}
			fullPath := filepath.Join(target, entry.Name())
			if info, err := os.Lstat(fullPath); err == nil && info.Mode()&os.ModeSymlink != 0 {
				continue
			}
			content, err := os.ReadFile(fullPath)
			if err != nil {
				continue
			}
			hash := fmt.Sprintf("%x", sha256.Sum256(content))
			known[hash] = true
		}

		var files []string
		if _, err := os.Stat(source); err == nil {
			sourceEntries, err := os.ReadDir(source)
			if err != nil {
				return "", nil, err
			}
			for _, entry := range sourceEntries {
				if entry.IsDir() {
					return "", nil, fmt.Errorf("invalid remote abstraction")
				}
				fullPath := filepath.Join(source, entry.Name())
				if info, err := os.Lstat(fullPath); err == nil && info.Mode()&os.ModeSymlink != 0 {
					return "", nil, fmt.Errorf("invalid remote abstraction")
				}
				files = append(files, fullPath)
			}
		}

		sort.Strings(files)
		counts[language] = len(files)

		for _, item := range files {
			data, err := os.ReadFile(item)
			if err != nil {
				return "", nil, err
			}
			digest := fmt.Sprintf("%x", sha256.Sum256(data))
			if known[digest] {
				continue
			}

			filename := filepath.Base(item)
			destination := filepath.Join(target, filename)
			if _, err := os.Stat(destination); err == nil {
				ext := filepath.Ext(filename)
				name := strings.TrimSuffix(filename, ext)
				destination = filepath.Join(target, name+"_pool_"+digest+ext)
			}

			if _, err := os.Lstat(destination); err == nil {
				existingData, err := os.ReadFile(destination)
				if err != nil {
					return "", nil, err
				}
				if !bytes.Equal(existingData, data) {
					return "", nil, fmt.Errorf("local abstraction conflict")
				}
			} else {
				if err := os.WriteFile(destination, data, 0644); err != nil {
					return "", nil, err
				}
			}
			known[digest] = true
		}
	}

	return revision, counts, nil
}

func updateStatusCounts(path string, revision string, counts map[string]int) error {
	content, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	text := string(content)

	rows := []string{"## Bestand", "", fmt.Sprintf("GitHub-Stand: `%s`", revision), ""}
	rows = append(rows, "| Zielsprache | Dateien |")
	rows = append(rows, "|---|---:|")

	sortedLangs := getSortedLanguages()
	for _, lang := range sortedLangs {
		if count, ok := counts[lang]; ok {
			rows = append(rows, fmt.Sprintf("| %s | %d |", lang, count))
		}
	}

	total := 0
	for _, count := range counts {
		total += count
	}
	rows = append(rows, fmt.Sprintf("| **gesamt** | **%d** |", total))
	rows = append(rows, "")

	re := regexp.MustCompile(`(?ms)^## Bestand\n.*?(?=^## Quellen\n)`)
	updated := re.ReplaceAllStringFunc(text, func(s string) string {
		return strings.Join(rows, "\n")
	})

	if updated == text {
		return fmt.Errorf("status inventory section missing")
	}

	return os.WriteFile(path, []byte(updated), 0644)
}

func queueArtifact(state map[string]interface{}, root string, path string) error {
	rootPath, err := filepath.Abs(root)
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

	absPath, err := filepath.Abs(path)
	if err != nil {
		return err
	}

	relPath, err := filepath.Rel(rootPath, absPath)
	if err != nil {
		return err
	}

	relPath = filepath.ToSlash(relPath)

	if relPath != "STATUS.md" {
		parts := strings.Split(relPath, "/")
		if len(parts) == 0 || !LANGUAGES[parts[0]] {
			return fmt.Errorf("artifact is outside a language directory")
		}
	}

	content, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	hash := fmt.Sprintf("%x", sha256.Sum256(content))

	if state["ausstehende_veroeffentlichungen"] == nil {
		state["ausstehende_veroeffentlichungen"] = make(map[string]interface{})
	}
	state["ausstehende_veroeffentlichungen"].(map[string]interface{})[relPath] = hash

	return nil
}

func publishPending(root string, state map[string]interface{}, save func(map[string]interface{}) error, token string, opener func(*http.Request) (*http.Response, error), sync func(string) (string, map[string]int, error)) (bool, error) {
	if opener == nil {
		opener = http.DefaultClient.Do
	}

	pendingInterface, exists := state["ausstehende_veroeffentlichungen"]
	pending, ok := pendingInterface.(map[string]interface{})
	if !exists || !ok {
		pending = make(map[string]interface{})
	}

	if len(pending) == 0 && sync == nil {
		return true, nil
	}

	if strings.TrimSpace(token) == "" {
		return false, nil
	}

	rootPath, err := filepath.Abs(root)
	if err != nil {
		return false, err
	}

	headers := map[string]string{
		"Authorization":           "Bearer " + strings.TrimSpace(token),
		"Accept":                  "application/vnd.github+json",
		"X-GitHub-Api-Version":    "2022-11-28",
		"User-Agent":              "abstractions-manager",
	}

	success := true

	var entries [][2]string
	for k, v := range pending {
		key := k
		value := ""
		if vStr, ok := v.(string); ok {
			value = vStr
		}
		entries = append(entries, [2]string{key, value})
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

			path := filepath.Join(rootPath, filepath.FromSlash(name))
			if info, err := os.Lstat(path); err == nil && info.Mode()&os.ModeSymlink != 0 {
				panic(fmt.Errorf("invalid queued path"))
			}

			absPath, err := filepath.Abs(path)
			if err != nil {
				panic(err)
			}

			relPath, err := filepath.Rel(rootPath, absPath)
			if err != nil {
				panic(err)
			}

			if filepath.ToSlash(relPath) != name {
				panic(fmt.Errorf("invalid queued path"))
			}

			data, err := os.ReadFile(path)
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
				revision, counts, err := sync(rootPath)
				if err != nil {
					panic(err)
				}
				synced = true

				err = updateStatusCounts(path, revision, counts)
				if err != nil {
					panic(err)
				}

				data, err = os.ReadFile(path)
				if err != nil {
					panic(err)
				}

				newExpected := fmt.Sprintf("%x", sha256.Sum256(data))
				pending[name] = newExpected
				err = save(state)
				if err != nil {
					panic(err)
				}
			}

			lookup := func(remoteName string) (string, map[string]interface{}, error) {
				endpoint := "https://api.github.com/repos/KikiKari/OpenClaw/contents/" + strings.ReplaceAll(remoteName, " ", "%20")
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

				body, err := io.ReadAll(resp.Body)
				if err != nil {
					return "", nil, err
				}

				var result map[string]interface{}
				err = json.Unmarshal(body, &result)
				if err != nil {
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
				panic(err)
			}

			if name == "STATUS.md" && existing != nil && !same(existing) {
				sha, _ := existing["sha"].(string)
				if sha == "" {
					panic(fmt.Errorf("missing remote status version"))
				}

				bodyData := map[string]interface{}{
					"message": "Update abstraction status",
					"branch":  "gateway1-abstractions",
					"content": base64.StdEncoding.EncodeToString(data),
					"sha":     sha,
				}
				bodyBytes, _ := json.Marshal(bodyData)

				req, err := http.NewRequest("PUT", endpoint, bytes.NewBuffer(bodyBytes))
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
				candidate := strings.Split(name, "/")
				filename := candidate[len(candidate)-1]
				ext := filepath.Ext(filename)
				nameWithoutExt := strings.TrimSuffix(filename, ext)
				dirPath := strings.Join(candidate[:len(candidate)-1], "/")
				if dirPath != "" {
					dirPath += "/"
				}
				alternate := dirPath + nameWithoutExt + "_" + expected[:12] + ext

				endpoint, existing, err = lookup(alternate)
				if err != nil {
					panic(err)
				}
				if existing != nil && !same(existing) {
					panic(fmt.Errorf("remote artifact conflict"))
				}
			}

			if existing == nil {
				bodyData := map[string]interface{}{
					"message": "Publish script abstraction",
					"branch":  "gateway1-abstractions",
					"content": base64.StdEncoding.EncodeToString(data),
				}
				bodyBytes, _ := json.Marshal(bodyData)

				req, err := http.NewRequest("PUT", endpoint, bytes.NewBuffer(bodyBytes))
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
			err = save(state)
			if err != nil {
				panic(err)
			}
		}()
	}

	if sync != nil && !synced {
		func() {
			defer func() {
				if r := recover(); r != nil {
					success = false
				}
			}()
			_, _, err := sync(rootPath)
			if err != nil {
				panic(err)
			}
		}()
	}

	return success, nil
}

// Helper functions
func getSortedLanguages() []string {
	var langs []string
	for lang := range LANGUAGES {
		langs = append(langs, lang)
	}
	sort.Strings(langs)
	return langs
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.IsDir()
}
