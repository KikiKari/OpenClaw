#!/usr/bin/env node
/**
 * Enhanced TikTok LIVE status checker.
 *
 * Uses exact account selectors and the direct /@username/live page to return
 * live, restricted, offline, dependency_missing, technical_error, or
 * overloaded. An accessible LIVE requires a successful allowed TikTok-CDN
 * FLV response; unrelated sidebar LIVE labels never count.
 *
 * Browser resources are closed on every completion path.
 */

const { chromium } = require('playwright');
const fs = require('fs');
const {
    classifyDirectLiveState,
    enforceLoadLimit,
    isSuccessfulStreamResponse,
    liveHrefSelectors,
    normalizeUsername
} = require('./tiktok-common');

let username;
try {
    username = normalizeUsername(process.argv[2]);
} catch (error) {
    console.error('Usage: node tiktok-check-profile.js <username>');
    console.error(error.message);
    process.exit(64);
}
enforceLoadLimit('playwright_enhanced');

// Realistische Verzögerung (2-4s zufällig)
function humanDelay(min = 2000, max = 4000) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function closeDSGVOBanner(page) {
    // Alle bekannten Cookie/DSGVO-Button-Varianten
    const selectors = [
        'button:has-text("Verstanden")',
        '[data-e2e="cookie-banner-accept"]',
        'button:has-text("Accept")',
        'button:has-text("Akzeptieren")',
        'button:has-text("Alle akzeptieren")',
        'button:has-text("Allow all")',
        'button:has-text("Accept all")',
        'button.TUXButton:has-text("Accept")',
        '[data-testid="cookie-policy-banner-accept"]'
    ];

    for (const selector of selectors) {
        try {
            const btn = await page.$(selector);
            if (btn) {
                await btn.click();
                await page.waitForTimeout(humanDelay(1000, 2000));
                return true;
            }
        } catch (e) { /* weiter probieren */ }
    }
    return false;
}

async function waitForPageReady(page) {
    // KRITISCH: TikTok lädt die Seite in Phasen.
    // Der LIVE-Badge und der rote Rahmen erscheinen ERST wenn die Seite
    // vollständig geladen ist. Erkennbar am Menüband:
    // "Videos" + "Erneute Veröffentlichungen" + "Gelikt"
    // "Erneute Veröffentlichungen" erscheint als LETZTES.

    // Phase 1: Initiales Laden abwarten
    await page.waitForTimeout(humanDelay(2000, 3000));

    // Phase 2: Warte explizit auf "Erneute Veröffentlichungen" Tab
    // Das ist der zuverlässigste Indikator für vollständigen Seitenaufbau
    let pageReady = false;
    try {
        await page.waitForSelector(
            'text="Erneute Veröffentlichungen"',
            { state: 'visible', timeout: 25000 }
        );
        pageReady = true;
    } catch (e) {
        // Fallback: englische Version probieren
        try {
            await page.waitForSelector(
                'text="Reposts"',
                { state: 'visible', timeout: 5000 }
            );
            pageReady = true;
        } catch (e2) {
            // Letzter Fallback: einfach auf networkidle warten
            try {
                await page.waitForLoadState('networkidle', { timeout: 10000 });
            } catch (e3) { /* weiter */ }
        }
    }

    // Phase 3: Nach dem Erscheinen des Menübands noch kurz warten,
    // damit der LIVE-Badge/roter Rahmen gerendert wird
    await page.waitForTimeout(humanDelay(2000, 3000));

    return pageReady;
}

async function detectLiveStatus(page, username) {
    const indicators = {
        liveIcon: false,
        liveBadge: false,
        liveBorder: false,
        liveLink: false,
        liveIndicator: false
    };
    let detectionMethod = 'none';

    // --- Priorität 1: LIVE-Icon innerhalb des exakten Account-LIVE-Links ---
    try {
        const liveLink = page.locator(liveHrefSelectors(username).join(', ')).first();
        const liveIconVisible = await liveLink.locator(
            '[data-e2e="live-icon"], [class*="LiveBadge"], [class*="live-indicator"]'
        ).first().isVisible().catch(() => false);
        if (liveIconVisible) {
            indicators.liveIcon = true;
            detectionMethod = 'live-icon';
            return { isLive: true, detectionMethod, indicators };
        }
    } catch (e) { /* weiter */ }

    // --- Priorität 2: exaktes LIVE-Badge innerhalb desselben Account-Links ---
    try {
        const liveLink = page.locator(liveHrefSelectors(username).join(', ')).first();
        const liveBadge = liveLink.locator('text=/^LIVE$/i').first();
        const liveBadgeVisible = await liveBadge.isVisible().catch(() => false);
        if (liveBadgeVisible) {
            indicators.liveBadge = true;
            detectionMethod = 'live-badge';
            return { isLive: true, detectionMethod, indicators };
        }
    } catch (e) { /* weiter */ }

    // --- Priorität 3: Live-Rahmen am Profilkopf/Avatar des Accounts ---
    try {
        const profileSelectors = [
            '[data-e2e="user-page"] img[data-e2e="avatar"]',
            '[data-e2e="user-page"] div[data-e2e="profile-avatar"] img',
            'main header img[data-e2e="avatar"]',
            'main header [class*="avatar"] img'
        ];

        for (const selector of profileSelectors) {
            const profileImg = await page.$(selector);
            if (!profileImg) continue;

            const styles = await profileImg.evaluate(el => {
                const computed = window.getComputedStyle(el);
                const parent = el.parentElement;
                const parentComputed = parent ? window.getComputedStyle(parent) : null;
                const grandParent = parent ? parent.parentElement : null;
                const grandParentComputed = grandParent ? window.getComputedStyle(grandParent) : null;
                return {
                    borderColor: computed.borderColor,
                    outlineColor: computed.outlineColor,
                    boxShadow: computed.boxShadow,
                    parentBorderColor: parentComputed ? parentComputed.borderColor : null,
                    parentBoxShadow: parentComputed ? parentComputed.boxShadow : null,
                    grandParentBorderColor: grandParentComputed ? grandParentComputed.borderColor : null,
                    grandParentBoxShadow: grandParentComputed ? grandParentComputed.boxShadow : null
                };
            });

            const allColors = [
                styles.borderColor,
                styles.outlineColor,
                styles.parentBorderColor,
                styles.grandParentBorderColor
            ];
            const allShadows = [
                styles.boxShadow,
                styles.parentBoxShadow,
                styles.grandParentBoxShadow
            ];

            const isRed = (color) => {
                if (!color || color === 'none') return false;
                return color.includes('255') || color.includes('red') ||
                       color.includes('rgb(254') || color.includes('fe2c55') ||
                       color.includes('#fe2c') || color.includes('rgb(255, 0') ||
                       color.includes('rgb(255, 44');
            };

            if (allColors.some(isRed) || allShadows.some(s => s && isRed(s))) {
                indicators.liveBorder = true;
                detectionMethod = 'live-border';
                return { isLive: true, detectionMethod, indicators };
            }
        }
    } catch (e) { /* weiter */ }

    // --- Priorität 4: Live-Indikator innerhalb des exakten Account-Links ---
    try {
        const liveLink = page.locator(liveHrefSelectors(username).join(', ')).first();
        const liveIndicatorVisible = await liveLink.locator(
            '[class*="live-indicator"], div[class*="LiveBadge"]'
        ).first().isVisible().catch(() => false);
        if (liveIndicatorVisible) {
            indicators.liveIndicator = true;
            detectionMethod = 'live-indicator';
            return { isLive: true, detectionMethod, indicators };
        }
    } catch (e) { /* weiter */ }

    // --- Priorität 5: sichtbarer exakter /@username/live-Link ---
    try {
        const liveLink = page.locator(liveHrefSelectors(username).join(', ')).first();
        if (await liveLink.isVisible().catch(() => false)) {
            indicators.liveLink = true;
            detectionMethod = 'live-link';
            return { isLive: true, detectionMethod, indicators };
        }
    } catch (e) { /* weiter */ }

    return { isLive: false, detectionMethod, indicators };
}

async function inspectDirectLiveState(page, username) {
    let successfulStreamResponse = false;
    const responseHandler = response => {
        if (isSuccessfulStreamResponse(response.status(), response.url())) {
            successfulStreamResponse = true;
        }
    };
    page.on('response', responseHandler);
    try {
        await page.goto(`https://www.tiktok.com/@${username}/live`, {
            waitUntil: 'domcontentloaded',
            timeout: 30000
        });
        await page.waitForTimeout(humanDelay(8000, 10000));
        const currentUrl = new URL(page.url());
        const bodyText = await page.locator('body').innerText().catch(() => '');
        return classifyDirectLiveState({
            username,
            currentPath: currentUrl.pathname,
            title: await page.title(),
            bodyText,
            successfulStreamResponse
        });
    } catch (error) {
        return { status: 'technical_error', reason: error.message };
    } finally {
        page.off('response', responseHandler);
    }
}

async function checkLiveStatus(username) {
    let browser;
    try {
        fs.accessSync(chromium.executablePath(), fs.constants.X_OK);
    } catch (error) {
        console.error(JSON.stringify({
            error: true,
            status: 'dependency_missing',
            method: 'playwright_enhanced',
            message: `Playwright Chromium unavailable: ${error.message}`,
            timestamp: new Date().toISOString()
        }));
        process.exit(2);
    }
    try {
        browser = await chromium.launch({ headless: true });
        const context = await browser.newContext({
            userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            viewport: { width: 1920, height: 1080 }
        });
        const page = await context.newPage();

        // Navigiere zum Profil
        await page.goto(`https://www.tiktok.com/@${username}`, {
            waitUntil: 'domcontentloaded',
            timeout: 30000
        });

        // Step 1: DSGVO Banner schließen
        const bannerClosed = await closeDSGVOBanner(page);

        // Step 2: Warte auf vollständigen Seitenaufbau
        // KRITISCH: LIVE-Badge erscheint erst nach "Erneute Veröffentlichungen"
        const pageReady = await waitForPageReady(page);

        // Debug-Screenshot
        if (process.env.DEBUG === '1') {
            await page.screenshot({ path: `/tmp/tiktok-${username}-v2.png`, fullPage: true });
        }

        // Step 3: Live-Status prüfen (priorisiert)
        const liveResult = await detectLiveStatus(page, username);

        // Step 4: Accountgenaue /live-Seite prüfen. Das trennt zugängliche
        // Streams, Login-/Content-Sperren und tatsächlich beendete Streams.
        const directResult = await inspectDirectLiveState(page, username);
        const finalStatus = directResult.status === 'restricted'
            ? 'restricted'
            : (
                liveResult.isLive || directResult.status === 'live'
                    ? 'live'
                    : directResult.status
            );

        // Ergebnis ausgeben
        const result = {
            username,
            status: finalStatus,
            isLive: finalStatus === 'live' || finalStatus === 'restricted',
            detectionMethod: directResult.status === 'restricted'
                ? 'account-live-restricted'
                : liveResult.detectionMethod,
            isAgeRestricted: finalStatus === 'restricted',
            ageRestrictionReason: finalStatus === 'restricted'
                ? directResult.reason
                : null,
            indicators: liveResult.indicators,
            bannerClosed,
            pageFullyLoaded: pageReady,
            timestamp: new Date().toISOString(),
            version: '2.1'
        };

        console.log(JSON.stringify(result, null, 2));
        return finalStatus;

    } catch (error) {
        const result = {
            username,
            isLive: false,
            status: 'technical_error',
            detectionMethod: 'error',
            isAgeRestricted: false,
            ageRestrictionReason: null,
            indicators: {},
            error: error.message,
            timestamp: new Date().toISOString(),
            version: 2
        };
        console.error(JSON.stringify(result, null, 2));
        return 'technical_error';
    } finally {
        if (browser) {
            await browser.close();
        }
    }
}

checkLiveStatus(username).then(status => {
    if (status === 'live') process.exit(0);
    if (status === 'offline' || status === 'restricted') process.exit(1);
    process.exit(2);
});
