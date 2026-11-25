<?php
// abstraction-provenance: {"artifact_sha256": "21cbbf925684f4d3195d794ffdd624e9ef7a94c75c44db6649b25ae3e3f552be", "source_sha256": "e90219318254f9b20057962724b153b7476a0511846415f2cc0a38bd9baa14f5", "target_language": "php"}
// tiktok-check-profile.js — portiert nach php
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-check-profile.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-check-profile.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * TikTok Live Status Checker
 * Prüft ausschließlich profilgebundene Live-Indikatoren.
 * Der allgemeine TikTok-Navigationspunkt "LIVE" ist kein Statussignal.
 * Unterstützt @handle-Normalisierung und optionalen Node-Lastschutz
 * via TIKTOK_MAX_LOAD_PER_CPU (Exit-Code 75 bei NODE_BUSY).
 */

// Prüfe Kommandozeilenargumente
if ($argc < 2) {
    fwrite(STDERR, "Usage: php tiktok-check-profile.php <username>\n");
    exit(1);
}

$rawUsername = $argv[1];
$username = ltrim($rawUsername, '@');

if (empty($username)) {
    fwrite(STDERR, "Username must not be empty\n");
    exit(1);
}

function rejectBusyNode() {
    $limit = getenv('TIKTOK_MAX_LOAD_PER_CPU');
    if ($limit === false || !is_numeric($limit) || $limit <= 0) {
        return;
    }
    
    $cpuCount = max(1, substr_count(file_get_contents('/proc/cpuinfo'), 'processor') ?: 1);
    
    if (file_exists('/proc/loadavg')) {
        $loadAvg = explode(' ', file_get_contents('/proc/loadavg'));
        $normalizedLoad = floatval($loadAvg[0]) / $cpuCount;
        
        if ($normalizedLoad > $limit) {
            fwrite(STDERR, "NODE_BUSY normalizedLoad=" . number_format($normalizedLoad, 2) . " limit=$limit\n");
            exit(75);
        }
    }
}

rejectBusyNode();

function checkLiveStatus($username) {
    // Prüfe ob chrome/chromium verfügbar ist
    $chromePath = null;
    foreach (['google-chrome', 'chromium-browser', 'chromium'] as $browser) {
        $which = trim(shell_exec("which $browser 2>/dev/null"));
        if (!empty($which)) {
            $chromePath = $which;
            break;
        }
    }
    
    if (!$chromePath) {
        throw new Exception("Chrome/Chromium browser not found");
    }
    
    // Erstelle temporäres Verzeichnis für User Data
    $tempDir = sys_get_temp_dir() . '/tiktok_check_' . uniqid();
    mkdir($tempDir, 0755, true);
    
    // Starte Chrome mit Remote Debugging
    $chromeCommand = "$chromePath --headless=new --disable-gpu --no-sandbox --disable-dev-shm-usage " .
                     "--remote-debugging-port=9222 --user-data-dir=\"$tempDir\" " .
                     "--user-agent=\"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36\" " .
                     "about:blank 2>/dev/null &";
    
    exec($chromeCommand);
    sleep(2); // Warte auf Start
    
    try {
        // Verbinde mit Chrome DevTools
        $context = stream_context_create([
            'http' => [
                'timeout' => 30,
                'ignore_errors' => true
            ]
        ]);
        
        // Hole Liste der Tabs
        $tabsJson = file_get_contents('http://localhost:9222/json', false, $context);
        if ($tabsJson === false) {
            throw new Exception("Cannot connect to Chrome DevTools");
        }
        
        $tabs = json_decode($tabsJson, true);
        if (empty($tabs)) {
            throw new Exception("No Chrome tabs available");
        }
        
        $tab = $tabs[0]; // Nimm ersten Tab
        $webSocketUrl = $tab['webSocketDebuggerUrl'];
        
        // Verbinde mit WebSocket
        $socket = stream_socket_client($webSocketUrl, $errno, $errstr, 30);
        if (!$socket) {
            throw new Exception("WebSocket connection failed: $errstr ($errno)");
        }
        
        $messageId = 1;
        
        // Hilfsfunktion zum Senden von Befehlen
        $sendCommand = function($method, $params = []) use (&$socket, &$messageId) {
            $command = json_encode([
                'id' => $messageId++,
                'method' => $method,
                'params' => $params
            ]);
            
            fwrite($socket, $command . "\n");
            
            // Lese Antwort
            $response = '';
            $startTime = time();
            while (time() - $startTime < 10) {
                $line = fgets($socket, 1024);
                if ($line !== false) {
                    $response .= $line;
                    if (strpos($line, '"id":' . ($messageId-1)) !== false && 
                        (strpos($line, '"result":') !== false || strpos($line, '"error":') !== false)) {
                        break;
                    }
                }
                usleep(10000); // 10ms warten
            }
            
            return json_decode($response, true);
        };
        
        // Navigiere zur Profilseite
        $sendCommand('Page.navigate', ['url' => "https://www.tiktok.com/@$username"]);
        
        // Warte auf Laden
        sleep(3);
        
        // Schließe DSGVO-Banner (versuche verschiedene Varianten)
        $cookieSelectors = [
            'button:has-text("Verstanden")',
            '[data-e2e="cookie-banner-accept"]',
            'button:has-text("Accept")',
            'button:has-text("Akzeptieren")',
            'button:has-text("Alle akzeptieren")',
            'button:has-text("Allow all")',
            'button:has-text("Accept all")',
            'button.TUXButton:has-text("Accept")',
            '[data-testid="cookie-policy-banner-accept"]'
        ];
        
        foreach ($cookieSelectors as $selector) {
            $result = $sendCommand('Runtime.evaluate', [
                'expression' => "document.querySelector('$selector')?.click()"
            ]);
            
            if (!isset($result['error'])) {
                usleep(500000); // 0.5 Sekunden warten
                break;
            }
        }
        
        // Warte auf vollständiges Laden
        sleep(3);
        
        // Screenshot für Debugging (optional)
        if (getenv('DEBUG') === '1') {
            $screenshotResult = $sendCommand('Page.captureScreenshot');
            if (isset($screenshotResult['result']['data'])) {
                file_put_contents("/tmp/tiktok-$username.png", base64_decode($screenshotResult['result']['data']));
            }
        }
        
        // Prüfe LIVE-Indikatoren
        
        // Method 1: data-e2e="live-icon"
        $liveIconResult = $sendCommand('Runtime.evaluate', [
            'expression' => '!!document.querySelector("[data-e2e=\"creator-page-header\"], [data-e2e=\"profile-avatar\"]")?.querySelector("[data-e2e=\"live-icon\"]")'
        ]);
        $liveIconVisible = isset($liveIconResult['result']['value']) ? $liveIconResult['result']['value'] : false;
        
        // Method 2: LIVE text/badge
        $liveBadgeResult = $sendCommand('Runtime.evaluate', [
            'expression' => 'Array.from(document.querySelectorAll("[data-e2e=\"creator-page-header\"], [data-e2e=\"profile-avatar\"]")).some(el => Array.from(el.querySelectorAll("*")).some(child => child.textContent?.match(/^LIVE$/i)))'
        ]);
        $liveBadgeVisible = isset($liveBadgeResult['result']['value']) ? $liveBadgeResult['result']['value'] : false;
        
        // Method 3: Roter Rahmen um Profilbild
        $profileSelectors = [
            'img[data-e2e="avatar"]',
            'div[data-e2e="profile-avatar"] img',
            '[data-e2e="creator-page-header"] img[alt*="profile"]'
        ];
        
        $hasLiveBorder = false;
        foreach ($profileSelectors as $selector) {
            $borderResult = $sendCommand('Runtime.evaluate', [
                'expression' => "
                    (function() {
                        const el = document.querySelector('$selector');
                        if (!el) return false;
                        
                        const computed = window.getComputedStyle(el);
                        const parent = el.parentElement;
                        const parentComputed = parent ? window.getComputedStyle(parent) : null;
                        
                        const styles = {
                            borderColor: computed.borderColor,
                            borderStyle: computed.borderStyle,
                            borderWidth: computed.borderWidth,
                            outlineColor: computed.outlineColor,
                            boxShadow: computed.boxShadow,
                            parentBorderColor: parentComputed ? parentComputed.borderColor : null,
                            parentBorderStyle: parentComputed ? parentComputed.borderStyle : null,
                            parentBorderWidth: parentComputed ? parentComputed.borderWidth : null
                        };
                        
                        const redIndicators = [
                            styles.borderColor,
                            styles.outlineColor,
                            styles.parentBorderColor
                        ];
                        
                        for (const color of redIndicators) {
                            if (color && (color.includes('255') || color.includes('red') || color.includes('rgb(254') || color.includes('fe2c55') || color.includes('#fe2c'))) {
                                return true;
                            }
                        }
                        
                        if (styles.boxShadow && (styles.boxShadow.includes('255') || styles.boxShadow.includes('254'))) {
                            return true;
                        }
                        
                        return false;
                    })()
                "
            ]);
            
            if (isset($borderResult['result']['value']) && $borderResult['result']['value']) {
                $hasLiveBorder = true;
                break;
            }
        }
        
        // Method 4: Live-Link
        $liveLinkResult = $sendCommand('Runtime.evaluate', [
            'expression' => "!!document.querySelector('a[href*=\"/@$username/live\"]')"
        ]);
        $hasLiveLink = isset($liveLinkResult['result']['value']) ? $liveLinkResult['result']['value'] : false;
        
        // Method 5: Live-Indicator (pulsierender roter Punkt)
        $indicatorResult = $sendCommand('Runtime.evaluate', [
            'expression' => '!!document.querySelector("[data-e2e=\"creator-page-header\"], [data-e2e=\"profile-avatar\"]")?.querySelector("[class*=\"live-indicator\"], div[class*=\"LiveBadge\"]")'
        ]);
        $liveIndicatorVisible = isset($indicatorResult['result']['value']) ? $indicatorResult['result']['value'] : false;
        
        $isLive = $liveIconVisible || $liveBadgeVisible || $hasLiveBorder || $hasLiveLink || $liveIndicatorVisible;
        
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
        
        fclose($socket);
        exec("killall chrome chromium-browser chromium 2>/dev/null");
        system("rm -rf " . escapeshellarg($tempDir));
        
        return $isLive;
        
    } catch (Exception $e) {
        if (isset($socket)) {
            fclose($socket);
        }
        exec("killall chrome chromium-browser chromium 2>/dev/null");
        if (isset($tempDir)) {
            system("rm -rf " . escapeshellarg($tempDir));
        }
        
        $errorResult = [
            'error' => true,
            'message' => $e->getMessage(),
            'timestamp' => date('c')
        ];
        
        fwrite(STDERR, json_encode($errorResult, JSON_PRETTY_PRINT) . "\n");
        exit(1);
    }
}

try {
    $isLive = checkLiveStatus($username);
    exit($isLive ? 0 : 1);
} catch (Exception $e) {
    $errorResult = [
        'error' => true,
        'message' => $e->getMessage(),
        'timestamp' => date('c')
    ];
    
    fwrite(STDERR, json_encode($errorResult, JSON_PRETTY_PRINT) . "\n");
    exit(1);
}
?>
