<?php
// abstraction-provenance: {"artifact_sha256": "fd1643fbdd5862360c1b544ccb9ed7e1a09559768e3bc09d14bdaad24d415423", "source_sha256": "a8f6fe56e5dd5b96670040ccdc5def2ed3024c7e3f08f330234770f4186c70de", "target_language": "php"}
// test_native_peak_limiter.cjs — portiert nach php
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
require_once "../browser-extension/content-core.php";

function assertOk($condition, $message = "") {
    if (!$condition) {
        throw new Exception($message ?: "Assertion failed");
    }
}

function assertEqual($actual, $expected, $message = "") {
    if ($actual !== $expected) {
        throw new Exception($message ?: "Expected $expected, got $actual");
    }
}

function assertOkNumber($value, $message = "") {
    if (!is_finite($value)) {
        throw new Exception($message ?: "Value is not finite: $value");
    }
}

$executable = $argv[1] ?? null;
assertOk($executable, "Pass compiled mobile/shared/native/limiter_trace.c executable");

$cases = 0;

foreach ([44100, 48000, 96000] as $rate) {
    foreach ([1, 2, 6] as $channels) {
        foreach ([[false, 100], [true, 25], [true, 75], [true, 100]] as [$enabled, $strength]) {
            $frames = intval(round($rate * 0.25));
            $input = [];
            
            for ($c = 0; $c < $channels; $c++) {
                $channel = [];
                for ($i = 0; $i < $frames; $i++) {
                    if ($i === 5 || $i === 129) {
                        $channel[] = ($c % 2) ? -0.95 : 0.95;
                    } elseif ($i === 300) {
                        $channel[] = NAN;
                    } elseif ($i === 301) {
                        $channel[] = INF;
                    } else {
                        $freq = ($i < 2000) ? 8000 : 220;
                        $amp = ($i < 2000) ? 0.9 : 0.01;
                        $channel[] = ($c + 1) / $channels * sin($i * 2 * M_PI * $freq / $rate) * $amp;
                    }
                }
                $input[] = $channel;
            }
            
            $kernel = createPeakLimiter($rate);
            $count = $frames + $kernel->delaySamples;
            
            // Create wire buffer
            $wire = str_repeat("\x00", $count * $channels * 4);
            $offset = 0;
            
            for ($i = 0; $i < $count; $i++) {
                for ($c = 0; $c < $channels; $c++) {
                    $value = $input[$c][$i] ?? 0;
                    // Pack float as little-endian
                    $packed = pack("f", $value);
                    if (unpack("S", "\x01\x00")[1] !== 1) {
                        // If system is big-endian, reverse bytes
                        $packed = strrev($packed);
                    }
                    substr_replace($wire, $packed, $offset, 4);
                    $offset += 4;
                }
            }
            
            // Execute process
            $process = proc_open(
                [$executable, strval($rate), strval($channels), strval(intval($enabled)), strval($strength)],
                [
                    0 => ["pipe", "r"],
                    1 => ["pipe", "w"],
                    2 => ["pipe", "w"]
                ],
                $pipes
            );
            
            if (!is_resource($process)) {
                throw new Exception("Failed to start process");
            }
            
            fwrite($pipes[0], $wire);
            fclose($pipes[0]);
            
            $stdout = stream_get_contents($pipes[1]);
            $stderr = stream_get_contents($pipes[2]);
            
            fclose($pipes[1]);
            fclose($pipes[2]);
            
            $returnCode = proc_close($process);
            
            assertEqual($returnCode, 0, $stderr ?: "");
            assertEqual(strlen($stdout), strlen($wire));
            
            $maxError = 0;
            
            for ($start = 0; $start < $count; $start += 127) {
                $size = min(127, $count - $start);
                $block = [];
                $output = [];
                
                for ($c = 0; $c < $channels; $c++) {
                    $channelBlock = [];
                    for ($i = 0; $i < $size; $i++) {
                        $channelBlock[] = $input[$c][$start + $i] ?? 0;
                    }
                    $block[] = $channelBlock;
                    $output[] = array_fill(0, $size, 0);
                }
                
                $kernel->process($block, $output, $enabled, $strength);
                
                for ($i = 0; $i < $size; $i++) {
                    for ($c = 0; $c < $channels; $c++) {
                        // Read float from stdout at position
                        $pos = (($start + $i) * $channels + $c) * 4;
                        $bytes = substr($stdout, $pos, 4);
                        
                        if (strlen($bytes) < 4) {
                            throw new Exception("Not enough bytes in stdout at position $pos");
                        }
                        
                        // Unpack little-endian float
                        if (unpack("S", "\x01\x00")[1] !== 1) {
                            // If system is big-endian, reverse bytes before unpacking
                            $bytes = strrev($bytes);
                        }
                        
                        $unpacked = unpack("f", $bytes);
                        $actual = $unpacked[1];
                        
                        assertOkNumber($actual);
                        $maxError = max($maxError, abs($actual - $output[$c][$i]));
                    }
                }
            }
            
            assertOk($maxError <= 1e-7, "$rate/$channels/" . json_encode($enabled) . "/$strength: $maxError");
            $cases++;
        }
    }
}

echo "$cases native/JavaScript PCM equivalence cases passed (error <= 1e-7).\n";
