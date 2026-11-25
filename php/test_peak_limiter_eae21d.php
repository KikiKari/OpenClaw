<?php
// abstraction-provenance: {"artifact_sha256": "9c7ade55d7d914faef9a1b0f32869693cd0a1545d5136fbf274e0e2a8db699af", "source_sha256": "eae21de9563d56348053e8960d0cb46932aedad7fc6eb85904cb2c5a7aa9d8e6", "target_language": "php"}
// test_peak_limiter.cjs — portiert nach php
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
require_once '../browser-extension/content-core.php';

function render($signal, $strength, $rate = 48000, $enabled = true) {
    $kernel = createPeakLimiter($rate);
    $output = array_map(function($channel) use ($kernel) {
        return array_fill(0, count($channel) + $kernel['delaySamples'], 0);
    }, $signal);
    
    for ($start = 0; $start < count($output[0]); $start += 128) {
        $length = min(128, count($output[0]) - $start);
        $input = array_map(function($channel) use ($start, $length) {
            $result = [];
            for ($i = 0; $i < $length; $i++) {
                $result[$i] = isset($channel[$start + $i]) ? $channel[$start + $i] : 0;
            }
            return $result;
        }, $signal);
        
        $outputSlice = array_map(function($channel) use ($start, $length) {
            return array_slice($channel, $start, $length);
        }, $output);
        
        $processed = $kernel['process']($input, $outputSlice, $enabled, $strength);
        
        // Update output array with processed data
        for ($ch = 0; $ch < count($output); $ch++) {
            for ($i = 0; $i < count($processed[$ch]); $i++) {
                if (isset($output[$ch][$start + $i])) {
                    $output[$ch][$start + $i] = $processed[$ch][$i];
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
            throw new Exception("delay exceeds 1%");
        }
        
        $previous = $measured;
    }
}

// Test: bypass preserves every sample with the documented delay
$signal = [];
for ($i = 0; $i < 10000; $i++) {
    $signal[$i] = sin($i * 0.7) * 0.8;
}
$result = render([$signal], 100, 48000, false);
$output = $result['output'];
$delay = $result['delay'];

$slice = array_slice($output[0], $delay);
if ($slice !== $signal) {
    throw new Exception("Bypass test failed");
}

// Test: quiet speech-band signal is not permanently attenuated
$signal = [];
for ($i = 0; $i < 48000; $i++) {
    $signal[$i] = 0.01 * sin($i * 2 * M_PI * 200 / 48000);
}
$result = render([$signal], 100);
$output = $result['output'];
$delay = $result['delay'];

$slice = array_slice($output[0], $delay);
if ($slice !== $signal) {
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

$peakRight = peak($output[1]);
$limit = 10 ** (-30 / 20) + 1e-7;
if (!($peakRight <= $limit)) {
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
        throw new Exception("Non-finite values found in output");
    }
}

if (!(abs($output[0][40000]) > 0.00999)) {
    throw new Exception("Gain recovery test failed");
}

// Test: empty input drains delayed audio and then returns to silence
$kernel = createPeakLimiter(48000);
$block = array_fill(0, 128, 0.01);
$out = array_fill(0, 128, 0);

$kernel['process']([$block], [$out], true, 100);
for ($n = 0; $n < 4; $n++) {
    $kernel['process']([], [$out], true, 100);
}

if (peak($out) != 0) {
    throw new Exception("Empty input drain test failed");
}

echo "All tests passed!\n";

?>
