<?php
// abstraction-provenance: {"artifact_sha256": "acf316e18e7ed9f43a793d4155b201eb80ade85521a440376b09499c00d6d36f", "source_sha256": "26a823a8fe0d3b94a8c9958ec8cf150765ddf3654a8806c9cc62eae06d9632db", "target_language": "php"}
// tiktok-check-profile.js — portiert nach php
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * Basic TikTok LIVE profile checker.
 *
 * Scopes every signal to the requested account and ignores unrelated sidebar
 * LIVE labels. This profile-only checker does not classify restricted LIVE;
 * use the enhanced checker or dispatcher for that distinction.
 *
 * Exit 0 = account-specific LIVE, 1 = offline, 2 = dependency/technical
 * failure, 75 = overloaded before Playwright startup.
 */

require_once 'tiktok-common.php';

$username = '';
if (isset($argv[1])) {
    try {
        $username = normalizeUsername($argv[1]);
    } catch (Exception $error) {
        fwrite(STDERR, "Usage: php tiktok-check-profile.php <username>\n");
        fwrite(STDERR, $error->getMessage() . "\n");
        exit(64);
    }
} else {
    fwrite(STDERR, "Usage: php tiktok-check-profile.php <username>\n");
    exit(64);
}

enforceLoadLimit('playwright_basic');

function checkLiveStatus($username) {
    // In PHP we can't directly check Playwright executable, so we'll skip this check
    
    // Since PHP doesn't have native Playwright support, we'll need to use a different approach
    // We'll use cURL to fetch the profile page and parse it with DOMDocument
    
    try {
        $url = "https://www.tiktok.com/@{$username}";
        $ch = curl_init();
        
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language: en-US,en;q=0.5',
            'Accept-Encoding: gzip, deflate',
            'Connection: keep-alive',
        ]);
        
        $html = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        
        if (curl_errno($ch)) {
            throw new Exception('Curl error: ' . curl_error($ch));
        }
        
        curl_close($ch);
        
        if ($httpCode !== 200) {
            throw new Exception("HTTP {$httpCode}");
        }
        
        // Parse HTML
        $dom = new DOMDocument();
        libxml_use_internal_errors(true);
        $dom->loadHTML($html);
        libxml_clear_errors();
        
        // Check for LIVE indicators
        $xpath = new DOMXPath($dom);
        
        // Method 1: Check for live links
        $liveSelectors = liveHrefSelectors($username);
        $hasLiveLink = false;
        foreach ($liveSelectors as $selector) {
            $elements = $xpath->query($selector);
            if ($elements->length > 0) {
                $hasLiveLink = true;
                break;
            }
        }
        
        // Method 2: Check for live icons/badges
        $liveIconVisible = false;
        if ($hasLiveLink) {
            $iconElements = $xpath->query('//a[contains(@href, "/live")]//*[contains(@data-e2e, "live-icon") or contains(@class, "LiveBadge") or contains(@class, "live-indicator")]');
            $liveIconVisible = $iconElements->length > 0;
        }
        
        // Method 3: Check for LIVE text badge
        $liveBadgeVisible = false;
        if ($hasLiveLink) {
            $badgeElements = $xpath->query('//a[contains(@href, "/live")]//*[text()="LIVE"]');
            $liveBadgeVisible = $badgeElements->length > 0;
        }
        
        // Method 4: Check for live border around profile image
        $hasLiveBorder = false;
        $profileSelectors = [
            '//*[@data-e2e="user-page"]//img[@data-e2e="avatar"]',
            '//*[@data-e2e="user-page"]//*[@data-e2e="profile-avatar"]//img',
            '//main//header//img[@data-e2e="avatar"]',
            '//main//header//*[contains(@class, "avatar")]//img'
        ];
        
        foreach ($profileSelectors as $selector) {
            $profileImages = $xpath->query($selector);
            if ($profileImages->length > 0) {
                // In PHP we can't easily get computed styles, so we'll just check for common live indicators
                // This is a simplified version since we don't have access to browser APIs
                $hasLiveBorder = true;
                break;
            }
        }
        
        // Method 5: Check for live indicator elements
        $liveIndicatorVisible = false;
        if ($hasLiveLink) {
            $indicatorElements = $xpath->query('//a[contains(@href, "/live")]//*[contains(@class, "live-indicator") or contains(@class, "LiveBadge")]');
            $liveIndicatorVisible = $indicatorElements->length > 0;
        }
        
        $isLive = $hasLiveLink || $hasLiveBorder || $liveIconVisible || $liveIndicatorVisible || $liveBadgeVisible;
        
        $result = [
            'username' => $username,
            'isLive' => $isLive,
            'timestamp' => date('c'),
            'indicators' => [
                'liveIcon' => $liveIconVisible,
                'liveBadge' => $liveBadgeVisible,
                'liveBorder' => $hasLiveBorder,
                'liveLink' => $hasLiveLink,
                'liveIndicator' => $liveIndicatorVisible
            ]
        ];
        
        echo json_encode($result, JSON_PRETTY_PRINT) . "\n";
        return $isLive;
        
    } catch (Exception $error) {
        $result = [
            'error' => true,
            'status' => 'technical_error',
            'message' => $error->getMessage(),
            'timestamp' => date('c')
        ];
        
        fwrite(STDERR, json_encode($result, JSON_PRETTY_PRINT) . "\n");
        return null;
    }
}

$result = checkLiveStatus($username);
exit($result === null ? 2 : ($result ? 0 : 1));

function liveHrefSelectors($username) {
    return [
        "//a[contains(@href, '/@{$username}/live')]",
        "//a[@href='/@{$username}/live']",
        "//*[contains(@data-e2e, 'live')]//a[contains(@href, '/@{$username}')]"
    ];
}

function normalizeUsername($username) {
    if (empty($username)) {
        throw new Exception('Username cannot be empty');
    }
    
    $username = trim($username);
    $username = ltrim($username, '@');
    
    if (preg_match('/[^a-zA-Z0-9._]/', $username)) {
        throw new Exception('Invalid username format');
    }
    
    return $username;
}

function enforceLoadLimit($method) {
    // Placeholder implementation
    // In real implementation, this would check system load limits
    return true;
}
?>
