#!/usr/bin/env bash
# json_websearch.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/json_websearch.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/json_websearch.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# JSON Utils + WebSearch integration.
# Fetch API schemas from web, validate real API responses, batch-validate endpoints.

# Add json-utils to path
JSON_UTILS_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../../json-utils/scripts"
if [[ -d "$JSON_UTILS_PATH" ]]; then
    export PYTHONPATH="$JSON_UTILS_PATH:$PYTHONPATH"
fi

# Check if required Python modules are available
JSON_UTILS_AVAILABLE=true
python3 -c "
import sys
try:
    from json_processor import parse_json, parse_and_validate
    from json_schema_validator import validate_with_jsonschema
    from json_batch_processor import process_file_batch
except ImportError:
    sys.exit(1)
" 2>/dev/null || JSON_UTILS_AVAILABLE=false

if [[ "$JSON_UTILS_AVAILABLE" == false ]]; then
    echo "Warning: json-utils not found. Some features disabled." >&2
fi

# WebSearchResult structure simulation using associative arrays
declare -A WEBSEARCH_RESULT

# WebSearchJSON class functions
use_repair=${USE_REPAIR:-true}
json_available=$JSON_UTILS_AVAILABLE

# Function to simulate web search and validation
search_and_validate() {
    local query="$1"
    local schema="${2:-}"
    local schema_path="${3:-}"

    # Simulate web search result (would be actual search in production)
    local mock_response='{"api":"'"${query%% *}"'","version":"1.0","endpoints":[{"path":"/items","method":"GET"},{"path":"/items","method":"POST"}]}'

    # Validate with json-utils if available
    local validation_errors=()
    local schema_matched=false

    if [[ "$json_available" == true ]] && [[ -n "$schema" || -n "$schema_path" ]]; then
        if [[ -n "$schema_path" ]]; then
            if python3 -c "
import sys
from json_schema_validator import validate_with_jsonschema
import json
try:
    data = json.loads('$mock_response')
    validate_with_jsonschema(data, '$schema_path')
except Exception as e:
    print(e, file=sys.stderr)
    sys.exit(1)
"; then
                schema_matched=true
            else
                validation_errors+=("$(python3 -c "
import sys
from json_schema_validator import validate_with_jsonschema
import json
try:
    data = json.loads('$mock_response')
    validate_with_jsonschema(data, '$schema_path')
except Exception as e:
    print(e, file=sys.stderr)
")")
            fi
        fi
    fi

    # Populate WebSearchResult-like structure
    WEBSEARCH_RESULT[query]="$query"
    WEBSEARCH_RESULT[json_data]="$mock_response"
    WEBSEARCH_RESULT[validation_errors]=$(printf '%s\n' "${validation_errors[@]}" | jq -R . | jq -s .)
    WEBSEARCH_RESULT[schema_matched]=$([[ "$schema_matched" == true ]] && echo "true" || echo "false")
    WEBSEARCH_RESULT[source_url]="https://api.github.com/search?q=${query// /+}"
}

# Function to validate an API response with auto-repair
validate_api_response() {
    local response_data="$1"
    local endpoint="$2"
    local expected_schema="${3:-}"

    if [[ "$json_available" == false ]]; then
        echo "$response_data"
        return
    fi

    # Use json-utils parser with auto-repair
    local result
    if [[ "$use_repair" == true ]]; then
        result=$(echo "$response_data" | python3 -c "
from json_processor import parse_json
import sys
import json
data = sys.stdin.read()
parsed = parse_json(data, repair=True)
print(json.dumps(parsed))
")
    else
        result=$(echo "$response_data" | python3 -c "
from json_processor import parse_json
import sys
import json
data = sys.stdin.read()
parsed = parse_json(data, repair=False)
print(json.dumps(parsed))
")
    fi

    if [[ -n "$expected_schema" ]]; then
        if ! echo "$result" | python3 -c "
import sys
import json
from json_processor import parse_and_validate
schema_str = '''$expected_schema'''
schema = json.loads(schema_str)
data = json.loads(sys.stdin.read())
parse_and_validate(json.dumps(data), schema)
" 2>/dev/null; then
            echo "Schema validation failed for $endpoint: $(echo "$result" | python3 -c "
import sys
import json
from json_processor import parse_and_validate
schema_str = '''$expected_schema'''
schema = json.loads(schema_str)
data = json.loads(sys.stdin.read())
try:
    parse_and_validate(json.dumps(data), schema)
except Exception as e:
    print(e, file=sys.stderr)
")" >&2
        fi
    fi

    echo "$result"
}

# Function to batch-validate multiple API endpoint responses
batch_validate_endpoints() {
    local endpoints=("$@")
    local responses=("${endpoints[@]:${#endpoints[@]}/2}")
    endpoints=("${endpoints[@]:0:${#endpoints[@]}/2}")

    local results=()
    for i in "${!endpoints[@]}"; do
        local endpoint="${endpoints[$i]}"
        local response="${responses[$i]}"
        local json_data
        local validation_error=""
        local schema_matched="true"

        if json_data=$(validate_api_response "$response" "$endpoint" 2>/dev/null); then
            results+=("{\"query\":\"$endpoint\",\"json_data\":$json_data,\"validation_errors\":[],\"schema_matched\":true,\"source_url\":\"$endpoint\"}")
        else
            validation_error=$(validate_api_response "$response" "$endpoint" 2>&1)
            results+=("{\"query\":\"$endpoint\",\"json_data\":{},\"validation_errors\":[\"$validation_error\"],\"schema_matched\":false,\"source_url\":\"$endpoint\"}")
        fi
    done

    printf '%s\n' "${results[@]}" | jq -s .
}

# Function to generate JSON Schema from sample API response
generate_api_schema() {
    local sample_response="$1"
    local endpoint="$2"

    if [[ "$json_available" == false ]]; then
        echo "{}"
        return
    fi

    local data
    data=$(echo "$sample_response" | python3 -c "
from json_processor import parse_json
import sys
data = sys.stdin.read()
parsed = parse_json(data)
print(parsed)
")

    # Basic schema generation using Python
    python3 -c "
import sys
import json

def infer_schema(obj, path='root'):
    if isinstance(obj, dict):
        return {
            'type': 'object',
            'properties': {
                k: infer_schema(v, f'{path}.{k}')
                for k, v in obj.items()
            }
        }
    elif isinstance(obj, list) and obj:
        return {
            'type': 'array',
            'items': infer_schema(obj[0], f'{path}[]')
        }
    elif isinstance(obj, str):
        return {'type': 'string'}
    elif isinstance(obj, int):
        return {'type': 'integer'}
    elif isinstance(obj, float):
        return {'type': 'number'}
    elif isinstance(obj, bool):
        return {'type': 'boolean'}
    else:
        return {'type': 'null'}

data = json.loads('''$data''')
schema = {
    '\$schema': 'http://json-schema.org/draft-07/schema#',
    'title': '$endpoint Response Schema',
    **infer_schema(data)
}
print(json.dumps(schema, indent=2))
"
}

# Main function
main() {
    local search_query=""
    local validate_file=""
    local schema_file=""
    local generate_schema_file=""
    local endpoint=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --search)
                search_query="$2"
                shift 2
                ;;
            --validate-file)
                validate_file="$2"
                shift 2
                ;;
            --schema)
                schema_file="$2"
                shift 2
                ;;
            --generate-schema)
                generate_schema_file="$2"
                shift 2
                ;;
            --endpoint)
                endpoint="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    if [[ -n "$search_query" ]]; then
        search_and_validate "$search_query" "" "$schema_file"
        echo "Query: ${WEBSEARCH_RESULT[query]}"
        echo "Data: $(echo "${WEBSEARCH_RESULT[json_data]}" | jq .)"
        echo "Schema matched: ${WEBSEARCH_RESULT[schema_matched]}"
        if [[ "${WEBSEARCH_RESULT[validation_errors]}" != "[]" ]]; then
            echo "Errors: $(echo "${WEBSEARCH_RESULT[validation_errors]}" | jq -r '.[]')"
        fi
    elif [[ -n "$generate_schema_file" ]] && [[ -n "$endpoint" ]]; then
        local sample
        sample=$(cat "$generate_schema_file")
        generate_api_schema "$sample" "$endpoint"
    else
        echo "No valid action specified." >&2
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
