#!/usr/bin/env bash
# gemini-ask.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# gemini-ask.sh - CLI tool for Google Gemini API
#
# Usage:
#   ./gemini-ask.sh "Your question here"
#   echo "Your question" | ./gemini-ask.sh
#   ./gemini-ask.sh --file prompt.txt
#   ./gemini-ask.sh --model gemini-pro "Your question"
#
# Environment:
#   GEMINI_API_KEY - Required API key
#   GEMINI_MODEL   - Optional default model (default: gemini-pro)

DEFAULT_MODEL="${GEMINI_MODEL:-gemini-pro}"
MODEL_NAME="$DEFAULT_MODEL"
SYSTEM_PROMPT=""
PROMPT=""

# Function to display usage information
usage() {
  echo "Error: No prompt provided" >&2
  echo "Usage: gemini-ask \"your question\"" >&2
  echo "       gemini-ask --model gemini-pro \"your question\"" >&2
  echo "       echo \"your question\" | gemini-ask" >&2
  exit 1
}

# Parse command line arguments
ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --model|-m)
      MODEL_NAME="$2"
      shift 2
      ;;
    --system|-s)
      SYSTEM_PROMPT="$2"
      shift 2
      ;;
    --file|-f)
      if [[ -z "$2" ]]; then
        echo "Error: No file specified" >&2
        exit 1
      fi
      PROMPT="$(cat "$2")"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

# If no file was provided, check remaining args or stdin
if [[ -z "$PROMPT" ]]; then
  if [[ ${#ARGS[@]} -gt 0 ]]; then
    PROMPT="${ARGS[*]}"
  elif [[ ! -t 0 ]]; then
    # Read from stdin if not connected to terminal
    PROMPT="$(cat)"
  fi
fi

# Validate prompt presence
if [[ -z "${PROMPT// }" ]]; then
  usage
fi

# Check API key
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "Error: GEMINI_API_KEY environment variable is required" >&2
  exit 1
fi

# Prepare request data
REQUEST_DATA="{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"$PROMPT\"}]}],\"generationConfig\":{\"maxOutputTokens\":8192,\"temperature\":0.7,\"topP\":0.95}}"

# Add system prompt if provided
if [[ -n "$SYSTEM_PROMPT" ]]; then
  REQUEST_DATA="{\"systemInstruction\":{\"parts\":[{\"text\":\"$SYSTEM_PROMPT\"}]},\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"$PROMPT\"}]}],\"generationConfig\":{\"maxOutputTokens\":8192,\"temperature\":0.7,\"topP\":0.95}}"
fi

# Make API call
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -d "$REQUEST_DATA" \
  "https://generativelanguage.googleapis.com/v1beta/models/$MODEL_NAME:generateContent")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | head -n -1)

# Check HTTP status code
if [[ "$HTTP_CODE" != "200" ]]; then
  ERROR_MSG=$(echo "$RESPONSE_BODY" | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "HTTP $HTTP_CODE")
  echo "Error: $ERROR_MSG" >&2
  
  if [[ "$ERROR_MSG" == *"API key"* ]]; then
    echo "Make sure GEMINI_API_KEY is set correctly" >&2
  fi
  
  exit 1
fi

# Extract and output the response text
echo "$RESPONSE_BODY" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null || {
  echo "Error: Failed to parse response" >&2
  echo "$RESPONSE_BODY" >&2
  exit 1
}
