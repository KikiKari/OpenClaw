#!/usr/bin/env bash
# tavily_search.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/tavily/scripts/tavily_search.py
# auch in: OpenClaw@gateway2:skills/tavily/scripts/tavily_search.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Tavily AI Search - Optimized search for LLMs and AI applications
# Requires: curl, jq

# Default values
API_KEY=""
SEARCH_DEPTH="basic"
TOPIC="general"
MAX_RESULTS=5
INCLUDE_ANSWER=true
INCLUDE_RAW_CONTENT=false
INCLUDE_IMAGES=false
INCLUDE_DOMAINS=()
EXCLUDE_DOMAINS=()
OUTPUT_JSON=false

# Function to display usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] QUERY

Tavily AI Search - Optimized search for LLMs

Options:
  --api-key KEY         Tavily API key (or set TAVILY_API_KEY env var)
  --depth DEPTH         Search depth: basic (fast) or advanced (comprehensive)
  --topic TOPIC         Search topic: general or news (current events)
  --max-results NUM     Maximum number of results (1-10)
  --no-answer           Exclude AI-generated answer summary
  --raw-content         Include raw HTML content of sources
  --images              Include relevant images in results
  --include-domains DOMAINS  List of domains to specifically include
  --exclude-domains DOMAINS  List of domains to exclude
  --json                Output raw JSON response
  --help                Display this help message

Examples:
  # Basic search
  $0 "What is quantum computing?"

  # Advanced search with more results
  $0 "Climate change solutions" --depth advanced --max-results 10

  # News-focused search
  $0 "AI developments" --topic news

  # Domain filtering
  $0 "Python tutorials" --include-domains python.org --exclude-domains w3schools.com

  # Include images in results
  $0 "Eiffel Tower" --images

Environment Variables:
  TAVILY_API_KEY    Your Tavily API key (get one at https://tavily.com)
EOF
}

# Function to perform the search
search() {
    local query="$1"
    
    # Check if API key is provided
    if [[ -z "$API_KEY" ]]; then
        echo '{"error": "Tavily API key required. Get one at https://tavily.com", "setup_instructions": "Set TAVILY_API_KEY environment variable or pass --api-key"}' >&2
        exit 1
    fi
    
    # Prepare the request body
    local request_body="{\"api_key\":\"$API_KEY\",\"query\":\"$query\",\"search_depth\":\"$SEARCH_DEPTH\",\"topic\":\"$TOPIC\",\"max_results\":$MAX_RESULTS,\"include_answer\":$INCLUDE_ANSWER,\"include_raw_content\":$INCLUDE_RAW_CONTENT,\"include_images\":$INCLUDE_IMAGES}"
    
    # Add include_domains if specified
    if [[ ${#INCLUDE_DOMAINS[@]} -gt 0 ]]; then
        local include_domains_json=$(printf '%s\n' "${INCLUDE_DOMAINS[@]}" | jq -R . | jq -s .)
        request_body=$(echo "$request_body" | jq ".include_domains = $include_domains_json")
    fi
    
    # Add exclude_domains if specified
    if [[ ${#EXCLUDE_DOMAINS[@]} -gt 0 ]]; then
        local exclude_domains_json=$(printf '%s\n' "${EXCLUDE_DOMAINS[@]}" | jq -R . | jq -s .)
        request_body=$(echo "$request_body" | jq ".exclude_domains = $exclude_domains_json")
    fi
    
    # Make the API request
    local response
    response=$(curl -s -X POST "https://api.tavily.com/search" \
        -H "Content-Type: application/json" \
        -d "$request_body")
    
    # Check if the response contains an error
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "$response" | jq '{error: .error.message, query: $query}' --arg query "$query"
        exit 1
    fi
    
    # Format the response
    echo "$response" | jq '{
        success: true,
        query: $query,
        answer: .answer,
        results: .results,
        images: .images,
        response_time: .response_time,
        usage: .usage
    }' --arg query "$query"
}

# Main function
main() {
    local query=""
    
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --api-key)
                API_KEY="$2"
                shift 2
                ;;
            --depth)
                SEARCH_DEPTH="$2"
                shift 2
                ;;
            --topic)
                TOPIC="$2"
                shift 2
                ;;
            --max-results)
                MAX_RESULTS="$2"
                shift 2
                ;;
            --no-answer)
                INCLUDE_ANSWER=false
                shift
                ;;
            --raw-content)
                INCLUDE_RAW_CONTENT=true
                shift
                ;;
            --images)
                INCLUDE_IMAGES=true
                shift
                ;;
            --include-domains)
                shift
                while [[ $# -gt 0 && $1 != --* ]]; do
                    INCLUDE_DOMAINS+=("$1")
                    shift
                done
                ;;
            --exclude-domains)
                shift
                while [[ $# -gt 0 && $1 != --* ]]; do
                    EXCLUDE_DOMAINS+=("$1")
                    shift
                done
                ;;
            --json)
                OUTPUT_JSON=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                query="$1"
                shift
                ;;
        esac
    done
    
    # If no query is provided, show usage
    if [[ -z "$query" ]]; then
        usage
        exit 1
    fi
    
    # Get API key from environment variable if not provided via argument
    if [[ -z "$API_KEY" ]]; then
        API_KEY="${TAVILY_API_KEY:-}"
    fi
    
    # Perform the search
    local result
    result=$(search "$query")
    
    # Output JSON if requested
    if [[ "$OUTPUT_JSON" == true ]]; then
        echo "$result" | jq .
        exit 0
    fi
    
    # Format human-readable output
    local answer
    answer=$(echo "$result" | jq -r '.answer')
    local response_time
    response_time=$(echo "$result" | jq -r '.response_time')
    local credits_used
    credits_used=$(echo "$result" | jq -r '.usage.credits // "N/A"')
    
    echo "Query: $query"
    echo "Response time: ${response_time} s"
    echo "Credits used: $credits_used"
    echo ""
    
    if [[ "$answer" != "null" ]]; then
        echo "=== AI ANSWER ==="
        echo "$answer"
        echo ""
    fi
    
    local results
    results=$(echo "$result" | jq -c '.results[]')
    if [[ -n "$results" ]]; then
        echo "=== RESULTS ==="
        local i=1
        while IFS= read -r item; do
            local title
            title=$(echo "$item" | jq -r '.title // "No title"')
            local url
            url=$(echo "$item" | jq -r '.url // "N/A"')
            local score
            score=$(echo "$item" | jq -r '.score // "N/A"')
            local content
            content=$(echo "$item" | jq -r '.content')
            
            echo ""
            echo "$i. $title"
            echo "   URL: $url"
            echo "   Score: $score"
            if [[ -n "$content" && "$content" != "null" ]]; then
                if [[ ${#content} -gt 200 ]]; then
                    content="${content:0:200}..."
                fi
                echo "   $content"
            fi
            ((i++))
        done <<< "$(echo "$results")"
    fi
    
    local images
    images=$(echo "$result" | jq -r '.images // []')
    if [[ "$images" != "[]" ]]; then
        local image_count
        image_count=$(echo "$images" | jq 'length')
        echo ""
        echo "=== IMAGES ($image_count) ==="
        echo "$images" | jq -r '.[:5][]'
    fi
}

# Call main function with all arguments
main "$@"
