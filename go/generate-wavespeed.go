// abstraction-provenance: {"artifact_sha256": "26216a5af11a4b8a84dd70204ad072f8d28e1b806cf7f1e7e7d73e0c24b4d823", "source_sha256": "3fed8b6be2b9b8639b55bcaf18c09c0395ac005ab02c27f2dff26ca20b5d5825", "target_language": "go"}
// generate-wavespeed.mjs — portiert nach go
// Quelle: javascript, Onboarding@main:scripts/generate-wavespeed.mjs
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type Job struct {
	ID           string   `json:"id"`
	Output       string   `json:"output"`
	Prompt       string   `json:"prompt"`
	Images       []string `json:"images"`
	AspectRatio  string   `json:"aspectRatio"`
}

type LogEntry struct {
	ID            string  `json:"id"`
	RequestID     string  `json:"requestId"`
	Model         string  `json:"model"`
	Resolution    string  `json:"resolution"`
	PlannedCostUsd float64 `json:"plannedCostUsd"`
	Output        string  `json:"output"`
}

type SubmitResponse struct {
	Data struct {
		ID string `json:"id"`
	} `json:"data"`
	ID string `json:"id"`
}

type ResultResponse struct {
	Data struct {
		Status  string   `json:"status"`
		Outputs []string `json:"outputs"`
	} `json:"data"`
}

func main() {
	key := os.Getenv("WAVESPEED_API_KEY")
	if key == "" {
		panic("WAVESPEED_API_KEY fehlt.")
	}

	// Get current directory
	currentDir, err := os.Getwd()
	if err != nil {
		panic(err)
	}
	
	// Define paths relative to current directory
	jobsFile := filepath.Join(currentDir, "..", "media-production", "wavespeed-jobs.json")
	rawDir := filepath.Join(currentDir, "..", "media-production", "raw")
	publicDir := filepath.Join(currentDir, "..", "public", "media")
	resultUrl := filepath.Join(currentDir, "..", "media-production", "wavespeed-results.json")

	// Create directories
	os.MkdirAll(rawDir, 0755)
	os.MkdirAll(publicDir, 0755)

	// Read jobs file
	jobsData, err := os.ReadFile(jobsFile)
	if err != nil {
		panic(err)
	}

	var jobs []Job
	err = json.Unmarshal(jobsData, &jobs)
	if err != nil {
		panic(err)
	}

	// Read or create log
	log := make([]LogEntry, 0)
	logData, err := os.ReadFile(resultUrl)
	if err == nil {
		json.Unmarshal(logData, &log)
	}

	client := &http.Client{}

	for _, job := range jobs {
		rawPath := filepath.Join(rawDir, job.ID+".png")
		targetPath := filepath.Join(publicDir, job.Output+".png")

		// Check if file already exists
		if _, err := os.Stat(rawPath); err == nil {
			found := false
			for _, entry := range log {
				if entry.ID == job.ID {
					found = true
					break
				}
			}
			if !found {
				log = append(log, LogEntry{
					ID:            job.ID,
					RequestID:     "completed-before-resume",
					Model:         "google/nano-banana-2/edit",
					Resolution:    "4k",
					PlannedCostUsd: 0.14,
					Output:        filepath.Base(targetPath),
				})
				
				logData, _ := json.MarshalIndent(log, "", "  ")
				os.WriteFile(resultUrl, logData, 0644)
			}
			fmt.Printf("Übersprungen: %s ist bereits vorhanden.\n", job.ID)
			continue
		}

		// Process images
		images := make([]string, len(job.Images))
		for i, image := range job.Images {
			if strings.HasPrefix(image, "http:") || strings.HasPrefix(image, "https:") || strings.HasPrefix(image, "data:") {
				images[i] = image
			} else {
				imagePath := filepath.Join(currentDir, "..", image)
				bytes, err := os.ReadFile(imagePath)
				if err != nil {
					panic(err)
				}
				images[i] = "data:image/png;base64," + base64.StdEncoding.EncodeToString(bytes)
			}
		}

		// Submit job
		submitData := map[string]interface{}{
			"prompt":              job.Prompt,
			"images":              images,
			"aspect_ratio":        job.AspectRatio,
			"resolution":          "4k",
			"output_format":       "png",
			"enable_web_search":   false,
			"enable_image_search": false,
			"enable_sync_mode":    false,
			"enable_base64_output": false,
		}

		submitBytes, _ := json.Marshal(submitData)
		req, _ := http.NewRequest("POST", "https://api.wavespeed.ai/api/v3/google/nano-banana-2/edit", strings.NewReader(string(submitBytes)))
		req.Header.Set("Authorization", "Bearer "+key)
		req.Header.Set("Content-Type", "application/json")

		resp, err := client.Do(req)
		if err != nil {
			panic(fmt.Sprintf("WaveSpeed submit fehlgeschlagen: %v", err))
		}

		if resp.StatusCode != 200 {
			body, _ := io.ReadAll(resp.Body)
			panic(fmt.Sprintf("WaveSpeed submit fehlgeschlagen: %d %s", resp.StatusCode, string(body)))
		}

		var submitted SubmitResponse
		json.NewDecoder(resp.Body).Decode(&submitted)
		resp.Body.Close()

		requestId := submitted.Data.ID
		if requestId == "" {
			requestId = submitted.ID
		}

		var result ResultResponse
		success := false
		for attempt := 0; attempt < 90; attempt++ {
			time.Sleep(4000 * time.Millisecond)
			
			pollReq, _ := http.NewRequest("GET", "https://api.wavespeed.ai/api/v3/predictions/"+requestId+"/result", nil)
			pollReq.Header.Set("Authorization", "Bearer "+key)
			
			pollResp, err := client.Do(pollReq)
			if err != nil {
				continue
			}
			
			json.NewDecoder(pollResp.Body).Decode(&result)
			pollResp.Body.Close()
			
			if result.Data.Status == "completed" {
				success = true
				break
			}
			if result.Data.Status == "failed" {
				panic(fmt.Sprintf("WaveSpeed job fehlgeschlagen: %s", job.ID))
			}
		}

		if !success {
			panic(fmt.Sprintf("WaveSpeed job nicht abgeschlossen: %s", job.ID))
		}

		if len(result.Data.Outputs) == 0 {
			panic(fmt.Sprintf("Kein Output für %s", job.ID))
		}

		url := result.Data.Outputs[0]
		
		// Download image
		imageResp, err := http.Get(url)
		if err != nil {
			panic(err)
		}
		defer imageResp.Body.Close()
		
		bytes, err := io.ReadAll(imageResp.Body)
		if err != nil {
			panic(err)
		}

		// Save files
		os.WriteFile(rawPath, bytes, 0644)
		os.WriteFile(targetPath, bytes, 0644)

		log = append(log, LogEntry{
			ID:            job.ID,
			RequestID:     requestId,
			Model:         "google/nano-banana-2/edit",
			Resolution:    "4k",
			PlannedCostUsd: 0.14,
			Output:        filepath.Base(targetPath),
		})

		logData, _ := json.MarshalIndent(log, "", "  ")
		os.WriteFile(resultUrl, logData, 0644)
		
		fmt.Printf("Abgeschlossen: %s\n", job.ID)
	}

	logData, _ := json.MarshalIndent(log, "", "  ")
	os.WriteFile(resultUrl, logData, 0644)
	
	fmt.Printf("WaveSpeed abgeschlossen: %d Assets, geplante Basiskosten $%.2f.\n", len(log), float64(len(log))*0.14)
}
