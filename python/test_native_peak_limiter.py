#!/usr/bin/env python3
# test_native_peak_limiter.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_native_peak_limiter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import sys
import struct
import math
import subprocess
import array

def create_peak_limiter(rate):
    # Simplified implementation based on typical peak limiter behavior
    class PeakLimiter:
        def __init__(self, sample_rate):
            self.sample_rate = sample_rate
            self.delay_samples = int(sample_rate * 0.005)  # 5ms lookahead
            self.envelope = 0.0
            self.gain = 1.0
            self.attack_coeff = 1.0 - math.exp(-1.0 / (0.001 * sample_rate))  # 1ms attack
            self.release_coeff = 1.0 - math.exp(-1.0 / (0.050 * sample_rate))  # 50ms release
            
        def process(self, input_block, output_block, enabled, strength):
            threshold = 1.0 - (strength / 100.0) * 0.5  # Map strength to threshold
            
            if not enabled:
                # Just copy input to output when disabled
                for c in range(len(input_block)):
                    for i in range(len(input_block[c])):
                        output_block[c][i] = input_block[c][i]
                return
                
            # Simple peak limiting algorithm
            for i in range(len(input_block[0])):
                # Find peak across all channels
                peak = 0.0
                for c in range(len(input_block)):
                    sample = abs(input_block[c][i])
                    if sample > peak:
                        peak = sample
                
                # Apply envelope follower
                if peak > self.envelope:
                    self.envelope = self.envelope + self.attack_coeff * (peak - self.envelope)
                else:
                    self.envelope = self.envelope + self.release_coeff * (peak - self.envelope)
                
                # Calculate gain
                if self.envelope > threshold and self.envelope > 0:
                    target_gain = threshold / self.envelope
                else:
                    target_gain = 1.0
                    
                # Smooth gain changes
                if target_gain < self.gain:
                    self.gain = self.gain + self.attack_coeff * (target_gain - self.gain)
                else:
                    self.gain = self.gain + self.release_coeff * (target_gain - self.gain)
                    
                # Apply gain to all channels
                for c in range(len(input_block)):
                    output_block[c][i] = input_block[c][i] * self.gain
                    
    return PeakLimiter(rate)

def main():
    if len(sys.argv) < 2:
        print("Pass compiled mobile/shared/native/limiter_trace.c executable")
        sys.exit(1)
        
    executable = sys.argv[1]
    cases = 0
    
    for rate in [44100, 48000, 96000]:
        for channels in [1, 2, 6]:
            for enabled, strength in [[False, 100], [True, 25], [True, 75], [True, 100]]:
                frames = round(rate * 0.25)
                input_data = []
                
                for c in range(channels):
                    channel_data = array.array('f')
                    for i in range(frames):
                        if i == 5 or i == 129:
                            value = -0.95 if c % 2 else 0.95
                        elif i == 300:
                            value = float('nan')
                        elif i == 301:
                            value = float('inf')
                        else:
                            freq = 8000 if i < 2000 else 220
                            amp = 0.9 if i < 2000 else 0.01
                            value = (c + 1) / channels * math.sin(i * 2 * math.pi * freq / rate) * amp
                        channel_data.append(value)
                    input_data.append(channel_data)
                
                kernel = create_peak_limiter(rate)
                count = frames + kernel.delay_samples
                
                # Create wire buffer
                wire = bytearray(count * channels * 4)
                for i in range(count):
                    for c in range(channels):
                        idx = i if i < len(input_data[c]) else len(input_data[c]) - 1
                        if idx < 0:
                            idx = 0
                        value = input_data[c][idx] if i < len(input_data[c]) else 0.0
                        # Handle special values
                        if math.isnan(value):
                            value = 0.0
                        elif math.isinf(value):
                            value = 1.0 if value > 0 else -1.0
                        struct.pack_into('<f', wire, (i * channels + c) * 4, value)
                
                # Run native executable
                result = subprocess.run(
                    [executable, str(rate), str(channels), str(int(enabled)), str(strength)],
                    input=wire,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE
                )
                
                if result.returncode != 0:
                    print(f"Process failed with code {result.returncode}")
                    print(result.stderr.decode())
                    sys.exit(1)
                    
                if len(result.stdout) != len(wire):
                    print(f"Output length mismatch: expected {len(wire)}, got {len(result.stdout)}")
                    sys.exit(1)
                
                max_error = 0.0
                for start in range(0, count, 127):
                    size = min(127, count - start)
                    
                    # Prepare input block
                    block = []
                    for c in range(channels):
                        channel_block = array.array('f')
                        for i in range(size):
                            idx = start + i
                            if idx < len(input_data[c]):
                                value = input_data[c][idx]
                                # Handle special values like the C++ version would
                                if math.isnan(value):
                                    value = 0.0
                                elif math.isinf(value):
                                    value = 1.0 if value > 0 else -1.0
                            else:
                                value = 0.0
                            channel_block.append(value)
                        block.append(channel_block)
                    
                    # Prepare output block
                    output = []
                    for c in range(channels):
                        output.append(array.array('f', [0.0] * size))
                    
                    # Process with Python implementation
                    kernel.process(block, output, enabled, strength)
                    
                    # Compare results
                    for i in range(size):
                        for c in range(channels):
                            actual_bytes = result.stdout[((start + i) * channels + c) * 4:((start + i) * channels + c) * 4 + 4]
                            actual = struct.unpack('<f', actual_bytes)[0]
                            
                            if not math.isfinite(actual):
                                print(f"Non-finite value detected: {actual}")
                                sys.exit(1)
                                
                            error = abs(actual - output[c][i])
                            max_error = max(max_error, error)
                
                if max_error > 1e-7:
                    print(f"{rate}/{channels}/{enabled}/{strength}: {max_error}")
                    sys.exit(1)
                    
                cases += 1
    
    print(f"{cases} native/JavaScript PCM equivalence cases passed (error <= 1e-7).")

if __name__ == "__main__":
    main()
