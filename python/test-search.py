#!/usr/bin/env python3
# test-search.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-search.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import json
import tempfile
import requests

# Ensure PERPLEXITY_API_KEY is set
PERPLEXITY_API_KEY = os.environ.get('PERPLEXITY_API_KEY')
if not PERPLEXITY_API_KEY:
    print("PERPLEXITY_API_KEY is required", file=sys.stderr)
    sys.exit(1)

# Get query from command line or use default
query = sys.argv[1] if len(sys.argv) > 1 else "Perplexity API Platform"

# Set default values for max_results and max_tokens_per_page
max_results = int(os.environ.get('PERPLEXITY_MAX_RESULTS', '3'))
max_tokens_per_page = int(os.environ.get('PERPLEXITY_MAX_TOKENS_PER_PAGE', '256'))

# Create temporary output file path
tmpdir = os.environ.get('TMPDIR', '/tmp')
out_file = os.path.join(tmpdir, 'perplexity-search-test.json')

# Prepare the request payload
payload = {
    'query': query,
    'max_results': max_results,
    'max_tokens_per_page': max_tokens_per_page
}

# Make the API request
headers = {
    'Authorization': f'Bearer {PERPLEXITY_API_KEY}',
    'Content-Type': 'application/json'
}

try:
    response = requests.post(
        'https://api.perplexity.ai/search',
        headers=headers,
        json=payload
    )
    
    # Write response to file
    with open(out_file, 'w') as f:
        f.write(response.text)
    
    # Print HTTP status code
    print(f"search_http={response.status_code}")
    
    # Process and print JSON response structure
    try:
        data = response.json()
        
        # Determine result count (check both 'results' and 'data' fields)
        results_field = data.get('results') or data.get('data') or []
        result_count = len(results_field)
        
        # Get first result if available
        first_result = results_field[0] if result_count > 0 else None
        
        # Create output structure
        output = {
            'keys': list(data.keys()),
            'result_count': result_count,
            'first': first_result
        }
        
        print(json.dumps(output, indent=2))
        
    except json.JSONDecodeError:
        # Handle case where response is not valid JSON
        output = {
            'keys': [],
            'result_count': 0,
            'first': None
        }
        print(json.dumps(output, indent=2))

except requests.exceptions.RequestException as e:
    print(f"Error making request: {e}", file=sys.stderr)
    sys.exit(1)
