#!/usr/bin/env node
/**
 * TikTok Stream URL Extractor
 * Nutzt Network Monitoring um FLV-Stream-URLs zu capturen
 * Basierend auf AGENTS.md Learnings
 */

const { chromium } = require('playwright');
const os = require('os');
const path = require('path');
const util = require('util');
const execFilePromise = util.promisify(require('child_process').execFile);

const rawUsername = process.argv[2];
if (!rawUsername) {
    console.error('Usage: node tiktok-get-stream.js <username>');
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

async function verifyLiveStatus(username) {
    const checkerPath = path.join(__dirname, 'tiktok-check-profile.js');
    try {
        const { stdout } = await execFilePromise(process.execPath, [checkerPath, username], {
            env: process.env,
            timeout: 60000,
            maxBuffer: 1024 * 1024
        });
        const result = JSON.parse(stdout);
        return result.isLive === true;
    } catch (error) {
        const output = error.stdout || error.stderr;
        if (output) {
            try {
                const result = JSON.parse(output);
                return result.isLive === true;
            } catch (parseError) { /* kein verwertbares JSON */ }
        }
        return false;
    }
}

async function getStreamUrl(username) {
    if (!await verifyLiveStatus(username)) {
        console.error(JSON.stringify({
            username,
            isLive: false,
            error: 'User is not currently live.',
            timestamp: new Date().toISOString()
        }));
        return false;
    }

    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });
    const page = await context.newPage();
    
    const flvUrls = [];
    
    // Monitor network traffic for FLV streams
    page.on('request', request => {
        const url = request.url();
        if (url.includes('.flv') || url.includes('pull-flv')) {
            flvUrls.push({
                url: url,
                type: request.resourceType(),
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
        // Additional wait to allow network requests for FLV URLs to be captured
        await page.waitForTimeout(10000);
        
        // Try to trigger video play if needed
        const video = await page.$('video');
        if (video) {
            await video.evaluate(v => v.play()).catch(() => {});
            await page.waitForTimeout(3000);
        }
        
        await browser.close();
        
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
            
            console.log(JSON.stringify({
                username,
                isLive: true,
                streamCount: uniqueUrls.length,
                streams: uniqueUrls,
                vlcCommand: `vlc "${uniqueUrls[0].url}"`,
                timestamp: new Date().toISOString()
            }, null, 2));
            return true;
        } else {
            console.error(JSON.stringify({
                username,
                isLive: false,
                error: 'No stream URLs found - user may not be live',
                timestamp: new Date().toISOString()
            }));
            return false;
        }
        
    } catch (error) {
        await browser.close();
        console.error(JSON.stringify({
            error: true,
            message: error.message,
            timestamp: new Date().toISOString()
        }));
        return false;
    }
}

getStreamUrl(username).then(success => {
    process.exit(success ? 0 : 1);
}).catch(error => {
    console.error(JSON.stringify({
        error: true,
        message: error.message,
        timestamp: new Date().toISOString()
    }));
    process.exit(1);
});
