<?php
// abstraction-provenance: {"artifact_sha256": "b6ad7c487bff0dc6c0ec6fa1e91890b9a16456fad5611605367e845128c7ba50", "source_sha256": "23879e22856f8bcfb0ddda7c9b1d7b0d7f3af474cea8620c1f7c10511ef03ed5", "target_language": "php"}
// tiktok-common.js — portiert nach php
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * Shared TikTok LIVE safety contract: handle normalization, per-CPU load
 * preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
 * validation, and normalized extractor statuses.
 */

const DEFAULT_MAX_LOAD_PER_CPU = 1.5;
const USERNAME_PATTERN = '/^[A-Za-z0-9._]{1,24}$/';
const FAILURE_STATUSES = [
    'offline',
    'restricted',
    'overloaded',
    'dependency_missing',
    'technical_error'
];

function normalizeUsername($raw) {
    $username = trim(ltrim((string)$raw, '@'));
    if (!preg_match(USERNAME_PATTERN, $username)) {
        throw new Exception('Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores');
    }
    return $username;
}

function loadState($env = null) {
    if ($env === null) {
        $env = $_ENV;
    }
    
    $cpuCount = max(1, count(getenv('TIKTOK_TEST_LOAD_PER_CPU') === false ? [] : [getenv('TIKTOK_TEST_LOAD_PER_CPU')]));
    $observed = isset($env['TIKTOK_TEST_LOAD_PER_CPU']) 
        ? (float)$env['TIKTOK_TEST_LOAD_PER_CPU'] 
        : sys_getloadavg()[0] / $cpuCount;
    $maximum = isset($env['TIKTOK_MAX_LOAD_PER_CPU']) 
        ? (float)$env['TIKTOK_MAX_LOAD_PER_CPU'] 
        : DEFAULT_MAX_LOAD_PER_CPU;
        
    if (!is_finite($observed) || !is_finite($maximum) || $maximum <= 0) {
        throw new Exception('Invalid TikTok load configuration');
    }
    
    return [
        'overloaded' => $observed > $maximum,
        'loadPerCpu' => $observed,
        'maximum' => $maximum
    ];
}

function enforceLoadLimit($method) {
    $state = loadState();
    if (!$state['overloaded']) return $state;
    
    $output = json_encode([
        'status' => 'overloaded',
        'method' => $method,
        'loadPerCpu' => round($state['loadPerCpu'], 3),
        'maximum' => $state['maximum'],
        'message' => 'Host is overloaded; retry on another node or later'
    ]);
    
    fwrite(STDERR, $output . "\n");
    exit(75);
}

function liveHrefSelectors($username) {
    $href = "/@$username/live";
    return ["a[href=\"$href\"]", "a[href^=\"$href?\"]"];
}

function isAllowedStreamUrl($value) {
    try {
        $url = parse_url($value);
        if (!$url || !isset($url['scheme']) || !isset($url['host']) || !isset($url['path'])) {
            return false;
        }
        
        $hostname = strtolower($url['host']);
        $path = strtolower($url['path']);
        
        return $url['scheme'] === 'https' &&
            strpos($path, '.flv') !== false &&
            preg_match('/(^|\.)tiktokcdn(?:-[a-z0-9-]+)?\.com$/', $hostname);
    } catch (Exception $error) {
        return false;
    }
}

function isSuccessfulStreamResponse($status, $value) {
    return is_int($status) &&
        $status >= 200 &&
        $status < 300 &&
        isAllowedStreamUrl($value);
}

// Order matters: longer keys first so `_uhd_60` never matches as `hd_60`/`hd`.
const QUALITY_URL_PATTERN = '/_(uhd_60|hd_60|origin|hd|sd|ld|ao)\.(?:flv|m3u8)/';

function qualityKeyFromUrl($value) {
    try {
        $parsed = parse_url($value);
        if (!$parsed || !isset($parsed['path'])) {
            return null;
        }
        
        $path = strtolower($parsed['path']);
        if (preg_match(QUALITY_URL_PATTERN, $path, $matches)) {
            return $matches[1];
        }
        return null;
    } catch (Exception $error) {
        return null;
    }
}

function normalizeExtractorResult($value, $method, $username) {
    $technicalError = [
        'success' => false,
        'status' => 'technical_error',
        'method' => $method,
        'username' => $username,
        'message' => 'invalid extractor result'
    ];
    
    if (!$value || !is_array($value) || array_keys($value) === range(0, count($value) - 1)) {
        return $technicalError;
    }
    
    if (isset($value['success']) && $value['success'] === true) {
        if (($value['status'] ?? '') !== 'live' || !isAllowedStreamUrl($value['url'] ?? '')) {
            return $technicalError;
        }
        return array_merge($value, ['success' => true, 'status' => 'live']);
    }
    
    if (!isset($value['success']) || $value['success'] !== false) {
        return $technicalError;
    }
    
    $result = array_merge($value, [
        'success' => false,
        'status' => in_array($value['status'] ?? '', FAILURE_STATUSES)
            ? $value['status']
            : 'technical_error',
        'method' => is_string($value['method'] ?? null) ? $value['method'] : $method,
        'username' => is_string($value['username'] ?? null) ? $value['username'] : $username
    ]);
    
    unset($result['url']);
    unset($result['streams']);
    unset($result['allUrls']);
    
    return $result;
}

function classifyFinalFailure($results) {
    $statuses = [];
    foreach ($results as $result) {
        if ($result && isset($result['status']) && in_array($result['status'], FAILURE_STATUSES)) {
            $statuses[] = $result['status'];
        }
    }
    $statuses = array_unique($statuses);
    
    if (in_array('overloaded', $statuses)) return 'overloaded';
    if (in_array('restricted', $statuses)) return 'restricted';
    if (in_array('technical_error', $statuses)) return 'technical_error';
    if (in_array('offline', $statuses)) return 'offline';
    if (in_array('dependency_missing', $statuses)) return 'dependency_missing';
    return 'technical_error';
}

function exitCodeForResult($result) {
    if ($result && ($result['success'] ?? false) === true && ($result['status'] ?? '') === 'live') return 0;
    if ($result && ($result['status'] ?? '') === 'overloaded') return 75;
    if ($result && in_array($result['status'] ?? '', ['offline', 'restricted'])) return 1;
    return 2;
}

function classifyDirectLiveState($params) {
    $username = $params['username'] ?? '';
    $currentPath = $params['currentPath'] ?? '';
    $title = $params['title'] ?? '';
    $bodyText = $params['bodyText'] ?? '';
    $successfulStreamResponse = $params['successfulStreamResponse'] ?? false;
    
    $expectedPath = "/@$username/live";
    if ($currentPath !== $expectedPath) {
        return ['status' => 'offline', 'reason' => 'target live page redirected'];
    }
    if ($successfulStreamResponse) {
        return ['status' => 'live', 'reason' => 'successful TikTok CDN stream response'];
    }

    $normalizedBody = strtolower(preg_replace('/\s+/', ' ', (string)$bodyText));
    $normalizedTitle = strtolower((string)$title);
    $accountLiveTitle = strpos($normalizedTitle, "(@{$username}) is live") !== false;
    
    $endedMarkers = [
        'live has ended',
        'das live ist beendet',
        'live wurde beendet',
        'dieses live ist beendet',
        'stream has ended'
    ];
    
    foreach ($endedMarkers as $marker) {
        if (strpos($normalizedBody, $marker) !== false) {
            return ['status' => 'offline', 'reason' => 'target live page reports ended stream'];
        }
    }

    $restrictionMarkers = [
        'dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten',
        'melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen',
        'bei tiktok anmelden',
        'melde dich an für das volle live-erlebnis',
        'melde dich an für das vollständige erlebnis',
        'this live may contain content that could be uncomfortable',
        'log in to tiktok',
        'log in for the full live experience',
        'mature content',
        'age-restricted',
        'viewer discretion'
    ];
    
    foreach ($restrictionMarkers as $marker) {
        if ($accountLiveTitle && strpos($normalizedBody, $marker) !== false) {
            return ['status' => 'restricted', 'reason' => 'target live page requires authentication'];
        }
    }
    
    if ($accountLiveTitle) {
        return [
            'status' => 'restricted',
            'reason' => 'target is live but no accessible media response was available'
        ];
    }
    
    return ['status' => 'offline', 'reason' => 'no account-specific live signal'];
}

function forcedOffline($method, $username) {
    if (getenv('TIKTOK_TEST_OFFLINE') !== '1') return false;
    
    $output = json_encode([
        'success' => false,
        'status' => 'offline',
        'method' => $method,
        'username' => $username,
        'message' => 'forced offline test mode'
    ]);
    
    fwrite(STDERR, $output . "\n");
    return true;
}

?>
