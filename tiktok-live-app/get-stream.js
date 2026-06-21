// @deprecated Legacy implementation. Use workspace/skills/tiktok-live*/.
// Current behavior: /home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md
const { chromium } = require('playwright');

const username = process.argv[2];
if (!username) {
    console.error('Usage: node get-stream.js <username>');
    process.exit(1);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: { width: 1920, height: 1080 }
  });
  const page = await context.newPage();
  
  try {
    // Capture network requests for stream URLs
    const streamUrls = [];
    page.on('request', req => {
      const url = req.url();
      if (url.includes('.flv') || url.includes('.m3u8') || url.includes('pull-flv') || url.includes('pull-hls')) {
        streamUrls.push(url);
      }
    });
    
    // Navigate to live page
    await page.goto(`https://www.tiktok.com/@${username}/live`, { 
        waitUntil: 'domcontentloaded',
        timeout: 30000 
    });
    await page.waitForTimeout(2000);
    
    // DSGVO-Banner schließen
    const consentSelectors = [
        'button:has-text("Verstanden")',
        '[data-e2e="cookie-banner-accept"]',
        'button:has-text("Accept")',
        'button:has-text("Akzeptieren")',
        'button:has-text("Alle akzeptieren")',
        'button:has-text("Allow all")',
        'button:has-text("Accept all")'
    ];
    
    for (const selector of consentSelectors) {
        const btn = await page.$(selector);
        if (btn) {
            await btn.click({ force: true }).catch(() => {});
            await page.waitForTimeout(1000);
            break;
        }
    }
    
    // Wait for stream to load and network traffic
    await page.waitForTimeout(8000);
    
    // Try to get networkidle
    try {
        await page.waitForLoadState('networkidle', { timeout: 5000 });
    } catch (e) {}
    
    await page.waitForTimeout(3000);
    
    // Extract from page source as fallback
    const content = await page.content();
    const flvMatch = content.match(/https:\/\/[^"'<>\s]+\.flv[^"'<>\s]*/);
    const m3u8Match = content.match(/https:\/\/[^"'<>\s]+\.m3u8[^"'<>\s]*/);
    
    // Combine network-captured and page-source URLs
    const allUrls = [...new Set(streamUrls)];
    
    // Find best FLV URL
    let bestUrl = null;
    
    // Priority 1: Network captured FLV
    const flvUrls = allUrls.filter(u => u.includes('.flv'));
    if (flvUrls.length > 0) {
        bestUrl = flvUrls[0];
    }
    
    // Priority 2: Page source FLV
    if (!bestUrl && flvMatch) {
        bestUrl = flvMatch[0];
    }
    
    // Priority 3: Network captured M3U8
    if (!bestUrl) {
        const m3u8Urls = allUrls.filter(u => u.includes('.m3u8'));
        if (m3u8Urls.length > 0) {
            bestUrl = m3u8Urls[0];
        }
    }
    
    // Priority 4: Page source M3U8
    if (!bestUrl && m3u8Match) {
        bestUrl = m3u8Match[0];
    }
    
    if (bestUrl) {
        // Output nur die nackte URL (für Pipe-Kompatibilität)
        console.log(bestUrl);
    } else {
        // Kein Stream gefunden - Debug-Info auf stderr
        const url = page.url();
        console.error(JSON.stringify({
            error: 'no_stream_found',
            username,
            currentUrl: url,
            capturedUrls: allUrls.length,
            pageHasFlv: !!flvMatch,
            pageHasM3u8: !!m3u8Match,
            timestamp: new Date().toISOString()
        }, null, 2));
        process.exit(1);
    }
    
    await browser.close();
    
  } catch (error) {
    await browser.close();
    console.error(JSON.stringify({ error: true, message: error.message }));
    process.exit(1);
  }
})();
