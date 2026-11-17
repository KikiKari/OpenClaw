#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "c642644f26285781e1242f24dcfd24a8f3db6c7c7f4afdd4ec0573d61f662dce", "source_sha256": "d3ab9d6951153a42390fb59c1a50b0c901cf4c399dcb731b89865fdc293f3ac9", "target_language": "shell"}
# json_websearch.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/json_websearch.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/json_websearch.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# JSON Utils + WebSearch integration.
# Fetch API schemas from web, validate real API responses, batch-validate endpoints.

# Add json-utils to path
JSON_UTILS_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../../json-utils/scripts"
if [[ -d "$JSON_UTILS_PATH" ]]; then
    export PYTHONPATH="$JSON_UTILS_PATH:$PYTHONPATH"
    JSON_UTILS_AVAILABLE=true
else
    JSON_UTILS_AVAILABLE=false
    echo "Warning: json-utils not found. Some features disabled."
fi

# WebSearchResult structure simulation using associative arrays
declare -A WebSearchResult=(
    [query]=""
    [json_data]=""
    [validation_errors]=""
    [schema_matched]="false"
    [source_url]=""
)

# WebSearchJSON class simulation
use_repair=true
json_available=$JSON_UTILS_AVAILABLE

# search_and_validate function
search_and_validate() {
    local query="$1"
    local schema="${2:-}"
    local schema_path="${3:-}"

    # Simulate web search result (would be actual search in production)
    local mock_response='{"api":"'"${query%% *}"'","version":"1.0","endpoints":[{"path":"/items","method":"GET"},{"path":"/items","method":"POST"}]}'

    # Validate with json-utils if available
    local validation_errors=""
    local schema_matched="false"

    if [[ $json_available == true ]] && [[ -n "$schema" || -n "$schema_path" ]]; then
        if [[ -n "$schema_path" ]]; then
            if python3 -c "
import sys
sys.path.insert(0, '$JSON_UTILS_PATH')
from json_schema_validator import validate_with_jsonschema
import json
validate_with_jsonschema(json.loads('$mock_response'), '$schema_path')
"; then
                schema_matched="true"
            else
                validation_errors=$(python3 -c "
import sys
sys.path.insert(0, '$JSON_UTILS_PATH')
from json_schema_validator import validate_with_jsonschema
import json
try:
    validate_with_jsonschema(json.loads('$mock_response'), '$schema_path')
except Exception as e:
    print(str(e))
")
            fi
        fi
    fi

    # Populate WebSearchResult
    WebSearchResult[query]="$query"
    WebSearchResult[json_data]="$mock_response"
    WebSearchResult[validation_errors]="$validation_errors"
    WebSearchResult[schema_matched]="$schema_matched"
    WebSearchResult[source_url]="https://api.github.com/search?q=${query// /+}"
}

# validate_api_response function
validate_api_response() {
    local response_data="$1"
    local endpoint="$2"
    local expected_schema="${3:-}"

    if [[ $json_available != true ]]; then
        echo "$response_data"
        return
    fi

    # Use json-utils parser with auto-repair
    local result
    if [[ $use_repair == true ]]; then
        result=$(echo "$response_data" | python3 -c "
import sys
sys.path.insert(0, '$JSON_UTILS_PATH')
from json_processor import parse_json
import json
print(json.dumps(parse_json(sys.stdin.read(), repair=True)))
")
    else
        result=$(echo "$response_data" | python3 -c "
import sys
sys.path.insert(0, '$JSON_UTILS_PATH')
from json_processor import parse_json
import json
print(json.dumps(parse_json(sys.stdin.read())))
")
    fi

    if [[ -n "$expected_schema" ]]; then
        if ! echo "$result" | python3 -c "
import sys
sys.path.insert(0, '$JSON_UTILS_PATH')
from json_processor import parse_and_validate
import json
schema = json.loads('$expected_schema')
parse_and_validate(sys.stdin.read(), schema)
"; then
            echo "Schema validation failed for $endpoint: $(echo "$result" | python3 -c "
import sys
sys.path.insert(0, '$JSON_UTILS_PATH')
from json_processor import parse_and_validate
import json
try:
    schema = json.loads('$expected_schema')
    parse_and_validate(sys.stdin.read(), schema)
except Exception as e:
    print(str(e))
")" >&2
        fi
    fi

    echo "$result"
}

# batch_validate_endpoints function
batch_validate_endpoints() {
    local endpoints=("$@")
    local responses=("${endpoints[@]:$(((${#endpoints[@]}+1)/2))}")  
    endpoints=("${endpoints[@]:0:$(((${#endpoints[@]}+1)/2))}")  

    local results=()
    for i in "${!endpoints[@]}"; do
        local endpoint="${endpoints[$i]}"
        local response="${responses[$i]}"
        local json_data
        json_data=$(validate_api_response "$response" "$endpoint" 2>/dev/null) || {
            results+=("{\"query\":\"$endpoint\",\"json_data\":{},\"validation_errors\":[\"$(echo "$json_data" | sed 's/"/\\"/g')\"],\"schema_matched\":false,\"source_url\":\"$endpoint\"}")
            continue
        }
        results+=("{\"query\":\"$endpoint\",\"json_data\":$json_data,\"validation_errors\":[],\"schema_matched\":true,\"source_url\":\"$endpoint\"}")
    done

    printf '%s\n' "${results[@]}"
}

# generate_api_schema function
generate_api_schema() {
    local sample_response="$1"
    local endpoint="$2"

    if [[ $json_available != true ]]; then
        echo "{}"
        return
    fi

    local data
    data=$(echo "$sample_response" | python3 -c "
import sys
sys.path.insert(0, '$JSON_UTILS_PATH')
from json_processor import parse_json
import json
print(json.dumps(parse_json(sys.stdin.read())))
")

    # Basic schema generation
    python3 -c "
import json
import sys

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

# main function
main() {
    local search=""
    local validate_file=""
    local schema=""
    local generate_schema=""
    local endpoint=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --search)
                search="$2"
                shift 2
                ;;
            --validate-file)
                validate_file="$2"
                shift 2
                ;;
            --schema)
                schema="$2"
                shift 2
                ;;
            --generate-schema)
                generate_schema="$2"
                shift 2
                ;;
            --endpoint)
                endpoint="$2"
                shift 2
                ;;
            *)
                echo "Unknown option $1"
                exit 1
                ;;
        esac
    done

    if [[ -n "$search" ]]; then
        search_and_validate "$search" "" "$schema"
        echo "Query: ${WebSearchResult[query]}"
        echo "Data: ${WebSearchResult[json_data]}" | python3 -m json.tool
        echo "Schema matched: ${WebSearchResult[schema_matched]}"
        if [[ -n "${WebSearchResult[validation_errors]}" ]]; then
            echo "Errors: ${WebSearchResult[validation_errors]}"
        fi
    elif [[ -n "$generate_schema" ]] && [[ -n "$endpoint" ]]; then
        local sample
        sample=$(cat "$generate_schema")
        generate_api_schema "$sample" "$endpoint"
    fi
}

# Entry point
main "$@"
