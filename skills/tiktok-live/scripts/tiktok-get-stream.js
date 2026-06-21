#!/usr/bin/env node
/**
 * Basic TikTok LIVE URL extractor.
 *
 * Accepts only observed HTTPS TikTok-CDN .flv responses with HTTP 2xx.
 * Success writes one naked URL to stdout. Offline/no URL exits 1, dependency
 * or technical failure exits 2, and preflight overload exits 75.
 */

const { chromium } = require('playwright');
const fs = require('fs');
const {
    enforceLoadLimit,
    forcedOffline,
    isSuccessfulStreamResponse,
    normalizeUsername
} = require('./tiktok-common');

let username;
try {
    username = normalizeUsername(process.argv[2]);
} catch (error) {
    console.error('Usage: node tiktok-get-stream.js <username>');
    console.error(error.message);
    process.exit(64);
}
enforceLoadLimit('playwright_network_basic');
const jsonOutput = process.argv.includes('--json');
if (forcedOffline('playwright_network_basic', username)) {
    process.exit(1);
}

async function getStreamUrl(username) {
    try {
        fs.accessSync(chromium.executablePath(), fs.constants.X_OK);
    } catch (error) {
        console.error(JSON.stringify({
            error: true,
            status: 'dependency_missing',
            method: 'playwright_network_basic',
            message: `Playwright Chromium unavailable: ${error.message}`,
            timestamp: new Date().toISOString()
        }));
        process.exit(2);
    }
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });
    const page = await context.newPage();

    const flvUrls = [];
    const maxCollectedUrls = 100;

    // Monitor network traffic for FLV streams
    page.on('response', response => {
        const url = response.url();
        if (
            flvUrls.length < maxCollectedUrls &&
            isSuccessfulStreamResponse(response.status(), url)
        ) {
            flvUrls.push({
                url: url,
                status: response.status(),
                timestamp: new Date().toISOString()
            });
        }
    });

    try {
        // Navigate to live page
        await page.goto(`https://www.tiktok.com/@${username}/live`, { 
            waitUntil: 'load', 
            timeout: 60000 
        });

        // Wait for potential DSGVO/consent dialogs
        await page.waitForTimeout(3000);

        // Accept cookies if present
        const acceptButton = await page.$('button[data-e2e="cookie-banner-accept"]');
        if (acceptButton) {
            await acceptButton.click();
            await page.waitForTimeout(1000);
        }

        // Wait for stream to load (5-10 seconds typically)
        await page.waitForTimeout(8000);

        // Try to trigger video play if needed
        const video = await page.$('video');
        if (video) {
            await video.evaluate(v => v.play()).catch(() => {});
            await page.waitForTimeout(3000);
        }

        if (flvUrls.length > 0) {
            // Deduplicate URLs
            const uniqueUrls = [...new Map(flvUrls.map(item => [item.url, item])).values()];

            // Sort by quality indicator (if present in URL)
            uniqueUrls.sort((a, b) => {
                const getQuality = url => {
                    const match = url.match(/(\d+)p/);
                    return match ? parseInt(match[1]) : 0;
                };
                return getQuality(b.url) - getQuality(a.url);
            });

            const result = {
                success: true,
                status: 'live',
                method: 'playwright',
                username,
                isLive: true,
                streamCount: uniqueUrls.length,
                streams: uniqueUrls.slice(0, 10).map(item => ({
                    ...item,
                    url: item.url.split('?')[0]
                })),
                url: uniqueUrls[0].url,
                timestamp: new Date().toISOString()
            };
            console.log(jsonOutput ? JSON.stringify(result) : result.url);
            return 0;
        } else {
            console.error(JSON.stringify({
                success: false,
                status: 'offline',
                method: 'playwright',
                username,
                isLive: false,
                error: 'No stream URLs found - user may not be live',
                timestamp: new Date().toISOString()
            }));
            return 1;
        }

    } catch (error) {
        console.error(JSON.stringify({
            error: true,
            status: 'technical_error',
            method: 'playwright',
            message: error.message,
            timestamp: new Date().toISOString()
        }));
        return 2;
    } finally {
        await browser.close();
    }
}

getStreamUrl(username).then(code => process.exit(code));
