// abstraction-provenance: {"artifact_sha256": "c58fb6d29319861ccb3cbb47c7b90df5dbe3662fe539377cb3f05cddb4798500", "source_sha256": "4112b3dbe78c8a495b73f6feaebe05ada553911d2e25f6bd1e2e4d704a6ac1b6", "target_language": "go"}
// generate-elevenlabs.mjs — portiert nach go
// Quelle: javascript, Onboarding@main:scripts/generate-elevenlabs.mjs
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
)

func main() {
	key := os.Getenv("ELEVENLABS_API_KEY")
	voiceId := os.Getenv("ELEVENLABS_VOICE_ID")
	if voiceId == "" {
		voiceId = "JBFqnCBsd6RMkjVDRZzb"
	}
	if key == "" {
		panic("ELEVENLABS_API_KEY fehlt.")
	}

	text := "Neun Projekte. Zwei Plattformen. Ein Ort, an dem Ideen verbunden und weiterentwickelt werden."

	url := fmt.Sprintf("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128", voiceId)

	payload := map[string]interface{}{
		"text":      text,
		"model_id":  "eleven_multilingual_v2",
		"voice_settings": map[string]interface{}{
			"stability":       0.58,
			"similarity_boost": 0.72,
			"style":           0.18,
			"use_speaker_boost": true,
		},
	}

	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		panic(err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonPayload))
	if err != nil {
		panic(err)
	}

	req.Header.Set("xi-api-key", key)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		panic(fmt.Sprintf("ElevenLabs fehlgeschlagen: %d", resp.StatusCode))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}

	// Create directories
	audioDir := filepath.Join("..", "public", "audio")
	err = os.MkdirAll(audioDir, 0755)
	if err != nil {
		panic(err)
	}

	// Write audio file
	audioPath := filepath.Join(audioDir, "project-narration.mp3")
	err = os.WriteFile(audioPath, body, 0644)
	if err != nil {
		panic(err)
	}

	// Write result info
	result := map[string]interface{}{
		"model":      "eleven_multilingual_v2",
		"voiceId":    voiceId,
		"characters": len(text),
		"text":       text,
		"output":     "public/audio/project-narration.mp3",
	}

	resultJSON, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		panic(err)
	}

	mediaProductionDir := filepath.Join("..", "media-production")
	err = os.MkdirAll(mediaProductionDir, 0755)
	if err != nil {
		panic(err)
	}

	resultPath := filepath.Join(mediaProductionDir, "elevenlabs-result.json")
	err = os.WriteFile(resultPath, resultJSON, 0644)
	if err != nil {
		panic(err)
	}

	fmt.Printf("ElevenLabs abgeschlossen: %d Zeichen.\n", len(text))
}
