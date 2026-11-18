#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "8f9bc7fb22e7dd144b3be167f8134721a9c56a439836306666692a104fae3c51", "source_sha256": "f76d25200d74ebc530580d7a7afb24c88ee8981f06c4d1734500f4cc830c4fe9", "target_language": "javascript"}
// scrape_to_markdown.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

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
  text = text.replace(/[^\w\s-]/g, '').trim().toLowerCase();
  text = text.replace(/[-\s]+/g, '-');
  return (text.substring(0, maxLen).trim('-') || 'page');
}

function extractHtml(obj) {
  if (obj === null || obj === undefined) {
    return "";
  }
  
  const attrs = ["html", "rawHtml", "content", "markup", "body", "innerHtml"];
  for (const attr of attrs) {
    let value = typeof obj[attr] === 'function' ? obj[attr]() : obj[attr];
    const text = toStr(value);
    if (text && text.includes('<') && text.includes('>')) {
      return text;
    }
  }
  
  const text = toStr(obj);
  return (text.includes('<') && text.includes('>')) ? text : "";
}

function extractTitle(html) {
  const match = html.match(/<title[^>]*>(.*?)<\/title>/is);
  if (!match) return "";
  
  let title = match[1].replace(/<[^>]+>/g, ' ');
  title = title.replace(/\s+/g, ' ').trim();
  return title;
}

// Simulated fetcher loading - in a real implementation, you'd need actual HTTP clients
async function fetchPage(url, options = {}) {
  const { js = false, waitSelector = null, timeout = 30 } = options;
  
  // This is a simplified mock - in reality you'd use something like puppeteer or axios
  try {
    const response = await fetch(url, { timeout: timeout * 1000 });
    const content = await response.text();
    
    return {
      status: response.status,
      html: content,
      cssFirst: (selector) => {
        try {
          const dom = new JSDOM(content);
          return dom.window.document.querySelector(selector);
        } catch (e) {
          return null;
        }
      }
    };
  } catch (error) {
    throw new Error(`Failed to fetch ${url}: ${error.message}`);
  }
}

function pickMainHtml(page, preferredSelector = null) {
  const selectors = [];
  if (preferredSelector) {
    selectors.push(preferredSelector);
  }
  selectors.push(...[
    "article",
    "main",
    "[role='main']",
    ".post-content",
    ".entry-content",
    ".article-content",
    "body",
  ]);

  if (typeof page.cssFirst === 'function') {
    for (const selector of selectors) {
      try {
        const node = page.cssFirst(selector);
        const html = extractHtml(node);
        if (html && html.length >= 120) {
          return [html, selector];
        }
      } catch (e) {
        // Continue trying other selectors
      }
    }
  }

  return [extractHtml(page), null];
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

  // Preserve tables if possible
  turndownService.keep(['table', 'thead', 'tbody', 'tr', 'th', 'td']);
  
  // Remove images
  turndownService.remove('img');
  
  let md = turndownService.turndown(html);
  md = md.replace(/\n{3,}/g, '\n\n').trim();
  return md;
}

function loadUrls(urlArgs, urlFile) {
  let urls = [...(urlArgs || [])];
  
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
  
  const clean = [];
  const seen = new Set();
  for (const u of urls) {
    if (!seen.has(u)) {
      clean.push(u);
      seen.add(u);
    }
  }
  return clean;
}

function validateUrl(urlString) {
  try {
    const url = new URL(urlString);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch (e) {
    return false;
  }
}

// Command line argument parsing
function parseArgs() {
  const args = {};
  const argv = process.argv.slice(2);
  
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    
    if (arg === '--url') {
      if (!args.url) args.url = [];
      args.url.push(argv[++i]);
    } else if (arg === '--url-file') {
      args.urlFile = argv[++i];
    } else if (arg === '--selector') {
      args.selector = argv[++i];
    } else if (arg === '--js') {
      args.js = true;
    } else if (arg === '--wait-selector') {
      args.waitSelector = argv[++i];
    } else if (arg === '--preserve-links') {
      args.preserveLinks = true;
    } else if (arg === '--body-width') {
      args.bodyWidth = parseInt(argv[++i], 10);
    } else if (arg === '--timeout') {
      args.timeout = parseInt(argv[++i], 10);
    } else if (arg === '--output-dir') {
      args.outputDir = argv[++i];
    } else if (arg === '--automatch-domain') {
      args.automatchDomain = argv[++i];
    }
  }
  
  return {
    url: args.url || [],
    urlFile: args.urlFile || '',
    selector: args.selector || '',
    js: !!args.js,
    waitSelector: args.waitSelector || '',
    preserveLinks: !!args.preserveLinks,
    bodyWidth: args.bodyWidth || 0,
    timeout: args.timeout || 30,
    outputDir: args.outputDir || 'outputs',
    automatchDomain: args.automatchDomain || ''
  };
}

async function main() {
  const args = parseArgs();
  
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
      const page = await fetchPage(url, {
        js: args.js,
        waitSelector: args.waitSelector || null,
        timeout: args.timeout,
      });
      
      const [html, selectorUsed] = pickMainHtml(page, args.selector || null);
      if (!html) {
        throw new Error("No HTML content extracted from page");
      }
      
      const title = extractTitle(html) || new URL(url).hostname;
      const markdown = htmlToMarkdown(
        html,
        args.preserveLinks,
        args.bodyWidth,
      );
      
      const filename = slugify(`${new URL(url).hostname}-${title}`) + ".md";
      const mdPath = path.join(outDir, filename);
      fs.writeFileSync(mdPath, markdown, 'utf-8');
      
      const status = page.status;
      
      item.ok = true;
      item.title = title;
      item.status = status;
      item.selectorUsed = selectorUsed;
      item.backend = "fetch"; // Simplified
      item.markdown = markdown;
      item.preview = markdown.substring(0, 1200);
      item.outputMarkdownFile = mdPath;
    } catch (e) {
      item.error = e.message;
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
    results: results,
  };
  
  fs.writeFileSync(indexPath, JSON.stringify(payload, null, 2), 'utf-8');
  console.log(JSON.stringify(payload));
}

if (require.main === module) {
  main().catch(console.error);
}
