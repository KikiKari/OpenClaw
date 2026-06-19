#!/usr/bin/env node
/**
 * TikTok Live Status Checker
 * Prüft visuell, ob ein TikTok-Account live ist
 * Korrigiert: DSGVO-Banner muss zuerst geschlossen werden
 */

const { chromium } = require('playwright');
const fs = require('fs');

const username = process.argv[2];
if (!username) {
    console.error('Usage: node tiktok-check-profile.js <username>');
    process.exit(1);
}

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
        
        // Check for LIVE indicators
        // Method 1: data-e2e="live-icon"
        const liveIcon = await page.$('[data-e2e="live-icon"]');
        
        // Method 2: LIVE text/badge
        const liveBadge = await page.locator('text=/^LIVE$/i').first();
        const liveBadgeVisible = await liveBadge.isVisible().catch(() => false);
        
        // Method 3: Roter Rahmen um Profilbild - mehrere Selektoren
        const profileSelectors = [
            'img[alt*="profile"]',
            'img[data-e2e="avatar"]',
            'div[data-e2e="profile-avatar"] img',
            'a[href*="/@"] img',
            '[class*="avatar"] img'
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
        
        // Method 4: Check für Live-Link oder Live-Button
        const escapedUsername = username.replace(/["\\]/g, '\\$&');
        const liveLink = await page.$(
            `a[href="/@${escapedUsername}/live"], a[href^="/@${escapedUsername}/live?"]`
        );
        const hasLiveLink = liveLink !== null;
        
        // Method 5: Check für pulsierenden roten Punkt (Live-Indikator)
        const liveIndicator = await page.$('[class*="live-indicator"], div[class*="LiveBadge"]');
        
        const isLive =
            liveIcon !== null ||
            hasLiveBorder ||
            liveIndicator !== null ||
            (liveBadgeVisible && hasLiveLink);
        
        console.log(JSON.stringify({
            username,
            isLive,
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
        return isLive;
        
    } catch (error) {
        await browser.close();
        console.error(JSON.stringify({
            error: true,
            message: error.message,
            stack: error.stack,
            timestamp: new Date().toISOString()
        }));
        process.exit(1);
    }
}

checkLiveStatus(username);
