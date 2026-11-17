#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "30506d01bb48b0907bc1b3cb1a0e5897dc8ee3233a9b2b216540ac1f5abfd3be", "source_sha256": "9411ee01f75190a7b3bf9f276fc6bb624d2c943629885c1ddfc9f71a0039070e", "target_language": "shell"}
# gemini-ask.js — portiert nach shell
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Default model name
DEFAULT_MODEL="${GEMINI_MODEL:-gemini-pro}"

# Function to display usage information
usage() {
  cat >&2 <<EOF
Usage: gemini-ask "your question"
       gemini-ask --model gemini-pro "your question"
       echo "your question" | gemini-ask
EOF
}

# Function to display an error message and exit
die() {
  echo "Error: $*" >&2
  usage
  exit 1
}

# Check for required API key
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  die "GEMINI_API_KEY environment variable is required"
fi

# Initialize variables
prompt=""
modelName="$DEFAULT_MODEL"
systemPrompt=""

# Parse command-line arguments
args=()
while (( $# )); do
  case "$1" in
    --model|-m)
      if [[ -n "${2:-}" ]]; then
        modelName="$2"
        shift 2
      else
        die "No model specified"
      fi
      ;;
    --system|-s)
      if [[ -n "${2:-}" ]]; then
        systemPrompt="$2"
        shift 2
      else
        die "No system prompt specified"
      fi
      ;;
    --file|-f)
      if [[ -n "${2:-}" ]]; then
        if [[ -r "$2" ]]; then
          prompt=$(cat "$2")
          shift 2
        else
          die "File '$2' not found or not readable"
        fi
      else
        die "No file specified"
      fi
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

# If no prompt was provided via --file, check remaining args or stdin
if [[ -z "$prompt" ]]; then
  if (( ${#args[@]} > 0 )); then
    prompt="${args[*]}"
  elif [[ ! -t 0 ]]; then
    # Read from stdin if available
    prompt=$(cat)
  else
    die "No prompt provided"
  fi
fi

# Trim leading/trailing whitespace
prompt=$(echo "$prompt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
if [[ -z "$prompt" ]]; then
  die "No prompt provided"
fi

# Prepare JSON payload for the API request
json_payload() {
  local content="$1"
  local model="$2"
  local system_prompt="$3"
  
  if [[ -n "$system_prompt" ]]; then
    cat <<EOF
{
  "contents": [
    {
      "role": "user",
      "parts": [{"text": "$system_prompt"}]
    },
    {
      "role": "model",
      "parts": [{"text": "Understood. I will follow that instruction."}]
    },
    {
      "role": "user",
      "parts": [{"text": "$content"}]
    }
  ],
  "generationConfig": {
    "maxOutputTokens": 8192,
    "temperature": 0.7,
    "topP": 0.95
  }
}
EOF
  else
    cat <<EOF
{
  "contents": [
    {
      "role": "user",
      "parts": [{"text": "$content"}]
    }
  ],
  "generationConfig": {
    "maxOutputTokens": 8192,
    "temperature": 0.7,
    "topP": 0.95
  }
}
EOF
  fi
}

# Generate the JSON data
data=$(json_payload "$prompt" "$modelName" "$systemPrompt")

# Make the API call using curl
response=$(curl -sS -w "\n%{http_code}" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -d "$data" \
  "https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent")

# Extract HTTP status code and response body
http_status=$(echo "$response" | tail -n1)
api_response=$(echo "$response" | head -n -1)

# Check for successful response
if [[ "$http_status" == "200" ]]; then
  # Extract and print the generated text
  echo "$api_response" | jq -r '.candidates[0].content.parts[0].text'
else
  # Handle errors
  error_msg=$(echo "$api_response" | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "Failed to parse error response")
  echo "Error: $error_msg" >&2
  if [[ "$error_msg" == *"API key"* ]]; then
    echo "Make sure GEMINI_API_KEY is set correctly" >&2
  fi
  exit 1
fi
