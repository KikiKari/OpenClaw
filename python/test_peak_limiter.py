#!/usr/bin/env python3
# test_peak_limiter.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_peak_limiter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import math
import sys
import unittest
from typing import List, Tuple, Optional, Union

# Mocking the required functions and classes
def createPeakLimiter(rate: int):
    """Mock implementation of createPeakLimiter"""
    return PeakLimiterKernel(rate)

def limiterStrengthToDbfs(strength: int) -> float:
    """Convert limiter strength to dBFS"""
    # This is a simplified conversion, adjust as needed
    return -strength * 0.3  # Approximate conversion

class PeakLimiterKernel:
    def __init__(self, rate: int):
        self.rate = rate
        self.delaySamples = int(rate * 0.01)  # 10ms delay
        self.buffer = []
        self.gain = 1.0
        
    def process(self, inputs: List[List[float]], outputs: List[List[float]], enabled: bool, strength: int):
        """Process audio signal through limiter"""
        if not inputs:
            # Handle empty input case
            for ch in outputs:
                for i in range(len(ch)):
                    ch[i] = 0
            return
            
        channels = len(inputs)
        length = len(inputs[0])
        
        # Initialize buffer if needed
        while len(self.buffer) < channels:
            self.buffer.append([0.0] * self.delaySamples)
            
        # Calculate ceiling from strength
        ceiling = 10 ** (limiterStrengthToDbfs(strength) / 20)
        
        # Process each sample
        for i in range(length):
            # Find peak across all channels
            peak_val = 0
            for ch in range(channels):
                if i < len(inputs[ch]):
                    peak_val = max(peak_val, abs(inputs[ch][i]))
                    
            # Adjust gain based on peak
            if peak_val > ceiling:
                target_gain = ceiling / peak_val
                if target_gain < self.gain:
                    self.gain = target_gain
            else:
                # Slowly recover gain
                self.gain = min(1.0, self.gain + (1.0 - self.gain) * 0.01)
                
            # Apply gain and handle delay
            for ch in range(channels):
                if i < len(inputs[ch]) and i < len(outputs[ch]):
                    # Apply gain limiting
                    val = inputs[ch][i] * self.gain
                    
                    # Handle NaN/Infinity
                    if not math.isfinite(val):
                        val = 0
                        
                    outputs[ch][i] = val

def render(signal: List[List[float]], strength: int, rate: int = 48000, enabled: bool = True) -> dict:
    """Render signal through limiter"""
    kernel = createPeakLimiter(rate)
    
    # Create output arrays with delay padding
    output = []
    for channel in signal:
        output.append([0.0] * (len(channel) + kernel.delaySamples))
        
    # Process in blocks of 128 samples
    for start in range(0, len(output[0]), 128):
        length = min(128, len(output[0]) - start)
        
        # Prepare input block
        input_block = []
        for channel in signal:
            block_data = []
            for i in range(length):
                idx = start + i
                if idx < len(channel):
                    block_data.append(channel[idx])
                else:
                    block_data.append(0)
            input_block.append(block_data)
            
        # Prepare output block
        output_block = []
        for channel in output:
            output_block.append(channel[start:start + length])
            
        # Process block
        kernel.process(input_block, output_block, enabled, strength)
        
        # Copy processed data back
        for ch_idx, block_data in enumerate(output_block):
            for i, val in enumerate(block_data):
                if start + i < len(output[ch_idx]):
                    output[ch_idx][start + i] = val
    
    return {"output": output, "delay": kernel.delaySamples}

def peak(channel: List[float]) -> float:
    """Find peak absolute value in channel"""
    return max(abs(value) for value in channel) if channel else 0

class TestPeakLimiter(unittest.TestCase):
    
    def test_isolated_and_high_frequency_peaks_are_bounded(self):
        """isolated and high-frequency peaks are bounded at different rates"""
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
                    output = result["output"][0]
                    delay = result["delay"]
                    measured = peak(output)
                    ceiling = 10 ** (limiterStrengthToDbfs(strength) / 20)
                    
                    self.assertTrue(measured <= ceiling + 1e-7, 
                                  f"{measured} exceeds {ceiling}")
                    self.assertTrue(measured < previous, 
                                  "higher strength must attenuate more")
                    self.assertTrue(delay / rate <= 0.01)
                    previous = measured

    def test_bypass_preserves_every_sample_with_documented_delay(self):
        """bypass preserves every sample with the documented delay"""
        signal = [math.sin(i * 0.7) * 0.8 for i in range(10000)]
        result = render([signal], 100, 48000, False)
        output = result["output"][0]
        delay = result["delay"]
        
        # Compare delayed output with original
        delayed_output = output[delay:]
        self.assertEqual(len(delayed_output), len(signal))
        for i, (a, b) in enumerate(zip(delayed_output, signal)):
            self.assertAlmostEqual(a, b, places=7, 
                                 msg=f"Mismatch at index {i}: {a} != {b}")

    def test_quiet_speech_band_signal_not_permanently_attenuated(self):
        """quiet speech-band signal is not permanently attenuated"""
        signal = [0.01 * math.sin(i * 2 * math.pi * 200 / 48000) for i in range(48000)]
        result = render([signal], 100)
        output = result["output"][0]
        delay = result["delay"]
        
        # Compare delayed output with original
        delayed_output = output[delay:]
        self.assertEqual(len(delayed_output), len(signal))
        for i, (a, b) in enumerate(zip(delayed_output, signal)):
            self.assertAlmostEqual(a, b, places=7, 
                                 msg=f"Mismatch at index {i}: {a} != {b}")

    def test_linked_stereo_gain_preserves_balance_and_limits_either_channel(self):
        """linked stereo gain preserves balance and limits either channel"""
        left = [0.0] * 1000
        left[127] = 0.5
        right = [0.0] * 1000
        right[127] = 1.0
        
        result = render([left, right], 100)
        output = result["output"]
        delay = result["delay"]
        
        # Check balance preservation
        self.assertAlmostEqual(output[0][127 + delay] * 2, output[1][127 + delay], 
                             places=7)
        
        # Check limiting on right channel
        right_peak = peak(output[1])
        ceiling = 10 ** (-30 / 20)
        self.assertTrue(right_peak <= ceiling + 1e-7)

    def test_gain_recovers_after_transient_and_invalid_samples_handled(self):
        """gain recovers after a transient and invalid samples cannot poison the graph"""
        signal = [0.0] * 48000
        signal[10] = 1
        signal[100] = float('nan')
        signal[200] = float('inf')
        
        for i in range(24000, len(signal)):
            signal[i] = 0.01
            
        result = render([signal], 100)
        output = result["output"][0]
        
        # Check that all values are finite
        self.assertTrue(all(math.isfinite(val) for val in output))
        
        # Check recovery after transient
        self.assertTrue(output[40000] > 0.00999)

    def test_empty_input_drains_delayed_audio_then_returns_to_silence(self):
        """empty input drains delayed audio and then returns to silence"""
        kernel = createPeakLimiter(48000)
        block = [0.01] * 128
        out = [0.0] * 128
        
        # Process initial block
        kernel.process([block], [out], True, 100)
        
        # Process empty blocks
        for _ in range(4):
            kernel.process([], [out], True, 100)
            
        # Check silence
        self.assertEqual(peak(out), 0)

if __name__ == "__main__":
    unittest.main()
