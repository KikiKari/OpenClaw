#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "1ee5fe701231b3d271143803d6cdd4a0c1ecb192e8e884d9cf7d418cf9d02e94", "source_sha256": "4ced2ca9b27b1be45a4172c7993a0693b54431a3a2703c30cb796b668ff34bc0", "target_language": "ruby"}
# peak-limiter.html — portiert nach ruby
# Quelle: html, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/tests/peak-limiter.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'json'

def generate_html(output_file)
  html_content = <<~HTML
    <!doctype html>
    <html lang="de">
    <meta charset="utf-8">
    <title>Pegelschutz Audioprüfung</title>
    <style>
    body {
      font: 16px system-ui;
      max-width: 1000px;
      margin: 40px auto;
      padding: 20px;
    }
    
    pre {
      white-space: pre-wrap;
    }
    
    button {
      padding: 12px;
    }
    </style>
    
    <h1>Pegelschutz: synthetischer Web-Audio-Vergleich</h1>
    <p>Offline gerenderte Testsignale. Kein LIVE- oder Hörnachweis.</p>
    
    <button id="run">Audioprüfung starten</button>
    <pre id="result">Bereit</pre>
    
    <script src="../browser-extension/content-core.js"></script>
    <script>
    const core = TLC_CONTENT_CORE;
    
    // Berechnet den Spitzenpegel in dBFS
    const peakDb = values => 20 * Math.log10(values.reduce((max, v) => Math.max(max, Math.abs(v)), 1e-10));
    
    /**
     * Rendert ein Testsignal mit/ohne Begrenzer
     * @param {string} kind - Art des Signals: impulse, short-high-tone, level-step, speech-band
     * @param {number|null} strength - Begrenzer-Stärke 0-100, oder null für ohne
     * @param {boolean} legacy - Ob der alte Compressor verwendet werden soll
     */
    async function render(kind, strength, legacy) {
      const rate = 48000, length = rate;
      const context = new OfflineAudioContext(1, length, rate);
      
      // Erzeuge Testsignal
      const buffer = context.createBuffer(1, length, rate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < length; i++) {
        if (kind === 'speech-band') 
          data[i] = 0.01 * Math.sin(2 * Math.PI * 220 * i / rate);
        else if (kind === 'short-high-tone' && i >= 5000 && i < 5100) 
          data[i] = 0.95 * Math.sin(2 * Math.PI * 8000 * i / rate);
        else if (kind === 'level-step' && i >= 5000 && i < 10000) 
          data[i] = 0.95 * Math.sin(2 * Math.PI * 1000 * i / rate);
      }
      if (kind === 'impulse') data[5000] = 0.95;
      
      // Schalte Signalverarbeitung
      const source = context.createBufferSource();
      source.buffer = buffer;
      
      if (strength === null) {
        // Ohne Begrenzer
        source.connect(context.destination);
      } else if (legacy) {
        // Alter DynamicsCompressor-Begrenzer
        const compressor = context.createDynamicsCompressor();
        const makeup = context.createGain();
        const threshold = core.limiterStrengthToDbfs(strength);
        
        compressor.threshold.value = threshold;
        compressor.knee.value = 0.5;
        compressor.ratio.value = 20;
        compressor.attack.value = 0.0015;
        compressor.release.value = 0.08;
        makeup.gain.value = core.limiterMakeupCompensation(threshold, 20);
        
        source.connect(compressor).connect(makeup).connect(context.destination);
      } else {
        // Neuer PeakLimiter
        const node = await core.createPeakLimiterNode(context);
        node.setProtection({enabled: true, strength});
        source.connect(node).connect(context.destination);
      }
      
      source.start();
      const rendered = await context.startRendering();
      
      return {
        kind,
        strength,
        path: strength === null ? 'off' : legacy ? '0.8.2-compressor' : 'candidate-lookahead',
        inputDbfs: peakDb(data),
        outputDbfs: peakDb(rendered.getChannelData(0))
      };
    }
    
    // Startet die Prüfung bei Button-Klick
    document.getElementById('run').onclick = async () => {
      const output = document.getElementById('result');
      output.textContent = 'Läuft';
      
      try {
        const rows = [];
        
        // Prüfe alle Signalarten
        for (const kind of ['impulse', 'short-high-tone', 'level-step', 'speech-band']) {
          // Referenz ohne Begrenzer
          rows.push(await render(kind, null, false));
          
          // Prüfe verschiedene Stärken
          for (const strength of [25, 75, 100]) {
            rows.push(await render(kind, strength, true));   // Alt
            rows.push(await render(kind, strength, false));  // Neu
          }
        }
        
        // Prüfergebnis: Fehler wenn Ausgang über Ziel oder bei Sprache ungleich Eingang
        const failures = rows.filter(row => 
          row.path === 'candidate-lookahead' &&
          (row.outputDbfs > core.limiterStrengthToDbfs(row.strength) + 0.05 ||
           (row.kind === 'speech-band' && Math.abs(row.outputDbfs - row.inputDbfs) > 0.05))
        );
        
        output.textContent = JSON.stringify({passed: failures.length === 0, failures, rows}, null, 2);
      } catch(error) {
        output.textContent = 'FEHLER: ' + error.stack;
      }
    };
    </script>
    </html>
  HTML

  File.write(output_file, html_content)
  puts "HTML file generated: #{output_file}"
end

if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: #{$0} <output-file>"
    exit 1
  end
  
  generate_html(ARGV[0])
end
