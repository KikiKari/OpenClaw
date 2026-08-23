#!/usr/bin/env node
// tavily_search.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/tavily/scripts/tavily_search.py
// auch in: OpenClaw@gateway2:skills/tavily/scripts/tavily_search.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/**
 * Tavily AI Search - Optimized search for LLMs and AI applications
 * Requires: npm install tavily-js
 */

const fs = require('fs');

/**
 * Execute a Tavily search query.
 * 
 * @param {string} query - Search query string
 * @param {string} apiKey - Tavily API key (tvly-...)
 * @param {Object} options - Search options
 * @returns {Promise<Object>} Tavily API response
 */
async function search(query, apiKey, options = {}) {
    const {
        searchDepth = "basic",
        topic = "general",
        maxResults = 5,
        includeAnswer = true,
        includeRawContent = false,
        includeImages = false,
        includeDomains = null,
        excludeDomains = null
    } = options;

    if (!apiKey) {
        return {
            error: "Tavily API key required. Get one at https://tavily.com",
            setupInstructions: "Set TAVILY_API_KEY environment variable or pass --api-key"
        };
    }

    try {
        // Dynamically import tavily-js
        const { TavilyClient } = await import('tavily-js');
        const client = new TavilyClient({ apiKey });
        
        // Build search parameters
        const searchParams = {
            query,
            searchDepth,
            topic,
            maxResults,
            includeAnswer,
            includeRawContent,
            includeImages
        };
        
        if (includeDomains) {
            searchParams.includeDomains = includeDomains;
        }
        if (excludeDomains) {
            searchParams.excludeDomains = excludeDomains;
        }
        
        const response = await client.search(searchParams);
        
        return {
            success: true,
            query,
            answer: response.answer,
            results: response.results || [],
            images: response.images || [],
            responseTime: response.responseTime,
            usage: response.usage || {}
        };
        
    } catch (error) {
        if (error.code === 'MODULE_NOT_FOUND') {
            return {
                error: "tavily-js package not installed. Run: npm install tavily-js",
                installCommand: "npm install tavily-js"
            };
        }
        return {
            error: error.message,
            query
        };
    }
}

function parseArguments() {
    const args = process.argv.slice(2);
    const parsed = {
        query: '',
        apiKey: null,
        depth: 'basic',
        topic: 'general',
        maxResults: 5,
        noAnswer: false,
        rawContent: false,
        images: false,
        includeDomains: null,
        excludeDomains: null,
        json: false,
        help: false
    };

    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        
        if (arg === '--help' || arg === '-h') {
            parsed.help = true;
        } else if (arg === '--api-key') {
            parsed.apiKey = args[++i];
        } else if (arg === '--depth') {
            parsed.depth = args[++i];
        } else if (arg === '--topic') {
            parsed.topic = args[++i];
        } else if (arg === '--max-results') {
            parsed.maxResults = parseInt(args[++i]);
        } else if (arg === '--no-answer') {
            parsed.noAnswer = true;
        } else if (arg === '--raw-content') {
            parsed.rawContent = true;
        } else if (arg === '--images') {
            parsed.images = true;
        } else if (arg === '--include-domains') {
            parsed.includeDomains = args[++i].split(',');
        } else if (arg === '--exclude-domains') {
            parsed.excludeDomains = args[++i].split(',');
        } else if (arg === '--json') {
            parsed.json = true;
        } else if (!arg.startsWith('--')) {
            if (!parsed.query) {
                parsed.query = arg;
            }
        }
    }
    
    return parsed;
}

function showHelp() {
    console.log(`
Tavily AI Search - Optimized search for LLMs

Usage:
  node tavily_search.js [query] [options]

Options:
  --api-key KEY          Tavily API key (or set TAVILY_API_KEY env var)
  --depth basic|advanced Search depth: 'basic' (fast) or 'advanced' (comprehensive)
  --topic general|news  Search topic: 'general' or 'news' (current events)
  --max-results NUM      Maximum number of results (1-10)
  --no-answer           Exclude AI-generated answer summary
  --raw-content         Include raw HTML content of sources
  --images              Include relevant images in results
  --include-domains D   Comma-separated list of domains to specifically include
  --exclude-domains D   Comma-separated list of domains to exclude
  --json                Output raw JSON response
  --help                Show this help message

Examples:
  # Basic search
  node tavily_search.js "What is quantum computing?"
  
  # Advanced search with more results
  node tavily_search.js "Climate change solutions" --depth advanced --max-results 10
  
  # News-focused search
  node tavily_search.js "AI developments" --topic news
  
  # Domain filtering
  node tavily_search.js "Python tutorials" --include-domains python.org --exclude-domains w3schools.com
  
  # Include images in results
  node tavily_search.js "Eiffel Tower" --images

Environment Variables:
  TAVILY_API_KEY    Your Tavily API key (get one at https://tavily.com)
`);
}

async function main() {
    const args = parseArguments();
    
    if (args.help || !args.query) {
        showHelp();
        process.exit(args.help ? 0 : 1);
    }
    
    // Get API key from args or environment
    const apiKey = args.apiKey || process.env.TAVILY_API_KEY;
    
    const result = await search(
        args.query,
        apiKey,
        {
            searchDepth: args.depth,
            topic: args.topic,
            maxResults: args.maxResults,
            includeAnswer: !args.noAnswer,
            includeRawContent: args.rawContent,
            includeImages: args.images,
            includeDomains: args.includeDomains,
            excludeDomains: args.excludeDomains
        }
    );
    
    if (args.json) {
        console.log(JSON.stringify(result, null, 2));
    } else {
        if (result.error) {
            console.error(`Error: ${result.error}`);
            if (result.installCommand) {
                console.error(`\nTo install: ${result.installCommand}`);
            }
            if (result.setupInstructions) {
                console.error(`\nSetup: ${result.setupInstructions}`);
            }
            process.exit(1);
        }
        
        // Format human-readable output
        console.log(`Query: ${result.query}`);
        console.log(`Response time: ${result.responseTime || 'N/A'}s`);
        console.log(`Credits used: ${result.usage?.credits || 'N/A'}\n`);
        
        if (result.answer) {
            console.log("=== AI ANSWER ===");
            console.log(result.answer);
            console.log();
        }
        
        if (result.results && result.results.length > 0) {
            console.log("=== RESULTS ===");
            result.results.forEach((item, i) => {
                console.log(`\n${i + 1}. ${item.title || 'No title'}`);
                console.log(`   URL: ${item.url || 'N/A'}`);
                console.log(`   Score: ${item.score !== undefined ? item.score.toFixed(3) : 'N/A'}`);
                if (item.content) {
                    let content = item.content;
                    if (content.length > 200) {
                        content = content.substring(0, 200) + "...";
                    }
                    console.log(`   ${content}`);
                }
            });
        }
        
        if (result.images && result.images.length > 0) {
            console.log(`\n=== IMAGES (${result.images.length}) ===`);
            result.images.slice(0, 5).forEach(imgUrl => {
                console.log(`   ${imgUrl}`);
            });
        }
    }
}

if (require.main === module) {
    main().catch(error => {
        console.error("Unexpected error:", error);
        process.exit(1);
    });
}

module.exports = { search };
