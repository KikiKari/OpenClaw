#!/usr/bin/env node
// scrape_to_markdown.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

// SECURITY MANIFEST:
// Environment variables accessed: none
// External endpoints called: only URLs supplied by the user at runtime via --url / --url-file
// Local files read: --url-file path (if provided by user)
// Local files written: --output-dir/*.md, --output-dir/index.json (if --output-dir provided)
//                      Scrapling automatch SQLite DB (managed by Scrapling, local only)
// Credentials handled: --proxy value (never logged or transmitted beyond the proxy itself)
// Shell injection risk: none (pure JavaScript, no subprocess or shell interpolation)

const fs = require('fs');
const path = require('path');
const { URL } = require('url');
const { JSDOM } = require('jsdom');
const TurndownService = require('turndown');

function toStr(value) {
    if (value === null || value === undefined) {
        return "";
    }
    if (Buffer.isBuffer(value)) {
        return value.toString('utf-8');
    }
    return String(value);
}

function slugify(text, maxLen = 80) {
    let result = text.replace(/[^\w\s-]/g, '').trim().toLowerCase();
    result = result.replace(/[-\s]+/g, '-');
    result = result.substring(0, maxLen).replace(/^-+|-+$/g, '');
    return result || "page";
}

function extractHtml(obj) {
    if (obj === null || obj === undefined) {
        return "";
    }
    
    const attrs = ["html", "rawHtml", "content", "markup", "body", "innerHtml"];
    for (const attr of attrs) {
        let value = typeof obj[attr] === 'function' ? obj[attr]() : obj[attr];
        const text = toStr(value);
        if (text && text.includes("<") && text.includes(">")) {
            return text;
        }
    }
    
    const text = toStr(obj);
    return (text.includes("<") && text.includes(">")) ? text : "";
}

function extractTitle(html) {
    const match = html.match(/<title[^>]*>(.*?)<\/title>/is);
    if (!match) {
        return "";
    }
    let title = match[1].replace(/<[^>]+>/g, " ");
    title = title.replace(/\s+/g, " ").trim();
    return title;
}

// Note: In Node.js we can't dynamically import Python modules like Scrapling.
// We'll use standard HTTP clients instead.
async function fetchPage(url, js = false, waitSelector = null, timeout = 30) {
    // For JS-enabled fetching, we would need puppeteer or similar
    // For now, we'll implement a basic fetch using node-fetch
    const fetch = (await import('node-fetch')).default;
    
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeout * 1000);
        
        const response = await fetch(url, {
            signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        
        const content = await response.text();
        return {
            status: response.status,
            status_code: response.status,
            html: content,
            rawHtml: content,
            content: content
        };
    } catch (error) {
        throw new Error(`Failed to fetch ${url}: ${error.message}`);
    }
}

function pickMainHtml(page, preferredSelector = null) {
    const htmlContent = extractHtml(page);
    if (!htmlContent) return ["", null];
    
    const selectors = [];
    if (preferredSelector) {
        selectors.push(preferredSelector);
    }
    selectors.push(
        "article",
        "main",
        "[role='main']",
        ".post-content",
        ".entry-content",
        ".article-content",
        "body"
    );
    
    try {
        const dom = new JSDOM(htmlContent);
        const document = dom.window.document;
        
        for (const selector of selectors) {
            const element = document.querySelector(selector);
            if (element) {
                const innerHtml = element.innerHTML;
                if (innerHtml && innerHtml.length >= 120) {
                    return [innerHtml, selector];
                }
            }
        }
    } catch (error) {
        // If DOM parsing fails, fall back to full HTML
    }
    
    return [htmlContent, null];
}

function htmlToMarkdown(html, preserveLinks = false, bodyWidth = 0) {
    const turndownService = new TurndownService({
        headingStyle: 'atx',
        hr: '---',
        bulletListMarker: '-',
        codeBlockStyle: 'fenced',
        emDelimiter: '*',
        strongDelimiter: '**',
        linkStyle: preserveLinks ? 'inlined' : 'referenced',
        linkReferenceStyle: 'full'
    });
    
    // Configure options based on parameters
    if (!preserveLinks) {
        turndownService.remove('a');
    }
    
    turndownService.remove('img'); // Always remove images
    
    let markdown = turndownService.turndown(html);
    
    // Apply body width limit manually if needed
    if (bodyWidth > 0) {
        const lines = markdown.split('\n');
        const wrappedLines = [];
        for (let line of lines) {
            while (line.length > bodyWidth) {
                const breakpoint = line.lastIndexOf(' ', bodyWidth);
                if (breakpoint === -1) {
                    wrappedLines.push(line.substring(0, bodyWidth));
                    line = line.substring(bodyWidth);
                } else {
                    wrappedLines.push(line.substring(0, breakpoint));
                    line = line.substring(breakpoint + 1);
                }
            }
            wrappedLines.push(line);
        }
        markdown = wrappedLines.join('\n');
    }
    
    // Normalize excessive newlines
    markdown = markdown.replace(/\n{3,}/g, '\n\n').trim();
    return markdown;
}

function loadUrls(urlArgs = [], urlFile = "") {
    let urls = [...urlArgs];
    
    if (urlFile) {
        const content = fs.readFileSync(urlFile, 'utf-8');
        const lines = content.split('\n');
        for (const line of lines) {
            const trimmed = line.trim();
            if (trimmed && !trimmed.startsWith('#')) {
                urls.push(trimmed);
            }
        }
    }
    
    // Remove duplicates while preserving order
    const seen = new Set();
    const clean = [];
    for (const u of urls) {
        if (!seen.has(u)) {
            clean.push(u);
            seen.add(u);
        }
    }
    
    return clean;
}

function validateUrl(url) {
    try {
        const parsed = new URL(url);
        return (parsed.protocol === 'http:' || parsed.protocol === 'https:') && 
               Boolean(parsed.hostname);
    } catch (error) {
        return false;
    }
}

function parseArguments() {
    const args = {
        url: [],
        urlFile: "",
        selector: "",
        js: false,
        waitSelector: "",
        preserveLinks: false,
        bodyWidth: 0,
        timeout: 30,
        outputDir: "outputs",
        automatchDomain: ""
    };
    
    for (let i = 2; i < process.argv.length; i++) {
        const arg = process.argv[i];
        switch (arg) {
            case '--url':
                args.url.push(process.argv[++i]);
                break;
            case '--url-file':
                args.urlFile = process.argv[++i];
                break;
            case '--selector':
                args.selector = process.argv[++i];
                break;
            case '--js':
                args.js = true;
                break;
            case '--wait-selector':
                args.waitSelector = process.argv[++i];
                break;
            case '--preserve-links':
                args.preserveLinks = true;
                break;
            case '--body-width':
                args.bodyWidth = parseInt(process.argv[++i], 10);
                break;
            case '--timeout':
                args.timeout = parseInt(process.argv[++i], 10);
                break;
            case '--output-dir':
                args.outputDir = process.argv[++i];
                break;
            case '--automatch-domain':
                args.automatchDomain = process.argv[++i];
                break;
        }
    }
    
    return args;
}

async function main() {
    const args = parseArguments();
    
    const urls = loadUrls(args.url, args.urlFile);
    if (urls.length === 0) {
        console.log(JSON.stringify({ok: false, error: "No URLs provided"}));
        process.exit(1);
    }
    
    for (const u of urls) {
        if (!validateUrl(u)) {
            console.log(JSON.stringify({ok: false, error: `Invalid URL: ${u}`}));
            process.exit(1);
        }
    }
    
    const outDir = path.resolve(args.outputDir);
    fs.mkdirSync(outDir, { recursive: true });
    
    const results = [];
    
    for (const url of urls) {
        const item = {
            url: url,
            ok: false,
            title: "",
            status: null,
            selectorUsed: null,
            backend: null,
            markdown: "",
            preview: "",
            outputMarkdownFile: null,
            error: null,
        };
        
        try {
            const page = await fetchPage(
                url,
                args.js,
                args.waitSelector || null,
                args.timeout
            );
            
            const [html, selectorUsed] = pickMainHtml(page, args.selector || null);
            if (!html) {
                throw new Error("No HTML content extracted from page");
            }
            
            const title = extractTitle(html) || new URL(url).hostname;
            const markdown = htmlToMarkdown(
                html,
                args.preserveLinks,
                args.bodyWidth
            );
            
            const filename = slugify(`${new URL(url).hostname}-${title}`) + ".md";
            const mdPath = path.join(outDir, filename);
            fs.writeFileSync(mdPath, markdown, 'utf-8');
            
            const status = page.status || page.status_code || null;
            
            Object.assign(item, {
                ok: true,
                title: title,
                status: status,
                selectorUsed: selectorUsed,
                backend: "node-fetch",
                markdown: markdown,
                preview: markdown.substring(0, 1200),
                outputMarkdownFile: mdPath
            });
        } catch (error) {
            item.error = error.message;
        }
        
        results.push(item);
    }
    
    const ok = results.some(x => x.ok);
    const indexPath = path.join(outDir, "index.json");
    const payload = {
        ok: ok,
        count: results.length,
        successCount: results.filter(x => x.ok).length,
        failureCount: results.filter(x => !x.ok).length,
        outputIndexFile: indexPath,
        results: results
    };
    
    fs.writeFileSync(indexPath, JSON.stringify(payload, null, 2), 'utf-8');
    console.log(JSON.stringify(payload));
}

if (require.main === module) {
    main().catch(error => {
        console.error(error);
        process.exit(1);
    });
}

module.exports = { 
    toStr, 
    slugify, 
    extractHtml, 
    extractTitle, 
    fetchPage, 
    pickMainHtml, 
    htmlToMarkdown, 
    loadUrls, 
    validateUrl,
    main
};
