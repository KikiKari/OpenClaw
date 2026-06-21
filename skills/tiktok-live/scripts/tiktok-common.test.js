'use strict';

const assert = require('assert');
const { chromium } = require('playwright');
const {
    classifyDirectLiveState,
    classifyFinalFailure,
    exitCodeForResult,
    isAllowedStreamUrl,
    isSuccessfulStreamResponse,
    liveHrefSelectors,
    loadState,
    normalizeExtractorResult,
    normalizeUsername
} = require('./tiktok-common');

async function main() {
    assert.strictEqual(normalizeUsername('@example_creator'), 'example_creator');
    assert.strictEqual(normalizeUsername(' example_creator '), 'example_creator');
    assert.throws(() => normalizeUsername('example_creator;id'));
    assert.deepStrictEqual(liveHrefSelectors('example_creator'), [
        'a[href="/@example_creator/live"]',
        'a[href^="/@example_creator/live?"]'
    ]);
    assert.strictEqual(loadState({
        TIKTOK_TEST_LOAD_PER_CPU: '2',
        TIKTOK_MAX_LOAD_PER_CPU: '1.5'
    }).overloaded, true);
    assert.strictEqual(
        isAllowedStreamUrl('https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'),
        true
    );
    assert.strictEqual(
        isAllowedStreamUrl('https://attacker.example/path/tiktokcdn/video.flv'),
        false
    );
    assert.strictEqual(
        isAllowedStreamUrl('http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv'),
        false
    );
    const allowedUrl =
        'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x';
    assert.strictEqual(isSuccessfulStreamResponse(200, allowedUrl), true);
    assert.strictEqual(isSuccessfulStreamResponse(206, allowedUrl), true);
    assert.strictEqual(isSuccessfulStreamResponse(404, allowedUrl), false);
    assert.strictEqual(
        normalizeExtractorResult(
            { success: 'false', status: 'offline' },
            'streamlink',
            'example_creator'
        ).status,
        'technical_error'
    );
    assert.strictEqual(
        normalizeExtractorResult(
            { success: true, status: 'live' },
            'streamlink',
            'example_creator'
        ).status,
        'technical_error'
    );
    const offlineResult = normalizeExtractorResult(
        { success: false, status: 'offline', url: allowedUrl },
        'streamlink',
        'example_creator'
    );
    assert.strictEqual(offlineResult.status, 'offline');
    assert.strictEqual(offlineResult.url, undefined);
    assert.strictEqual(
        normalizeExtractorResult(
            { success: true, status: 'live', url: allowedUrl },
            'streamlink',
            'example_creator'
        ).status,
        'live'
    );
    assert.strictEqual(
        classifyFinalFailure([
            { status: 'offline' },
            { status: 'dependency_missing' }
        ]),
        'offline'
    );
    assert.strictEqual(exitCodeForResult({ success: false, status: 'restricted' }), 1);
    assert.strictEqual(
        exitCodeForResult({ success: false, status: 'technical_error' }),
        2
    );
    assert.strictEqual(
        classifyDirectLiveState({
            username: 'example_creator',
            currentPath: '/@example_creator/live',
            title: 'Example (@example_creator) is LIVE - TikTok LIVE',
            bodyText: 'Dieses LIVE enthält Themen, die unangenehm sein könnten.',
            successfulStreamResponse: false
        }).status,
        'restricted'
    );
    assert.strictEqual(
        classifyDirectLiveState({
            username: 'example_creator',
            currentPath: '/@example_creator/live',
            title: 'Example (@example_creator) is LIVE - TikTok LIVE',
            bodyText: 'LIVE has ended',
            successfulStreamResponse: false
        }).status,
        'offline'
    );
    assert.strictEqual(
        classifyDirectLiveState({
            username: 'example_creator',
            currentPath: '/@example_creator/live',
            title: 'Example (@example_creator) is LIVE - TikTok LIVE',
            bodyText: 'Suggested LIVE creators',
            successfulStreamResponse: true
        }).status,
        'live'
    );

    const browser = await chromium.launch({ headless: true });
    try {
        const page = await browser.newPage();
        await page.setContent(`
            <aside><a href="/@other_creator/live"><span>LIVE</span></a></aside>
            <main><header><h1>example_creator</h1></header></main>
        `);
        const ownLiveLink = await page.$(liveHrefSelectors('example_creator').join(', '));
        assert.strictEqual(ownLiveLink, null, 'sidebar LIVE for another account must not match');
    } finally {
        await browser.close();
    }
}

main().catch(error => {
    console.error(error);
    process.exit(1);
});
