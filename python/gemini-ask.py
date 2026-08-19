#!/usr/bin/env python3
# gemini-ask.js — portiert nach python
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

"""
gemini-ask.py - CLI tool for Google Gemini API

Usage:
  python gemini-ask.py "Your question here"
  echo "Your question" | python gemini-ask.py
  python gemini-ask.py --file prompt.txt
  python gemini-ask.py --model gemini-pro "Your question"

Environment:
  GEMINI_API_KEY - Required API key
  GEMINI_MODEL   - Optional default model (default: gemini-pro)
"""

import os
import sys
import argparse
import asyncio
import aiohttp
import json

DEFAULT_MODEL = os.environ.get('GEMINI_MODEL', 'gemini-pro')

async def main():
    # Check API key
    api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        print('Error: GEMINI_API_KEY environment variable is required', file=sys.stderr)
        sys.exit(1)

    parser = argparse.ArgumentParser(description='CLI tool for Google Gemini API')
    parser.add_argument('prompt', nargs='*', help='The prompt to send to Gemini')
    parser.add_argument('--model', '-m', default=DEFAULT_MODEL, help='Model name to use')
    parser.add_argument('--system', '-s', help='System prompt')
    parser.add_argument('--file', '-f', help='Read prompt from file')

    args = parser.parse_args()

    # Read prompt content
    if args.file:
        try:
            with open(args.file, 'r', encoding='utf-8') as f:
                prompt = f.read()
        except FileNotFoundError:
            print(f'Error: File {args.file} not found', file=sys.stderr)
            sys.exit(1)
    elif args.prompt:
        prompt = ' '.join(args.prompt)
    elif not sys.stdin.isatty():
        prompt = sys.stdin.read()
    else:
        prompt = ''

    if not prompt.strip():
        print('Error: No prompt provided', file=sys.stderr)
        print('Usage: gemini-ask "your question"', file=sys.stderr)
        print('       gemini-ask --model gemini-pro "your question"', file=sys.stderr)
        print('       echo "your question" | gemini-ask', file=sys.stderr)
        sys.exit(1)

    try:
        # Prepare generation config
        generation_config = {
            "maxOutputTokens": 8192,
            "temperature": 0.7,
            "topP": 0.95,
        }

        headers = {
            'Content-Type': 'application/json'
        }

        async with aiohttp.ClientSession() as session:
            if args.system:
                # Use chat with system prompt
                url = f'https://generativelanguage.googleapis.com/v1beta/models/{args.model}:generateContent?key={api_key}'
                
                # Create initial history with system prompt
                history = [
                    {"role": "user", "parts": [{"text": args.system}]},
                    {"role": "model", "parts": [{"text": "Understood. I will follow that instruction."}]}
                ]
                
                # Add the user's prompt
                history.append({"role": "user", "parts": [{"text": prompt}]})
                
                data = {
                    "contents": history,
                    "generationConfig": generation_config
                }
                
                async with session.post(url, headers=headers, json=data) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        raise Exception(f"API request failed with status {response.status}: {error_text}")
                    
                    result = await response.json()
            else:
                # Direct generation
                url = f'https://generativelanguage.googleapis.com/v1beta/models/{args.model}:generateContent?key={api_key}'
                
                data = {
                    "contents": [{"role": "user", "parts": [{"text": prompt}]}],
                    "generationConfig": generation_config
                }
                
                async with session.post(url, headers=headers, json=data) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        raise Exception(f"API request failed with status {response.status}: {error_text}")
                    
                    result = await response.json()

            # Extract and print the response text
            if 'candidates' in result and len(result['candidates']) > 0:
                candidate = result['candidates'][0]
                if 'content' in candidate and 'parts' in candidate['content']:
                    text_parts = [part['text'] for part in candidate['content']['parts'] if 'text' in part]
                    response_text = ''.join(text_parts)
                    print(response_text)
                else:
                    print("Error: Unexpected response format", file=sys.stderr)
                    sys.exit(1)
            else:
                print("Error: No candidates in response", file=sys.stderr)
                sys.exit(1)

    except Exception as error:
        print(f'Error: {error}', file=sys.stderr)
        if 'API key' in str(error):
            print('Make sure GEMINI_API_KEY is set correctly', file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    asyncio.run(main())
