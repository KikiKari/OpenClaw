// abstraction-provenance: {"artifact_sha256": "ca0cbfcd5ef13812d50f4f48a06ea463180b434adea97665ca9899d29c5d895e", "source_sha256": "9846e805dd3219c9d0bd40ccd4a368fb397647c0f7db6d88a1eab2f1d73061f3", "target_language": "go"}
// docs-link-audit.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-link-audit.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

const (
	ROOT                            = "."
	DOCS_DIR                        = "docs"
	DOCS_JSON_PATH                  = "docs/docs.json"
	NODE_25_UNSUPPORTED_BY_MINTLIFY  = 25
)

var (
	MINTLIFY_BROKEN_LINKS_ARGS       = []string{"dlx", "mint", "broken-links", "--check-anchors"}
	markdownLinkRegex               = regexp.MustCompile(`!?\[[^\]]*\]\(([^)]+)\)`)
)

func main() {
	if isCliEntry() {
		os.Exit(runDocsLinkAuditCli())
	}
}

func isCliEntry() bool {
	if len(os.Args) < 2 {
		return false
	}
	
	absPath, err := filepath.Abs(os.Args[0])
	if err != nil {
		return false
	}
	
	currentExecutable, err := os.Executable()
	if err != nil {
		return false
	}
	
	return absPath == currentExecutable
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

func isDirectory(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.IsDir()
}

func walk(dir string) []string {
	var out []string
	entries, err := os.ReadDir(dir)
	if err != nil {
		return out
	}
	
	for _, entry := range entries {
		if strings.HasPrefix(entry.Name(), ".") {
			continue
		}
		full := filepath.Join(dir, entry.Name())
		if entry.IsDir() {
			out = append(out, walk(full)...)
		} else if !entry.IsDir() {
			out = append(out, full)
		}
	}
	return out
}

func normalizeSlashes(p string) string {
	return strings.ReplaceAll(p, "\\", "/")
}

func normalizeRoute(p string) string {
	parts := strings.Split(p, "#")
	withoutFragment := parts[0]
	queryParts := strings.Split(withoutFragment, "?")
	withoutQuery := queryParts[0]
	stripped := strings.TrimPrefix(strings.TrimSuffix(withoutQuery, "/"), "/")
	if stripped == "" {
		return "/"
	}
	return "/" + stripped
}

func stripInlineCode(text string) string {
	re := regexp.MustCompile("`[^`]+`")
	return re.ReplaceAllString(text, "")
}

func isLocalizedDocPath(p string) bool {
	re := regexp.MustCompile(`^/?[a-z]{2}(?:-[A-Za-z]{2,8})+/`)
	return re.MatchString(p)
}

func isGeneratedTranslatedDoc(relPath string) bool {
	return isLocalizedDocPath(relPath)
}

func collectNavPageEntries(node interface{}) []string {
	var entries []string
	
	switch v := node.(type) {
	case []interface{}:
		for _, item := range v {
			entries = append(entries, collectNavPageEntries(item)...)
		}
		return entries
	case map[string]interface{}:
		if pages, ok := v["pages"].([]interface{}); ok {
			for _, page := range pages {
				if pageStr, ok := page.(string); ok {
					entries = append(entries, pageStr)
				} else {
					entries = append(entries, collectNavPageEntries(page)...)
				}
			}
		}
		
		for _, value := range v {
			if key := getKeyFromValue(v, value); key != "pages" {
				entries = append(entries, collectNavPageEntries(value)...)
			}
		}
		return entries
	default:
		return entries
	}
}

func getKeyFromValue(m map[string]interface{}, value interface{}) string {
	for k, v := range m {
		if fmt.Sprintf("%v", v) == fmt.Sprintf("%v", value) {
			return k
		}
	}
	return ""
}

func sanitizeDocsConfigForEnglishOnly(value interface{}) interface{} {
	switch v := value.(type) {
	case []interface{}:
		var result []interface{}
		for _, item := range v {
			sanitized := sanitizeDocsConfigForEnglishOnly(item)
			if sanitized != nil {
				result = append(result, sanitized)
			}
		}
		return result
	case map[string]interface{}:
		if lang, ok := v["language"].(string); ok && lang != "en" {
			return nil
		}
		
		sanitized := make(map[string]interface{})
		for key, child := range v {
			next := sanitizeDocsConfigForEnglishOnly(child)
			if next == nil {
				continue
			}
			
			if arr, ok := next.([]interface{}); ok && len(arr) == 0 {
				continue
			}
			
			if obj, ok := next.(map[string]interface{}); ok {
				if len(obj) == 0 {
					continue
				}
			}
			
			sanitized[key] = next
		}
		
		if _, hasPages := v["pages"]; hasPages {
			if _, isArray := sanitized["pages"].([]interface{}); !isArray {
				return nil
			}
		}
		
		if _, hasGroups := v["groups"]; hasGroups {
			if _, isArray := sanitized["groups"].([]interface{}); !isArray {
				return nil
			}
		}
		
		if _, hasTabs := v["tabs"]; hasTabs {
			if _, isArray := sanitized["tabs"].([]interface{}); !isArray {
				return nil
			}
		}
		
		if _, hasSource := v["source"]; hasSource {
			if _, isString := v["source"].(string); isString {
				if _, isStringNext := sanitized["source"].(string); !isStringNext {
					return nil
				}
			}
		}
		
		if _, hasDestination := v["destination"]; hasDestination {
			if _, isString := v["destination"].(string); isString {
				if _, isStringNext := sanitized["destination"].(string); !isStringNext {
					return nil
				}
			}
		}
		
		if len(sanitized) > 0 {
			return sanitized
		}
		return nil
	case string:
		if isLocalizedDocPath(v) {
			return nil
		}
		return v
	default:
		return v
	}
}

func prepareAnchorAuditDocsDir(sourceDir string) string {
	tempDir, err := os.MkdirTemp("", "openclaw-docs-anchor-audit-*")
	if err != nil {
		panic(err)
	}
	
	copyDir(sourceDir, tempDir)
	
	entries, err := os.ReadDir(tempDir)
	if err != nil {
		panic(err)
	}
	
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		if !isGeneratedTranslatedDoc(entry.Name() + "/") {
			continue
		}
		os.RemoveAll(filepath.Join(tempDir, entry.Name()))
	}
	
	docsJsonPath := filepath.Join(tempDir, "docs.json")
	docsConfigBytes, err := os.ReadFile(docsJsonPath)
	if err != nil {
		panic(err)
	}
	
	var docsConfig interface{}
	err = json.Unmarshal(docsJsonPath, &docsConfig)
	if err != nil {
		panic(err)
	}
	
	sanitized := sanitizeDocsConfigForEnglishOnly(docsConfig)
	sanitizedBytes, err := json.MarshalIndent(sanitized, "", "  ")
	if err != nil {
		panic(err)
	}
	
	err = os.WriteFile(docsJsonPath, append(sanitizedBytes, '\n'), 0644)
	if err != nil {
		panic(err)
	}
	
	return tempDir
}

func copyDir(src, dst string) error {
	return filepath.Walk(src, func(path string, info fs.FileInfo, err error) error {
		if err != nil {
			return err
		}
		
		relPath, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		
		dstPath := filepath.Join(dst, relPath)
		
		if info.IsDir() {
			return os.MkdirAll(dstPath, info.Mode())
		}
		
		srcFile, err := os.Open(path)
		if err != nil {
			return err
		}
		defer srcFile.Close()
		
		dstFile, err := os.Create(dstPath)
		if err != nil {
			return err
		}
		defer dstFile.Close()
		
		_, err = io.Copy(dstFile, srcFile)
		return err
	})
}

func parseNodeMajor(version string) int {
	parts := strings.Split(version, ".")
	if len(parts) == 0 {
		return 0
	}
	major, err := strconv.Atoi(parts[0])
	if err != nil {
		return 0
	}
	return major
}

func resolveMintlifyAnchorAuditInvocation(cwd string, nodeVersion string) (string, []string) {
	if parseNodeMajor(nodeVersion) < NODE_25_UNSUPPORTED_BY_MINTLIFY {
		return "pnpm", MINTLIFY_BROKEN_LINKS_ARGS
	}
	
	node22Probe := "process.exit(Number(process.versions.node.split('.')[0]) === 22 ? 0 : 1)"
	candidates := []struct{
		command string
		probeArgs []string
		args []string
	}{
		{
			command: "fnm",
			probeArgs: []string{"exec", "--using=22", "node", "-e", node22Probe},
			args: []string{"exec", "--using=22", "pnpm"},
		},
		{
			command: "mise",
			probeArgs: []string{"exec", "node@22", "--", "node", "-e", node22Probe},
			args: []string{"exec", "node@22", "--", "pnpm"},
		},
	}
	
	for _, candidate := range candidates {
		cmd := exec.Command(candidate.command, candidate.probeArgs...)
		cmd.Dir = cwd
		cmd.Stdin = nil
		cmd.Stdout = nil
		cmd.Stderr = nil
		
		if err := cmd.Run(); err == nil {
			args := append(candidate.args, MINTLIFY_BROKEN_LINKS_ARGS...)
			return candidate.command, args
		}
	}
	
	return "pnpm", MINTLIFY_BROKEN_LINKS_ARGS
}

func auditDocsLinks() (int, []map[string]interface{}) {
	broken := []map[string]interface{}{}
	checked := 0
	
	allFiles := walk(DOCS_DIR)
	relAllFiles := make(map[string]bool)
	for _, abs := range allFiles {
		rel := normalizeSlashes(strings.TrimPrefix(abs, DOCS_DIR+"/"))
		relAllFiles[rel] = true
	}
	
	markdownFiles := []string{}
	for _, abs := range allFiles {
		if !regexp.MustCompile(`\.(md|mdx)$`).MatchString(strings.ToLower(abs)) {
			continue
		}
		rel := normalizeSlashes(strings.TrimPrefix(abs, DOCS_DIR+"/"))
		if !isGeneratedTranslatedDoc(rel) {
			markdownFiles = append(markdownFiles, abs)
		}
	}
	
	routes := make(map[string]bool)
	redirects := make(map[string]string)
	
	docsJsonBytes, err := os.ReadFile(DOCS_JSON_PATH)
	if err != nil {
		panic(err)
	}
	
	var docsConfig map[string]interface{}
	err = json.Unmarshal(docsJsonBytes, &docsConfig)
	if err != nil {
		panic(err)
	}
	
	if redirs, ok := docsConfig["redirects"].([]interface{}); ok {
		for _, item := range redirs {
			if itemMap, ok := item.(map[string]interface{}); ok {
				source := ""
				destination := ""
				
				if src, ok := itemMap["source"].(string); ok {
					source = normalizeRoute(src)
				}
				if dest, ok := itemMap["destination"].(string); ok {
					destination = normalizeRoute(dest)
				}
				
				if source != "" && destination != "" {
					redirects[source] = destination
				}
			}
		}
	}
	
	for _, abs := range markdownFiles {
		rel := normalizeSlashes(strings.TrimPrefix(abs, DOCS_DIR+"/"))
		rawTextBytes, err := os.ReadFile(abs)
		if err != nil {
			continue
		}
		rawText := string(rawTextBytes)
		slug := regexp.MustCompile(`\.(md|mdx)$`).ReplaceAllString(rel, "")
		route := normalizeRoute(slug)
		routes[route] = true
		
		if strings.HasSuffix(slug, "/index") {
			routes[normalizeRoute(strings.TrimSuffix(slug, "/index"))] = true
		}
		
		if !strings.HasPrefix(rawText, "---") {
			continue
		}
		
		end := strings.Index(rawText[3:], "\n---")
		if end == -1 {
			continue
		}
		frontMatter := rawText[3 : 3+end]
		
		lines := strings.Split(frontMatter, "\n")
		for _, line := range lines {
			if strings.HasPrefix(strings.TrimSpace(line), "permalink:") {
				permalink := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(line), "permalink:"))
				permalink = strings.Trim(permalink, "'\"")
				routes[normalizeRoute(permalink)] = true
				break
			}
		}
	}
	
	resolveRoute := func(route string) map[string]interface{} {
		current := normalizeRoute(route)
		if current == "/" {
			return map[string]interface{}{"ok": true, "terminal": "/"}
		}
		
		seen := make(map[string]bool)
		seen[current] = true
		
		for redirects[current] != "" {
			current = normalizeRoute(redirects[current])
			if seen[current] {
				return map[string]interface{}{"ok": false, "terminal": current, "loop": true}
			}
			seen[current] = true
		}
		
		return map[string]interface{}{"ok": routes[current], "terminal": current}
	}
	
	for _, abs := range markdownFiles {
		rel := normalizeSlashes(strings.TrimPrefix(abs, DOCS_DIR+"/"))
		baseDir := normalizeSlashes(filepath.Dir(rel))
		
		rawTextBytes, err := os.ReadFile(abs)
		if err != nil {
			continue
		}
		rawText := string(rawTextBytes)
		lines := strings.Split(rawText, "\n")
		
		inCodeFence := false
		
		for lineNum, line := range lines {
			trimmedLine := strings.TrimSpace(line)
			
			if strings.HasPrefix(trimmedLine, "```") {
				inCodeFence = !inCodeFence
				continue
			}
			if inCodeFence {
				continue
			}
			
			line = stripInlineCode(line)
			
			matches := markdownLinkRegex.FindAllStringSubmatch(line, -1)
			for _, match := range matches {
				if len(match) < 2 {
					continue
				}
				raw := strings.TrimSpace(match[1])
				if raw == "" {
					continue
				}
				if regexp.MustCompile(`^(https?:|mailto:|tel:|data:|#)`).MatchString(raw) {
					continue
				}
				
				pathParts := strings.Split(raw, "#")
				pathPart := pathParts[0]
				queryParts := strings.Split(pathPart, "?")
				clean := queryParts[0]
				if clean == "" {
					continue
				}
				checked++
				
				if strings.HasPrefix(clean, "/") {
					route := normalizeRoute(clean)
					resolvedRoute := resolveRoute(route)
					if !resolvedRoute["ok"].(bool) {
						staticRel := strings.TrimPrefix(route, "/")
						if !relAllFiles[staticRel] {
							broken = append(broken, map[string]interface{}{
								"file": rel,
								"line": lineNum + 1,
								"link": raw,
								"reason": fmt.Sprintf("route/file not found (terminal: %s)", resolvedRoute["terminal"]),
							})
						}
					}
					continue
				}
				
				if !strings.HasPrefix(clean, ".") && !strings.Contains(clean, "/") {
					continue
				}
				
				normalizedRel := normalizeSlashes(filepath.Clean(filepath.Join(baseDir, clean)))
				
				if regexp.MustCompile(`\.[a-zA-Z0-9]+$`).MatchString(normalizedRel) {
					if !relAllFiles[normalizedRel] {
						broken = append(broken, map[string]interface{}{
							"file": rel,
							"line": lineNum + 1,
							"link": raw,
							"reason": "relative file not found",
						})
					}
					continue
				}
				
				candidates := []string{
					normalizedRel,
					normalizedRel + ".md",
					normalizedRel + ".mdx",
					normalizedRel + "/index.md",
					normalizedRel + "/index.mdx",
				}
				
				found := false
				for _, candidate := range candidates {
					if relAllFiles[candidate] {
						found = true
						break
					}
				}
				
				if !found {
					broken = append(broken, map[string]interface{}{
						"file": rel,
						"line": lineNum + 1,
						"link": raw,
						"reason": "relative doc target not found",
					})
				}
			}
		}
	}
	
	if nav, ok := docsConfig["navigation"]; ok {
		pages := collectNavPageEntries(nav)
		for _, page := range pages {
			if isGeneratedTranslatedDoc(page) {
				continue
			}
			checked++
			route := normalizeRoute(page)
			resolvedRoute := resolveRoute(route)
			if resolvedRoute["ok"].(bool) {
				continue
			}
			
			broken = append(broken, map[string]interface{}{
				"file": "docs.json",
				"line": 0,
				"link": page,
				"reason": fmt.Sprintf("navigation page not published (terminal: %s)", resolvedRoute["terminal"]),
			})
		}
	}
	
	return checked, broken
}

func runDocsLinkAuditCli() int {
	args := os.Args[1:]
	
	for _, arg := range args {
		if arg == "--anchors" {
			anchorDocsDir := prepareAnchorAuditDocsDir(DOCS_DIR)
			
			defer func() {
				os.RemoveAll(anchorDocsDir)
			}()
			
			command, cmdArgs := resolveMintlifyAnchorAuditInvocation(anchorDocsDir, "0.0.0")
			
			cmd := exec.Command(command, cmdArgs...)
			cmd.Dir = anchorDocsDir
			cmd.Stdin = os.Stdin
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			
			err := cmd.Run()
			if err != nil {
				if exitError, ok := err.(*exec.ExitError); ok {
					return exitError.ExitCode()
				}
				return 1
			}
			return 0
		}
	}
	
	checked, broken := auditDocsLinks()
	fmt.Printf("checked_internal_links=%d\n", checked)
	fmt.Printf("broken_links=%d\n", len(broken))
	
	for _, item := range broken {
		fmt.Printf("%s:%d :: %s :: %s\n", 
			item["file"], 
			int(item["line"].(float64)), 
			item["link"], 
			item["reason"])
	}
	
	if len(broken) > 0 {
		return 1
	}
	return 0
}
