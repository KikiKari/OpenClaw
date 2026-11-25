<?php
// abstraction-provenance: {"artifact_sha256": "85e100ae5059adfb93be5f5c783c9c5ba510df0117dc220951c801e3f77a6994", "source_sha256": "a53191c31c8f3e0c2cf2f32b08da78e3ddf05a87beb8d40862645641631e7855", "target_language": "php"}
// tiktok-common.test.js — portiert nach php
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
require_once 'tiktok-common.php';

function assertStrictEquals($actual, $expected, $message = '') {
    if ($actual !== $expected) {
        throw new Exception("Assertion failed: " . ($message ?: "Expected $expected, got $actual"));
    }
}

function assertThrows($callback, $message = '') {
    try {
        $callback();
        throw new Exception("Assertion failed: Expected exception but none was thrown");
    } catch (Exception $e) {
        // Expected
    }
}

function assertDeepEquals($actual, $expected, $message = '') {
    if ($actual !== $expected) {
        throw new Exception("Assertion failed: " . ($message ?: "Arrays do not match"));
    }
}

function main() {
    assertStrictEquals(normalizeUsername('@example_creator'), 'example_creator');
    assertStrictEquals(normalizeUsername(' example_creator '), 'example_creator');
    assertThrows(function() { normalizeUsername('example_creator;id'); });
    assertDeepEquals(liveHrefSelectors('example_creator'), [
        'a[href="/@example_creator/live"]',
        'a[href^="/@example_creator/live?"]'
    ]);
    assertStrictEquals(loadState([
        'TIKTOK_TEST_LOAD_PER_CPU' => '2',
        'TIKTOK_MAX_LOAD_PER_CPU' => '1.5'
    ])['overloaded'], true);
    assertStrictEquals(
        isAllowedStreamUrl('https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'),
        true
    );
    assertStrictEquals(
        isAllowedStreamUrl('https://attacker.example/path/tiktokcdn/video.flv'),
        false
    );
    assertStrictEquals(
        isAllowedStreamUrl('http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv'),
        false
    );
    $allowedUrl = 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x';
    assertStrictEquals(isSuccessfulStreamResponse(200, $allowedUrl), true);
    assertStrictEquals(isSuccessfulStreamResponse(206, $allowedUrl), true);
    assertStrictEquals(isSuccessfulStreamResponse(404, $allowedUrl), false);
    assertStrictEquals(
        normalizeExtractorResult(
            ['success' => 'false', 'status' => 'offline'],
            'streamlink',
            'example_creator'
        )['status'],
        'technical_error'
    );
    assertStrictEquals(
        normalizeExtractorResult(
            ['success' => true, 'status' => 'live'],
            'streamlink',
            'example_creator'
        )['status'],
        'technical_error'
    );
    $offlineResult = normalizeExtractorResult(
        ['success' => false, 'status' => 'offline', 'url' => $allowedUrl],
        'streamlink',
        'example_creator'
    );
    assertStrictEquals($offlineResult['status'], 'offline');
    assertStrictEquals(isset($offlineResult['url']), false);
    assertStrictEquals(
        normalizeExtractorResult(
            ['success' => true, 'status' => 'live', 'url' => $allowedUrl],
            'streamlink',
            'example_creator'
        )['status'],
        'live'
    );
    assertStrictEquals(
        classifyFinalFailure([
            ['status' => 'offline'],
            ['status' => 'dependency_missing']
        ]),
        'offline'
    );
    assertStrictEquals(exitCodeForResult(['success' => false, 'status' => 'restricted']), 1);
    assertStrictEquals(
        exitCodeForResult(['success' => false, 'status' => 'technical_error']),
        2
    );
    assertStrictEquals(
        classifyDirectLiveState([
            'username' => 'example_creator',
            'currentPath' => '/@example_creator/live',
            'title' => 'Example (@example_creator) is LIVE - TikTok LIVE',
            'bodyText' => 'Dieses LIVE enthält Themen, die unangenehm sein könnten.',
            'successfulStreamResponse' => false
        ])['status'],
        'restricted'
    );
    assertStrictEquals(
        classifyDirectLiveState([
            'username' => 'example_creator',
            'currentPath' => '/@example_creator/live',
            'title' => 'Example (@example_creator) is LIVE - TikTok LIVE',
            'bodyText' => 'LIVE has ended',
            'successfulStreamResponse' => false
        ])['status'],
        'offline'
    );
    assertStrictEquals(
        classifyDirectLiveState([
            'username' => 'example_creator',
            'currentPath' => '/@example_creator/live',
            'title' => 'Example (@example_creator) is LIVE - TikTok LIVE',
            'bodyText' => 'Suggested LIVE creators',
            'successfulStreamResponse' => true
        ])['status'],
        'live'
    );

    // Note: The Playwright test is omitted as PHP doesn't have a direct equivalent
    // The HTML parsing and selector matching would require additional libraries like DOMDocument or Symfony DomCrawler
}

try {
    main();
    echo "All tests passed!\n";
} catch (Exception $e) {
    fwrite(STDERR, $e->getMessage() . "\n");
    exit(1);
}
