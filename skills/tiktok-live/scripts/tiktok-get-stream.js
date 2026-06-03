#!/usr/bin/env node
/**
 * TikTok Stream URL Extractor
 * Nutzt Network Monitoring um FLV-Stream-URLs zu capturen
 * Basierend auf AGENTS.md Learnings
 */

const { chromium } = require('playwright');

const username = process.argv[2];
if (!username) {
    console.error('Usage: node tiktok-get-stream.js <username>');
    process.exit(1);
}

async function getStreamUrl(username) {
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
        } else {
            console.log(JSON.stringify({
                username,
                isLive: false,
                error: 'No stream URLs found - user may not be live',
                timestamp: new Date().toISOString()
            }));
        }
        
    } catch (error) {
        await browser.close();
        console.error(JSON.stringify({
            error: true,
            message: error.message,
            timestamp: new Date().toISOString()
        }));
        process.exit(1);
    }
}

getStreamUrl(username);
