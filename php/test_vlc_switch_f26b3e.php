<?php
// abstraction-provenance: {"artifact_sha256": "c4c95a643a9e83382cf661b94b974c36cfc3f9f1f7007517bdcdf09dd7533421", "source_sha256": "f26b3eccbd673f5fa54aac1c90f22b0649827637622aa8e22ffab339ae8abc28", "target_language": "php"}
// test_vlc_switch.cjs — portiert nach php
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_vlc_switch.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
function readFileSync($path) {
    return file_get_contents($path);
}

function joinPath(...$parts) {
    return implode(DIRECTORY_SEPARATOR, $parts);
}

function dirname($path) {
    return pathinfo($path, PATHINFO_DIRNAME);
}

$__dirname = dirname(__FILE__);

$source = readFileSync(joinPath($__dirname, '../browser-extension/content.js'));

$listeners = [];
$native = (object)[
    'muted' => false,
    'paused' => false,
    'pause' => function() use (&$native) { $native->paused = true; },
    'play' => function() use (&$native) { $native->paused = false; return new Promise(function($resolve) { $resolve(); }); }
];
$fallback = (object)[
    'muted' => false,
    'paused' => false
];
$media = [$native, $fallback];
$unrelatedVideo = clone $native;
$speechAudio = clone $native;
$surface = (object)[
    'querySelectorAll' => function($selector) use ($media) {
        if ($selector !== 'video') {
            throw new Exception('Assertion failed: selector should be "video"');
        }
        return $media;
    }
];
$fallback->closest = function() use ($surface) {
    return (object)['parentElement' => $surface];
};
$gain = (object)['value' => 0.7];
$changed = null;

class MutationObserverMock {
    private $callback;
    
    public function __construct($fn) {
        global $changed;
        $changed = $fn;
    }
    
    public function observe() {}
    public function disconnect() {}
}

$context = [
    'audioPipeline' => (object)[
        'video' => $native,
        'outputGain' => (object)['gain' => $gain]
    ],
    'document' => (object)[
        'querySelectorAll' => function() {
            throw new Exception('Must not globally suppress page media');
        },
        'documentElement' => (object)[],
        'addEventListener' => function($name, $fn) use (&$listeners) {
            $listeners[$name] = $fn;
        },
        'removeEventListener' => function($name) use (&$listeners) {
            unset($listeners[$name]);
        }
    ],
    'MutationObserver' => 'MutationObserverMock'
];

// Extract and run relevant code portions
$startPos = strpos($source, '  function suppressNativeAudio(');
$endPos = strpos($source, '  async function playMediaFallback(');
$relevantCode = substr($source, $startPos, $endPos - $startPos);

eval($relevantCode);

// Execute suppressNativeAudio
$release = suppressNativeAudio($fallback);

// Assertions
if ($native->muted !== true) {
    throw new Exception('Assertion failed: native.muted should be true');
}
if ($native->paused !== true) {
    throw new Exception('Assertion failed: native.paused should be true');
}
if ($gain->value !== 0) {
    throw new Exception('Assertion failed: gain.value should be 0');
}
if ($fallback->muted !== false) {
    throw new Exception('Assertion failed: fallback.muted should be false');
}
if ($fallback->paused !== false) {
    throw new Exception('Assertion failed: fallback.paused should be false');
}

$native->paused = false;
call_user_func($listeners['play']);

if ($native->paused !== true) {
    throw new Exception('Assertion failed: native.paused should be true after play event');
}

$replacement = (object)[
    'muted' => false,
    'paused' => false
];
$media[] = $replacement;
$changed();

if ($replacement->muted !== true) {
    throw new Exception('Assertion failed: replacement.muted should be true');
}
if ($replacement->paused !== true) {
    throw new Exception('Assertion failed: replacement.paused should be true');
}

$release();

if ($native->muted !== false) {
    throw new Exception('Assertion failed: native.muted should be false after release');
}
if ($native->paused !== false) {
    throw new Exception('Assertion failed: native.paused should be false after release');
}
if ($gain->value !== 0.7) {
    throw new Exception('Assertion failed: gain.value should be 0.7 after release');
}
if (count($listeners) !== 0) {
    throw new Exception('Assertion failed: listeners should be empty');
}
if ($unrelatedVideo->paused !== false) {
    throw new Exception('Assertion failed: unrelatedVideo.paused should be false');
}
if ($speechAudio->paused !== false) {
    throw new Exception('Assertion failed: speechAudio.paused should be false');
}

$context['audioPipeline']->video = $unrelatedVideo;
$releaseUnrelated = suppressNativeAudio($fallback);

if ($gain->value !== 0.7) {
    throw new Exception('Assertion failed: Unrelated audio pipeline must remain unchanged');
}

$releaseUnrelated();

$background = readFileSync(joinPath($__dirname, '../browser-extension/background.js'));
$normalStartPos = strpos($background, 'async function openNormalLive(');
$normalEndPos = strpos($background, 'chrome.sidePanel.setPanelBehavior');
$normal = substr($background, $normalStartPos, $normalEndPos - $normalStartPos);

if (!preg_match('/await chrome\.tabs\.update\(tabId, \{ url: normalLiveUrl\(handle\) \}\)/', $normal)) {
    throw new Exception('Assertion failed: Pattern not found in normal function');
}

if (preg_match('/if \(reloading\)/', $normal)) {
    throw new Exception('Assertion failed: Pattern should not match in normal function');
}

if (!preg_match('/if \(holder\?\.isConnected\) return holder\.querySelector\("video"\)/', $source)) {
    throw new Exception('Assertion failed: Pattern not found in source');
}

echo "PASS: VLC isolates native audio, suppresses restarted/replaced media, restores on failure; Normal navigates even at same URL; existing fallback reused\n";

function exerciseSwitch() {
    global $__dirname, $source;
    
    $panel = readFileSync(joinPath($__dirname, '../browser-extension/sidepanel.js'));
    $clickStart = strpos($panel, '  elements["player-vlc-frame"].addEventListener("click"');
    $clickEnd = strpos($panel, '  elements["player-volume"].addEventListener', $clickStart);
    
    $click = null;
    $starts = 0;
    $button = (object)[
        'addEventListener' => function($event, $fn) use (&$click) {
            $click = $fn;
        }
    ];
    
    $panelContext = [
        'elements' => ['player-vlc-frame' => $button],
        'installVlcIfNeeded' => function() {
            throw new Exception('Internal replacement must not wait for desktop installation');
        },
        'runPlayer' => function($action, $target) use (&$starts) {
            if ($action !== 'play-vlc-source') {
                throw new Exception('Assertion failed: action should be "play-vlc-source"');
            }
            if ($target !== $button) {
                throw new Exception('Assertion failed: target should be button');
            }
            $starts++;
        }
    ];
    
    $clickCode = substr($panel, $clickStart, $clickEnd - $clickStart);
    eval($clickCode);
    
    if ($click) {
        $click();
    }
    
    if ($starts !== 1) {
        throw new Exception('Assertion failed: VLC click dispatches internal player immediately');
    }
    
    $largeNative = (object)[
        'closest' => function() { return null; },
        'getBoundingClientRect' => function() { return (object)['width' => 1000, 'height' => 1000]; }
    ];
    $smallReplacement = (object)[
        'closest' => function() { return (object)[]; },
        'getBoundingClientRect' => function() { return (object)['width' => 100, 'height' => 100]; }
    ];
    
    $selection = [
        'activeMediaFallbackItem' => (object)[],
        'mediaFallbackRunning' => false,
        'document' => (object)[
            'querySelector' => function() use ($smallReplacement) { return $smallReplacement; },
            'querySelectorAll' => function() use ($largeNative, $smallReplacement) { return [$largeNative, $smallReplacement]; }
        ]
    ];
    
    $primaryStartPos = strpos($source, '  function primaryVideo(');
    $primaryEndPos = strpos($source, '  function playerToggleControl(');
    $primaryCode = substr($source, $primaryStartPos, $primaryEndPos - $primaryStartPos);
    eval($primaryCode);
    
    if (primaryVideo() !== $smallReplacement) {
        throw new Exception('Assertion failed: Active replacement wins regardless of video size');
    }
    
    $selection['activeMediaFallbackItem'] = null;
    $selection['mediaFallbackRunning'] = true;
    
    if (primaryVideo() !== $smallReplacement) {
        throw new Exception('Assertion failed: Starting replacement owns player controls');
    }
    
    $selection['mediaFallbackRunning'] = false;
    
    if (primaryVideo() !== $largeNative) {
        throw new Exception('Assertion failed: Inactive replacement excluded from native selection');
    }
    
    $navigated = 0;
    $ctx = [
        'chrome' => (object)[
            'tabs' => (object)[
                'get' => function() { return (object)['url' => 'https://www.tiktok.com/@test/live']; },
                'update' => function() use (&$navigated) { $navigated++; }
            ]
        ],
        'getState' => function() { return (object)[]; },
        'pageHandle' => function() { return 'test'; },
        'cancelEmbedSession' => function() {},
        'cancelRecoveryForModeChange' => function() {},
        'closeEmbedChatSource' => function() {},
        'armLiveTab' => function() {},
        'normalLiveUrl' => function() { return 'https://www.tiktok.com/@test/live'; }
    ];
    
    eval($normal);
    
    openNormalLive(1);
    
    if ($navigated !== 1) {
        throw new Exception('Assertion failed: Normal must navigate even from the same LIVE URL');
    }
    
    $released = 0;
    $removed = 0;
    $created = 0;
    $video = (object)[
        'pause' => function() {},
        'removeAttribute' => function() {},
        'load' => function() {}
    ];
    
    $player = [
        'mediaFallbackRunning' => false,
        'mediaFallbackPageUrl' => 'live',
        'location' => (object)['href' => 'live'],
        'attemptedMediaFallbackUrls' => [],
        'activeMediaFallbackItem' => null,
        'releaseNativeAudio' => null,
        'mediaFallbackCandidates' => function($x) { return $x; },
        'mediaFallbackKey' => function($x) { return $x->url; },
        'ensureMediaFallbackVideo' => function() use (&$created, $video) { $created++; return $video; },
        'suppressNativeAudio' => function() use (&$released) { return function() use (&$released) { $released++; }; },
        'setMediaFallbackStatus' => function() {},
        'destroyMediaFallbackPlayer' => function() {},
        'tryMediaUrl' => function() { return (object)['ok' => false, 'reason' => 'test failure']; },
        'getPlayerState' => function() { return (object)[]; },
        'document' => (object)[
            'getElementById' => function() {
                return (object)[
                    'remove' => function() use (&$removed) { $removed++; }
                ];
            }
        ]
    ];
    
    $playStartPos = strpos($source, '  async function playMediaFallback(');
    $playEndPos = strpos($source, '  async function configureLimiter(');
    $playCode = substr($source, $playStartPos, $playEndPos - $playStartPos);
    eval($playCode);
    
    playMediaFallback([]);
    
    if ($created !== 0) {
        throw new Exception('Assertion failed: No sources must not cover the native player');
    }
    
    $result = playMediaFallback([(object)['url' => 'test', 'quality' => 'test']]);
    
    if ($result->activated !== false) {
        throw new Exception('Assertion failed: Result activated should be false');
    }
    if ($released !== 1) {
        throw new Exception('Assertion failed: Failed startup restores native audio');
    }
    if ($removed !== 1) {
        throw new Exception('Assertion failed: Failed startup removes replacement');
    }
    if ($player['mediaFallbackRunning'] !== false) {
        throw new Exception('Assertion failed: mediaFallbackRunning should be false');
    }
    
    echo "PASS: actual Normal handler navigates same URL; failed VLC startup restores native player; empty sources create no overlay\n";
}

try {
    exerciseSwitch();
} catch (Exception $error) {
    echo "Error: " . $error->getMessage() . "\n";
    exit(1);
}
?>
