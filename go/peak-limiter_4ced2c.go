// abstraction-provenance: {"artifact_sha256": "c5c1429487b07ec0bb9baf408c99ce5d0ae8e4fe1bf94c84de929b7e26eba697", "source_sha256": "4ced2ca9b27b1be45a4172c7993a0693b54431a3a2703c30cb796b668ff34bc0", "target_language": "go"}
// peak-limiter.html — portiert nach go
// Quelle: html, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/tests/peak-limiter.html
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
)

// HTMLDocument represents the structure of our HTML document
type HTMLDocument struct {
	Title       string
	Style       string
	Heading     string
	Description string
	ButtonID    string
	ButtonLabel string
	ResultID    string
	ScriptSrc   string
	Script      string
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <output-file>\n", filepath.Base(os.Args[0]))
		os.Exit(1)
	}

	filename := os.Args[1]
	
	doc := HTMLDocument{
		Title:       "Pegelschutz Audioprüfung",
		Style:       "body{font:16px system-ui;max-width:1000px;margin:40px auto;padding:20px}pre{white-space:pre-wrap}button{padding:12px}",
		Heading:     "Pegelschutz: synthetischer Web-Audio-Vergleich",
		Description: "Offline gerenderte Testsignale. Kein LIVE- oder Hörnachweis.",
		ButtonID:    "run",
		ButtonLabel: "Audioprüfung starten",
		ResultID:    "result",
		ScriptSrc:   "../browser-extension/content-core.js",
		Script: `const core = TLC_CONTENT_CORE;
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
};`,
	}

	htmlContent := generateHTML(doc)
	
	err := os.WriteFile(filename, []byte(htmlContent), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file: %v\n", err)
		os.Exit(1)
	}
}

func generateHTML(doc HTMLDocument) string {
	return fmt.Sprintf(`<!doctype html>
<html lang="de"><meta charset="utf-8"><title>%s</title>
<style>%s</style>
<h1>%s</h1>
<p>%s</p>
<button id="%s">%s</button><pre id="%s">Bereit</pre>
<script src="%s"></script>
<script>%s</script></html>`,
		doc.Title,
		doc.Style,
		doc.Heading,
		doc.Description,
		doc.ButtonID,
		doc.ButtonLabel,
		doc.ResultID,
		doc.ScriptSrc,
		doc.Script)
}
