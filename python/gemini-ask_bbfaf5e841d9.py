#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "170dc6c421fb1e7978e1bd3be00299235e9059b1ea3c3bb01206d4aabab4d8e6", "source_sha256": "9411ee01f75190a7b3bf9f276fc6bb624d2c943629885c1ddfc9f71a0039070e", "target_language": "python"}
# gemini-ask.js — portiert nach python
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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

    parser = argparse.ArgumentParser(description='CLI tool for Google Gemini API', add_help=False)
    parser.add_argument('--model', '-m', help='Model name to use')
    parser.add_argument('--system', '-s', help='System prompt')
    parser.add_argument('--file', '-f', help='Read prompt from file')
    parser.add_argument('prompt', nargs='*', help='The prompt text')

    args, unknown = parser.parse_known_args()

    # Handle positional arguments that might be mixed with optional ones
    if args.file:
        try:
            with open(args.file, 'r', encoding='utf-8') as f:
                prompt = f.read()
        except Exception as e:
            print(f'Error reading file: {e}', file=sys.stderr)
            sys.exit(1)
    elif args.prompt:
        prompt = ' '.join(args.prompt + unknown)
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

    model_name = args.model or DEFAULT_MODEL
    system_prompt = args.system

    try:
        async with aiohttp.ClientSession() as session:
            headers = {
                'Content-Type': 'application/json'
            }

            generation_config = {
                'maxOutputTokens': 8192,
                'temperature': 0.7,
                'topP': 0.95,
            }

            if system_prompt:
                # Use chat with system prompt
                url = f'https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}'
                
                data = {
                    'contents': [
                        {'role': 'user', 'parts': [{'text': system_prompt}]},
                        {'role': 'model', 'parts': [{'text': 'Understood. I will follow that instruction.'}]},
                        {'role': 'user', 'parts': [{'text': prompt}]}
                    ],
                    'generationConfig': generation_config
                }
            else:
                # Direct generation
                url = f'https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}'
                
                data = {
                    'contents': [
                        {'role': 'user', 'parts': [{'text': prompt}]}
                    ],
                    'generationConfig': generation_config
                }

            async with session.post(url, headers=headers, json=data) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f'API request failed with status {response.status}: {error_text}')
                
                result = await response.json()
                
                if 'candidates' in result and len(result['candidates']) > 0:
                    candidate = result['candidates'][0]
                    if 'content' in candidate:
                        content = candidate['content']
                        if 'parts' in content and len(content['parts']) > 0:
                            text = content['parts'][0].get('text', '')
                            print(text)
                        else:
                            raise Exception('No text found in response')
                    else:
                        raise Exception('No content found in response')
                else:
                    raise Exception('No candidates found in response')

    except Exception as error:
        print(f'Error: {error}', file=sys.stderr)
        if 'API key' in str(error):
            print('Make sure GEMINI_API_KEY is set correctly', file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    asyncio.run(main())
