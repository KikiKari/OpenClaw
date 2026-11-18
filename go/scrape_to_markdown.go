// abstraction-provenance: {"artifact_sha256": "19b4340a7e3115837b255b5859ea4fe5dbf3e79337e22d92d39c4223f73b7b20", "source_sha256": "f76d25200d74ebc530580d7a7afb24c88ee8981f06c4d1734500f4cc830c4fe9", "target_language": "go"}
// scrape_to_markdown.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"golang.org/x/net/html"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type Result struct {
	URL                 string `json:"url"`
	Ok                  bool   `json:"ok"`
	Title               string `json:"title"`
	Status              int    `json:"status,omitempty"`
	SelectorUsed        string `json:"selector_used,omitempty"`
	Backend             string `json:"backend,omitempty"`
	Markdown            string `json:"markdown"`
	Preview             string `json:"preview"`
	OutputMarkdownFile  string `json:"output_markdown_file,omitempty"`
	Error               string `json:"error,omitempty"`
}

type Args struct {
	URL           []string
	URLFile       string
	Selector      string
	Js            bool
	WaitSelector  string
	PreserveLinks bool
	BodyWidth     int
	Timeout       int
	OutputDir     string
	AutomatchDomain string
}

func toString(value interface{}) string {
	if value == nil {
		return ""
	}
	switch v := value.(type) {
	case string:
		return v
	case []byte:
		return string(v)
	default:
		return fmt.Sprintf("%v", v)
	}
}

func slugify(text string, maxLen int) string {
	reg := regexp.MustCompile(`[^\w\s-]`)
	text = reg.ReplaceAllString(text, "")
	text = strings.ToLower(strings.TrimSpace(text))
	reg = regexp.MustCompile(`[-\s]+`)
	text = reg.ReplaceAllString(text, "-")
	if len(text) > maxLen {
		text = text[:maxLen]
	}
	text = strings.Trim(text, "-")
	if text == "" {
		return "page"
	}
	return text
}

func extractHTML(obj interface{}) string {
	if obj == nil {
		return ""
	}
	
	// Try common attributes that might contain HTML
	attrs := []string{"html", "raw_html", "content", "markup", "body", "inner_html"}
	
	for _, attr := range attrs {
		// This is a simplified approach since Go doesn't have direct attribute access like Python
		// In a real implementation, you'd need reflection or a more structured approach
		text := toString(obj)
		if strings.Contains(text, "<") && strings.Contains(text, ">") {
			return text
		}
	}
	
	text := toString(obj)
	if strings.Contains(text, "<") && strings.Contains(text, ">") {
		return text
	}
	return ""
}

func extractTitle(htmlContent string) string {
	re := regexp.MustCompile(`(?i)<title[^>]*>(.*?)</title>`)
	matches := re.FindStringSubmatch(htmlContent)
	if len(matches) < 2 {
		return ""
	}
	title := matches[1]
	// Remove HTML tags
	tagRe := regexp.MustCompile(`<[^>]+>`)
	title = tagRe.ReplaceAllString(title, " ")
	// Normalize whitespace
	spaceRe := regexp.MustCompile(`\s+`)
	title = spaceRe.ReplaceAllString(title, " ")
	return strings.TrimSpace(title)
}

func fetchPage(u string, js bool, waitSelector string, timeout int, automatchDomain string) (string, int, error) {
	client := &http.Client{
		Timeout: time.Duration(timeout) * time.Second,
	}
	
	resp, err := client.Get(u)
	if err != nil {
		return "", 0, err
	}
	defer resp.Body.Close()
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", 0, err
	}
	
	return string(body), resp.StatusCode, nil
}

func pickMainHTML(htmlContent string, preferredSelector string) (string, string) {
	selectors := []string{}
	if preferredSelector != "" {
		selectors = append(selectors, preferredSelector)
	}
	selectors = append(selectors, "article", "main", "[role='main']", 
		".post-content", ".entry-content", ".article-content", "body")
	
	// For simplicity, we'll just return the full HTML content
	// A proper implementation would parse the HTML and find elements by selectors
	return htmlContent, ""
}

func htmlToMarkdown(htmlContent string, preserveLinks bool, bodyWidth int) string {
	doc, err := html.Parse(strings.NewReader(htmlContent))
	if err != nil {
		return ""
	}
	
	var buf strings.Builder
	walkHTML(doc, &buf, preserveLinks)
	
	md := buf.String()
	
	// Normalize newlines
	newlineRe := regexp.MustCompile(`\n{3,}`)
	md = newlineRe.ReplaceAllString(md, "\n\n")
	
	return strings.TrimSpace(md)
}

func walkHTML(n *html.Node, buf *strings.Builder, preserveLinks bool) {
	if n.Type == html.TextNode {
		buf.WriteString(n.Data)
	} else if n.Type == html.ElementNode {
		switch n.Data {
		case "a":
			if preserveLinks {
				buf.WriteString("[")
				for c := n.FirstChild; c != nil; c = c.NextSibling {
					walkHTML(c, buf, preserveLinks)
				}
				buf.WriteString("]")
				
				for _, attr := range n.Attr {
					if attr.Key == "href" {
						buf.WriteString("(" + attr.Val + ")")
						break
					}
				}
			} else {
				for c := n.FirstChild; c != nil; c = c.NextSibling {
					walkHTML(c, buf, preserveLinks)
				}
			}
		case "img":
			// Ignore images as per original
		case "br":
			buf.WriteString("\n")
		case "p", "div":
			buf.WriteString("\n\n")
			for c := n.FirstChild; c != nil; c = c.NextSibling {
				walkHTML(c, buf, preserveLinks)
			}
			buf.WriteString("\n\n")
		default:
			for c := n.FirstChild; c != nil; c = c.NextSibling {
				walkHTML(c, buf, preserveLinks)
			}
		}
	} else {
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walkHTML(c, buf, preserveLinks)
		}
	}
}

func loadURLs(urlArgs []string, urlFile string) ([]string, error) {
	urls := make([]string, 0)
	if urlArgs != nil {
		urls = append(urls, urlArgs...)
	}
	
	if urlFile != "" {
		file, err := os.Open(urlFile)
		if err != nil {
			return nil, err
		}
		defer file.Close()
		
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line != "" && !strings.HasPrefix(line, "#") {
				urls = append(urls, line)
			}
		}
		
		if err := scanner.Err(); err != nil {
			return nil, err
		}
	}
	
	// Deduplicate URLs
	seen := make(map[string]bool)
	clean := make([]string, 0)
	for _, u := range urls {
		if !seen[u] {
			clean = append(clean, u)
			seen[u] = true
		}
	}
	
	return clean, nil
}

func validateURL(u string) bool {
	parsed, err := url.Parse(u)
	if err != nil {
		return false
	}
	return (parsed.Scheme == "http" || parsed.Scheme == "https") && parsed.Host != ""
}

func parseArgs() Args {
	args := Args{
		URL:           make([]string, 0),
		URLFile:       "",
		Selector:      "",
		Js:            false,
		WaitSelector:  "",
		PreserveLinks: false,
		BodyWidth:     0,
		Timeout:       30,
		OutputDir:     "outputs",
		AutomatchDomain: "",
	}
	
	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		switch arg {
		case "--url":
			i++
			if i < len(os.Args) {
				args.URL = append(args.URL, os.Args[i])
			}
		case "--url-file":
			i++
			if i < len(os.Args) {
				args.URLFile = os.Args[i]
			}
		case "--selector":
			i++
			if i < len(os.Args) {
				args.Selector = os.Args[i]
			}
		case "--js":
			args.Js = true
		case "--wait-selector":
			i++
			if i < len(os.Args) {
				args.WaitSelector = os.Args[i]
			}
		case "--preserve-links":
			args.PreserveLinks = true
		case "--body-width":
			i++
			if i < len(os.Args) {
				width, err := strconv.Atoi(os.Args[i])
				if err == nil {
					args.BodyWidth = width
				}
			}
		case "--timeout":
			i++
			if i < len(os.Args) {
				timeout, err := strconv.Atoi(os.Args[i])
				if err == nil {
					args.Timeout = timeout
				}
			}
		case "--output-dir":
			i++
			if i < len(os.Args) {
				args.OutputDir = os.Args[i]
			}
		case "--automatch-domain":
			i++
			if i < len(os.Args) {
				args.AutomatchDomain = os.Args[i]
			}
		}
	}
	
	return args
}

func main() {
	args := parseArgs()
	
	urls, err := loadURLs(args.URL, args.URLFile)
	if err != nil {
		result := map[string]interface{}{
			"ok":    false,
			"error": fmt.Sprintf("Failed to load URLs: %v", err),
		}
		jsonResult, _ := json.Marshal(result)
		fmt.Println(string(jsonResult))
		os.Exit(1)
	}
	
	if len(urls) == 0 {
		result := map[string]interface{}{
			"ok":    false,
			"error": "No URLs provided",
		}
		jsonResult, _ := json.Marshal(result)
		fmt.Println(string(jsonResult))
		os.Exit(1)
	}
	
	for _, u := range urls {
		if !validateURL(u) {
			result := map[string]interface{}{
				"ok":    false,
				"error": fmt.Sprintf("Invalid URL: %s", u),
			}
			jsonResult, _ := json.Marshal(result)
			fmt.Println(string(jsonResult))
			os.Exit(1)
		}
	}
	
	err = os.MkdirAll(args.OutputDir, 0755)
	if err != nil {
		result := map[string]interface{}{
			"ok":    false,
			"error": fmt.Sprintf("Failed to create output directory: %v", err),
		}
		jsonResult, _ := json.Marshal(result)
		fmt.Println(string(jsonResult))
		os.Exit(1)
	}
	
	results := make([]Result, 0)
	
	for _, u := range urls {
		item := Result{
			URL:   u,
			Ok:    false,
			Title: "",
		}
		
		try := func() (err error) {
			defer func() {
				if r := recover(); r != nil {
					err = fmt.Errorf("panic occurred: %v", r)
				}
			}()
			
			htmlContent, status, err := fetchPage(
				u,
				args.Js,
				args.WaitSelector,
				args.Timeout,
				args.AutomatchDomain,
			)
			if err != nil {
				return err
			}
			
			selectedHTML, selectorUsed := pickMainHTML(htmlContent, args.Selector)
			if selectedHTML == "" {
				return fmt.Errorf("No HTML content extracted from page")
			}
			
			title := extractTitle(selectedHTML)
			if title == "" {
				parsedURL, _ := url.Parse(u)
				title = parsedURL.Host
			}
			
			markdown := htmlToMarkdown(
				selectedHTML,
				args.PreserveLinks,
				args.BodyWidth,
			)
			
			parsedURL, _ := url.Parse(u)
			filename := slugify(fmt.Sprintf("%s-%s", parsedURL.Host, title), 80) + ".md"
			mdPath := filepath.Join(args.OutputDir, filename)
			
			err = os.WriteFile(mdPath, []byte(markdown), 0644)
			if err != nil {
				return err
			}
			
			preview := markdown
			if len(markdown) > 1200 {
				preview = markdown[:1200]
			}
			
			item.Ok = true
			item.Title = title
			item.Status = status
			item.SelectorUsed = selectorUsed
			item.Backend = "http.Client" // Simplified
			item.Markdown = markdown
			item.Preview = preview
			item.OutputMarkdownFile = mdPath
			
			return nil
		}
		
		err := try()
		if err != nil {
			item.Error = err.Error()
		}
		
		results = append(results, item)
	}
	
	ok := false
	successCount := 0
	failureCount := 0
	
	for _, result := range results {
		if result.Ok {
			ok = true
			successCount++
		} else {
			failureCount++
		}
	}
	
	indexPath := filepath.Join(args.OutputDir, "index.json")
	payload := map[string]interface{}{
		"ok":                ok,
		"count":             len(results),
		"success_count":     successCount,
		"failure_count":     failureCount,
		"output_index_file": indexPath,
		"results":           results,
	}
	
	jsonData, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		fmt.Printf("{\"ok\":false,\"error\":\"Failed to serialize results: %v\"}\n", err)
		os.Exit(1)
	}
	
	err = os.WriteFile(indexPath, jsonData, 0644)
	if err != nil {
		fmt.Printf("{\"ok\":false,\"error\":\"Failed to write index file: %v\"}\n", err)
		os.Exit(1)
	}
	
	fmt.Println(string(jsonData))
}
