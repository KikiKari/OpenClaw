#!/usr/bin/env node
/**
 * TikTok Live Status Checker
 * Prüft ausschließlich profilgebundene Live-Indikatoren.
 * Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
 * Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
 * via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).
 */

const { chromium } = require('playwright');
const os = require('os');

const rawUsername = process.argv[2];
if (!rawUsername) {
    console.error('Usage: node tiktok-check-profile.js <username>');
    process.exit(1);
}
const username = rawUsername.replace(/^@+/, '');
if (!username) {
    console.error('Username must not be empty');
    process.exit(1);
}

function rejectBusyNode() {
    const limit = Number(process.env.TIKTOK_MAX_LOAD_PER_CPU);
    if (!Number.isFinite(limit) || limit <= 0) return;

    const cpuCount = Math.max(1, os.cpus().length);
    const normalizedLoad = os.loadavg()[0] / cpuCount;
    if (normalizedLoad > limit) {
        console.error(`NODE_BUSY normalizedLoad=${normalizedLoad.toFixed(2)} limit=${limit}`);
        process.exit(75);
    }
}

rejectBusyNode();

async function checkLiveStatus(username) {
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
        const profileScope = page.locator(
            '[data-e2e="creator-page-header"], [data-e2e="profile-avatar"]'
        );
        const liveIcon = profileScope.locator('[data-e2e="live-icon"]').first();
        const liveIconVisible = await liveIcon.isVisible().catch(() => false);
        
        // Method 2: LIVE text/badge (scoped to profile header/avatar)
        let liveBadgeVisible = false;
        const profileBadge = profileScope.getByText(/^LIVE$/i).first();
        liveBadgeVisible = await profileBadge.isVisible().catch(() => false);

        // Method 3: Roter Rahmen um Profilbild - mehrere Selektoren
        const profileSelectors = [
            'img[data-e2e="avatar"]',
            'div[data-e2e="profile-avatar"] img',
            '[data-e2e="creator-page-header"] img[alt*="profile"]'
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
        const liveLink = await page.$(`a[href*="/@${username}/live"]`);
        const hasLiveLink = liveLink !== null;
        
        // Method 5: Check für pulsierenden roten Punkt (Live-Indikator)
        const liveIndicator = profileScope.locator(
            '[class*="live-indicator"], div[class*="LiveBadge"]'
        ).first();
        const liveIndicatorVisible = await liveIndicator.isVisible().catch(() => false);
        
        const isLive = liveIconVisible || liveBadgeVisible || hasLiveBorder || hasLiveLink || liveIndicatorVisible;
        
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

checkLiveStatus(username).then(isLive => {
    process.exit(isLive ? 0 : 1);
}).catch(error => {
    console.error(JSON.stringify({
        error: true,
        message: error.message,
        timestamp: new Date().toISOString()
    }));
    process.exit(1);
});
