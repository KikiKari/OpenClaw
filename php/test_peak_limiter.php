<?php
// abstraction-provenance: {"artifact_sha256": "9a0d01fae1ed0d8106356d30bd624796787834074beaa64b1a3bc3d7ff0e9531", "source_sha256": "8e7a477eeeb754ba1e86a22a033ce29eb66d4c0500493fe596a60daf5ac9d10c", "target_language": "php"}
// test_peak_limiter.cjs — portiert nach php
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
require_once "../browser-extension/content-core.php";

function render($signal, $strength, $rate = 48000, $enabled = true) {
    $kernel = createPeakLimiter($rate);
    $output = array_map(function($channel) use ($kernel) {
        return array_fill(0, count($channel) + $kernel['delaySamples'], 0.0);
    }, $signal);
    
    for ($start = 0; $start < count($output[0]); $start += 128) {
        $length = min(128, count($output[0]) - $start);
        $input = array_map(function($channel) use ($start, $length) {
            $result = [];
            for ($i = 0; $i < $length; $i++) {
                $result[] = ($start + $i < count($channel)) ? $channel[$start + $i] : 0;
            }
            return $result;
        }, $signal);
        
        $outputSubarrays = array_map(function($channel) use ($start, $length) {
            return array_slice($channel, $start, $length);
        }, $output);
        
        $processed = $kernel['process']($input, $outputSubarrays, $enabled, $strength);
        
        // Update output array with processed data
        foreach ($output as $chIndex => $channel) {
            foreach ($processed[$chIndex] as $i => $value) {
                if ($start + $i < count($output[$chIndex])) {
                    $output[$chIndex][$start + $i] = $value;
                }
            }
        }
    }
    
    return ['output' => $output, 'delay' => $kernel['delaySamples']];
}

function peak($channel) {
    return array_reduce($channel, function($result, $value) {
        return max($result, abs($value));
    }, 0);
}

foreach ([44100, 48000, 96000] as $rate) {
    // Test: isolated and high-frequency peaks are bounded at $rate Hz
    $signal = array_fill(0, $rate, 0);
    $signal[1] = 1;
    $signal[127] = -1;
    for ($i = 1000; $i < 1100; $i++) {
        $signal[$i] = sin(2 * M_PI * 8000 * $i / $rate);
    }
    
    $previous = 1;
    foreach ([25, 75, 100] as $strength) {
        $result = render([$signal], $strength, $rate);
        $output = $result['output'];
        $delay = $result['delay'];
        
        $measured = peak($output[0]);
        $ceiling = 10 ** (limiterStrengthToDbfs($strength) / 20);
        
        if (!($measured <= $ceiling + 1e-7)) {
            throw new Exception("$measured exceeds $ceiling");
        }
        
        if (!($measured < $previous)) {
            throw new Exception("higher strength must attenuate more");
        }
        
        if (!($delay / $rate <= 0.01)) {
            throw new Exception("delay too large");
        }
        
        $previous = $measured;
    }
}

// Test: bypass preserves every sample with the documented delay
$signal = array_map(function($i) {
    return sin($i * 0.7) * 0.8;
}, range(0, 9999));

$result = render([$signal], 100, 48000, false);
$output = $result['output'];
$delay = $result['delay'];

$slicedOutput = array_slice($output[0], $delay);
if ($slicedOutput !== $signal) {
    throw new Exception("Bypass test failed");
}

// Test: quiet speech-band signal is not permanently attenuated
$signal = array_map(function($i) {
    return 0.01 * sin($i * 2 * M_PI * 200 / 48000);
}, range(0, 47999));

$result = render([$signal], 100);
$output = $result['output'];
$delay = $result['delay'];

$slicedOutput = array_slice($output[0], $delay);
if ($slicedOutput !== $signal) {
    throw new Exception("Quiet signal test failed");
}

// Test: linked stereo gain preserves balance and limits either channel
$left = array_fill(0, 1000, 0);
$left[127] = 0.5;
$right = array_fill(0, 1000, 0);
$right[127] = 1;

$result = render([$left, $right], 100);
$output = $result['output'];
$delay = $result['delay'];

if (abs($output[0][127 + $delay] * 2 - $output[1][127 + $delay]) > 1e-10) {
    throw new Exception("Stereo balance test failed");
}

if (!(peak($output[1]) <= 10 ** (-30 / 20) + 1e-7)) {
    throw new Exception("Stereo limiting test failed");
}

// Test: gain recovers after a transient and invalid samples cannot poison the graph
$signal = array_fill(0, 48000, 0);
$signal[10] = 1;
$signal[100] = NAN;
$signal[200] = INF;
for ($i = 24000; $i < count($signal); $i++) {
    $signal[$i] = 0.01;
}

$result = render([$signal], 100);
$output = $result['output'];

foreach ($output[0] as $value) {
    if (!is_finite($value)) {
        throw new Exception("Non-finite value found in output");
    }
}

if ($output[0][40000] <= 0.00999) {
    throw new Exception("Gain recovery test failed");
}

// Test: empty input drains delayed audio and then returns to silence
$kernel = createPeakLimiter(48000);
$block = array_fill(0, 128, 0.01);
$out = array_fill(0, 128, 0);

$out = $kernel['process']([$block], [$out], true, 100)[0];
for ($n = 0; $n < 4; $n++) {
    $out = $kernel['process']([], [$out], true, 100)[0];
}

if (peak($out) != 0) {
    throw new Exception("Empty input drain test failed");
}

echo "All tests passed!\n";

?>
