<?php
// abstraction-provenance: {"artifact_sha256": "e06ff06136f42a640115a3dd3be7124dfe1c190b1b192782e0989e5eb63262cc", "source_sha256": "c35cd96b675520599ee4e079348382ea145674af678ab98253bde2108e1ec5f6", "target_language": "php"}
// test_native_peak_limiter.cjs — portiert nach php
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
require_once __DIR__ . "/../browser-extension/content-core.php";

$executable = $argv[1] ?? null;
if (!$executable) {
    fwrite(STDERR, "Pass compiled mobile/shared/native/limiter_trace.c executable\n");
    exit(1);
}

function spawnSync($command, $args, $input) {
    $descriptorspec = [
        0 => ["pipe", "r"],
        1 => ["pipe", "w"],
        2 => ["pipe", "w"]
    ];
    $proc = proc_open([$command, ...$args], $descriptorspec, $pipes);
    if (!is_resource($proc)) {
        throw new Exception("Failed to start process");
    }
    fwrite($pipes[0], $input);
    fclose($pipes[0]);
    $stdout = stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[2]);
    $status = proc_close($proc);
    return (object)[
        "status" => $status,
        "stdout" => $stdout,
        "stderr" => $stderr
    ];
}

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
                        $channel[] = $c % 2 ? -0.95 : 0.95;
                    } elseif ($i === 300) {
                        $channel[] = NAN;
                    } elseif ($i === 301) {
                        $channel[] = INF;
                    } else {
                        $freq = $i < 2000 ? 8000 : 220;
                        $amp = $i < 2000 ? 0.9 : 0.01;
                        $channel[] = ($c + 1) / $channels * sin($i * 2 * M_PI * $freq / $rate) * $amp;
                    }
                }
                $input[] = $channel;
            }
            $kernel = createPeakLimiter($rate);
            $count = $frames + $kernel->delaySamples;
            $wire = str_repeat("\0", $count * $channels * 4);
            for ($i = 0; $i < $count; $i++) {
                for ($c = 0; $c < $channels; $c++) {
                    $value = $input[$c][$i] ?? 0;
                    $offset = ($i * $channels + $c) * 4;
                    $packed = pack("f", $value);
                    for ($j = 0; $j < 4; $j++) {
                        $wire[$offset + $j] = $packed[$j];
                    }
                }
            }
            $rendered = spawnSync($executable, [(string)$rate, (string)$channels, (string)(int)$enabled, (string)$strength], $wire);
            if ($rendered->status !== 0) {
                fwrite(STDERR, $rendered->stderr ?? "");
                exit(1);
            }
            if (strlen($rendered->stdout) !== strlen($wire)) {
                fwrite(STDERR, "Output length mismatch\n");
                exit(1);
            }
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
                        $offset = (($start + $i) * $channels + $c) * 4;
                        $packed = substr($rendered->stdout, $offset, 4);
                        if (strlen($packed) < 4) {
                            fwrite(STDERR, "Unexpected end of stdout\n");
                            exit(1);
                        }
                        $actual = unpack("f", $packed)[1];
                        if (!is_finite($actual)) {
                            fwrite(STDERR, "Non-finite value encountered\n");
                            exit(1);
                        }
                        $expected = $output[$c][$i];
                        $maxError = max($maxError, abs($actual - $expected));
                    }
                }
            }
            if ($maxError > 1e-7) {
                fwrite(STDERR, "$rate/$channels/" . (int)$enabled . "/$strength: $maxError\n");
                exit(1);
            }
            $cases++;
        }
    }
}
echo "$cases native/JavaScript PCM equivalence cases passed (error <= 1e-7).\n";
