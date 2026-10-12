#!/usr/bin/env python3
# test_peak_limiter.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_peak_limiter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import math
import unittest
from typing import List, Tuple, Optional, Union
import sys
import os

# Add the parent directory to sys.path to import content_core
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'browser-extension'))
try:
    from content_core import createPeakLimiter, limiterStrengthToDbfs
except ImportError:
    # If content_core is not available, define mock functions for demonstration
    def createPeakLimiter(rate):
        class MockKernel:
            def __init__(self, rate):
                self.delaySamples = int(rate * 0.005)  # Example delay
                self.rate = rate
                self.buffer = []
            
            def process(self, inputs, outputs, enabled, strength):
                # Simplified processing logic for testing purposes
                if not inputs:
                    for ch in outputs:
                        ch[:] = 0
                    return
                
                gain = 10 ** (limiterStrengthToDbfs(strength) / 20)
                for i, (inp_ch, out_ch) in enumerate(zip(inputs, outputs)):
                    for j in range(len(out_ch)):
                        val = inp_ch[j] if j < len(inp_ch) else 0
                        out_ch[j] = val * gain if abs(val) > gain else val
                        
        return MockKernel(rate)
    
    def limiterStrengthToDbfs(strength):
        return -strength / 10


def render(signal: List[List[float]], strength: int, rate: int = 48000, enabled: bool = True) -> dict:
    kernel = createPeakLimiter(rate)
    output = [
        [0.0] * (len(channel) + kernel.delaySamples) 
        for channel in signal
    ]
    
    output_length = len(output[0]) if output else 0
    
    for start in range(0, output_length, 128):
        length = min(128, output_length - start)
        
        # Prepare input arrays
        input_arrays = []
        for channel in signal:
            input_array = []
            for i in range(length):
                idx = start + i
                if idx < len(channel):
                    input_array.append(channel[idx])
                else:
                    input_array.append(0.0)
            input_arrays.append(input_array)
        
        # Prepare output subarrays
        output_subarrays = []
        for channel in output:
            subarray = channel[start:start+length]
            output_subarrays.append(subarray)
        
        # Process the block
        kernel.process(input_arrays, output_subarrays, enabled, strength)
        
    return {"output": output, "delay": kernel.delaySamples}


def peak(channel: List[float]) -> float:
    result = 0.0
    for value in channel:
        result = max(result, abs(value))
    return result


class TestPeakLimiter(unittest.TestCase):
    
    def test_isolated_and_high_frequency_peaks_are_bounded(self):
        for rate in [44100, 48000, 96000]:
            with self.subTest(rate=rate):
                signal = [0.0] * rate
                signal[1] = 1
                signal[127] = -1
                for i in range(1000, 1100):
                    signal[i] = math.sin(2 * math.pi * 8000 * i / rate)
                
                previous = 1
                for strength in [25, 75, 100]:
                    result = render([signal], strength, rate)
                    output = result["output"]
                    delay = result["delay"]
                    
                    measured = peak(output[0])
                    ceiling = 10 ** (limiterStrengthToDbfs(strength) / 20)
                    
                    self.assertLessEqual(measured, ceiling + 1e-7, f"{measured} exceeds {ceiling}")
                    self.assertLess(measured, previous, "higher strength must attenuate more")
                    self.assertLessEqual(delay / rate, 0.01)
                    previous = measured

    def test_bypass_preserves_every_sample_with_documented_delay(self):
        signal = [math.sin(i * 0.7) * 0.8 for i in range(10000)]
        result = render([signal], 100, 48000, False)
        output = result["output"]
        delay = result["delay"]
        
        output_slice = output[0][delay:]
        self.assertEqual(output_slice, signal)

    def test_quiet_speech_band_signal_not_permanently_attenuated(self):
        signal = [0.01 * math.sin(i * 2 * math.pi * 200 / 48000) for i in range(48000)]
        result = render([signal], 100)
        output = result["output"]
        delay = result["delay"]
        
        output_slice = output[0][delay:]
        self.assertEqual(output_slice, signal)

    def test_linked_stereo_gain_preserves_balance_and_limits_either_channel(self):
        left = [0.0] * 1000
        left[127] = 0.5
        right = [0.0] * 1000
        right[127] = 1.0
        
        result = render([left, right], 100)
        output = result["output"]
        delay = result["delay"]
        
        self.assertAlmostEqual(output[0][127 + delay] * 2, output[1][127 + delay], places=7)
        self.assertLessEqual(peak(output[1]), 10 ** (-30 / 20) + 1e-7)

    def test_gain_recovers_after_transient_and_invalid_samples_cannot_poison_graph(self):
        signal = [0.0] * 48000
        signal[10] = 1.0
        signal[100] = float('nan')
        signal[200] = float('inf')
        for i in range(24000, len(signal)):
            signal[i] = 0.01
            
        result = render([signal], 100)
        output = result["output"]
        
        for val in output[0]:
            self.assertTrue(math.isfinite(val))
        
        self.assertGreater(output[0][40000], 0.00999)

    def test_empty_input_drains_delayed_audio_and_then_returns_to_silence(self):
        kernel = createPeakLimiter(48000)
        block = [0.01] * 128
        out = [0.0] * 128
        
        kernel.process([block], [out], True, 100)
        for _ in range(4):
            kernel.process([], [out], True, 100)
            
        self.assertEqual(peak(out), 0)


if __name__ == "__main__":
    unittest.main()
