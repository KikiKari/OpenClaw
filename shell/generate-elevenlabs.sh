#!/bin/bash
# generate-elevenlabs.mjs — portiert nach shell
# Quelle: javascript, Onboarding@main:scripts/generate-elevenlabs.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Prüfe ob ELEVENLABS_API_KEY gesetzt ist
if [[ -z "${ELEVENLABS_API_KEY:-}" ]]; then
  echo "ELEVENLABS_API_KEY fehlt." >&2
  exit 1
fi

# Setze Standard-Voice-ID falls nicht gesetzt
: "${ELEVENLABS_VOICE_ID:=JBFqnCBsd6RMkjVDRZzb}"

# Text für die Sprachsynthese
TEXT="Neun Projekte. Zwei Plattformen. Ein Ort, an dem Ideen verbunden und weiterentwickelt werden."

# API-Endpunkt
URL="https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}?output_format=mp3_44100_128"

# JSON-Payload erstellen
read -r -d '' PAYLOAD <<EOF || true
{
  "text": "$TEXT",
  "model_id": "eleven_multilingual_v2",
  "voice_settings": {
    "stability": 0.58,
    "similarity_boost": 0.72,
    "style": 0.18,
    "use_speaker_boost": true
  }
}
EOF

# API-Anfrage senden und Antwort speichern
RESPONSE_FILE=$(mktemp)
HTTP_STATUS=$(curl -s -w "%{http_code}" -X POST "$URL" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  -o "$RESPONSE_FILE")

# Prüfe ob Anfrage erfolgreich war
if [[ "$HTTP_STATUS" -ge 400 ]]; then
  echo "ElevenLabs fehlgeschlagen: $HTTP_STATUS" >&2
  rm -f "$RESPONSE_FILE"
  exit 1
fi

# Zielverzeichnis erstellen
mkdir -p "../public/audio/"

# Audio-Datei speichern
mv "$RESPONSE_FILE" "../public/audio/project-narration.mp3"

# JSON-Resultat erstellen
read -r -d '' RESULT_JSON <<EOF || true
{
  "model": "eleven_multilingual_v2",
  "voiceId": "$ELEVENLABS_VOICE_ID",
  "characters": ${#TEXT},
  "text": "$TEXT",
  "output": "public/audio/project-narration.mp3"
}
EOF

# Resultat als JSON-Datei speichern
echo "$RESULT_JSON" | jq . > "../media-production/elevenlabs-result.json"

# Erfolgsmeldung ausgeben
echo "ElevenLabs abgeschlossen: ${#TEXT} Zeichen."
