// abstraction-provenance: {"artifact_sha256": "f799173a156bf624cd17d1ff77135d9cce8fc9f3ceb61510a4024ca7abdc63b9", "source_sha256": "9e1571035b3437fe4d1a830b7a20217de22a01508d7fc92bfed5fd58b7738b33", "target_language": "go"}
// pplx-inject.mjs — portiert nach go
// Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const (
	profile = "codespace"
	email   = "KarimKiki@gmx.de"
)

type Cookie struct {
	Name     string `json:"name"`
	Value    string `json:"value"`
	Domain   string `json:"domain"`
	Path     string `json:"path"`
	Expires  int64  `json:"expires"`
	HTTPOnly bool   `json:"httpOnly"`
	Secure   bool   `json:"secure"`
	SameSite string `json:"sameSite"`
}

type ProfilePaths struct {
	Dir         string `json:"dir"`
	ModelsCache string `json:"modelsCache"`
	Reinit      string `json:"reinit"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "usage: %s <cookies-file>\n", os.Args[0])
		os.Exit(1)
	}

	file := os.Args[1]
	dist := os.Getenv("PPLX_DIST")
	if dist == "" {
		home, _ := os.UserHomeDir()
		cmd := exec.Command("find", filepath.Join(home, ".npm", "_npx"), "-type", "d", "-path", "*perplexity-user-mcp/dist")
		output, err := cmd.CombinedOutput()
		if err == nil {
			lines := strings.Split(strings.TrimSpace(string(output)), "\n")
			if len(lines) > 0 {
				dist = lines[0]
			}
		}
	}

	if dist == "" || !exists(dist) {
		fmt.Fprintln(os.Stderr, "cannot locate perplexity-user-mcp/dist (set PPLX_DIST)")
		os.Exit(1)
	}

	vaultChunk := chunkFor(dist, "Vault")
	profChunk := chunkFor(dist, "getProfilePaths")
	if vaultChunk == "" || profChunk == "" {
		fmt.Fprintln(os.Stderr, "could not locate Vault/profile chunks in dist")
		os.Exit(1)
	}

	text, err := ioutil.ReadFile(file)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error reading file: %v\n", err)
		os.Exit(1)
	}

	cookies := parseCookies(strings.TrimSpace(string(text)))
	names := make([]string, len(cookies))
	for i, c := range cookies {
		names[i] = c.Name
	}

	fmt.Printf("Parsed %d perplexity.ai cookies: %s\n", len(cookies), strings.Join(names, ", "))
	hasSessionToken := false
	for _, n := range names {
		if strings.HasPrefix(n, "__Secure-next-auth.session-token") {
			hasSessionToken = true
			break
		}
	}
	if !hasSessionToken {
		fmt.Fprintln(os.Stderr, "WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate.")
	}

	paths := getProfilePaths(profile)
	if !exists(paths.Dir) {
		os.MkdirAll(paths.Dir, 0755)
	}

	vault := NewVault()
	vault.Set(profile, "cookies", toJSON(cookies))
	vault.Set(profile, "email", email)

	if !exists(paths.ModelsCache) {
		models := map[string]interface{}{"models": map[string]interface{}{}}
		ioutil.WriteFile(paths.ModelsCache, []byte(toJSON(models)), 0644)
	}

	recordLoginSuccess(profile, map[string]interface{}{
		"tier":      "pro",
		"loginMode": "manual",
		"lastLogin": time.Now().Format(time.RFC3339),
	})

	ioutil.WriteFile(paths.Reinit, []byte(fmt.Sprintf("%d", time.Now().Unix())), 0644)
	fmt.Printf("OK: injected %d cookie(s) into vault profile '%s'.\n", len(cookies), profile)
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func chunkFor(dist, symbol string) string {
	entries := []string{"manual-login-runner.mjs", "login-runner.mjs", "cli.mjs"}
	for _, entry := range entries {
		path := filepath.Join(dist, entry)
		if !exists(path) {
			continue
		}

		content, err := ioutil.ReadFile(path)
		if err != nil {
			continue
		}

		re := regexp.MustCompile(`import\s*\{([^}]*)\}\s*from\s*"(\./chunk-[^"]+\.mjs)"`)
		matches := re.FindAllStringSubmatch(string(content), -1)
		for _, match := range matches {
			names := strings.Split(match[1], ",")
			for _, name := range names {
				name = strings.TrimSpace(name)
				if parts := strings.Split(name, " as "); len(parts) > 1 {
					name = parts[0]
				}
				if name == symbol {
					return filepath.Join(dist, match[2][2:])
				}
			}
		}
	}
	return ""
}

func parseCookies(text string) []Cookie {
	var cookies []Cookie

	if strings.HasPrefix(text, "[") || strings.HasPrefix(text, "{") {
		var data interface{}
		if err := json.Unmarshal([]byte(text), &data); err == nil {
			if arr, ok := data.([]interface{}); ok {
				for _, item := range arr {
					if cookie, ok := item.(map[string]interface{}); ok {
						cookies = append(cookies, normalizeCookie(cookie))
					}
				}
			} else if obj, ok := data.(map[string]interface{}); ok {
				if arr, ok := obj["cookies"].([]interface{}); ok {
					for _, item := range arr {
						if cookie, ok := item.(map[string]interface{}); ok {
							cookies = append(cookies, normalizeCookie(cookie))
						}
					}
				}
			}
		}
	} else if strings.HasPrefix(text, "eyJ") && !strings.Contains(text, "=") && !strings.Contains(text, ";") {
		cookies = []Cookie{{
			Name:   "__Secure-next-auth.session-token",
			Value:  text,
			Domain: ".perplexity.ai",
			Path:   "/",
			Expires: -1,
			Secure: true,
			SameSite: "Lax",
		}}
	} else {
		parts := strings.Split(text, ";")
		for _, part := range parts {
			part = strings.TrimSpace(part)
			if idx := strings.Index(part, "="); idx >= 0 {
				name := part[:idx]
				value := part[idx+1:]
				cookies = append(cookies, Cookie{
					Name:   name,
					Value:  value,
					Domain: ".perplexity.ai",
					Path:   "/",
					Expires: -1,
					Secure: true,
					SameSite: "Lax",
				})
			}
		}
	}

	var result []Cookie
	for _, cookie := range cookies {
		if cookie.Name == "" || cookie.Value == "" {
			continue
		}
		if cookie.Domain != "" && !strings.Contains(cookie.Domain, "perplexity") {
			continue
		}
		result = append(result, cookie)
	}
	return result
}

func normalizeCookie(c map[string]interface{}) Cookie {
	domain := ".perplexity.ai"
	if d, ok := c["domain"].(string); ok && strings.Contains(d, "perplexity") {
		domain = d
	}

	expires := int64(-1)
	if e, ok := c["expires"].(float64); ok {
		expires = int64(e)
	} else if e, ok := c["expirationDate"].(float64); ok {
		expires = int64(e)
	}

	sameSite := normSameSite(c["sameSite"])

	return Cookie{
		Name:     toString(c["name"]),
		Value:    toString(c["value"]),
		Domain:   domain,
		Path:     toStringDefault(c["path"], "/"),
		Expires:  expires,
		HTTPOnly: toBool(c["httpOnly"]),
		Secure:   toBoolDefault(c["secure"], true),
		SameSite: sameSite,
	}
}

func normSameSite(v interface{}) string {
	s := strings.ToLower(toString(v))
	switch s {
	case "no_restriction", "none":
		return "None"
	case "strict":
		return "Strict"
	default:
		return "Lax"
	}
}

func toString(v interface{}) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func toStringDefault(v interface{}, def string) string {
	if s, ok := v.(string); ok && s != "" {
		return s
	}
	return def
}

func toBool(v interface{}) bool {
	if b, ok := v.(bool); ok {
		return b
	}
	return false
}

func toBoolDefault(v interface{}, def bool) bool {
	if b, ok := v.(bool); ok {
		return b
	}
	return def
}

func getProfilePaths(profile string) ProfilePaths {
	home, _ := os.UserHomeDir()
	dir := filepath.Join(home, ".config", "perplexity-user-mcp", profile)
	return ProfilePaths{
		Dir:         dir,
		ModelsCache: filepath.Join(dir, "models-cache.json"),
		Reinit:      filepath.Join(dir, "reinit"),
	}
}

func toJSON(v interface{}) string {
	data, _ := json.Marshal(v)
	return string(data)
}

type Vault struct {
	data map[string]map[string]string
}

func NewVault() *Vault {
	return &Vault{data: make(map[string]map[string]string)}
}

func (v *Vault) Set(profile, key, value string) {
	if _, ok := v.data[profile]; !ok {
		v.data[profile] = make(map[string]string)
	}
	v.data[profile][key] = value
}

func recordLoginSuccess(profile string, data map[string]interface{}) {
	paths := getProfilePaths(profile)
	loginFile := filepath.Join(paths.Dir, "login.json")
	ioutil.WriteFile(loginFile, []byte(toJSON(data)), 0644)
}
