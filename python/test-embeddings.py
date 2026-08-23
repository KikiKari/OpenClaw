#!/usr/bin/env python3
# test-embeddings.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import json
import tempfile
import urllib.request
from typing import Any, Dict

def main():
    # Ensure PERPLEXITY_API_KEY is set
    api_key = os.environ.get('PERPLEXITY_API_KEY')
    if not api_key:
        raise ValueError("PERPLEXITY_API_KEY is required")

    # Create temporary file path
    tmpdir = os.environ.get('TMPDIR', '/tmp')
    out_path = os.path.join(tmpdir, 'perplexity-embeddings-test.json')

    # Prepare payload
    payload_data = {
        "input": [
            "Scientists explore the universe driven by curiosity.",
            "Curiosity compels us to seek explanations, not just observations.",
            "Historical discoveries began with curious questions.",
            "The pursuit of knowledge distinguishes human curiosity from mere stimulus response.",
            "Philosophy examines the nature of curiosity."
        ],
        "model": "pplx-embed-v1-4b"
    }
    
    payload = json.dumps(payload_data).encode('utf-8')

    # Make HTTP request
    req = urllib.request.Request(
        'https://api.perplexity.ai/v1/embeddings',
        data=payload,
        headers={
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        },
        method='POST'
    )

    try:
        with urllib.request.urlopen(req) as response:
            code = response.getcode()
            response_data = response.read()
            
        # Write response to file
        with open(out_path, 'wb') as f:
            f.write(response_data)
            
    except urllib.error.HTTPError as e:
        code = e.code
        # Even on error, we want to capture the response body
        response_data = e.read()
        with open(out_path, 'wb') as f:
            f.write(response_data)

    print(f"embeddings_http={code}")

    # Process and output JSON summary
    with open(out_path, 'r') as f:
        data = json.load(f)

    # Build summary similar to jq command
    summary = {
        "keys": list(data.keys()),
        "model": data.get("model", None),
        "item_count": len(data.get("data", [])),
        "first_dim": len(data.get("data", [{}])[0].get("embedding", [])) if data.get("data") else 0,
        "error": data.get("error", None)
    }

    print(json.dumps(summary, indent=2))

if __name__ == '__main__':
    main()
