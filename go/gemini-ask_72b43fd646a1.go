// abstraction-provenance: {"artifact_sha256": "a7ad846b844f4635114d8bb94e21e731e3c8aba89ca2ba647e4f161d958c225e", "source_sha256": "9411ee01f75190a7b3bf9f276fc6bb624d2c943629885c1ddfc9f71a0039070e", "target_language": "go"}
// gemini-ask.js — portiert nach go
// Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
// auch in: OpenClaw@gateway2:scripts/gemini-ask.js
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/*
 * gemini-ask.go - CLI tool for Google Gemini API
 *
 * Usage:
 *   go run gemini-ask.go "Your question here"
 *   echo "Your question" | go run gemini-ask.go
 *   go run gemini-ask.go --file prompt.txt
 *   go run gemini-ask.go --model gemini-pro "Your question"
 *
 * Environment:
 *   GEMINI_API_KEY - Required API key
 *   GEMINI_MODEL   - Optional default model (default: gemini-pro)
 */

package main

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"strings"

	"github.com/google/generative-ai-go/genai"
	"google.golang.org/api/option"
)

var DEFAULT_MODEL string

func init() {
	DEFAULT_MODEL = os.Getenv("GEMINI_MODEL")
	if DEFAULT_MODEL == "" {
		DEFAULT_MODEL = "gemini-pro"
	}
}

func main() {
	// Check API key
	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		log.Fatal("Error: GEMINI_API_KEY environment variable is required")
	}

	// Parse arguments
	var prompt string
	modelName := DEFAULT_MODEL
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
		if (arg == "--file" || arg == "-f") && i+1 < len(args) {
			fileFlagFound = true
			filePath = args[i+1]
			// Remove --file and value from args
			copy(args[i:], args[i+2:])
			args = args[:len(args)-2]
			break
		}
	}

	if fileFlagFound {
		if filePath == "" {
			log.Fatal("Error: No file specified")
		}
		content, err := os.ReadFile(filePath)
		if err != nil {
			log.Fatalf("Error reading file: %v", err)
		}
		prompt = string(content)
	} else if len(args) > 0 {
		prompt = strings.Join(args, " ")
	} else if !isatty(os.Stdin.Fd()) {
		// Read from stdin
		var buf bytes.Buffer
		_, err := io.Copy(&buf, os.Stdin)
		if err != nil {
			log.Fatalf("Error reading from stdin: %v", err)
		}
		prompt = buf.String()
	}

	if strings.TrimSpace(prompt) == "" {
		fmt.Fprintln(os.Stderr, "Error: No prompt provided")
		fmt.Fprintln(os.Stderr, `Usage: gemini-ask "your question"`)
		fmt.Fprintln(os.Stderr, `       gemini-ask --model gemini-pro "your question"`)
		fmt.Fprintln(os.Stderr, `       echo "your question" | gemini-ask`)
		os.Exit(1)
	}

	// Initialize Gemini client
	ctx := context.Background()
	client, err := genai.NewClient(ctx, option.WithAPIKey(apiKey))
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}
	defer client.Close()

	// Get model
	model := client.GenerativeModel(modelName)

	// Set generation config
	model.SetTemperature(0.7)
	model.SetTopP(0.95)
	model.SetMaxOutputTokens(8192)

	var response *genai.GenerateContentResponse

	if systemPrompt != "" {
		// Use chat with system prompt
		session := model.StartChat()

		// Send system prompt
		sysResp, err := session.SendMessage(ctx, genai.Text(systemPrompt))
		if err != nil {
			log.Fatalf("Error sending system prompt: %v", err)
		}

		// Add model's acknowledgment to history
		session.History = append(session.History, sysResp.Candidates[0].Content)
		session.History = append(session.History, &genai.Content{
			Parts: []genai.Part{genai.Text("Understood. I will follow that instruction.")},
			Role:  "model",
		})

		// Send user prompt
		response, err = session.SendMessage(ctx, genai.Text(prompt))
		if err != nil {
			log.Fatalf("Error: %v", err)
		}
	} else {
		// Direct generation
		resp, err := model.GenerateContent(ctx, genai.Text(prompt))
		if err != nil {
			log.Fatalf("Error: %v", err)
		}
		response = resp
	}

	// Print response
	printResponse(response)
}

func printResponse(resp *genai.GenerateContentResponse) {
	for _, cand := range resp.Candidates {
		if cand.Content != nil {
			for _, part := range cand.Content.Parts {
				if txt, ok := part.(genai.Text); ok {
					fmt.Print(txt)
				}
			}
		}
	}
	fmt.Println()
}

// isatty checks if a file descriptor refers to a terminal
func isatty(fd uintptr) bool {
	// This is a simplified version; in production you might want to use
	// golang.org/x/term or syscall packages for better detection
	stat, _ := os.Stdin.Stat()
	return (stat.Mode() & os.ModeCharDevice) != 0
}
