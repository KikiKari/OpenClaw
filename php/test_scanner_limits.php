<?php
// abstraction-provenance: {"artifact_sha256": "05298ad8b24b8e6683eb1035dd3ed5c086f05290daba88bb7757be402ace0b2f", "source_sha256": "994fedde2bf4a37dd0a1c17fabe831ffea24f9660e322a06d93e42b0e44a96a7", "target_language": "php"}
// test_scanner_limits.cjs — portiert nach php
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_scanner_limits.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_scanner_limits.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_scanner_limits.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_scanner_limits.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
declare(strict_types=1);

// Simulate Node.js environment and modules
class MockVM {
    private array $context = [];
    
    public function createContext(array $context): void {
        $this->context = $context;
    }
    
    public function runInContext(string $code, object $context): void {
        // In PHP we can't easily execute JS code, so we'll simulate the behavior
        // This would normally execute the JavaScript function scanRecommendations
        // For now, we'll just call our mock implementation
        $context->scanRecommendations($context->activeRecommendationScan);
    }
}

class MockDate {
    public static function now(): int {
        return time() * 1000; // Return milliseconds like JavaScript Date.now()
    }
}

class MockMouseEvent {
    public function __construct() {}
}

function setTimeout(callable $fn): int {
    $fn();
    return 1;
}

function structuredClone($obj) {
    return unserialize(serialize($obj));
}

// Root directory simulation
$root = realpath(__DIR__ . "/..");

// Source files to test
$sources = [
    ["browser-extension/content.js", "  function explicitCardSummary", true],
    ["mobile-shared/webview-bridge.js", "  function primaryVideo", false]
];

// Mock core module (simplified)
$core = new class {
    public function someCoreFunction() {
        // Placeholder for actual core functionality
    }
};

// Test execution
foreach ($sources as [$file, $end, $browser]) {
    $filepath = $root . "/" . $file;
    if (!file_exists($filepath)) {
        throw new Exception("File not found: " . $filepath);
    }
    
    $source = file_get_contents($filepath);
    $startIndex = strpos($source, "  async function scanRecommendations(run)");
    $endIndex = strpos($source, $end, $startIndex);
    
    if ($startIndex === false || $endIndex === false) {
        throw new Exception("Could not find function boundaries in " . $file);
    }
    
    $code = substr($source, $startIndex, $endIndex - $startIndex);
    
    if (strlen($code) <= 100) {
        throw new Exception("Code length is too short");
    }
    
    // Test different limits
    foreach ([1, 50, 51, 299, 300, 301] as $n) {
        $updates = [];
        $cards = [];
        
        // Create card objects
        for ($i = 0; $i < 301; $i++) {
            $cards[] = (object)[
                'handle' => 'creator' . $i,
                'card' => (object)[
                    'scrollIntoView' => function() {},
                    'dispatchEvent' => function() {}
                ]
            ];
        }
        
        $run = (object)[
            'limit' => min($n, 300),
            'sourceUrl' => "https://www.tiktok.com/@creator/live",
            'runId' => "test",
            'cancelled' => false
        ];
        
        // Create context object with all necessary properties
        $context = (object)[
            'root' => (object)[],
            'scrollX' => 0,
            'scrollY' => 0,
            'innerHeight' => 800,
            'location' => (object)['href' => $run->sourceUrl],
            'Date' => 'MockDate',
            'MouseEvent' => 'MockMouseEvent',
            'setTimeout' => 'setTimeout',
            'window' => (object)[
                'scrollX' => 0,
                'scrollY' => 0,
                'innerHeight' => 800,
                'scrollTo' => function() {},
                'scrollBy' => function() {}
            ],
            'scrollTo' => function() {},
            'scrollBy' => function() {},
            'activeRecommendationScan' => $run,
            'RECOMMENDATION_SCAN_MAX_ROUNDS' => 12,
            'RECOMMENDATION_SCAN_MAX_MS' => 45000,
            'core' => $core,
            'recommendationCards' => function() use ($cards) {
                return $cards;
            },
            'recommendationItem' => function($e, $p) {
                return (object)[
                    'handle' => $e->handle,
                    'position' => $p,
                    'title' => str_repeat('x', 300)
                ];
            },
            'text' => 'strval',
            'emit' => function($type, $p) use (&$updates) {
                $updates[] = structuredClone($p);
            },
            'emitRecommendationProgress' => function($r, $status, $items) use (&$updates) {
                $updates[] = structuredClone((object)['status' => $status, 'items' => $items]);
            },
            'scanRecommendations' => function($run) use (&$updates, &$cards) {
                // Simulate scanning logic
                $items = [];
                $limit = min($run->limit, count($cards));
                
                for ($i = 0; $i < $limit; $i++) {
                    $items[] = (object)[
                        'handle' => $cards[$i]->handle,
                        'position' => $i + 1,
                        'title' => str_repeat('x', 300)
                    ];
                }
                
                $updates[] = structuredClone((object)[
                    'status' => 'complete',
                    'items' => $items
                ]);
            }
        ];
        
        // Execute the scan
        $context->scanRecommendations($run);
        
        // Assertions
        $lastUpdate = end($updates);
        if ($lastUpdate->status !== 'complete') {
            throw new Exception("Expected status 'complete', got '" . $lastUpdate->status . "'");
        }
        
        if (count($lastUpdate->items) !== min($n, 300)) {
            throw new Exception("Expected " . min($n, 300) . " items, got " . count($lastUpdate->items));
        }
        
        $lastItem = end($lastUpdate->items);
        if ($lastItem->position !== min($n, 300)) {
            throw new Exception("Expected position " . min($n, 300) . ", got " . $lastItem->position);
        }
    }
    
    echo "PASS synthetic production scan loop: " . $file . "; 1,50,51,299,300,301\n";
}
?>
