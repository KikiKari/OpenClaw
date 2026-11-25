<?php
// abstraction-provenance: {"artifact_sha256": "f3502e407c1b5e9632a0d1178ca48b02b62c0d540b9fcd897b9b4e5a9f20aef8", "source_sha256": "1c74aa0ec785639584af8f4d4e128e120c85d9712a7fca7650c80bfc0c1fe946", "target_language": "php"}
// tiktok-get-stream.js — portiert nach php
// Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:git/skills/tiktok-live/scripts/tiktok-get-stream.js
// auch in: workspace@local:skills/tiktok-live/scripts/tiktok-get-stream.js
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * TikTok Stream URL Extractor
 * Führt zuerst den profilgebundenen Status-Checker aus.
 * Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
 * Offline wird keine Stream-URL ausgegeben.
 */

// Prüfe Kommandozeilenargumente
if ($argc < 2) {
    fwrite(STDERR, "Usage: php tiktok-get-stream.php <username>\n");
    exit(1);
}

$username = ltrim($argv[1], '@');
if (empty($username)) {
    fwrite(STDERR, "Username must not be empty\n");
    exit(1);
}

/**
 * Prüft, ob der Knoten überlastet ist
 */
function rejectBusyNode() {
    $limit = getenv('TIKTOK_MAX_LOAD_PER_CPU');
    if ($limit === false || !is_numeric($limit) || $limit <= 0) {
        return;
    }

    $cpuCount = max(1, count(getenv('NUMBER_OF_PROCESSORS') ?: [])); // Windows
    if (PHP_OS_FAMILY !== 'Windows') {
        $cpuInfo = @file_get_contents('/proc/cpuinfo');
        if ($cpuInfo) {
            preg_match_all('/^processor/m', $cpuInfo, $matches);
            $cpuCount = max(1, count($matches[0]));
        } else {
            $cpuCount = max(1, (int)shell_exec('nproc 2>/dev/null') ?: 1);
        }
    }

    $loadAvg = sys_getloadavg();
    if ($loadAvg === false) {
        return;
    }

    $normalizedLoad = $loadAvg[0] / $cpuCount;
    if ($normalizedLoad > $limit) {
        fwrite(STDERR, sprintf("NODE_BUSY normalizedLoad=%.2f limit=%s\n", $normalizedLoad, $limit));
        exit(75);
    }
}

rejectBusyNode();

/**
 * Überprüft den Live-Status eines Benutzers
 *
 * @param string $username Der TikTok-Benutzername
 * @return bool True, wenn der Benutzer live ist, sonst false
 */
function verifyLiveStatus(string $username): bool {
    $checkerPath = __DIR__ . '/tiktok-check-profile.php';
    if (!file_exists($checkerPath)) {
        $checkerPath = __DIR__ . '/tiktok-check-profile.js';
    }

    $cmd = '"' . escapeshellcmd(PHP_BINARY) . '" "' . escapeshellarg($checkerPath) . '" ' . escapeshellarg($username);
    $descriptorspec = [
        0 => ["pipe", "r"],  // stdin
        1 => ["pipe", "w"],  // stdout
        2 => ["pipe", "w"]   // stderr
    ];

    $process = proc_open($cmd, $descriptorspec, $pipes);
    if (!is_resource($process)) {
        return false;
    }

    fclose($pipes[0]);
    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);

    $exitCode = proc_close($process);

    if ($exitCode === 0) {
        $result = json_decode($stdout, true);
        return isset($result['isLive']) && $result['isLive'] === true;
    }

    // Versuche Fehlerausgabe zu parsen
    if (!empty($stderr)) {
        $result = json_decode($stderr, true);
        if (isset($result['isLive'])) {
            return $result['isLive'] === true;
        }
    }

    return false;
}

/**
 * Extrahiert Stream-URLs für einen Live-Benutzer
 *
 * @param string $username Der TikTok-Benutzername
 * @return bool Erfolg oder Misserfolg
 */
function getStreamUrl(string $username): bool {
    if (!verifyLiveStatus($username)) {
        echo json_encode([
            'username' => $username,
            'isLive' => false,
            'error' => 'User is not currently live.',
            'timestamp' => date('c')
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
        return false;
    }

    // Hinweis: Da PHP keine native Browser-Automatisierung wie Playwright bietet,
    // verwenden wir cURL zur Simulation und Parsen des HTML-Codes
    
    $url = "https://www.tiktok.com/@{$username}/live";
    $headers = [
        'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language: en-US,en;q=0.5',
        'Accept-Encoding: gzip, deflate',
        'Connection: keep-alive',
    ];

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => $url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HEADER => false,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT => 60,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_ENCODING => '', // Alle Encodings akzeptieren
    ]);

    $html = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode !== 200 || $html === false) {
        echo json_encode([
            'error' => true,
            'message' => 'Failed to fetch page content',
            'timestamp' => date('c')
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
        return false;
    }

    // Suche nach möglichen FLV-URLs im HTML
    $flvUrls = [];
    
    // Regex-Muster für FLV-URLs
    $patterns = [
        '/https?:\/\/[^"\']+\.(flv|live)[^"\']*/i',
        '/https?:\/\/[^"\']*pull-flv[^"\']*/i',
        '/stream_url["\']?\s*:\s*["\']([^"\']+)/i'
    ];

    foreach ($patterns as $pattern) {
        if (preg_match_all($pattern, $html, $matches)) {
            foreach ($matches[0] as $match) {
                // Entferne Escape-Zeichen und potenzielle Quotes
                $cleanUrl = trim($match, '"\'');
                if (filter_var($cleanUrl, FILTER_VALIDATE_URL)) {
                    $flvUrls[] = [
                        'url' => $cleanUrl,
                        'type' => strpos($cleanUrl, '.flv') !== false ? 'flv' : 'unknown',
                        'timestamp' => date('c')
                    ];
                }
            }
        }
    }

    // Entferne Duplikate
    $seenUrls = [];
    $uniqueUrls = [];
    foreach ($flvUrls as $item) {
        if (!in_array($item['url'], $seenUrls)) {
            $seenUrls[] = $item['url'];
            $uniqueUrls[] = $item;
        }
    }

    if (count($uniqueUrls) > 0) {
        // Sortiere nach Qualität
        usort($uniqueUrls, function($a, $b) {
            $getQuality = function($url) {
                $suffixRanks = [
                    ['_origin.', 600],
                    ['_uhd_60.', 550],
                    ['_uhd.', 540],
                    ['_hd_60.', 500],
                    ['_hd.', 450],
                    ['_sd.', 350],
                    ['_ld.', 250]
                ];
                
                foreach ($suffixRanks as [$suffix, $rank]) {
                    if (strpos($url, $suffix) !== false) {
                        return $rank;
                    }
                }
                
                if (preg_match('/(\d+)p/', $url, $matches)) {
                    return (int)$matches[1];
                }
                
                return 0;
            };
            
            return $getQuality($b['url']) - $getQuality($a['url']);
        });

        echo json_encode([
            'username' => $username,
            'isLive' => true,
            'streamCount' => count($uniqueUrls),
            'streams' => $uniqueUrls,
            'vlcCommand' => 'vlc "' . $uniqueUrls[0]['url'] . '"',
            'timestamp' => date('c')
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
        
        return true;
    } else {
        echo json_encode([
            'username' => $username,
            'isLive' => false,
            'error' => 'No stream URLs found - user may not be live',
            'timestamp' => date('c')
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
        return false;
    }
}

try {
    $success = getStreamUrl($username);
    exit($success ? 0 : 1);
} catch (Exception $e) {
    echo json_encode([
        'error' => true,
        'message' => $e->getMessage(),
        'timestamp' => date('c')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
    exit(1);
}
?>
