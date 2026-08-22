#!/bin/bash
# scrape_to_markdown.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# SECURITY MANIFEST:
# Environment variables accessed: none
# External endpoints called: only URLs supplied by the user at runtime via --url / --url-file
# Local files read: --url-file path (if provided by user)
# Local files written: --output-dir/*.md, --output-dir/index.json (if --output-dir provided)
#                      Scrapling automatch SQLite DB (managed by Scrapling, local only)
# Credentials handled: --proxy value (never logged or transmitted beyond the proxy itself)
# Shell injection risk: none (pure Bash, no eval or command substitution on user input)

to_str() {
    local value="$1"
    if [[ "$value" == "None" ]] || [[ -z "$value" ]]; then
        echo ""
        return
    fi
    echo "$value"
}

slugify() {
    local text="$1"
    local max_len="${2:-80}"
    # Remove non-word characters and convert to lowercase
    text=$(echo "$text" | sed 's/[^a-zA-Z0-9 _-]//g' | tr '[:upper:]' '[:lower:]')
    # Replace spaces and hyphens with single hyphen
    text=$(echo "$text" | sed 's/[- _]\+/-/g')
    # Trim leading/trailing hyphens and limit length
    text=$(echo "$text" | sed 's/^-//' | sed 's/-$//' | cut -c1-"$max_len")
    if [[ -z "$text" ]]; then
        echo "page"
    else
        echo "$text"
    fi
}

extract_html() {
    local obj="$1"
    if [[ "$obj" == "None" ]] || [[ -z "$obj" ]]; then
        echo ""
        return
    fi
    
    # Try common HTML attributes
    for attr in "html" "raw_html" "content" "markup" "body" "inner_html"; do
        # In bash we can't directly access object attributes, so we simulate by checking if 
        # the variable contains HTML-like content
        if [[ "$obj" == *"<"* ]] && [[ "$obj" == *">"* ]]; then
            echo "$obj"
            return
        fi
    done
    
    # If still no HTML found, return the string if it looks like HTML
    if [[ "$obj" == *"<"* ]] && [[ "$obj" == *">"* ]]; then
        echo "$obj"
    else
        echo ""
    fi
}

extract_title() {
    local html="$1"
    # Extract title tag content
    if [[ "$html" =~ \<title[^\>]*\>(.*)\<\/title\> ]]; then
        local title="${BASH_REMATCH[1]}"
        # Remove HTML tags from title
        title=$(echo "$title" | sed 's/<[^>]*>//g')
        # Normalize whitespace
        title=$(echo "$title" | tr -s ' ' | sed 's/^ *//;s/ *$//')
        echo "$title"
    else
        echo ""
    fi
}

pick_main_html() {
    local page="$1"
    local preferred_selector="${2:-}"
    
    # We don't have CSS selection capabilities in bash, so we just return the page content
    echo "$page"
}

html_to_markdown() {
    local html="$1"
    local preserve_links="${2:-false}"
    local body_width="${3:-0}"
    
    # This is a very basic conversion - in reality you'd want to use a proper tool
    # For now we'll just strip most HTML tags and preserve some structure
    
    # Convert headers
    local md="$html"
    md=$(echo "$md" | sed 's/<h1[^>]*>/# /g' | sed 's/<\/h1>/\n/g')
    md=$(echo "$md" | sed 's/<h2[^>]*>/## /g' | sed 's/<\/h2>/\n/g')
    md=$(echo "$md" | sed 's/<h3[^>]*>/### /g' | sed 's/<\/h3>/\n/g')
    md=$(echo "$md" | sed 's/<h4[^>]*>/#### /g' | sed 's/<\/h4>/\n/g')
    md=$(echo "$md" | sed 's/<h5[^>]*>/##### /g' | sed 's/<\/h5>/\n/g')
    md=$(echo "$md" | sed 's/<h6[^>]*>/###### /g' | sed 's/<\/h6>/\n/g')
    
    # Convert paragraphs
    md=$(echo "$md" | sed 's/<p[^>]*>/\n/g' | sed 's/<\/p>/\n/g')
    
    # Convert lists
    md=$(echo "$md" | sed 's/<ul[^>]*>/\n/g' | sed 's/<\/ul>/\n/g')
    md=$(echo "$md" | sed 's/<ol[^>]*>/\n/g' | sed 's/<\/ol>/\n/g')
    md=$(echo "$md" | sed 's/<li[^>]*>- /g' | sed 's/<\/li>/\n/g')
    
    # Convert links if preserving them
    if [[ "$preserve_links" == "true" ]]; then
        # Keep link text but remove href
        md=$(echo "$md" | sed 's/<a[^>]*href=["'"'"'][^"'"'"']*["'"'"'][^>]*>/[/g' | sed 's/<\/a>/]/g')
    else
        # Just remove anchor tags but keep content
        md=$(echo "$md" | sed 's/<a[^>]*>//g' | sed 's/<\/a>//g')
    fi
    
    # Convert bold/strong
    md=$(echo "$md" | sed 's/<b[^>]*>/**/g' | sed 's/<\/b>/**/g')
    md=$(echo "$md" | sed 's/<strong[^>]*>/**/g' | sed 's/<\/strong>/**/g')
    
    # Convert emphasis
    md=$(echo "$md" | sed 's/<i[^>]*>/*/g' | sed 's/<\/i>/*/g')
    md=$(echo "$md" | sed 's/<em[^>]*>/*/g' | sed 's/<\/em>/*/g')
    
    # Remove remaining HTML tags
    md=$(echo "$md" | sed 's/<[^>]*>//g')
    
    # Normalize whitespace
    md=$(echo "$md" | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Limit body width if specified
    if [[ $body_width -gt 0 ]]; then
        # Wrap lines (basic implementation)
        md=$(echo "$md" | fold -w "$body_width" -s)
    fi
    
    # Reduce multiple newlines
    md=$(echo "$md" | tr '\n' '\r' | sed 's/\r\r\r*/\n\n/g' | tr '\r' '\n')
    
    echo "$md" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

load_urls() {
    local -a url_args=("${!1}")
    local url_file="$2"
    
    local -a urls=()
    
    # Add direct URLs
    for url in "${url_args[@]}"; do
        urls+=("$url")
    done
    
    # Load from file if provided
    if [[ -n "$url_file" ]] && [[ -f "$url_file" ]]; then
        while IFS= read -r line; do
            # Skip empty lines and comments
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
                urls+=("$line")
            fi
        done < "$url_file"
    fi
    
    # Deduplicate URLs
    local -a clean=()
    local -A seen=()
    for u in "${urls[@]}"; do
        if [[ -z "${seen[$u]:-}" ]]; then
            clean+=("$u")
            seen["$u"]=1
        fi
    done
    
    # Return the cleaned array
    printf '%s\n' "${clean[@]}"
}

validate_url() {
    local url="$1"
    if [[ "$url" =~ ^https?://[^/]+ ]]; then
        return 0
    else
        return 1
    fi
}

fetch_page() {
    local url="$1"
    local js="${2:-false}"
    local wait_selector="${3:-}"
    local timeout="${4:-30}"
    local automatch_domain="${5:-}"
    
    # Use curl to fetch the page
    local temp_file
    temp_file=$(mktemp)
    
    local cmd=(curl -s -L)
    
    # Set timeout
    cmd+=("--max-time" "$timeout")
    
    # Add user agent to appear more browser-like
    cmd+=("-H" "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
    
    # Follow redirects
    cmd+=("-L")
    
    # Fetch the page
    if "${cmd[@]}" "$url" > "$temp_file" 2>/dev/null; then
        cat "$temp_file"
        rm "$temp_file"
        return 0
    else
        rm "$temp_file"
        return 1
    fi
}

main() {
    # Parse arguments
    local -a urls=()
    local url_file=""
    local selector=""
    local js=false
    local wait_selector=""
    local preserve_links=false
    local body_width=0
    local timeout=30
    local output_dir="outputs"
    local automatch_domain=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --url)
                urls+=("$2")
                shift 2
                ;;
            --url-file)
                url_file="$2"
                shift 2
                ;;
            --selector)
                selector="$2"
                shift 2
                ;;
            --js)
                js=true
                shift
                ;;
            --wait-selector)
                wait_selector="$2"
                shift 2
                ;;
            --preserve-links)
                preserve_links=true
                shift
                ;;
            --body-width)
                body_width="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --automatch-domain)
                automatch_domain="$2"
                shift 2
                ;;
            *)
                echo '{"ok": false, "error": "Unknown argument: '"$1"'"}' >&2
                exit 1
                ;;
        esac
    done
    
    # Load URLs
    mapfile -t urls < <(load_urls urls[@] "$url_file")
    
    # Check if we have URLs
    if [[ ${#urls[@]} -eq 0 ]]; then
        echo '{"ok": false, "error": "No URLs provided"}'
        exit 1
    fi
    
    # Validate URLs
    for u in "${urls[@]}"; do
        if ! validate_url "$u"; then
            echo '{"ok": false, "error": "Invalid URL: '"$u"'"}'
            exit 1
        fi
    done
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Process each URL
    local -a results=()
    local overall_success=false
    
    for url in "${urls[@]}"; do
        local item="{\"url\": \"$url\", \"ok\": false, \"title\": \"\", \"status\": null, \"selector_used\": null, \"backend\": null, \"markdown\": \"\", \"preview\": \"\", \"output_markdown_file\": null, \"error\": null}"
        
        local error_msg=""
        local page_content=""
        local title=""
        local markdown=""
        local status="200"  # Default assumption for successful fetch
        
        # Try to fetch the page
        if page_content=$(fetch_page "$url" "$js" "$wait_selector" "$timeout" "$automatch_domain"); then
            # Extract main HTML content
            local html
            html=$(pick_main_html "$page_content" "$selector")
            
            if [[ -z "$html" ]]; then
                error_msg="No HTML content extracted from page"
            else
                # Extract title
                title=$(extract_title "$html")
                if [[ -z "$title" ]]; then
                    # Fallback to domain name
                    title=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')
                fi
                
                # Convert to markdown
                markdown=$(html_to_markdown "$html" "$preserve_links" "$body_width")
                
                if [[ -z "$markdown" ]]; then
                    error_msg="Failed to convert HTML to markdown"
                else
                    # Write markdown file
                    local filename
                    local domain
                    domain=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')
                    filename=$(slugify "${domain}-${title}")".md"
                    local md_path="$output_dir/$filename"
                    
                    echo "$markdown" > "$md_path"
                    
                    # Update success item
                    local preview="${markdown:0:1200}"
                    item="{\"url\": \"$url\", \"ok\": true, \"title\": \"$title\", \"status\": \"$status\", \"selector_used\": null, \"backend\": \"curl\", \"markdown\": \"$(echo "$markdown" | sed 's/"/\\"/g')\", \"preview\": \"$(echo "$preview" | sed 's/"/\\"/g')\", \"output_markdown_file\": \"$md_path\", \"error\": null}"
                    overall_success=true
                fi
            fi
        else
            error_msg="Failed to fetch page"
        fi
        
        if [[ -n "$error_msg" ]]; then
            item="{\"url\": \"$url\", \"ok\": false, \"title\": \"\", \"status\": null, \"selector_used\": null, \"backend\": null, \"markdown\": \"\", \"preview\": \"\", \"output_markdown_file\": null, \"error\": \"$error_msg\"}"
        fi
        
        results+=("$item")
    done
    
    # Generate summary statistics
    local count=${#results[@]}
    local success_count=0
    local failure_count=0
    
    for result in "${results[@]}"; do
        if [[ "$result" == *"\"ok\": true"* ]]; then
            ((success_count++))
        else
            ((failure_count++))
        fi
    done
    
    local index_path="$output_dir/index.json"
    
    # Build JSON payload manually
    local results_json=""
    local first=true
    for result in "${results[@]}"; do
        if [[ "$first" == true ]]; then
            results_json="$result"
            first=false
        else
            results_json="$results_json,$result"
        fi
    done
    
    local payload="{\"ok\": $overall_success, \"count\": $count, \"success_count\": $success_count, \"failure_count\": $failure_count, \"output_index_file\": \"$index_path\", \"results\": [$results_json]}"
    
    # Write index file
    echo "$payload" > "$index_path"
    
    # Output final result
    echo "$payload"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
