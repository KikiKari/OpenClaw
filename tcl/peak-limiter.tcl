#!/usr/bin/env tclsh
# peak-limiter.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/peak-limiter.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/peak-limiter.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/peak-limiter.html
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/tests/peak-limiter.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Tcl/Tk port of peak-limiter.html - synthetic audio limiter comparison test
# This script generates the HTML content and can optionally save it to a file

proc generate_html {} {
    set html {}
    
    # Add DOCTYPE and opening html tag
    append html "<!doctype html>\n"
    append html "<html lang=\"de\"><meta charset=\"utf-8\"><title>Pegelschutz Audioprüfung</title>\n"
    
    # Add CSS styles
    append html "<style>body{font:16px system-ui;max-width:1000px;margin:40px auto;padding:20px}pre{white-space:pre-wrap}button{padding:12px}</style>\n"
    
    # Add content
    append html "<h1>Pegelschutz: synthetischer Web-Audio-Vergleich</h1>\n"
    append html "<p>Offline gerenderte Testsignale. Kein LIVE- oder Hörnachweis.</p>\n"
    append html "<button id=\"run\">Audioprüfung starten</button><pre id=\"result\">Bereit</pre>\n"
    
    # Add script dependencies
    append html "<script src=\"../browser-extension/content-core.js\"></script>\n"
    append html "<script>\n"
    
    # Add JavaScript code
    append html "const core = TLC_CONTENT_CORE;\n"
    append html "const peakDb = values => 20 * Math.log10(values.reduce((max, v) => Math.max(max, Math.abs(v)), 1e-10));\n"
    append html "async function render(kind, strength, legacy) {\n"
    append html "  const rate = 48000, length = rate;\n"
    append html "  const context = new OfflineAudioContext(1, length, rate);\n"
    append html "  const buffer = context.createBuffer(1, length, rate);\n"
    append html "  const data = buffer.getChannelData(0);\n"
    append html "  for (let i = 0; i < length; i++) {\n"
    append html "    if (kind === 'speech-band') data[i] = 0.01 * Math.sin(2 * Math.PI * 220 * i / rate);\n"
    append html "    else if (kind === 'short-high-tone' && i >= 5000 && i < 5100) data[i] = 0.95 * Math.sin(2 * Math.PI * 8000 * i / rate);\n"
    append html "    else if (kind === 'level-step' && i >= 5000 && i < 10000) data[i] = 0.95 * Math.sin(2 * Math.PI * 1000 * i / rate);\n"
    append html "  }\n"
    append html "  if (kind === 'impulse') data[5000] = 0.95;\n"
    append html "  const source = context.createBufferSource(); source.buffer = buffer;\n"
    append html "  if (strength === null) source.connect(context.destination);\n"
    append html "  else if (legacy) {\n"
    append html "    const compressor = context.createDynamicsCompressor(), makeup = context.createGain();\n"
    append html "    const threshold = core.limiterStrengthToDbfs(strength);\n"
    append html "    compressor.threshold.value = threshold; compressor.knee.value = 0.5;\n"
    append html "    compressor.ratio.value = 20; compressor.attack.value = 0.0015; compressor.release.value = 0.08;\n"
    append html "    makeup.gain.value = core.limiterMakeupCompensation(threshold, 20);\n"
    append html "    source.connect(compressor).connect(makeup).connect(context.destination);\n"
    append html "  } else {\n"
    append html "    const node = await core.createPeakLimiterNode(context);\n"
    append html "    node.setProtection({enabled:true, strength});\n"
    append html "    source.connect(node).connect(context.destination);\n"
    append html "  }\n"
    append html "  source.start();\n"
    append html "  const rendered = await context.startRendering();\n"
    append html "  return {kind, strength, path: strength === null ? 'off' : legacy ? '0.8.2-compressor' : 'candidate-lookahead',\n"
    append html "    inputDbfs: peakDb(data), outputDbfs: peakDb(rendered.getChannelData(0))};\n"
    append html "}\n"
    append html "document.getElementById('run').onclick = async () => {\n"
    append html "  const output = document.getElementById('result'); output.textContent = 'Läuft';\n"
    append html "  try {\n"
    append html "    const rows = [];\n"
    append html "    for (const kind of ['impulse','short-high-tone','level-step','speech-band']) {\n"
    append html "      rows.push(await render(kind, null, false));\n"
    append html "      for (const strength of [25,75,100]) {\n"
    append html "        rows.push(await render(kind, strength, true));\n"
    append html "        rows.push(await render(kind, strength, false));\n"
    append html "      }\n"
    append html "    }\n"
    append html "    const failures = rows.filter(row => row.path === 'candidate-lookahead' &&\n"
    append html "      (row.outputDbfs > core.limiterStrengthToDbfs(row.strength) + 0.05 ||\n"
    append html "       (row.kind === 'speech-band' && Math.abs(row.outputDbfs-row.inputDbfs) > 0.05)));\n"
    append html "    output.textContent = JSON.stringify({passed: failures.length === 0, failures, rows}, null, 2);\n"
    append html "  } catch(error) { output.textContent = 'FEHLER: ' + error.stack; }\n"
    append html "};\n"
    append html "</script></html>\n"
    
    return $html
}

# Main execution
if {$argc > 0} {
    set filename [lindex $argv 0]
    set html_content [generate_html]
    set fh [open $filename w]
    puts -nonewline $fh $html_content
    close $fh
    puts "HTML content written to $filename"
} else {
    # Output to stdout if no parameter given
    puts [generate_html]
}
