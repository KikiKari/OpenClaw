#!/usr/bin/env python3
# peak-limiter.html — portiert nach python
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/peak-limiter.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/peak-limiter.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/peak-limiter.html
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/tests/peak-limiter.html
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import json
import math
import sys
from typing import List, Dict, Any, Optional


class ContentCore:
    @staticmethod
    def limiter_strength_to_dbfs(strength: int) -> float:
        return -60 + (strength / 100) * 50

    @staticmethod
    def limiter_makeup_compensation(threshold: float, ratio: float) -> float:
        return -threshold * (1 - 1 / ratio)

    @staticmethod
    async def create_peak_limiter_node(context):
        # Mock implementation since we can't create real Web Audio nodes in Python
        class MockLimiterNode:
            def __init__(self):
                self._protection = {"enabled": False, "strength": 0}

            def set_protection(self, protection):
                self._protection = protection

            def connect(self, destination):
                return destination

        return MockLimiterNode()


def peak_db(values: List[float]) -> float:
    max_val = max(abs(v) for v in values) if values else 1e-10
    return 20 * math.log10(max(max_val, 1e-10))


def create_buffer(length: int) -> List[float]:
    return [0.0] * length


def generate_signal(kind: str, length: int, rate: int) -> List[float]:
    data = create_buffer(length)
    for i in range(length):
        if kind == 'speech-band':
            data[i] = 0.01 * math.sin(2 * math.pi * 220 * i / rate)
        elif kind == 'short-high-tone' and 5000 <= i < 5100:
            data[i] = 0.95 * math.sin(2 * math.pi * 8000 * i / rate)
        elif kind == 'level-step' and 5000 <= i < 10000:
            data[i] = 0.95 * math.sin(2 * math.pi * 1000 * i / rate)
    
    if kind == 'impulse':
        data[5000] = 0.95
    
    return data


def apply_compressor(data: List[float], threshold: float, ratio: float, 
                     attack: float, release: float, knee: float) -> List[float]:
    # Simplified compressor implementation for testing purposes
    # This is not a full implementation but sufficient for the test
    makeup_gain = -threshold * (1 - 1/ratio)
    gain_factor = 10**(makeup_gain/20)
    
    result = []
    for sample in data:
        # Simple hard knee compression approximation
        abs_sample = abs(sample)
        if abs_sample > 10**(threshold/20):
            compressed = 10**(threshold/20) * (abs_sample / 10**(threshold/20))**(1/ratio)
            result.append(math.copysign(compressed * gain_factor, sample))
        else:
            result.append(sample * gain_factor)
    
    return result


async def render(kind: str, strength: Optional[int], legacy: bool, core) -> Dict[str, Any]:
    rate = 48000
    length = rate
    
    # Generate input signal
    input_data = generate_signal(kind, length, rate)
    
    # Process through "limiter"
    if strength is None:
        output_data = input_data[:]  # No processing
    elif legacy:
        # Apply dynamics compressor simulation
        threshold = core.limiter_strength_to_dbfs(strength)
        makeup_gain = core.limiter_makeup_compensation(threshold, 20)
        output_data = apply_compressor(input_data, threshold, 20, 0.0015, 0.08, 0.5)
    else:
        # Apply peak limiter simulation (mocked)
        threshold = core.limiter_strength_to_dbfs(strength)
        threshold_linear = 10**(threshold/20)
        
        output_data = []
        for sample in input_data:
            if abs(sample) > threshold_linear:
                output_data.append(math.copysign(threshold_linear, sample))
            else:
                output_data.append(sample)
    
    # Calculate paths
    path = 'off' if strength is None else ('0.8.2-compressor' if legacy else 'candidate-lookahead')
    
    return {
        'kind': kind,
        'strength': strength,
        'path': path,
        'inputDbfs': peak_db(input_data),
        'outputDbfs': peak_db(output_data)
    }


async def run_test() -> Dict[str, Any]:
    core = ContentCore()
    rows = []
    
    kinds = ['impulse', 'short-high-tone', 'level-step', 'speech-band']
    strengths = [25, 75, 100]
    
    # Render all combinations
    for kind in kinds:
        rows.append(await render(kind, None, False, core))
        for strength in strengths:
            rows.append(await render(kind, strength, True, core))
            rows.append(await render(kind, strength, False, core))
    
    # Check for failures
    failures = []
    for row in rows:
        if row['path'] == 'candidate-lookahead':
            threshold = core.limiter_strength_to_dbfs(row['strength'])
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


async def main():
    if len(sys.argv) != 2:
        print("Usage: python3 peak_limiter.py <output_file>")
        sys.exit(1)
    
    output_file = sys.argv[1]
    
    if output_file.endswith('.html'):
        # Generate HTML file
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(generate_html())
    else:
        # Run the test and save results
        try:
            result = await run_test()
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2, ensure_ascii=False)
        except Exception as e:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(f"FEHLER: {str(e)}")
            raise


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
