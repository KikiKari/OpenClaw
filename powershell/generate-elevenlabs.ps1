#!/usr/bin/env pwsh
# generate-elevenlabs.mjs — portiert nach powershell
# Quelle: javascript, Onboarding@main:scripts/generate-elevenlabs.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$key = $env:ELEVENLABS_API_KEY
$voiceId = if ($env:ELEVENLABS_VOICE_ID) { $env:ELEVENLABS_VOICE_ID } else { "JBFqnCBsd6RMkjVDRZzb" }

if (-not $key) {
    throw "ELEVENLABS_API_KEY fehlt."
}

$text = "Neun Projekte. Zwei Plattformen. Ein Ort, an dem Ideen verbunden und weiterentwickelt werden."

$headers = @{
    "xi-api-key" = $key
    "Content-Type" = "application/json"
}

$body = @{
    text = $text
    model_id = "eleven_multilingual_v2"
    voice_settings = @{
        stability = 0.58
        similarity_boost = 0.72
        style = 0.18
        use_speaker_boost = $true
    }
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri "https://api.elevenlabs.io/v1/text-to-speech/$voiceId?output_format=mp3_44100_128" -Method POST -Headers $headers -Body $body

if ($response.StatusCode -ne 200) {
    throw "ElevenLabs fehlgeschlagen: $($response.StatusCode)"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$publicAudioDir = Join-Path $scriptDir "..\public\audio"
New-Item -ItemType Directory -Path $publicAudioDir -Force | Out-Null

$outputFile = Join-Path $publicAudioDir "project-narration.mp3"
Set-Content -Path $outputFile -Value $response.Content -Encoding Byte

$result = @{
    model = "eleven_multilingual_v2"
    voiceId = $voiceId
    characters = $text.Length
    text = $text
    output = "public/audio/project-narration.mp3"
}

$resultJson = $result | ConvertTo-Json -Depth 10
$mediaProductionDir = Join-Path $scriptDir "..\media-production"
New-Item -ItemType Directory -Path $mediaProductionDir -Force | Out-Null
$resultFile = Join-Path $mediaProductionDir "elevenlabs-result.json"
Set-Content -Path $resultFile -Value $resultJson

Write-Host "ElevenLabs abgeschlossen: $($text.Length) Zeichen."
