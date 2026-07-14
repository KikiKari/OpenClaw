#!/usr/bin/env node
/**
 * Enhanced TikTok LIVE URL extractor.
 *
 * Order: Playwright response interception, streamlink, then yt-dlp. Every
 * result is schema-normalized and must be an allowed HTTPS TikTok-CDN FLV
 * URL. Fallbacks use fixed argument arrays, bounded output, timeouts, and
 * process-group cleanup.
 *
 * Exit 0 = URL, 1 = offline/restricted/no URL, 2 = dependency/technical
 * failure, 75 = overloaded before Playwright startup.
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const {
    classifyFinalFailure,
    enforceLoadLimit,
    exitCodeForResult,
    forcedOffline,
    isSuccessfulStreamResponse,
    normalizeExtractorResult,
    normalizeUsername,
    qualityKeyFromUrl
} = require('./tiktok-common');

const FALLBACK_TIMEOUT_MS = 45000;
const FALLBACK_MAX_OUTPUT = 1024 * 1024;

function log(message) {
    console.error(message);
}

function runFallback(scriptPath, args) {
    return new Promise(resolve => {
        const child = spawn('bash', [scriptPath, ...args], {
            detached: true,
            stdio: ['ignore', 'pipe', 'pipe']
        });
        let stdout = '';
        let stderr = '';
        let overflow = false;
        const collect = target => chunk => {
            const next = target() + chunk.toString('utf8');
            if (Buffer.byteLength(next) > FALLBACK_MAX_OUTPUT) {
                overflow = true;
                return;
            }
            if (target === getStdout) stdout = next;
            else stderr = next;
        };
        const getStdout = () => stdout;
        const getStderr = () => stderr;
        child.stdout.on('data', collect(getStdout));
        child.stderr.on('data', collect(getStderr));
        let timedOut = false;
        const timer = setTimeout(() => {
            timedOut = true;
            try { process.kill(-child.pid, 'SIGTERM'); } catch (error) { /* exited */ }
            setTimeout(() => {
                try { process.kill(-child.pid, 'SIGKILL'); } catch (error) { /* exited */ }
            }, 3000).unref();
        }, FALLBACK_TIMEOUT_MS);
        child.on('error', error => {
            clearTimeout(timer);
            resolve({ code: 2, stdout, stderr: `${stderr}\n${error.message}`.trim() });
        });
        child.on('close', code => {
            clearTimeout(timer);
            if (overflow) {
                resolve({ code: 2, stdout: '', stderr: 'fallback output exceeded limit' });
            } else if (timedOut) {
                resolve({ code: 2, stdout, stderr: `${stderr}\nfallback timeout`.trim() });
            } else {
                resolve({ code: code ?? 2, stdout: stdout.trim(), stderr: stderr.trim() });
            }
        });
    });
}

function parseFallbackResult(method, username, execution) {
    for (const text of [execution.stdout, execution.stderr]) {
        if (!text) continue;
        try {
            const value = JSON.parse(text);
            if (value && typeof value === 'object') {
                return normalizeExtractorResult(value, method, username);
            }
        } catch (error) { /* try next channel */ }
    }
    return normalizeExtractorResult({
        success: false,
        status: execution.code === 75 ? 'overloaded' : 'technical_error',
        method,
        username,
        message: execution.stderr || `fallback exited ${execution.code}`
    }, method, username);
}

function playwrightPreflight() {
    try {
        const executable = chromium.executablePath();
        fs.accessSync(executable, fs.constants.X_OK);
        return { ok: true, executable };
    } catch (error) {
        return {
            ok: false,
            status: 'dependency_missing',
            error: `Playwright Chromium unavailable: ${error.message}`
        };
    }
}

function humanDelay(min = 2000, max = 4000) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

// DSGVO + Login-Popups schließen
async function handlePopups(page) {
    let closed = false;

    // DSGVO
    const dsgvoSelectors = [
        'button:has-text("Verstanden")', '[data-e2e="cookie-banner-accept"]',
        'button:has-text("Accept")', 'button:has-text("Akzeptieren")',
        'button:has-text("Alle akzeptieren")', 'button:has-text("Allow all")',
        'button:has-text("Accept all")', '[data-testid="cookie-policy-banner-accept"]'
    ];
    for (const sel of dsgvoSelectors) {
        try {
            const btn = await page.waitForSelector(sel, { state: 'visible', timeout: 3000 });
            if (btn) { await btn.click(); await page.waitForTimeout(humanDelay(1000, 2000)); closed = true; break; }
        } catch (e) { /* weiter */ }
    }

    // Login Pop-up 1: "Bei TikTok anmelden" → X-Button
    try {
        const loginText = await page.$('text="Bei TikTok anmelden"');
        if (loginText) {
            const closeBtn = await page.$('div[role="dialog"] [aria-label="Close"], div[role="dialog"] button[aria-label="Schließen"], div[role="dialog"] svg');
            if (closeBtn) { await closeBtn.click(); await page.waitForTimeout(humanDelay(1000, 2000)); closed = true; }
        }
    } catch (e) { /* nicht da */ }

    // Login Pop-up 2: "Jetzt nicht" Button
    try {
        const skipBtn = await page.$('button:has-text("Jetzt nicht"), button:has-text("Not now")');
        if (skipBtn) { await skipBtn.click(); await page.waitForTimeout(humanDelay(1000, 2000)); closed = true; }
    } catch (e) { /* nicht da */ }

    return closed;
}

// Prüfe ob Stream eingeschränkt ist (nach Popup-Handling)
async function checkRestrictions(page) {
    const restrictionTexts = [
        'text="Bei TikTok anmelden"',
        'text=/Dieses LIVE enthält Themen/',
        'text="Melde dich an für das vollständige Erlebnis"',
        'text=/Melde dich an für das volle/',
        'text="Log in to TikTok"',
        'text=/mature content/',
        'text=/age-restricted/'
    ];
    for (const sel of restrictionTexts) {
        try {
            const el = await page.$(sel);
            if (el && await el.isVisible()) {
                return { restricted: true, reason: sel.replace('text=', '').replace(/[/"]/g, '') };
            }
        } catch (e) { /* weiter */ }
    }
    return { restricted: false, reason: null };
}

// Playwright-basierte FLV-Extraktion
async function extractWithPlaywright(username, qualityPreference) {
    let browser;
    const preflight = playwrightPreflight();
    if (!preflight.ok) {
        return {
            success: false,
            method: 'playwright',
            status: preflight.status,
            error: preflight.error
        };
    }
    try {
        browser = await chromium.launch({
            headless: true,
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu', '--disable-dev-shm-usage']
        });
        const context = await browser.newContext({
            userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            viewport: { width: 1920, height: 1080 }
        });
        const page = await context.newPage();

        // FLV-URLs sammeln via Event-Listener BEVOR wir navigieren
        const collectedUrls = [];
        page.on('response', response => {
            const url = response.url();
            if (
                collectedUrls.length < 100 &&
                isSuccessfulStreamResponse(response.status(), url)
            ) {
                collectedUrls.push({
                    url: url,
                    status: response.status(),
                    timestamp: new Date().toISOString()
                });
            }
        });

        // Navigiere direkt zu /live
        await page.goto(`https://www.tiktok.com/@${username}/live`, {
            waitUntil: 'domcontentloaded',
            timeout: 30000
        });

        // Popups schließen
        await handlePopups(page);

        // Warte auf Seitenaufbau
        await page.waitForTimeout(humanDelay(3000, 5000));
        try { await page.waitForLoadState('networkidle', { timeout: 10000 }); } catch (e) { /* ok */ }

        // Prüfe auf Einschränkungen
        const restrictions = await checkRestrictions(page);
        if (restrictions.restricted) {
            log(`Playwright: Stream restricted - ${restrictions.reason}`);
            return { success: false, method: 'playwright', status: 'restricted',
                     restricted: true, reason: restrictions.reason };
        }

        // Versuche Video abzuspielen falls nötig
        try {
            const video = await page.$('video');
            if (video) { await video.evaluate(v => v.play()).catch(() => {}); }
        } catch (e) { /* ok */ }

        // Warte auf FLV-URLs (Stream muss laden)
        await page.waitForTimeout(humanDelay(8000, 12000));

        // Zweiter Versuch Popups zu schließen (können nach Delay erscheinen)
        await handlePopups(page);
        await page.waitForTimeout(humanDelay(3000, 5000));

        // Nochmal Restrictions prüfen
        const restrictions2 = await checkRestrictions(page);
        if (restrictions2.restricted) {
            log(`Playwright: Stream became restricted after wait - ${restrictions2.reason}`);
            return { success: false, method: 'playwright', status: 'restricted',
                     restricted: true, reason: restrictions2.reason };
        }

        // URLs auswerten
        if (collectedUrls.length === 0) {
            log('Playwright: No FLV URLs captured via network monitoring.');
            return { success: false, method: 'playwright', status: 'offline',
                     restricted: false, reason: 'No FLV URLs found' };
        }

        // Deduplizieren und nach Qualität sortieren
        const uniqueUrls = [...new Map(collectedUrls.map(item => [item.url.split('?')[0], item])).values()];

        // Qualitäts-Präferenz anwenden
        const qualityOrder = {
            original: ['_origin.flv', '_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv'],
            '1080p60': ['_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv'],
            '720p60': ['_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv'],
            '720p': ['_hd.flv', '_sd.flv', '_ld.flv'],
            '540p': ['_sd.flv', '_ld.flv'],
            '360p': ['_ld.flv'],
            auto: ['_origin.flv', '_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv'],
        }[qualityPreference];

        let bestUrl = null;
        for (const suffix of qualityOrder) {
            bestUrl = uniqueUrls.find(u => u.url.includes(suffix));
            if (bestUrl) break;
        }
        if (!bestUrl && (qualityPreference === 'auto' || qualityPreference === 'original')) {
            bestUrl = uniqueUrls[0];
        }
        if (!bestUrl) {
            return { success: false, method: 'playwright', status: 'quality_unavailable',
                     reason: `Requested quality ${qualityPreference} was not captured in this fresh browser session` };
        }

        return {
            success: true,
            status: 'live',
            method: 'playwright',
            username,
            url: bestUrl.url,
            quality: qualityPreference,
            allUrls: uniqueUrls.map(item => ({
                url: item.url,
                quality: qualityKeyFromUrl(item.url)
            })),
            allUrlsCount: uniqueUrls.length,
            timestamp: new Date().toISOString()
        };

    } catch (error) {
        log(`Playwright error: ${error.message}`);
        return { success: false, method: 'playwright', status: 'technical_error',
                 error: error.message };
    } finally {
        if (browser) await browser.close();
    }
}

// Streamlink Fallback
async function tryStreamlink(username, quality) {
    const scriptPath = path.join(__dirname, 'extraction-methods', 'extract-tiktok-streamlink.sh');
    const execution = await runFallback(scriptPath, [username, quality, '--json']);
    return parseFallbackResult('streamlink', username, execution);
}

// yt-dlp Fallback
async function tryYtDlp(username, quality) {
    const scriptPath = path.join(__dirname, 'extraction-methods', 'extract-tiktok-yt-dlp.sh');
    const ytFormat = {
        original: 'hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld',
        '1080p60': 'hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
        '720p60': 'hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
        '720p': 'hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld',
        '540p': 'hls-sd/hls-ld/flv-sd/flv-ld', '360p': 'hls-ld/flv-ld',
        auto: 'hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld',
    }[quality];
    const execution = await runFallback(scriptPath, [username, ytFormat, '--json']);
    return parseFallbackResult('yt-dlp', username, execution);
}

// Hauptfunktion mit Fallback-Kette
async function getStreamUrl(username, qualityPreference = 'auto') {
    const timestamp = new Date().toISOString();

    // --- 1. Playwright ---
    log(`[1/3] Trying Playwright for @${username}...`);
    const pwResult = await extractWithPlaywright(username, qualityPreference);
    if (pwResult.success) {
        pwResult.timestamp = timestamp;
        return pwResult;
    }
    if (pwResult.status === 'restricted' || pwResult.status === 'overloaded') {
        return pwResult;
    }
    log(`Playwright result: ${pwResult.reason || pwResult.error || 'failed'}`);

    // --- 2. Streamlink (bounded fallback; output is normalized below) ---
    log(`[2/3] Trying streamlink for @${username} (quality: ${qualityPreference})...`);
    const slResult = await tryStreamlink(username, qualityPreference);
    if (slResult.success) {
        return slResult;
    }
    if (slResult.status === 'restricted' || slResult.status === 'overloaded') {
        return slResult;
    }
    log(`Streamlink result: ${slResult.message || slResult.error || 'failed'}`);

    // --- 3. yt-dlp (final bounded fallback; output is normalized below) ---
    log(`[3/3] Trying yt-dlp for @${username}...`);
    const ytResult = await tryYtDlp(username, qualityPreference);
    if (ytResult.success) {
        return ytResult;
    }
    if (ytResult.status === 'restricted' || ytResult.status === 'overloaded') {
        return ytResult;
    }
    log(`yt-dlp result: ${ytResult.message || ytResult.error || 'failed'}`);

    // --- Alle fehlgeschlagen ---
    const status = classifyFinalFailure([pwResult, slResult, ytResult]);
    return {
        success: false,
        status,
        username,
        message: 'All extraction methods failed (Playwright, streamlink, yt-dlp).',
        playwrightReason: pwResult.reason || pwResult.error,
        streamlinkReason: slResult.message || slResult.error,
        ytdlpReason: ytResult.message || ytResult.error,
        timestamp
    };
}

// --- CLI ---
if (process.argv.length < 3) {
    console.error('Usage: node tiktok-get-stream.js <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]');
    process.exit(1);
}

let cliUsername;
try {
    cliUsername = normalizeUsername(process.argv[2]);
} catch (error) {
    console.error(error.message);
    process.exit(64);
}
enforceLoadLimit('playwright_streamlink_ytdlp');
if (forcedOffline('playwright_streamlink_ytdlp', cliUsername)) {
    process.exit(1);
}
const cliQuality = process.argv
    .slice(3)
    .find(argument => !argument.startsWith('--')) || 'auto';
const cliJson = process.argv.includes('--json');
if (!['original', '1080p60', '720p60', '720p', '540p', '360p', 'auto'].includes(cliQuality)) {
    console.error('Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto');
    process.exit(64);
}

getStreamUrl(cliUsername, cliQuality).then(result => {
    if (cliJson) {
        console.log(JSON.stringify(result, null, 2));
    } else {
        if (result.success) {
            console.log(result.url);
        } else {
            console.error(result.message);
        }
    }
    process.exit(exitCodeForResult(result));
}).catch(err => {
    console.error('Unhandled error:', err.message);
    process.exit(2);
});
