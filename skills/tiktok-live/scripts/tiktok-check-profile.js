#!/usr/bin/env node
/**
 * Basic TikTok LIVE profile checker.
 *
 * Scopes every signal to the requested account and ignores unrelated sidebar
 * LIVE labels. This profile-only checker does not classify restricted LIVE;
 * use the enhanced checker or dispatcher for that distinction.
 *
 * Exit 0 = account-specific LIVE, 1 = offline, 2 = dependency/technical
 * failure, 75 = overloaded before Playwright startup.
 */

const { chromium } = require('playwright');
const fs = require('fs');
const { enforceLoadLimit, liveHrefSelectors, normalizeUsername } = require('./tiktok-common');

let username;
try {
    username = normalizeUsername(process.argv[2]);
} catch (error) {
    console.error('Usage: node tiktok-check-profile.js <username>');
    console.error(error.message);
    process.exit(64);
}
enforceLoadLimit('playwright_basic');

async function checkLiveStatus(username) {
    try {
        fs.accessSync(chromium.executablePath(), fs.constants.X_OK);
    } catch (error) {
        console.error(JSON.stringify({
            error: true,
            status: 'dependency_missing',
            method: 'playwright_basic',
            message: `Playwright Chromium unavailable: ${error.message}`,
            timestamp: new Date().toISOString()
        }));
        process.exit(2);
    }
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();
    
    try {
        // Navigate to profile
        await page.goto(`https://www.tiktok.com/@${username}`, { 
            waitUntil: 'domcontentloaded',
            timeout: 30000 
        });
        
        // Warte auf initialen Seitenaufbau
        await page.waitForTimeout(2000);
        
        // DSGVO-Banner schließen - mehrere Varianten probieren
        // Variante 1: "Verstanden" Button (deutsch)
        const verstandenButton = await page.$('button:has-text("Verstanden"), [data-e2e="cookie-banner-accept"], button:has-text("Accept")');
        if (verstandenButton) {
            await verstandenButton.click().catch(() => {});
            await page.waitForTimeout(1000);
        }
        
        // Variante 2: Andere Cookie-Buttons
        const cookieSelectors = [
            'button:has-text("Akzeptieren")',
            'button:has-text("Alle akzeptieren")',
            'button:has-text("Allow all")',
            'button:has-text("Accept all")',
            'button.TUXButton:has-text("Accept")',
            '[data-testid="cookie-policy-banner-accept"]'
        ];
        
        for (const selector of cookieSelectors) {
            const btn = await page.$(selector);
            if (btn) {
                await btn.click().catch(() => {});
                await page.waitForTimeout(500);
                break;
            }
        }
        
        // Warte auf vollständiges Laden ("Erneute Veröffentlichungen" Reiter)
        // Dieser Reiter erscheint erst, wenn die Seite komplett geladen ist
        await page.waitForTimeout(3000);
        
        // Zusätzlich warte auf network idle für API-Calls
        try {
            await page.waitForLoadState('networkidle', { timeout: 5000 });
        } catch (e) {
            // Ignorieren - Seite sollte trotzdem genug geladen sein
        }
        
        // Nochmal warten für Live-Status-Prüfung durch TikTok
        await page.waitForTimeout(2000);
        
        // Screenshot für Debugging (optional, nur wenn DEBUG=1)
        if (process.env.DEBUG === '1') {
            await page.screenshot({ path: `/tmp/tiktok-${username}.png` });
        }
        
        // Account-scoped LIVE indicators only. Sidebar/recommendation labels
        // are outside the exact /@username/live link and never count.
        // Method 1: live icon inside the exact account link
        const liveLink = page.locator(liveHrefSelectors(username).join(', ')).first();
        const hasLiveLink = await liveLink.isVisible().catch(() => false);
        const liveIconVisible = hasLiveLink &&
            await liveLink.locator(
                '[data-e2e="live-icon"], [class*="LiveBadge"], [class*="live-indicator"]'
            ).first().isVisible().catch(() => false);
        
        // Method 2: exact LIVE text/badge inside the account link
        const liveBadge = hasLiveLink
            ? liveLink.locator('text=/^LIVE$/i').first()
            : page.locator('body > __never_match__');
        const liveBadgeVisible = await liveBadge.isVisible().catch(() => false);
        
        // Method 3: Live-Rahmen am Profilkopf/Avatar
        const profileSelectors = [
            '[data-e2e="user-page"] img[data-e2e="avatar"]',
            '[data-e2e="user-page"] div[data-e2e="profile-avatar"] img',
            'main header img[data-e2e="avatar"]',
            'main header [class*="avatar"] img'
        ];
        
        let hasLiveBorder = false;
        for (const selector of profileSelectors) {
            const profileImg = await page.$(selector);
            if (profileImg) {
                const styles = await profileImg.evaluate(el => {
                    const computed = window.getComputedStyle(el);
                    const parent = el.parentElement;
                    const parentComputed = parent ? window.getComputedStyle(parent) : null;
                    return {
                        borderColor: computed.borderColor,
                        borderStyle: computed.borderStyle,
                        borderWidth: computed.borderWidth,
                        outlineColor: computed.outlineColor,
                        boxShadow: computed.boxShadow,
                        parentBorderColor: parentComputed ? parentComputed.borderColor : null,
                        parentBorderStyle: parentComputed ? parentComputed.borderStyle : null,
                        parentBorderWidth: parentComputed ? parentComputed.borderWidth : null
                    };
                });
                
                // Prüfe auf rote/live-farbige Rahmen
                const redIndicators = [
                    styles.borderColor,
                    styles.outlineColor,
                    styles.parentBorderColor
                ];
                
                for (const color of redIndicators) {
                    if (color && (color.includes('255') || color.includes('red') || color.includes('rgb(254') || color.includes('fe2c55') || color.includes('#fe2c'))) {
                        hasLiveBorder = true;
                        break;
                    }
                }
                
                // Box-Shadow für Live-Indikator (TikTok nutzt oft Glow-Effekte)
                if (styles.boxShadow && (styles.boxShadow.includes('255') || styles.boxShadow.includes('254'))) {
                    hasLiveBorder = true;
                }
                
                if (hasLiveBorder) break;
            }
        }
        
        // Method 4: exact account LIVE link
        // Method 5: live indicator inside that account link
        const liveIndicatorVisible = hasLiveLink &&
            await liveLink.locator(
                '[class*="live-indicator"], div[class*="LiveBadge"]'
            ).first().isVisible().catch(() => false);
        
        const isLive =
            hasLiveLink ||
            hasLiveBorder ||
            liveIconVisible ||
            liveIndicatorVisible ||
            liveBadgeVisible;
        
        console.log(JSON.stringify({
            username,
            isLive,
            timestamp: new Date().toISOString(),
            indicators: {
                liveIcon: liveIconVisible,
                liveBadge: liveBadgeVisible,
                liveBorder: hasLiveBorder,
                liveLink: hasLiveLink,
                liveIndicator: liveIndicatorVisible
            }
        }, null, 2));
        
        return isLive;
        
    } catch (error) {
        console.error(JSON.stringify({
            error: true,
            status: 'technical_error',
            message: error.message,
            stack: error.stack,
            timestamp: new Date().toISOString()
        }));
        return null;
    } finally {
        await browser.close();
    }
}

checkLiveStatus(username).then(isLive => process.exit(isLive === null ? 2 : (isLive ? 0 : 1)));
