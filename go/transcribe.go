// abstraction-provenance: {"artifact_sha256": "3d93106c61c1abccab0e9222280ae34f752b75375f5c8d2845f4be6b81066571", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "go"}
// transcribe.sh — portiert nach go
// Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func usage() {
	fmt.Fprintln(os.Stderr, `Usage:
  transcribe.go <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt "hint"] [--json]`)
	os.Exit(2)
}

func main() {
	if len(os.Args) < 2 {
		usage()
	}

	firstArg := os.Args[1]
	if firstArg == "-h" || firstArg == "--help" {
		usage()
	}

	in := firstArg
	args := os.Args[2:]

	model := "whisper-1"
	out := ""
	language := ""
	prompt := ""
	responseFormat := "text"

	// Parse flags manually to match original behavior
	i := 0
	for i < len(args) {
		arg := args[i]
		switch arg {
		case "--model":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --model")
				os.Exit(2)
			}
			model = args[i+1]
			i += 2
		case "--out":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --out")
				os.Exit(2)
			}
			out = args[i+1]
			i += 2
		case "--language":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --language")
				os.Exit(2)
			}
			language = args[i+1]
			i += 2
		case "--prompt":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --prompt")
				os.Exit(2)
			}
			prompt = args[i+1]
			i += 2
		case "--json":
			responseFormat = "json"
			i++
		default:
			fmt.Fprintf(os.Stderr, "Unknown arg: %s\n", arg)
			usage()
		}
	}

	if _, err := os.Stat(in); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "File not found: %s\n", in)
		os.Exit(1)
	}

	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		fmt.Fprintln(os.Stderr, "Missing OPENAI_API_KEY")
		os.Exit(1)
	}

	if out == "" {
		ext := ".txt"
		if responseFormat == "json" {
			ext = ".json"
		}
		base := strings.TrimSuffix(in, filepath.Ext(in))
		out = base + ext
	}

	// Create output directory
	dir := filepath.Dir(out)
	if err := os.MkdirAll(dir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create directory: %v\n", err)
		os.Exit(1)
	}

	// Build API request
	apiBase := os.Getenv("OPENAI_BASE_URL")
	if apiBase == "" {
		apiBase = "https://api.openai.com/v1"
	}
	apiBase = strings.TrimRight(apiBase, "/")

	url := fmt.Sprintf("%s/audio/transcriptions", apiBase)

	// Create multipart form data
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	// Add file field
	fileWriter, err := writer.CreateFormFile("file", filepath.Base(in))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create form file: %v\n", err)
		os.Exit(1)
	}

	file, err := os.Open(in)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to open file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	_, err = io.Copy(fileWriter, file)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to copy file: %v\n", err)
		os.Exit(1)
	}

	// Add other fields
	writer.WriteField("model", model)
	writer.WriteField("response_format", responseFormat)
	if language != "" {
		writer.WriteField("language", language)
	}
	if prompt != "" {
		writer.WriteField("prompt", prompt)
	}

	writer.Close()

	// Make HTTP request
	req, err := http.NewRequest("POST", url, &body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create request: %v\n", err)
		os.Exit(1)
	}

	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Accept", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "HTTP request failed: %v\n", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	// Write response to file
	outputFile, err := os.Create(out)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create output file: %v\n", err)
		os.Exit(1)
	}
	defer outputFile.Close()

	_, err = io.Copy(outputFile, resp.Body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to write response: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(out)
}
