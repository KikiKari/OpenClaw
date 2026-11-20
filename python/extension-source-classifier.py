#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "8d8e130186b50f5bddd7f6f3f8f9254a1da4ae7d5f91a173e6b8a9e2805ccea0", "source_sha256": "13d5446c5e30146c4173cad6e5ecff0482c7febec4cd8586ae04dff1eaf2417b", "target_language": "python"}
# extension-source-classifier.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-source-classifier.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import re

CODE_FILE_RE = re.compile(r'\.(?:[cm]?ts|[cm]?js|tsx|jsx)$')
DECLARATION_FILE_RE = re.compile(r'\.d\.ts$')
RUNTIME_API_BARREL_RE = re.compile(r'(^|/)runtime-api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$')
PUBLIC_API_BARREL_RE = re.compile(r'(^|/)api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$')
TEST_LIKE_SEGMENT_RE = re.compile(r'(^|/)(?:__tests__|fixtures|test|tests|test-fixtures|test-support|test-utils)(?:/|$)')
TEST_LIKE_FILENAME_RE = re.compile(r'(^|/)[^/]*test-(?:support|helpers|fixtures|harness)\.(?:[cm]?ts|[cm]?js|tsx|jsx)$')
TEST_SHARED_FILENAME_RE = re.compile(r'(^|/)[^/]*\.test-[^/]*\.(?:[cm]?ts|[cm]?js|tsx|jsx)$')
TEST_CANARY_FILENAME_RE = re.compile(r'(^|/).__rootdir_boundary_canary__\.(?:[cm]?ts|[cm]?js|tsx|jsx)$')
SNAPSHOT_FILE_RE = re.compile(r'\.snap$')
SUFFIX_SKIP_RE = re.compile(r'\.(?:test|spec|fixture)\.')
INFRA_DIR_RE = re.compile(r'(^|/)(?:coverage|dist|node_modules)(?:/|$)')
INFRA_NAME_RE = re.compile(r'(test-harness|test-support|test-helpers|test-fixtures)')

def normalize_extension_source_path(file_path):
    return file_path.replace("\\", "/")

def classify_bundled_extension_source_path(file_path):
    normalized_path = normalize_extension_source_path(file_path)
    is_code_file = bool(CODE_FILE_RE.search(normalized_path)) and not bool(DECLARATION_FILE_RE.search(normalized_path))
    is_runtime_api_barrel = bool(RUNTIME_API_BARREL_RE.search(normalized_path))
    is_public_api_barrel = bool(PUBLIC_API_BARREL_RE.search(normalized_path))
    is_test_like = (
        bool(TEST_LIKE_SEGMENT_RE.search(normalized_path)) or
        bool(TEST_LIKE_FILENAME_RE.search(normalized_path)) or
        bool(TEST_SHARED_FILENAME_RE.search(normalized_path)) or
        bool(TEST_CANARY_FILENAME_RE.search(normalized_path)) or
        bool(SUFFIX_SKIP_RE.search(normalized_path)) or
        bool(SNAPSHOT_FILE_RE.search(normalized_path)) or
        bool(INFRA_NAME_RE.search(normalized_path))
    )
    is_infra_artifact = bool(INFRA_DIR_RE.search(normalized_path))

    return {
        'normalizedPath': normalized_path,
        'isCodeFile': is_code_file,
        'isRuntimeApiBarrel': is_runtime_api_barrel,
        'isPublicApiBarrel': is_public_api_barrel,
        'isTestLike': is_test_like,
        'isInfraArtifact': is_infra_artifact,
        'isProductionSource': is_code_file and not is_runtime_api_barrel and not is_test_like and not is_infra_artifact,
    }
