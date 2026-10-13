#!/usr/bin/env pwsh
# tiktok-common.test.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Import necessary modules
using module './tiktok-common.psm1'

# Main test function
function Test-TikTokCommon {
    # Test normalizeUsername
    $result = Normalize-Username -Username '@example_creator'
    if ($result -ne 'example_creator') {
        throw "normalizeUsername test failed: expected 'example_creator', got '$result'"
    }

    $result = Normalize-Username -Username ' example_creator '
    if ($result -ne 'example_creator') {
        throw "normalizeUsername test failed: expected 'example_creator', got '$result'"
    }

    try {
        Normalize-Username -Username 'example_creator;id'
        throw "normalizeUsername test failed: should have thrown an exception"
    } catch {
        # Expected to fail
    }

    # Test liveHrefSelectors
    $selectors = Get-LiveHrefSelectors -Username 'example_creator'
    $expected = @(
        'a[href="/@example_creator/live"]',
        'a[href^="/@example_creator/live?"]'
    )
    if (-not (Compare-Object $selectors $expected)) {
        throw "liveHrefSelectors test failed"
    }

    # Test loadState overloaded condition
    $env:TIKTOK_TEST_LOAD_PER_CPU = '2'
    $env:TIKTOK_MAX_LOAD_PER_CPU = '1.5'
    $state = Get-LoadState
    if (-not $state.overloaded) {
        throw "loadState overloaded test failed"
    }
    Remove-Item Env:TIKTOK_TEST_LOAD_PER_CPU
    Remove-Item Env:TIKTOK_MAX_LOAD_PER_CPU

    # Test isAllowedStreamUrl
    $allowed = Test-IsAllowedStreamUrl -Url 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'
    if (-not $allowed) {
        throw "isAllowedStreamUrl test 1 failed"
    }

    $allowed = Test-IsAllowedStreamUrl -Url 'https://attacker.example/path/tiktokcdn/video.flv'
    if ($allowed) {
        throw "isAllowedStreamUrl test 2 failed"
    }

    $allowed = Test-IsAllowedStreamUrl -Url 'http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv'
    if ($allowed) {
        throw "isAllowedStreamUrl test 3 failed"
    }

    # Test isSuccessfulStreamResponse
    $url = 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'
    if (-not (Test-IsSuccessfulStreamResponse -StatusCode 200 -Url $url)) {
        throw "isSuccessfulStreamResponse test 1 failed"
    }

    if (-not (Test-IsSuccessfulStreamResponse -StatusCode 206 -Url $url)) {
        throw "isSuccessfulStreamResponse test 2 failed"
    }

    if (Test-IsSuccessfulStreamResponse -StatusCode 404 -Url $url) {
        throw "isSuccessfulStreamResponse test 3 failed"
    }

    # Test normalizeExtractorResult
    $result = Normalize-ExtractorResult -Result @{ success = 'false'; status = 'offline' } -Extractor 'streamlink' -Username 'example_creator'
    if ($result.status -ne 'technical_error') {
        throw "normalizeExtractorResult test 1 failed"
    }

    $result = Normalize-ExtractorResult -Result @{ success = $true; status = 'live' } -Extractor 'streamlink' -Username 'example_creator'
    if ($result.status -ne 'technical_error') {
        throw "normalizeExtractorResult test 2 failed"
    }

    $result = Normalize-ExtractorResult -Result @{ success = $false; status = 'offline'; url = $url } -Extractor 'streamlink' -Username 'example_creator'
    if ($result.status -ne 'offline') {
        throw "normalizeExtractorResult test 3 failed"
    }
    if ($result.url -ne $null) {
        throw "normalizeExtractorResult test 4 failed"
    }

    $result = Normalize-ExtractorResult -Result @{ success = $true; status = 'live'; url = $url } -Extractor 'streamlink' -Username 'example_creator'
    if ($result.status -ne 'live') {
        throw "normalizeExtractorResult test 5 failed"
    }

    # Test classifyFinalFailure
    $result = Classify-FinalFailure -Results @(@{ status = 'offline' }, @{ status = 'dependency_missing' })
    if ($result -ne 'offline') {
        throw "classifyFinalFailure test failed"
    }

    # Test exitCodeForResult
    $code = Get-ExitCodeForResult -Result @{ success = $false; status = 'restricted' }
    if ($code -ne 1) {
        throw "exitCodeForResult test 1 failed"
    }

    $code = Get-ExitCodeForResult -Result @{ success = $false; status = 'technical_error' }
    if ($code -ne 2) {
        throw "exitCodeForResult test 2 failed"
    }

    # Test classifyDirectLiveState
    $state = @{
        username = 'example_creator'
        currentPath = '/@example_creator/live'
        title = 'Example (@example_creator) is LIVE - TikTok LIVE'
        bodyText = 'Dieses LIVE enthält Themen, die unangenehm sein könnten.'
        successfulStreamResponse = $false
    }
    $result = Classify-DirectLiveState -State $state
    if ($result.status -ne 'restricted') {
        throw "classifyDirectLiveState test 1 failed"
    }

    $state.bodyText = 'LIVE has ended'
    $result = Classify-DirectLiveState -State $state
    if ($result.status -ne 'offline') {
        throw "classifyDirectLiveState test 2 failed"
    }

    $state.bodyText = 'Suggested LIVE creators'
    $state.successfulStreamResponse = $true
    $result = Classify-DirectLiveState -State $state
    if ($result.status -ne 'live') {
        throw "classifyDirectLiveState test 3 failed"
    }

    # Test Playwright integration
    try {
        $browser = Start-Chromium -Headless
        $page = New-BrowserPage -Browser $browser
        Set-PageContent -Page $page -Content @"
            <aside><a href="/@other_creator/live"><span>LIVE</span></a></aside>
            <main><header><h1>example_creator</h1></header></main>
"@
        
        $selectors = Get-LiveHrefSelectors -Username 'example_creator'
        $selectorString = $selectors -join ', '
        $ownLiveLink = Find-Element -Page $page -Selector $selectorString
        
        if ($ownLiveLink -ne $null) {
            throw "Playwright test failed: sidebar LIVE for another account must not match"
        }
    } finally {
        if ($browser) {
            Stop-Browser -Browser $browser
        }
    }

    Write-Host "All tests passed!" -ForegroundColor Green
}

# Error handling wrapper
try {
    Test-TikTokCommon
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
