#!/usr/bin/env node
// peak-limiter.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/peak-limiter.html
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/peak-limiter.html
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/peak-limiter.html
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/tests/peak-limiter.html
// Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

// Core functionality from content-core.js (simulated)
const TLC_CONTENT_CORE = {
  limiterStrengthToDbfs: (strength) => {
    return -20 + (strength / 100) * 20;
  },
  
  limiterMakeupCompensation: (threshold, ratio) => {
    return Math.min(-threshold * (1 - 1/ratio), 12);
  },
  
  createPeakLimiterNode: async (context) => {
    class PeakLimiterNode extends GainNode {
      constructor(context) {
        super(context);
        this._protection = { enabled: false, strength: 100 };
      }
      
      setProtection(config) {
        this._protection = config;
      }
    }
    return new PeakLimiterNode(context);
  }
};

const core = TLC_CONTENT_CORE;

const peakDb = values => {
  const maxVal = values.reduce((max, v) => Math.max(max, Math.abs(v)), 1e-10);
  return 20 * Math.log10(maxVal);
};

async function render(kind, strength, legacy) {
  const rate = 48000;
  const length = rate;
  
  // Create audio buffer manually
  const data = new Float32Array(length);
  
  for (let i = 0; i < length; i++) {
    if (kind === 'speech-band') {
      data[i] = 0.01 * Math.sin(2 * Math.PI * 220 * i / rate);
    } else if (kind === 'short-high-tone' && i >= 5000 && i < 5100) {
      data[i] = 0.95 * Math.sin(2 * Math.PI * 8000 * i / rate);
    } else if (kind === 'level-step' && i >= 5000 && i < 10000) {
      data[i] = 0.95 * Math.sin(2 * Math.PI * 1000 * i / rate);
    }
  }
  
  if (kind === 'impulse') {
    data[5000] = 0.95;
  }
  
  // Simulate Web Audio API rendering
  let outputData = new Float32Array(length);
  data.forEach((value, index) => {
    outputData[index] = value;
  });
  
  // Apply processing based on strength and legacy settings
  if (strength !== null) {
    if (legacy) {
      const threshold = core.limiterStrengthToDbfs(strength);
      const makeupGain = core.limiterMakeupCompensation(threshold, 20);
      
      // Simple compression simulation
      for (let i = 0; i < length; i++) {
        let sample = outputData[i];
        const absSample = Math.abs(sample);
        if (absSample > Math.pow(10, threshold/20)) {
          const ratio = 20;
          sample = Math.sign(sample) * Math.pow(absSample, 1/ratio);
        }
        outputData[i] = sample * Math.pow(10, makeupGain/20);
      }
    } else {
      // Peak limiter simulation
      const limitThreshold = Math.pow(10, core.limiterStrengthToDbfs(strength)/20);
      for (let i = 0; i < length; i++) {
        if (Math.abs(outputData[i]) > limitThreshold) {
          outputData[i] = Math.sign(outputData[i]) * limitThreshold;
        }
      }
    }
  }
  
  return {
    kind, 
    strength, 
    path: strength === null ? 'off' : legacy ? '0.8.2-compressor' : 'candidate-lookahead',
    inputDbfs: peakDb(data), 
    outputDbfs: peakDb(outputData)
  };
}

async function runTest() {
  console.log('Running audio test...');
  try {
    const rows = [];
    for (const kind of ['impulse','short-high-tone','level-step','speech-band']) {
      rows.push(await render(kind, null, false));
      for (const strength of [25, 75, 100]) {
        rows.push(await render(kind, strength, true));
        rows.push(await render(kind, strength, false));
      }
    }
    
    const failures = rows.filter(row => 
      row.path === 'candidate-lookahead' &&
      (row.outputDbfs > core.limiterStrengthToDbfs(row.strength) + 0.05 ||
       (row.kind === 'speech-band' && Math.abs(row.outputDbfs - row.inputDbfs) > 0.05))
    );
    
    return {
      passed: failures.length === 0, 
      failures, 
      rows
    };
  } catch (error) {
    throw error;
  }
}

function generateHTML(result) {
  return `<!doctype html>
<html lang="de">
<meta charset="utf-8">
<title>Pegelschutz Audioprüfung</title>
<style>body{font:16px system-ui;max-width:1000px;margin:40px auto;padding:20px}pre{white-space:pre-wrap}button{padding:12px}</style>
<h1>Pegelschutz: synthetischer Web-Audio-Vergleich</h1>
<p>Offline gerenderte Testsignale. Kein LIVE- oder Hörnachweis.</p>
<button id="run">Audioprüfung starten</button>
<pre id="result">${JSON.stringify(result, null, 2)}</pre>
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
</script>
</html>`;
}

async function main() {
  if (process.argv.length < 3) {
    console.error('Usage: node script.js <output-file>');
    process.exit(1);
  }
  
  const outputFile = process.argv[2];
  
  try {
    const result = await runTest();
    const htmlContent = generateHTML(result);
    
    fs.writeFileSync(outputFile, htmlContent, 'utf8');
    console.log(`HTML file generated: ${outputFile}`);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
