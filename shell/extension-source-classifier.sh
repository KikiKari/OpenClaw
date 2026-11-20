#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "bf223f16b82783b91c02eb6ef21240f87423ebc23a1de64aa05993551318bf66", "source_sha256": "13d5446c5e30146c4173cad6e5ecff0482c7febec4cd8586ae04dff1eaf2417b", "target_language": "shell"}
# extension-source-classifier.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-source-classifier.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Definiere reguläre Ausdrücke als Variablen
CODE_FILE_RE='\.\([cm]\?ts\|[cm]\?js\|tsx\|jsx\)$'
DECLARATION_FILE_RE='\.d\.ts$'
RUNTIME_API_BARREL_RE='\(/\\\|^\)runtime-api\.\([cm]\?ts\|[cm]\?js\|tsx\|jsx\)$'
PUBLIC_API_BARREL_RE='\(/\\\|^\)api\.\([cm]\?ts\|[cm]\?js\|tsx\|jsx\)$'
TEST_LIKE_SEGMENT_RE='\(/\\\|^\)\(__tests__\|fixtures\|test\|tests\|test-fixtures\|test-support\|test-utils\)\(/\|$\)'
TEST_LIKE_FILENAME_RE='\(/\\\|^\)[^/]*/[^/]*test-\(support\|helpers\|fixtures\|harness\)\.\([cm]\?ts\|[cm]\?js\|tsx\|jsx\)$'
TEST_SHARED_FILENAME_RE='\(/\\\|^\)[^/]*/[^/]*\.test-[^/]*\.\([cm]\?ts\|[cm]\?js\|tsx\|jsx\)$'
TEST_CANARY_FILENAME_RE='\(/\\\|^\)__rootdir_boundary_canary__\.\([cm]\?ts\|[cm]\?js\|tsx\|jsx\)$'
SNAPSHOT_FILE_RE='\.snap$'
SUFFIX_SKIP_RE='\.\(test\|spec\|fixture\)\.'
INFRA_DIR_RE='\(/\\\|^\)\(coverage\|dist\|node_modules\)\(/\|$\)'
INFRA_NAME_RE='\(test-harness\|test-support\|test-helpers\|test-fixtures\)'

normalize_extension_source_path() {
    local file_path="$1"
    echo "${file_path//\\//}"
}

classify_bundled_extension_source_path() {
    local file_path="$1"
    
    # Normalisiere den Pfad
    local normalized_path
    normalized_path=$(normalize_extension_source_path "$file_path")
    
    # Prüfe ob es eine Code-Datei ist (aber keine Deklarationsdatei)
    local is_code_file=0
    if [[ $normalized_path =~ $CODE_FILE_RE ]] && ! [[ $normalized_path =~ $DECLARATION_FILE_RE ]]; then
        is_code_file=1
    fi
    
    # Prüfe auf Runtime API Barrel
    local is_runtime_api_barrel=0
    if [[ $normalized_path =~ $RUNTIME_API_BARREL_RE ]]; then
        is_runtime_api_barrel=1
    fi
    
    # Prüfe auf Public API Barrel
    local is_public_api_barrel=0
    if [[ $normalized_path =~ $PUBLIC_API_BARREL_RE ]]; then
        is_public_api_barrel=1
    fi
    
    # Prüfe auf Test-ähnliche Strukturen
    local is_test_like=0
    if [[ $normalized_path =~ $TEST_LIKE_SEGMENT_RE ]] || \
       [[ $normalized_path =~ $TEST_LIKE_FILENAME_RE ]] || \
       [[ $normalized_path =~ $TEST_SHARED_FILENAME_RE ]] || \
       [[ $normalized_path =~ $TEST_CANARY_FILENAME_RE ]] || \
       [[ $normalized_path =~ $SUFFIX_SKIP_RE ]] || \
       [[ $normalized_path =~ $SNAPSHOT_FILE_RE ]] || \
       [[ $normalized_path =~ $INFRA_NAME_RE ]]; then
        is_test_like=1
    fi
    
    # Prüfe auf Infrastruktur-Artefakte
    local is_infra_artifact=0
    if [[ $normalized_path =~ $INFRA_DIR_RE ]]; then
        is_infra_artifact=1
    fi
    
    # Bestimme ob es Produktionsquelle ist
    local is_production_source=0
    if [[ $is_code_file -eq 1 ]] && [[ $is_runtime_api_barrel -eq 0 ]] && [[ $is_test_like -eq 0 ]] && [[ $is_infra_artifact -eq 0 ]]; then
        is_production_source=1
    fi
    
    # Gebe die Ergebnisse als JSON-ähnlichen String aus
    cat <<EOF
{
  "normalizedPath": "$normalized_path",
  "isCodeFile": $is_code_file,
  "isRuntimeApiBarrel": $is_runtime_api_barrel,
  "isPublicApiBarrel": $is_public_api_barrel,
  "isTestLike": $is_test_like,
  "isInfraArtifact": $is_infra_artifact,
  "isProductionSource": $is_production_source
}
EOF
}
