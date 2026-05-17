const { chromium } = require('playwright');

const username = process.argv[2];
if (!username) {
    console.error('Usage: node check-profile.js <username>');
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
    await page.goto(`https://www.tiktok.com/@${username}`, { 
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
            await btn.click().catch(() => {});
            await page.waitForTimeout(1000);
            break;
        }
    }
    
    // Warte auf vollständiges Laden
    await page.waitForTimeout(3000);
    try {
        await page.waitForLoadState('networkidle', { timeout: 5000 });
    } catch (e) {}
    await page.waitForTimeout(2000);
    
    // Check 1: data-e2e="live-icon"
    const liveIcon = await page.$('[data-e2e="live-icon"]');
    
    // Check 2: LIVE Badge (exakter Text-Match, nicht substring)
    const liveBadge = await page.locator('text=/^LIVE$/i').first();
    const liveBadgeVisible = await liveBadge.isVisible().catch(() => false);
    
    // Check 3: Roter Rahmen um Profilbild
    let hasLiveBorder = false;
    const profileSelectors = [
        'img[data-e2e="avatar"]',
        'div[data-e2e="profile-avatar"] img',
        '[class*="avatar"] img'
    ];
    
    for (const selector of profileSelectors) {
        const profileImg = await page.$(selector);
        if (profileImg) {
            const styles = await profileImg.evaluate(el => {
                const computed = window.getComputedStyle(el);
                const parent = el.parentElement;
                const parentComputed = parent ? window.getComputedStyle(parent) : null;
                return {
                    borderColor: computed.borderColor,
                    outlineColor: computed.outlineColor,
                    boxShadow: computed.boxShadow,
                    parentBorderColor: parentComputed ? parentComputed.borderColor : null
                };
            });
            
            const redIndicators = [styles.borderColor, styles.outlineColor, styles.parentBorderColor];
            for (const color of redIndicators) {
                if (color && (color.includes('255') || color.includes('fe2c55') || color.includes('#fe2c'))) {
                    hasLiveBorder = true;
                    break;
                }
            }
            if (styles.boxShadow && (styles.boxShadow.includes('255') || styles.boxShadow.includes('254'))) {
                hasLiveBorder = true;
            }
            if (hasLiveBorder) break;
        }
    }
    
    // Check 4: Live-Link
    const liveLink = await page.$('a[href*="/live"]');
    const hasLiveLink = liveLink !== null;
    
    // Check 5: Live-Indikator Klasse
    const liveIndicator = await page.$('[class*="live-indicator"], div[class*="LiveBadge"]');
    
    const isLive = liveIcon !== null || liveBadgeVisible || hasLiveBorder || hasLiveLink || liveIndicator !== null;
    
    const url = page.url();
    
    console.log(JSON.stringify({
        username,
        isLive,
        url,
        timestamp: new Date().toISOString(),
        indicators: {
            liveIcon: liveIcon !== null,
            liveBadge: liveBadgeVisible,
            liveBorder: hasLiveBorder,
            liveLink: hasLiveLink,
            liveIndicator: liveIndicator !== null
        }
    }, null, 2));
    
    await browser.close();
    process.exit(isLive ? 0 : 1);
    
  } catch (error) {
    await browser.close();
    console.error(JSON.stringify({ error: true, message: error.message }));
    process.exit(1);
  }
})();
