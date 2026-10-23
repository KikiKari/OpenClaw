#!/usr/bin/env python3
# test_native_peak_limiter.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_native_peak_limiter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_native_peak_limiter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import sys
import struct
import math
import subprocess
import array
from typing import List, Tuple, Optional

# Import the peak limiter implementation
# Assuming content_core.py contains the createPeakLimiter function
from content_core import createPeakLimiter

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
                
                # Create input data
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
                
                # Create kernel
                kernel = createPeakLimiter(rate)
                
                # Prepare wire buffer
                count = frames + kernel.delaySamples
                wire = bytearray(count * channels * 4)
                
                # Fill wire buffer
                for i in range(count):
                    for c in range(channels):
                        value = input_data[c][i] if i < len(input_data[c]) else 0.0
                        # Convert to little-endian float and write to buffer
                        packed = struct.pack('<f', value)
                        offset = (i * channels + c) * 4
                        wire[offset:offset+4] = packed
                
                # Run executable
                try:
                    result = subprocess.run(
                        [executable, str(rate), str(channels), str(int(enabled)), str(strength)],
                        input=wire,
                        capture_output=True,
                        check=True
                    )
                except subprocess.CalledProcessError as e:
                    print(f"Process failed with stderr: {e.stderr.decode()}")
                    raise
                    
                # Check output length
                assert len(result.stdout) == len(wire), f"Output length mismatch: {len(result.stdout)} != {len(wire)}"
                
                # Validate results
                max_error = 0.0
                for start in range(0, count, 127):
                    size = min(127, count - start)
                    
                    # Create block data
                    block = []
                    for channel in input_data:
                        channel_block = array.array('f')
                        for i in range(size):
                            idx = start + i
                            value = channel[idx] if idx < len(channel) else 0.0
                            channel_block.append(value)
                        block.append(channel_block)
                    
                    # Create output arrays
                    output = [array.array('f', [0.0] * size) for _ in range(channels)]
                    
                    # Process with kernel
                    kernel.process(block, output, enabled, strength)
                    
                    # Compare with native output
                    for i in range(size):
                        for c in range(channels):
                            offset = ((start + i) * channels + c) * 4
                            # Read float from stdout
                            actual = struct.unpack('<f', result.stdout[offset:offset+4])[0]
                            
                            # Check if finite
                            assert math.isfinite(actual), f"Non-finite value detected: {actual}"
                            
                            # Calculate error
                            error = abs(actual - output[c][i])
                            max_error = max(max_error, error)
                
                # Check maximum error tolerance
                assert max_error <= 1e-7, f"{rate}/{channels}/{enabled}/{strength}: {max_error}"
                cases += 1
    
    print(f"{cases} native/JavaScript PCM equivalence cases passed (error <= 1e-7).")

if __name__ == "__main__":
    main()
