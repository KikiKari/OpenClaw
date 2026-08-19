#!/usr/bin/env python3
# generate-elevenlabs.mjs — portiert nach python
# Quelle: javascript, Onboarding@main:scripts/generate-elevenlabs.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import os
import json
import requests
from pathlib import Path

key = os.environ.get("ELEVENLABS_API_KEY")
voiceId = os.environ.get("ELEVENLABS_VOICE_ID") or "JBFqnCBsd6RMkjVDRZzb"
if not key:
    raise Exception("ELEVENLABS_API_KEY fehlt.")

text = "Neun Projekte. Zwei Plattformen. Ein Ort, an dem Ideen verbunden und weiterentwickelt werden."
response = requests.post(
    f"https://api.elevenlabs.io/v1/text-to-speech/{voiceId}?output_format=mp3_44100_128",
    headers={"xi-api-key": key, "Content-Type": "application/json"},
    json={
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {
            "stability": 0.58,
            "similarity_boost": 0.72,
            "style": 0.18,
            "use_speaker_boost": True
        }
    }
)

if not response.ok:
    raise Exception(f"ElevenLabs fehlgeschlagen: {response.status_code}")

# Create directories and write files
audio_dir = Path(__file__).parent.parent / "public" / "audio"
audio_dir.mkdir(parents=True, exist_ok=True)

audio_file = audio_dir / "project-narration.mp3"
with open(audio_file, "wb") as f:
    f.write(response.content)

result_file = Path(__file__).parent.parent / "media-production" / "elevenlabs-result.json"
result_data = {
    "model": "eleven_multilingual_v2",
    "voiceId": voiceId,
    "characters": len(text),
    "text": text,
    "output": "public/audio/project-narration.mp3"
}

with open(result_file, "w", encoding="utf-8") as f:
    json.dump(result_data, f, indent=2, ensure_ascii=False)

print(f"ElevenLabs abgeschlossen: {len(text)} Zeichen.")
