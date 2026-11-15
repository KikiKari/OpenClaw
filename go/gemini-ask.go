// abstraction-provenance: {"artifact_sha256": "53a38719035668ce08c7bde1a769e6c5f7eec8a54df1f89f81020d205106851d", "source_sha256": "9411ee01f75190a7b3bf9f276fc6bb624d2c943629885c1ddfc9f71a0039070e", "target_language": "go"}
// gemini-ask.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
// auch in: OpenClaw@gateway2:scripts/gemini-ask.js
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"strings"

	"github.com/google/generative-ai-go/genai"
	"google.golang.org/api/option"
)

func main() {
	// Check API key
	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		log.Fatal("Error: GEMINI_API_KEY environment variable is required")
	}

	// Get default model
	defaultModel := os.Getenv("GEMINI_MODEL")
	if defaultModel == "" {
		defaultModel = "gemini-pro"
	}

	// Parse arguments
	var prompt string
	modelName := defaultModel
	args := os.Args[1:]

	// Check for --model flag
	for i, arg := range args {
		if (arg == "--model" || arg == "-m") && i+1 < len(args) {
			modelName = args[i+1]
			// Remove --model and value from args
			copy(args[i:], args[i+2:])
			args = args[:len(args)-2]
			break
		}
	}

	// Check for --system flag
	systemPrompt := ""
	for i, arg := range args {
		if (arg == "--system" || arg == "-s") && i+1 < len(args) {
			systemPrompt = args[i+1]
			// Remove --system and value from args
			copy(args[i:], args[i+2:])
			args = args[:len(args)-2]
			break
		}
	}

	// Check for --file flag
	fileFlagFound := false
	var filePath string
	for i, arg := range args {
		if arg == "--file" || arg == "-f" {
			if i+1 < len(args) {
				filePath = args[i+1]
				fileFlagFound = true
				// Remove --file and path from args
				copy(args[i:], args[i+2:])
				args = args[:len(args)-2]
				break
			} else {
				log.Fatal("Error: No file specified")
			}
		}
	}

	if fileFlagFound {
		content, err := os.ReadFile(filePath)
		if err != nil {
			log.Fatalf("Error reading file: %v", err)
		}
		prompt = string(content)
	} else if len(args) > 0 {
		prompt = strings.Join(args, " ")
	} else {
		// Check if running in a terminal
		stat, _ := os.Stdin.Stat()
		if (stat.Mode() & os.ModeCharDevice) == 0 {
			// Read from stdin
			reader := bufio.NewReader(os.Stdin)
			var buf strings.Builder
			for {
				line, err := reader.ReadString('\n')
				if err != nil && err != io.EOF {
					log.Fatalf("Error reading stdin: %v", err)
				}
				buf.WriteString(line)
				if err == io.EOF {
					break
				}
			}
			prompt = buf.String()
		}
	}

	if strings.TrimSpace(prompt) == "" {
		fmt.Fprintln(os.Stderr, "Error: No prompt provided")
		fmt.Fprintln(os.Stderr, "Usage: gemini-ask \"your question\"")
		fmt.Fprintln(os.Stderr, "       gemini-ask --model gemini-pro \"your question\"")
		fmt.Fprintln(os.Stderr, "       echo \"your question\" | gemini-ask")
		os.Exit(1)
	}

	// Initialize Gemini client
	ctx := context.Background()
	client, err := genai.NewClient(ctx, option.WithAPIKey(apiKey))
	if err != nil {
		log.Fatalf("Error creating client: %v", err)
	}
	defer client.Close()

	// Configure the model
	model := client.GenerativeModel(modelName)
	model.SetTemperature(0.7)
	model.SetTopP(0.95)
	model.SetMaxOutputTokens(8192)

	var resp *genai.GenerateContentResponse

	if systemPrompt != "" {
		// Use chat with system prompt
		session := model.StartChat()
		// Send system prompt
		_, err = session.SendMessage(ctx, genai.Text(systemPrompt))
		if err != nil {
			log.Fatalf("Error sending system prompt: %v", err)
		}
		// Send user prompt
		resp, err = session.SendMessage(ctx, genai.Text(prompt))
		if err != nil {
			log.Fatalf("Error getting response: %v", err)
		}
	} else {
		// Direct generation
		resp, err = model.GenerateContent(ctx, genai.Text(prompt))
		if err != nil {
			log.Fatalf("Error generating content: %v", err)
		}
	}

	// Print the response
	for _, cand := range resp.Candidates {
		if cand.Content != nil {
			for _, part := range cand.Content.Parts {
				fmt.Print(part)
			}
		}
	}
	fmt.Println()
}
