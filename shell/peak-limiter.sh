#!/bin/bash
# peak-limiter.html — portiert nach shell
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/tests/peak-limiter.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/tests/peak-limiter.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/tests/peak-limiter.html
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/tests/peak-limiter.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Ziel: Erzeuge HTML-Datei analog zu peak-limiter.html
# Diese Bash-Version simuliert das Rendering und gibt strukturierte Ergebnisse aus,
# anstatt echte Web-Audio-API-Funktionen auszuführen.

# Funktion zur Berechnung des Pegels in dBFS
peak_db() {
  local max_val=1e-10
  for val in "$@"; do
    local abs_val
    abs_val=$(echo "scale=10; if ($val < 0) -($val) else $val" | bc -l)
    if (( $(echo "$abs_val > $max_val" | bc -l) )); then
      max_val="$abs_val"
    fi
  done
  echo "l( $max_val ) / l( 10 )" | bc -l | awk '{print 20 * $1}'
}

# Dummy-Datenrendering basierend auf Art des Signals
render_signal() {
  local kind="$1"
  local length=48000
  local data=()

  # Initialisiere Array mit Nullen
  for ((i=0; i<length; i++)); do
    data[i]=0
  done

  case "$kind" in
    speech-band)
      for ((i=0; i<length; i++)); do
        data[i]=$(echo "0.01 * s(2 * 3.141592653589793 * 220 * $i / 48000)" | bc -l)
      done
      ;;
    short-high-tone)
      for ((i=5000; i<5100; i++)); do
        data[i]=$(echo "0.95 * s(2 * 3.141592653589793 * 8000 * $i / 48000)" | bc -l)
      done
      ;;
    level-step)
      for ((i=5000; i<10000; i++)); do
        data[i]=$(echo "0.95 * s(2 * 3.141592653589793 * 1000 * $i / 48000)" | bc -l)
      done
      ;;
    impulse)
      data[5000]="0.95"
      ;;
  esac

  echo "${data[@]}"
}

# Limiter-Stärke in dBFS umrechnen
limiter_strength_to_dbfs() {
  local strength=$1
  echo "scale=10; 0 - ( ( 100 - $strength ) * 60 / 100 )" | bc -l
}

# Makeup-Kompensation berechnen
limiter_makeup_compensation() {
  local threshold=$1
  local ratio=20
  echo "scale=10; -($threshold) * (1 - 1/$ratio)" | bc -l
}

# Peak-Limiter-Simulation
create_peak_limiter_node() {
  # In echter Implementierung würde hier ein Lookahead-Limiter erstellt
  echo '{"type":"PeakLimiterNode","lookahead":true}'
}

# Hauptfunktion zur Simulation des Renderings
run_audio_test() {
  local results=()
  local kinds=("impulse" "short-high-tone" "level-step" "speech-band")
  local strengths=(25 75 100)

  echo "Starte Audioprüfung..."

  for kind in "${kinds[@]}"; do
    echo "Verarbeite Signalart: $kind"

    # Ohne Begrenzer
    signal_data=$(render_signal "$kind")
    read -ra signal_array <<< "$signal_data"
    input_dbfs=$(peak_db "${signal_array[@]}")

    results+=("{\"kind\":\"$kind\",\"strength\":null,\"path\":\"off\",\"inputDbfs\":$input_dbfs}")

    for strength in "${strengths[@]}"; do
      # Legacy Compressor
      threshold=$(limiter_strength_to_dbfs "$strength")
      makeup_gain=$(limiter_makeup_compensation "$threshold")
      # Simuliere Kompression durch Clipping bei threshold + makeup
      clipped_data=()
      for val in "${signal_array[@]}"; do
        processed=$(echo "scale=10; $val * e($makeup_gain/20*l(10))" | bc -l)
        limit=$(echo "scale=10; 10^($threshold/20)" | bc -l)
        if (( $(echo "$processed > $limit" | bc -l) )); then
          clipped_data+=("$limit")
        elif (( $(echo "$processed < -$limit" | bc -l) )); then
          clipped_data+=("-$limit")
        else
          clipped_data+=("$processed")
        fi
      done
      output_dbfs=$(peak_db "${clipped_data[@]}")
      results+=("{\"kind\":\"$kind\",\"strength\":$strength,\"path\":\"0.8.2-compressor\",\"inputDbfs\":$input_dbfs,\"outputDbfs\":$output_dbfs}")

      # Neuer Peak-Limiter (simuliert)
      # Angenommen, dieser hat bessere Steuerung und geringere Verzerrung
      limited_data=()
      for val in "${signal_array[@]}"; do
        # Vereinfachte Annahme: guter Limiter hält alles unterhalb des Limits
        limit=$(echo "scale=10; 10^($threshold/20)" | bc -l)
        if (( $(echo "$val > $limit" | bc -l) )); then
          limited_data+=("$limit")
        elif (( $(echo "$val < -$limit" | bc -l) )); then
          limited_data+=("-$limit")
        else
          limited_data+=("$val")
        fi
      done
      output_dbfs=$(peak_db "${limited_data[@]}")
      results+=("{\"kind\":\"$kind\",\"strength\":$strength,\"path\":\"candidate-lookahead\",\"inputDbfs\":$input_dbfs,\"outputDbfs\":$output_dbfs}")
    done
  done

  # Prüfe auf Fehler (Überschreitung des Limits oder unerwartete Änderungen bei speech-band)
  failures=()
  for result in "${results[@]}"; do
    if [[ $(echo "$result" | jq -r '.path') == "candidate-lookahead" ]]; then
      output_dbfs=$(echo "$result" | jq -r '.outputDbfs')
      strength=$(echo "$result" | jq -r '.strength')
      kind=$(echo "$result" | jq -r '.kind')
      input_dbfs=$(echo "$result" | jq -r '.inputDbfs')
      limit_dbfs=$(limiter_strength_to_dbfs "$strength")
      if (( $(echo "$output_dbfs > $limit_dbfs + 0.05" | bc -l) )) || \
         { [[ "$kind" == "speech-band" ]] && (( $(echo "sqrt(($output_dbfs - $input_dbfs)^2) > 0.05" | bc -l) )); }; then
        failures+=("$result")
      fi
    fi
  done

  passed="true"
  if [[ ${#failures[@]} -gt 0 ]]; then
    passed="false"
  fi

  # Erstelle JSON-Ausgabe
  printf '{\n  "passed": %s,\n  "failures": [\n' "$passed"
  for failure in "${failures[@]}"; do
    printf '    %s,\n' "$failure"
  done | sed '$ s/,$//'
  printf '  ],\n  "rows": [\n'
  for result in "${results[@]}"; do
    printf '    %s,\n' "$result"
  done | sed '$ s/,$//'
  printf '  ]\n}\n'
}

# Generiere HTML-Datei mit eingebettetem Skript
generate_html() {
  cat << 'EOF'
<!doctype html>
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
</script></html>
EOF
}

# Hauptprogramm
main() {
  if [[ $# -eq 0 ]]; then
    generate_html
  elif [[ $# -eq 1 ]]; then
    generate_html > "$1"
    echo "HTML-Datei wurde in $1 gespeichert."
  else
    echo "Aufruf: $0 [ausgabedatei]" >&2
    exit 1
  fi
}

main "$@"
