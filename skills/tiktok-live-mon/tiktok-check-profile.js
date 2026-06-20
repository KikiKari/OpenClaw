#!/usr/bin/env node
/**
 * TikTok Live Status Checker v2.1
 * Verbesserte Version mit:
 * - Robusteres DSGVO-Banner-Handling (alle bekannten Varianten)
 * - Wartet auf vollständigen Seitenaufbau ("Erneute Veröffentlichungen" Tab)
 * - Priorisierte Live-Erkennung (Badge > Border > Link)
 * - Age-Restriction-Erkennung
 * - Bessere Fehlerbehandlung & konsistente JSON-Ausgabe
 * - Debug-Modus (DEBUG=1)
 * - Realistische Verzögerungen gegen Bot-Erkennung
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

    const profileScope = page.locator(
        '[data-e2e="creator-page-header"], [data-e2e="profile-avatar"]'
    );

    // --- Priorität 1: Profilgebundenes data-e2e="live-icon" ---
    try {
        const liveIcon = profileScope.locator('[data-e2e="live-icon"]').first();
        if (await liveIcon.isVisible().catch(() => false)) {
            indicators.liveIcon = true;
            detectionMethod = 'live-icon';
            return { isLive: true, detectionMethod, indicators };
        }
    } catch (e) { /* weiter */ }

    // --- Priorität 2: LIVE Text/Badge nur im Profilkopf ---
    try {
        const liveBadge = profileScope.getByText(/^LIVE$/i).first();
        const liveBadgeVisible = await liveBadge.isVisible().catch(() => false);
        if (liveBadgeVisible) {
            indicators.liveBadge = true;
            detectionMethod = 'live-badge';
            return { isLive: true, detectionMethod, indicators };
        }
    } catch (e) { /* weiter */ }

    // --- Priorität 3: Roter Rahmen um Profilbild ---
    try {
        const profileSelectors = [
            'img[data-e2e="avatar"]',
            'div[data-e2e="profile-avatar"] img',
            '[data-e2e="creator-page-header"] img[alt*="profile"]'
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

    // --- Priorität 4: Pulsierender Live-Indikator im Profilkopf ---
    try {
        const liveIndicator = profileScope.locator(
            '[class*="live-indicator"], div[class*="LiveBadge"]'
        ).first();
        if (await liveIndicator.isVisible().catch(() => false)) {
            indicators.liveIndicator = true;
            detectionMethod = 'live-indicator';
            return { isLive: true, detectionMethod, indicators };
        }
    } catch (e) { /* weiter */ }

    // --- Priorität 5: Exakter Link auf das Live des geprüften Profils ---
    try {
        const liveLink = await page.$(`a[href*="/@${username}/live"]`);
        if (liveLink) {
            indicators.liveLink = true;
            detectionMethod = 'live-link';
            return { isLive: true, detectionMethod, indicators };
        }
    } catch (e) { /* weiter */ }

    return { isLive: false, detectionMethod, indicators };
}

async function checkAgeRestriction(page, username) {
    // Navigiere zur /live Seite um Age-Restriction zu prüfen
    try {
        await page.goto(`https://www.tiktok.com/@${username}/live`, {
            waitUntil: 'domcontentloaded',
            timeout: 20000
        });
        await page.waitForTimeout(humanDelay(2000, 3000));

        // Prüfe auf Login-Aufforderung
        const loginTexts = [
            'text="Bei TikTok anmelden"',
            'text="Log in to TikTok"',
            'text="Sign in"'
        ];
        for (const selector of loginTexts) {
            try {
                const el = await page.$(selector);
                if (el && await el.isVisible()) {
                    return {
                        isAgeRestricted: true,
                        reason: 'Login erforderlich (möglicherweise altersbeschränkt)'
                    };
                }
            } catch (e) { /* weiter */ }
        }

        // Prüfe auf Inhaltswarnung
        const warningTexts = [
            'text=/unangenehm empfunden/',
            'text=/mature content/',
            'text=/age-restricted/',
            'text=/viewer discretion/'
        ];
        for (const selector of warningTexts) {
            try {
                const el = await page.$(selector);
                if (el && await el.isVisible()) {
                    return {
                        isAgeRestricted: true,
                        reason: 'Inhaltswarnung/Altersbeschränkung angezeigt'
                    };
                }
            } catch (e) { /* weiter */ }
        }
    } catch (e) { /* Navigation fehlgeschlagen */ }

    return { isAgeRestricted: false, reason: null };
}

async function checkLiveStatus(username) {
    let browser;
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

        // Step 4: Age-Restriction prüfen (nur wenn live erkannt)
        let ageResult = { isAgeRestricted: false, reason: null };
        if (liveResult.isLive) {
            ageResult = await checkAgeRestriction(page, username);
        }

        // Ergebnis ausgeben
        const result = {
            username,
            isLive: liveResult.isLive,
            detectionMethod: liveResult.detectionMethod,
            isAgeRestricted: ageResult.isAgeRestricted,
            ageRestrictionReason: ageResult.reason,
            indicators: liveResult.indicators,
            bannerClosed,
            pageFullyLoaded: pageReady,
            timestamp: new Date().toISOString(),
            version: '2.1'
        };

        console.log(JSON.stringify(result, null, 2));
        process.exit(liveResult.isLive ? 0 : 1);

    } catch (error) {
        const result = {
            username,
            isLive: false,
            detectionMethod: 'error',
            isAgeRestricted: false,
            ageRestrictionReason: null,
            indicators: {},
            error: error.message,
            timestamp: new Date().toISOString(),
            version: 2
        };
        console.error(JSON.stringify(result, null, 2));
        process.exit(1);
    } finally {
        if (browser) {
            await browser.close();
        }
    }
}

checkLiveStatus(username);
