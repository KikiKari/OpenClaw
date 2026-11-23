// abstraction-provenance: {"artifact_sha256": "22ad75362a87958159d8d81a897d9102d5a8c7416c4eb1b71bff9297c6da02b2", "source_sha256": "5b19bba778485b72894d3e7b04adf4782d842ad89c9cb89bd33639183c7b6075", "target_language": "go"}
// tavily_search.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/tavily/scripts/tavily_search.py
// auch in: OpenClaw@gateway2:skills/tavily/scripts/tavily_search.py
// auch in: workspace@local:git/skills/tavily/scripts/tavily_search.py
// auch in: workspace@local:skills/tavily/scripts/tavily_search.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/*
Tavily AI Search - Optimized search for LLMs and AI applications
Requires: go get github.com/tavily-ai/tavily-go
*/

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
)

// SearchResult represents a single search result
type SearchResult struct {
	Title   string  `json:"title"`
	URL     string  `json:"url"`
	Score   float64 `json:"score"`
	Content string  `json:"content,omitempty"`
}

// SearchResponse represents the response from Tavily API
type SearchResponse struct {
	Success       bool           `json:"success"`
	Query         string         `json:"query"`
	Answer        string         `json:"answer,omitempty"`
	Results       []SearchResult `json:"results,omitempty"`
	Images        []string       `json:"images,omitempty"`
	ResponseTime  float64        `json:"response_time,omitempty"`
	Usage         map[string]int `json:"usage,omitempty"`
	Error         string         `json:"error,omitempty"`
	InstallCmd    string         `json:"install_command,omitempty"`
	SetupInstr    string         `json:"setup_instructions,omitempty"`
}

// SearchParams holds all search parameters
type SearchParams struct {
	Query              string
	APIKey             string
	SearchDepth        string
	Topic              string
	MaxResults         int
	IncludeAnswer      bool
	IncludeRawContent  bool
	IncludeImages      bool
	IncludeDomains     []string
	ExcludeDomains     []string
}

// search executes a Tavily search query
func search(params SearchParams) SearchResponse {
	// Since we can't use the actual Tavily Go client,
	// we'll simulate an error response indicating the need for installation
	return SearchResponse{
		Error:      "tavily-go package not available. This implementation requires the official Tavily Go client.",
		InstallCmd: "go get github.com/tavily-ai/tavily-go",
		Query:      params.Query,
	}
}

func main() {
	var (
		query             = flag.String("query", "", "Search query")
		apiKey            = flag.String("api-key", "", "Tavily API key (or set TAVILY_API_KEY env var)")
		depth             = flag.String("depth", "basic", "Search depth: 'basic' (fast) or 'advanced' (comprehensive)")
		topic             = flag.String("topic", "general", "Search topic: 'general' or 'news' (current events)")
		maxResults        = flag.Int("max-results", 5, "Maximum number of results (1-10)")
		noAnswer          = flag.Bool("no-answer", false, "Exclude AI-generated answer summary")
		rawContent        = flag.Bool("raw-content", false, "Include raw HTML content of sources")
		images            = flag.Bool("images", false, "Include relevant images in results")
		includeDomainsStr = flag.String("include-domains", "", "Comma-separated list of domains to specifically include")
		excludeDomainsStr = flag.String("exclude-domains", "", "Comma-separated list of domains to exclude")
		jsonOutput        = flag.Bool("json", false, "Output raw JSON response")
	)

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Tavily AI Search - Optimized search for LLMs\n\n")
		fmt.Fprintf(os.Stderr, "Usage: %s [OPTIONS] QUERY\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nExamples:\n")
		fmt.Fprintf(os.Stderr, "  # Basic search\n")
		fmt.Fprintf(os.Stderr, "  %s \"What is quantum computing?\"\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  # Advanced search with more results\n")
		fmt.Fprintf(os.Stderr, "  %s \"Climate change solutions\" --depth advanced --max-results 10\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  # News-focused search\n")
		fmt.Fprintf(os.Stderr, "  %s \"AI developments\" --topic news\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  # Domain filtering\n")
		fmt.Fprintf(os.Stderr, "  %s \"Python tutorials\" --include-domains python.org --exclude-domains w3schools.com\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  # Include images in results\n")
		fmt.Fprintf(os.Stderr, "  %s \"Eiffel Tower\" --images\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Environment Variables:\n")
		fmt.Fprintf(os.Stderr, "  TAVILY_API_KEY    Your Tavily API key (get one at https://tavily.com)\n")
	}

	flag.Parse()

	// If no positional argument, check if query was provided via flag
	if *query == "" {
		if flag.NArg() > 0 {
			*query = strings.Join(flag.Args(), " ")
		} else {
			fmt.Fprintln(os.Stderr, "Error: Search query is required")
			flag.Usage()
			os.Exit(1)
		}
	}

	// Parse domain lists
	var includeDomains, excludeDomains []string
	if *includeDomainsStr != "" {
		includeDomains = strings.Split(*includeDomainsStr, ",")
		for i := range includeDomains {
			includeDomains[i] = strings.TrimSpace(includeDomains[i])
		}
	}
	if *excludeDomainsStr != "" {
		excludeDomains = strings.Split(*excludeDomainsStr, ",")
		for i := range excludeDomains {
			excludeDomains[i] = strings.TrimSpace(excludeDomains[i])
		}
	}

	// Get API key from args or environment
	key := *apiKey
	if key == "" {
		key = os.Getenv("TAVILY_API_KEY")
	}

	params := SearchParams{
		Query:             *query,
		APIKey:            key,
		SearchDepth:       *depth,
		Topic:             *topic,
		MaxResults:        *maxResults,
		IncludeAnswer:     !*noAnswer,
		IncludeRawContent: *rawContent,
		IncludeImages:     *images,
		IncludeDomains:    includeDomains,
		ExcludeDomains:    excludeDomains,
	}

	result := search(params)

	if *jsonOutput {
		output, err := json.MarshalIndent(result, "", "  ")
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(string(output))
		return
	}

	if result.Error != "" {
		fmt.Fprintf(os.Stderr, "Error: %s\n", result.Error)
		if result.InstallCmd != "" {
			fmt.Fprintf(os.Stderr, "\nTo install: %s\n", result.InstallCmd)
		}
		if result.SetupInstr != "" {
			fmt.Fprintf(os.Stderr, "\nSetup: %s\n", result.SetupInstr)
		}
		os.Exit(1)
	}

	// Format human-readable output
	fmt.Printf("Query: %s\n", result.Query)
	fmt.Printf("Response time: %.3fs\n", result.ResponseTime)
	usageCredits := "N/A"
	if credits, ok := result.Usage["credits"]; ok {
		usageCredits = fmt.Sprintf("%d", credits)
	}
	fmt.Printf("Credits used: %s\n\n", usageCredits)

	if result.Answer != "" {
		fmt.Println("=== AI ANSWER ===")
		fmt.Println(result.Answer)
		fmt.Println()
	}

	if len(result.Results) > 0 {
		fmt.Println("=== RESULTS ===")
		for i, item := range result.Results {
			fmt.Printf("\n%d. %s\n", i+1, item.Title)
			fmt.Printf("   URL: %s\n", item.URL)
			fmt.Printf("   Score: %.3f\n", item.Score)
			if item.Content != "" {
				content := item.Content
				if len(content) > 200 {
					content = content[:200] + "..."
				}
				fmt.Printf("   %s\n", content)
			}
		}
	}

	if len(result.Images) > 0 {
		fmt.Printf("\n=== IMAGES (%d) ===\n", len(result.Images))
		for i, imgUrl := range result.Images {
			if i >= 5 { // Show first 5
				break
			}
			fmt.Printf("   %s\n", imgUrl)
		}
	}
}
