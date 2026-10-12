#!/usr/bin/env python3
# peak-limiter.html — portiert nach python
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/peak-limiter.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/peak-limiter.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/peak-limiter.html
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/tests/peak-limiter.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import math
import json
import sys
from typing import List, Dict, Any, Optional, Tuple

class AudioBuffer:
    def __init__(self, channels: int, length: int, sample_rate: int):
        self.channels = channels
        self.length = length
        self.sample_rate = sample_rate
        self.data = [[0.0 for _ in range(length)] for _ in range(channels)]
    
    def get_channel_data(self, channel: int) -> List[float]:
        return self.data[channel]

class OfflineAudioContext:
    def __init__(self, channels: int, length: int, sample_rate: int):
        self.channels = channels
        self.length = length
        self.sample_rate = sample_rate
        self.nodes = []
    
    def create_buffer(self, channels: int, length: int, sample_rate: int) -> AudioBuffer:
        return AudioBuffer(channels, length, sample_rate)
    
    def create_buffer_source(self):
        return BufferSourceNode()
    
    def create_dynamics_compressor(self):
        return DynamicsCompressorNode()
    
    def create_gain(self):
        return GainNode()

class AudioNode:
    def __init__(self):
        self.connections = []
    
    def connect(self, destination):
        self.connections.append(destination)
        return destination

class BufferSourceNode(AudioNode):
    def __init__(self):
        super().__init__()
        self.buffer = None
    
    def start(self):
        pass

class DynamicsCompressorNode(AudioNode):
    def __init__(self):
        super().__init__()
        self.threshold = Parameter()
        self.knee = Parameter()
        self.ratio = Parameter()
        self.attack = Parameter()
        self.release = Parameter()

class GainNode(AudioNode):
    def __init__(self):
        super().__init__()
        self.gain = Parameter()

class Parameter:
    def __init__(self):
        self.value = 0

def limiter_strength_to_dbfs(strength: int) -> float:
    """Convert limiter strength (0-100) to dBFS threshold"""
    return -100 + (strength / 100) * 60

def limiter_makeup_compensation(threshold: float, ratio: float) -> float:
    """Calculate makeup gain compensation"""
    # Simplified model - in reality this would be more complex
    return pow(10, (-threshold * (1 - 1/ratio)) / 20)

def peak_db(values: List[float]) -> float:
    """Calculate peak level in dBFS"""
    max_val = max(abs(v) for v in values) if values else 1e-10
    return 20 * math.log10(max(max_val, 1e-10))

def create_test_signal(kind: str, length: int, rate: int) -> AudioBuffer:
    """Create test signal based on type"""
    buffer = AudioBuffer(1, length, rate)
    data = buffer.get_channel_data(0)
    
    for i in range(length):
        if kind == 'speech-band':
            data[i] = 0.01 * math.sin(2 * math.pi * 220 * i / rate)
        elif kind == 'short-high-tone' and 5000 <= i < 5100:
            data[i] = 0.95 * math.sin(2 * math.pi * 8000 * i / rate)
        elif kind == 'level-step' and 5000 <= i < 10000:
            data[i] = 0.95 * math.sin(2 * math.pi * 1000 * i / rate)
    
    if kind == 'impulse':
        data[5000] = 0.95
    
    return buffer

def apply_compressor(buffer: AudioBuffer, threshold: float, makeup_gain: float) -> AudioBuffer:
    """Apply simple compressor simulation"""
    output = AudioBuffer(buffer.channels, buffer.length, buffer.sample_rate)
    
    for ch in range(buffer.channels):
        input_data = buffer.get_channel_data(ch)
        output_data = output.get_channel_data(ch)
        
        # Very simplified compressor model
        for i, sample in enumerate(input_data):
            abs_sample = abs(sample)
            if abs_sample > pow(10, threshold/20):
                # Apply compression
                compressed = abs_sample * pow(10, (threshold - 20 * math.log10(abs_sample))/20)
                output_data[i] = math.copysign(min(compressed, 1.0), sample) * makeup_gain
            else:
                output_data[i] = sample * makeup_gain
    
    return output

def simulate_rendering(kind: str, strength: Optional[int], legacy: bool) -> Dict[str, Any]:
    """Simulate audio rendering process"""
    rate = 48000
    length = rate
    
    # Create input buffer
    input_buffer = create_test_signal(kind, length, rate)
    input_peak = peak_db(input_buffer.get_channel_data(0))
    
    if strength is None:
        # No processing
        output_buffer = input_buffer
        output_peak = input_peak
    elif legacy:
        # Legacy compressor simulation
        threshold = limiter_strength_to_dbfs(strength)
        makeup_gain = limiter_makeup_compensation(threshold, 20)
        output_buffer = apply_compressor(input_buffer, threshold, makeup_gain)
        output_peak = peak_db(output_buffer.get_channel_data(0))
    else:
        # Candidate lookahead limiter (simplified)
        # In reality this would be much more complex
        threshold = limiter_strength_to_dbfs(strength)
        output_buffer = AudioBuffer(1, length, rate)
        input_data = input_buffer.get_channel_data(0)
        output_data = output_buffer.get_channel_data(0)
        
        # Simple lookahead limiting simulation
        window_size = 100
        for i in range(len(input_data)):
            # Look ahead in window
            window_end = min(i + window_size, len(input_data))
            window_max = max(abs(input_data[j]) for j in range(i, window_end)) if window_end > i else 0
            
            if window_max > pow(10, threshold/20):
                # Apply limiting
                reduction = pow(10, threshold/20) / max(window_max, 1e-10)
                output_data[i] = input_data[i] * reduction
            else:
                output_data[i] = input_data[i]
        
        output_peak = peak_db(output_data)
    
    path = 'off' if strength is None else ('0.8.2-compressor' if legacy else 'candidate-lookahead')
    
    return {
        'kind': kind,
        'strength': strength,
        'path': path,
        'inputDbfs': input_peak,
        'outputDbfs': output_peak
    }

def run_audio_test() -> Dict[str, Any]:
    """Run the complete audio test suite"""
    print("Running audio test...")
    
    rows = []
    test_kinds = ['impulse', 'short-high-tone', 'level-step', 'speech-band']
    strengths = [25, 75, 100]
    
    for kind in test_kinds:
        # No processing
        rows.append(simulate_rendering(kind, None, False))
        
        # With processing
        for strength in strengths:
            rows.append(simulate_rendering(kind, strength, True))   # Legacy
            rows.append(simulate_rendering(kind, strength, False))  # Candidate
    
    # Check for failures
    failures = []
    for row in rows:
        if row['path'] == 'candidate-lookahead':
            threshold = limiter_strength_to_dbfs(row['strength']) if row['strength'] else 0
            if row['outputDbfs'] > threshold + 0.05:
                failures.append(row)
            elif row['kind'] == 'speech-band' and abs(row['outputDbfs'] - row['inputDbfs']) > 0.05:
                failures.append(row)
    
    return {
        'passed': len(failures) == 0,
        'failures': failures,
        'rows': rows
    }

def generate_html() -> str:
    """Generate the complete HTML document"""
    return '''<!doctype html>
<html lang="de"><meta charset="utf-8"><title>Pegelschutz Audioprüfung</title>
<style>body{font:16px system-ui;max-width:1000px;margin:40px auto;padding:20px}pre{white-space:pre-wrap}button{padding:12px}</style>
<h1>Pegelschutz: synthetischer Web-Audio-Vergleich</h1>
<p>Offline gerenderte Testsignale. Kein LIVE- oder Hörnachweis.</p>
<button id="run">Audioprüfung starten</button><pre id="result">Bereit</pre>
<script src="../browser-extension/content-core.js"></script>
<script>
const core = TLC_CONTENT_CORE;
const peakDb = values => 20 * Math.log10(values.reduce((max, v) => Math.max(max, Math.abs(v)), 1e-10));
async function render(kind, strength, legacy) {
  const rate = 48000, length = rate;
  const context = new OfflineAudioContext(1, length, rate);
  const buffer = context.createBuffer(1, length, rate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < length; i++) {
    if (kind === 'speech-band') data[i] = 0.01 * Math.sin(2 * Math.PI * 220 * i / rate);
    else if (kind === 'short-high-tone' && i >= 5000 && i < 5100) data[i] = 0.95 * Math.sin(2 * Math.PI * 8000 * i / rate);
    else if (kind === 'level-step' && i >= 5000 && i < 10000) data[i] = 0.95 * Math.sin(2 * Math.PI * 1000 * i / rate);
  }
  if (kind === 'impulse') data[5000] = 0.95;
  const source = context.createBufferSource(); source.buffer = buffer;
  if (strength === null) source.connect(context.destination);
  else if (legacy) {
    const compressor = context.createDynamicsCompressor(), makeup = context.createGain();
    const threshold = core.limiterStrengthToDbfs(strength);
    compressor.threshold.value = threshold; compressor.knee.value = 0.5;
    compressor.ratio.value = 20; compressor.attack.value = 0.0015; compressor.release.value = 0.08;
    makeup.gain.value = core.limiterMakeupCompensation(threshold, 20);
    source.connect(compressor).connect(makeup).connect(context.destination);
  } else {
    const node = await core.createPeakLimiterNode(context);
    node.setProtection({enabled:true, strength});
    source.connect(node).connect(context.destination);
  }
  source.start();
  const rendered = await context.startRendering();
  return {kind, strength, path: strength === null ? 'off' : legacy ? '0.8.2-compressor' : 'candidate-lookahead',
    inputDbfs: peakDb(data), outputDbfs: peakDb(rendered.getChannelData(0))};
}
document.getElementById('run').onclick = async () => {
  const output = document.getElementById('result'); output.textContent = 'Läuft';
  try {
    const rows = [];
    for (const kind of ['impulse','short-high-tone','level-step','speech-band']) {
      rows.push(await render(kind, null, false));
      for (const strength of [25,75,100]) {
        rows.push(await render(kind, strength, true));
        rows.push(await render(kind, strength, false));
      }
    }
    const failures = rows.filter(row => row.path === 'candidate-lookahead' &&
      (row.outputDbfs > core.limiterStrengthToDbfs(row.strength) + 0.05 ||
       (row.kind === 'speech-band' && Math.abs(row.outputDbfs-row.inputDbfs) > 0.05)));
    output.textContent = JSON.stringify({passed: failures.length === 0, failures, rows}, null, 2);
  } catch(error) { output.textContent = 'FEHLER: ' + error.stack; }
};
</script></html>'''

def main():
    """Main function to generate HTML file"""
    if len(sys.argv) != 2:
        print("Usage: python3 peak_limiter.py <output_file>")
        sys.exit(1)
    
    output_file = sys.argv[1]
    
    # Generate HTML content
    html_content = generate_html()
    
    # Write to file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"HTML file generated: {output_file}")
    
    # Run test to demonstrate functionality
    try:
        result = run_audio_test()
        print("\nTest Results:")
        print(f"Passed: {result['passed']}")
        print(f"Total tests: {len(result['rows'])}")
        print(f"Failures: {len(result['failures'])}")
    except Exception as e:
        print(f"\nError running test: {e}")

if __name__ == "__main__":
    main()
