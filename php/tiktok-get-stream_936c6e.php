<?php
// abstraction-provenance: {"artifact_sha256": "014a8b87c59bb0acadf344ec6cd2b68f4c027f9e95f6076e355ce6cea07de026", "source_sha256": "936c6e8c471f328a11317781bf628366871738b72e1e4ece900691507231dd15", "target_language": "php"}
// tiktok-get-stream.js — portiert nach php
// Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * Basic TikTok LIVE URL extractor.
 *
 * Accepts only observed HTTPS TikTok-CDN .flv responses with HTTP 2xx.
 * Success writes one naked URL to stdout. Offline/no URL exits 1, dependency
 * or technical failure exits 2, and preflight overload exits 75.
 */

require_once 'tiktok-common.php';

$username = '';
try {
    $username = normalizeUsername($argv[1] ?? '');
} catch (Exception $error) {
    fwrite(STDERR, "Usage: php tiktok-get-stream.php <username>\n");
    fwrite(STDERR, $error->getMessage() . "\n");
    exit(64);
}

enforceLoadLimit('playwright_network_basic');
$jsonOutput = in_array('--json', $argv);
if (forcedOffline('playwright_network_basic', $username)) {
    exit(1);
}

function getStreamUrl($username, $jsonOutput) {
    // Check if chrome executable exists (basic check)
    $chromePath = '/usr/bin/google-chrome'; // Adjust path as needed
    if (!file_exists($chromePath) || !is_executable($chromePath)) {
        $errorData = [
            'error' => true,
            'status' => 'dependency_missing',
            'method' => 'playwright_network_basic',
            'message' => 'Chrome/Chromium unavailable',
            'timestamp' => date('c')
        ];
        fwrite(STDERR, json_encode($errorData) . "\n");
        exit(2);
    }

    // Start Chrome with remote debugging
    $chromePort = rand(9000, 9999);
    $chromeProcess = proc_open(
        "$chromePath --headless=new --remote-debugging-port=$chromePort --disable-gpu --no-sandbox about:blank",
        [['pipe', 'r'], ['pipe', 'w'], ['pipe', 'w']],
        $pipes
    );

    if (!is_resource($chromeProcess)) {
        $errorData = [
            'error' => true,
            'status' => 'technical_error',
            'method' => 'playwright_network_basic',
            'message' => 'Failed to start Chrome process',
            'timestamp' => date('c')
        ];
        fwrite(STDERR, json_encode($errorData) . "\n");
        exit(2);
    }

    sleep(2); // Wait for Chrome to start

    // Connect to Chrome DevTools Protocol
    $devtoolsUrl = "http://localhost:$chromePort/json/version";
    $devtoolsResponse = @file_get_contents($devtoolsUrl);
    
    if ($devtoolsResponse === false) {
        proc_terminate($chromeProcess);
        proc_close($chromeProcess);
        $errorData = [
            'error' => true,
            'status' => 'technical_error',
            'method' => 'playwright_network_basic',
            'message' => 'Failed to connect to Chrome DevTools',
            'timestamp' => date('c')
        ];
        fwrite(STDERR, json_encode($errorData) . "\n");
        exit(2);
    }

    $devtoolsData = json_decode($devtoolsResponse, true);
    $websocketUrl = $devtoolsData['webSocketDebuggerUrl'] ?? null;

    if (!$websocketUrl) {
        proc_terminate($chromeProcess);
        proc_close($chromeProcess);
        $errorData = [
            'error' => true,
            'status' => 'technical_error',
            'method' => 'playwright_network_basic',
            'message' => 'WebSocket URL not found in DevTools response',
            'timestamp' => date('c')
        ];
        fwrite(STDERR, json_encode($errorData) . "\n");
        exit(2);
    }

    // Create WebSocket connection
    $socket = stream_socket_client(str_replace('ws://', 'tcp://', $websocketUrl), $errno, $errstr, 30);
    if (!$socket) {
        proc_terminate($chromeProcess);
        proc_close($chromeProcess);
        $errorData = [
            'error' => true,
            'status' => 'technical_error',
            'method' => 'playwright_network_basic',
            'message' => "WebSocket connection failed: $errstr",
            'timestamp' => date('c')
        ];
        fwrite(STDERR, json_encode($errorData) . "\n");
        exit(2);
    }

    // Upgrade to WebSocket
    $key = base64_encode(random_bytes(16));
    $headers = [
        "GET /devtools/browser/$chromePort HTTP/1.1",
        "Host: localhost:$chromePort",
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Key: $key",
        "Sec-WebSocket-Version: 13",
        ""
    ];
    fwrite($socket, implode("\r\n", $headers) . "\r\n");

    // Create target and page
    $targetId = createTarget($socket);
    if (!$targetId) {
        fclose($socket);
        proc_terminate($chromeProcess);
        proc_close($chromeProcess);
        $errorData = [
            'error' => true,
            'status' => 'technical_error',
            'method' => 'playwright_network_basic',
            'message' => 'Failed to create browser target',
            'timestamp' => date('c')
        ];
        fwrite(STDERR, json_encode($errorData) . "\n");
        exit(2);
    }

    // Enable network monitoring
    sendCommand($socket, 'Network.enable', []);

    $flvUrls = [];
    $maxCollectedUrls = 100;

    // Set up response handler
    $responseHandler = function($message) use (&$flvUrls, $maxCollectedUrls) {
        if (isset($message['method']) && $message['method'] === 'Network.responseReceived') {
            $url = $message['params']['response']['url'] ?? '';
            $status = $message['params']['response']['status'] ?? 0;
            
            if (count($flvUrls) < $maxCollectedUrls && isSuccessfulStreamResponse($status, $url)) {
                $flvUrls[] = [
                    'url' => $url,
                    'status' => $status,
                    'timestamp' => date('c')
                ];
            }
        }
    };

    // Navigate to page
    try {
        sendCommand($socket, 'Page.navigate', [
            'url' => "https://www.tiktok.com/@$username/live"
        ]);

        // Wait for page load
        sendCommand($socket, 'Page.loadEventFired', [], 60);

        // Wait for potential cookie dialogs
        usleep(3000000);

        // Accept cookies if present
        sendCommand($socket, 'Runtime.evaluate', [
            'expression' => "document.querySelector('button[data-e2e=\"cookie-banner-accept\"]').click()"
        ]);
        
        usleep(1000000);

        // Wait for stream to load
        usleep(8000000);

        // Try to trigger video play
        sendCommand($socket, 'Runtime.evaluate', [
            'expression' => "document.querySelector('video').play().catch(()=>{})"
        ]);
        
        usleep(3000000);

        if (count($flvUrls) > 0) {
            // Deduplicate URLs
            $uniqueUrls = array_values(array_unique(array_map(function($item) {
                return $item['url'];
            }, $flvUrls)));
            
            $uniqueUrls = array_map(function($url) use ($flvUrls) {
                foreach ($flvUrls as $item) {
                    if ($item['url'] === $url) {
                        return $item;
                    }
                }
                return null;
            }, $uniqueUrls);
            
            // Remove null values
            $uniqueUrls = array_filter($uniqueUrls);

            // Sort by quality indicator
            usort($uniqueUrls, function($a, $b) {
                $getQuality = function($url) {
                    preg_match('/(\d+)p/', $url, $matches);
                    return isset($matches[1]) ? (int)$matches[1] : 0;
                };
                return $getQuality($b['url']) - $getQuality($a['url']);
            });

            $result = [
                'success' => true,
                'status' => 'live',
                'method' => 'playwright',
                'username' => $username,
                'isLive' => true,
                'streamCount' => count($uniqueUrls),
                'streams' => array_slice(array_map(function($item) {
                    $item['quality'] = qualityKeyFromUrl($item['url']);
                    return $item;
                }, array_values($uniqueUrls)), 0, 10),
                'url' => $uniqueUrls[0]['url'],
                'timestamp' => date('c')
            ];
            
            echo ($jsonOutput ? json_encode($result) : $result['url']) . "\n";
            fclose($socket);
            proc_terminate($chromeProcess);
            proc_close($chromeProcess);
            return 0;
        } else {
            $errorData = [
                'success' => false,
                'status' => 'offline',
                'method' => 'playwright',
                'username' => $username,
                'isLive' => false,
                'error' => 'No stream URLs found - user may not be live',
                'timestamp' => date('c')
            ];
            fwrite(STDERR, json_encode($errorData) . "\n");
            fclose($socket);
            proc_terminate($chromeProcess);
            proc_close($chromeProcess);
            return 1;
        }

    } catch (Exception $error) {
        $errorData = [
            'error' => true,
            'status' => 'technical_error',
            'method' => 'playwright',
            'message' => $error->getMessage(),
            'timestamp' => date('c')
        ];
        fwrite(STDERR, json_encode($errorData) . "\n");
        fclose($socket);
        proc_terminate($chromeProcess);
        proc_close($chromeProcess);
        return 2;
    }
}

// Helper functions for Chrome DevTools Protocol
function createTarget($socket) {
    $response = sendCommand($socket, 'Target.createTarget', ['url' => 'about:blank']);
    return $response['result']['targetId'] ?? null;
}

function sendCommand($socket, $method, $params = [], $timeout = 10) {
    static $id = 1;
    $message = json_encode([
        'id' => $id++,
        'method' => $method,
        'params' => $params
    ]);
    
    fwrite($socket, $message . "\n");
    
    // Simple response reading (in real implementation you'd want proper async handling)
    $response = fgets($socket, 8192);
    return json_decode($response, true);
}

exit(getStreamUrl($username, $jsonOutput));
?>
