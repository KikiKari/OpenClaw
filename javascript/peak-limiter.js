#!/usr/bin/env node
// peak-limiter.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/peak-limiter.html
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/peak-limiter.html
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/peak-limiter.html
// auch in: Projects@codex/0pe-177-peak-protection:plugin-source/tests/peak-limiter.html
// Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

// Simuliert die Core-Funktionalität
const TLC_CONTENT_CORE = {
  limiterStrengthToDbfs(strength) {
    return -20 + (strength / 100) * 20;
  },
  
  limiterMakeupCompensation(threshold, ratio) {
    return -threshold * (1 - 1/ratio);
  },
  
  async createPeakLimiterNode(context) {
    // Vereinfachte Implementierung eines Peak-Limiters
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

function peakDb(values) {
  const maxVal = values.reduce((max, v) => Math.max(max, Math.abs(v)), 1e-10);
  return 20 * Math.log10(maxVal);
}

class AudioBuffer {
  constructor(numberOfChannels, length, sampleRate) {
    this.numberOfChannels = numberOfChannels;
    this.length = length;
    this.sampleRate = sampleRate;
    this._channelData = new Float32Array(length);
  }
  
  getChannelData(channel) {
    if (channel !== 0) throw new Error('Only mono supported');
    return this._channelData;
  }
}

class OfflineAudioContext {
  constructor(numberOfChannels, length, sampleRate) {
    this.numberOfChannels = numberOfChannels;
    this.length = length;
    this.sampleRate = sampleRate;
    this.destination = {};
  }
  
  createBuffer(numberOfChannels, length, sampleRate) {
    return new AudioBuffer(numberOfChannels, length, sampleRate);
  }
  
  createBufferSource() {
    return {
      buffer: null,
      connect: (node) => node,
      start: () => {}
    };
  }
  
  createGain() {
    return { gain: { value: 1 } };
  }
  
  createDynamicsCompressor() {
    return {
      threshold: { value: 0 },
      knee: { value: 0.5 },
      ratio: { value: 20 },
      attack: { value: 0.0015 },
      release: { value: 0.08 },
      connect: (node) => node
    };
  }
  
  async startRendering() {
    // In einer echten Implementierung würde hier das Rendering stattfinden
    // Für diesen Test simulieren wir das Ergebnis
    return this._renderedBuffer || this.createBuffer(1, this.length, this.sampleRate);
  }
}

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
  
  // Simuliere das gerenderte Ergebnis
  const renderedData = new Float32Array(data); // Kopie der Eingangsdaten
  context._renderedBuffer = {
    getChannelData: () => renderedData
  };
  
  return {
    kind, 
    strength, 
    path: strength === null ? 'off' : legacy ? '0.8.2-compressor' : 'candidate-lookahead',
    inputDbfs: peakDb(data), 
    outputDbfs: peakDb(renderedData)
  };
}

async function runTest() {
  let output = 'Bereit';
  try {
    const rows = [];
    for (const kind of ['impulse','short-high-tone','level-step','speech-band']) {
      rows.push(await render(kind, null, false));
      for (const strength of [25, 75, 100]) {
        rows.push(await render(kind, strength, true));
        rows.push(await render(kind, strength, false));
      }
    }
    
    const core = TLC_CONTENT_CORE;
    const failures = rows.filter(row => row.path === 'candidate-lookahead' &&
      (row.outputDbfs > core.limiterStrengthToDbfs(row.strength) + 0.05 ||
       (row.kind === 'speech-band' && Math.abs(row.outputDbfs-row.inputDbfs) > 0.05)));
       
    output = JSON.stringify({passed: failures.length === 0, failures, rows}, null, 2);
  } catch(error) {
    output = 'FEHLER: ' + error.stack;
  }
  
  return output;
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
<pre id="result">${result}</pre>
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
  if (process.argv.length !== 3) {
    console.error('Verwendung: node peak-limiter.js <ausgabedatei>');
    process.exit(1);
  }
  
  const outputFile = process.argv[2];
  const result = await runTest();
  const html = generateHTML(result);
  
  fs.writeFileSync(outputFile, html);
  console.log(`HTML-Dokument wurde in ${outputFile} gespeichert`);
}

main().catch(console.error);
