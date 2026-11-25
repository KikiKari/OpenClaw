#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "94b5f81e3952d16fb1f6b9754533601e874184e295f02df97ae48765427d4843", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "python"}
# transcribe.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import argparse
from pathlib import Path
import requests
import json

def usage():
    print("Usage:", file=sys.stderr)
    print("  transcribe.py <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt \"hint\"] [--json]", file=sys.stderr)
    sys.exit(2)

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        usage()

    parser = argparse.ArgumentParser(
        description="Transcribe audio using OpenAI API",
        add_help=False,
        usage=argparse.SUPPRESS
    )
    parser.add_argument('input', nargs='?', help='Input audio file')
    parser.add_argument('--model', default='whisper-1')
    parser.add_argument('--out', default='')
    parser.add_argument('--language', default='')
    parser.add_argument('--prompt', default='')
    parser.add_argument('--json', action='store_true')

    args, unknown = parser.parse_known_args()

    if unknown:
        print(f"Unknown arg: {unknown[0]}", file=sys.stderr)
        usage()

    if not args.input:
        usage()

    input_file = args.input

    if not os.path.isfile(input_file):
        print(f"File not found: {input_file}", file=sys.stderr)
        sys.exit(1)

    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        print("Missing OPENAI_API_KEY", file=sys.stderr)
        sys.exit(1)

    response_format = 'json' if args.json else 'text'

    if not args.out:
        base = os.path.splitext(input_file)[0]
        out_file = f"{base}.{'json' if args.json else 'txt'}"
    else:
        out_file = args.out

    # Create output directory if needed
    Path(out_file).parent.mkdir(parents=True, exist_ok=True)

    api_base = os.environ.get('OPENAI_BASE_URL', 'https://api.openai.com/v1').rstrip('/')
    
    url = f"{api_base}/audio/transcriptions"
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Accept': 'application/json'
    }
    
    files = {
        'file': (os.path.basename(input_file), open(input_file, 'rb')),
    }
    
    data = {
        'model': args.model,
        'response_format': response_format
    }
    
    if args.language:
        data['language'] = args.language
    
    if args.prompt:
        data['prompt'] = args.prompt

    try:
        response = requests.post(url, headers=headers, files=files, data=data)
        response.raise_for_status()
        
        with open(out_file, 'wb') as f:
            f.write(response.content)
            
        print(out_file)
        
    except requests.exceptions.RequestException as e:
        print(f"API request failed: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        if 'files' in locals():
            files['file'][1].close()

if __name__ == "__main__":
    main()
