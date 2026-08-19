#!/bin/bash
# generate-wavespeed.mjs — portiert nach shell
# Quelle: javascript, Onboarding@main:scripts/generate-wavespeed.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Prüfe ob WAVESPEED_API_KEY gesetzt ist
if [[ -z "${WAVESPEED_API_KEY:-}" ]]; then
  echo "Fehler: WAVESPEED_API_KEY fehlt." >&2
  exit 1
fi

# Pfade definieren
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "$script_dir")"
jobs_file="$repo_root/media-production/wavespeed-jobs.json"
raw_dir="$repo_root/media-production/raw"
public_dir="$repo_root/public/media"
results_file="$repo_root/media-production/wavespeed-results.json"

# Verzeichnisse erstellen
mkdir -p "$raw_dir"
mkdir -p "$public_dir"

# Logdatei initialisieren
if [[ ! -f "$results_file" ]]; then
  echo "[]" > "$results_file"
fi

# Funktion zum Lesen von JSON-Werten mit jq
get_json_value() {
  local json_file="$1"
  local query="$2"
  jq -r "$query" "$json_file"
}

# Anzahl der Jobs ermitteln
jobs_count=$(jq -r 'length' "$jobs_file")

# Für jeden Job iterieren
for (( i=0; i<jobs_count; i++ )); do
  job_id=$(jq -r ".[$i].id" "$jobs_file")
  job_output=$(jq -r ".[$i].output" "$jobs_file")
  raw_path="$raw_dir/$job_id.png"
  target_path="$public_dir/$job_output.png"

  # Prüfen ob Bild bereits generiert wurde
  if [[ -f "$raw_path" ]]; then
    # Prüfen ob Eintrag im Log existiert
    if ! jq -e --arg id "$job_id" '.[] | select(.id == $id)' "$results_file" >/dev/null; then
      # Neuen Eintrag hinzufügen
      jq --arg id "$job_id" \
         --arg output "$job_output.png" \
         '. + [{id: $id, requestId: "completed-before-resume", model: "google/nano-banana-2/edit", resolution: "4k", plannedCostUsd: 0.14, output: $output}]' \
         "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
    fi
    echo "Übersprungen: $job_id ist bereits vorhanden."
    continue
  fi

  # Bilder sammeln
  images_count=$(jq -r ".[$i].images | length" "$jobs_file")
  images_json="["
  
  for (( j=0; j<images_count; j++ )); do
    image_url=$(jq -r ".[$i].images[$j]" "$jobs_file")
    
    # Wenn es eine lokale Datei ist, in base64 konvertieren
    if [[ ! "$image_url" =~ ^https?:// ]] && [[ ! "$image_url" =~ ^data: ]]; then
      image_path="$repo_root/$image_url"
      if [[ ! -f "$image_path" ]]; then
        echo "Fehler: Bilddatei nicht gefunden: $image_path" >&2
        exit 1
      fi
      base64_data=$(base64 -i "$image_path" | tr -d '\n')
      image_url="data:image/png;base64,$base64_data"
    fi
    
    images_json+="\"$image_url\""
    if (( j < images_count - 1 )); then
      images_json+=","
    fi
  done
  
  images_json+="]"
  
  # Prompt und Aspect Ratio lesen
  prompt=$(jq -r ".[$i].prompt" "$jobs_file")
  aspect_ratio=$(jq -r ".[$i].aspectRatio" "$jobs_file")
  
  # Request Body erstellen
  request_body=$(jq -n \
    --arg prompt "$prompt" \
    --argjson images "$images_json" \
    --arg aspect_ratio "$aspect_ratio" \
    '{
      prompt: $prompt,
      images: $images,
      aspect_ratio: $aspect_ratio,
      resolution: "4k",
      output_format: "png",
      enable_web_search: false,
      enable_image_search: false,
      enable_sync_mode: false,
      enable_base64_output: false
    }')

  # API-Aufruf senden
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $WAVESPEED_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$request_body" \
    "https://api.wavespeed.ai/api/v3/google/nano-banana-2/edit")
  
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | head -n -1)
  
  if [[ "$http_code" != "2"* ]]; then
    echo "WaveSpeed submit fehlgeschlagen: $http_code $response_body" >&2
    exit 1
  fi
  
  # Request ID extrahieren
  request_id=$(echo "$response_body" | jq -r '.data.id // .id')
  
  # Polling für Ergebnis
  result=""
  for (( attempt=0; attempt<90; attempt++ )); do
    sleep 4
    
    poll_response=$(curl -s -H "Authorization: Bearer $WAVESPEED_API_KEY" \
      "https://api.wavespeed.ai/api/v3/predictions/$request_id/result")
    
    status=$(echo "$poll_response" | jq -r '.data.status')
    
    if [[ "$status" == "completed" ]]; then
      result="$poll_response"
      break
    elif [[ "$status" == "failed" ]]; then
      echo "WaveSpeed job fehlgeschlagen: $job_id" >&2
      exit 1
    fi
  done
  
  if [[ -z "$result" ]]; then
    echo "Zeitüberschreitung beim Warten auf Ergebnis für Job: $job_id" >&2
    exit 1
  fi
  
  # Bild-URL extrahieren
  image_url=$(echo "$result" | jq -r '.data.outputs[0]')
  
  if [[ -z "$image_url" ]] || [[ "$image_url" == "null" ]]; then
    echo "Kein Output für $job_id" >&2
    exit 1
  fi
  
  # Bild herunterladen
  curl -s "$image_url" -o "$raw_path"
  cp "$raw_path" "$target_path"
  
  # Logeintrag hinzufügen
  jq --arg id "$job_id" \
     --arg requestId "$request_id" \
     --arg output "$job_output.png" \
     '. + [{id: $id, requestId: $requestId, model: "google/nano-banana-2/edit", resolution: "4k", plannedCostUsd: 0.14, output: $output}]' \
     "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
  
  echo "Abgeschlossen: $job_id"
done

# Zusammenfassung ausgeben
log_length=$(jq -r 'length' "$results_file")
cost=$(echo "$log_length * 0.14" | bc -l)
printf "WaveSpeed abgeschlossen: %d Assets, geplante Basiskosten \$%.2f.\n" "$log_length" "$cost"
