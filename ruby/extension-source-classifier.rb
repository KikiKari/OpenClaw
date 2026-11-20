#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "35e24038042b8d9d99ecc40e8fb6f0ae7d1514ad52d9639f6d586a1eddbccf83", "source_sha256": "13d5446c5e30146c4173cad6e5ecff0482c7febec4cd8586ae04dff1eaf2417b", "target_language": "ruby"}
# extension-source-classifier.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-source-classifier.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

CODE_FILE_RE = /\.(?:[cm]?ts|[cm]?js|tsx|jsx)$/i
DECLARATION_FILE_RE = /\.d\.ts$/i
RUNTIME_API_BARREL_RE = %r{(^|/)(?:runtime-api|runtime-api\.d)\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}i
PUBLIC_API_BARREL_RE = %r{(^|/)(?:api|api\.d)\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}i
TEST_LIKE_SEGMENT_RE = %r{(^|/)(?:__tests__|fixtures|test|tests|test-fixtures|test-support|test-utils)(?:/|$)}i
TEST_LIKE_FILENAME_RE = %r{(^|/)[^/]*test-(?:support|helpers|fixtures|harness)\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}i
TEST_SHARED_FILENAME_RE = %r{(^|/)[^/]*\.test-[^/]*\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}i
TEST_CANARY_FILENAME_RE = %r{(^|/)__rootdir_boundary_canary__\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}i
SNAPSHOT_FILE_RE = /\.snap$/i
SUFFIX_SKIP_RE = /\.(?:test|spec|fixture)\./i
INFRA_DIR_RE = %r{(^|/)(?:coverage|dist|node_modules)(?:/|$)}i
INFRA_NAME_RE = /(test-harness|test-support|test-helpers|test-fixtures)/i

def normalize_extension_source_path(file_path)
  file_path.gsub("\\", "/")
end

def classify_bundled_extension_source_path(file_path)
  normalized_path = normalize_extension_source_path(file_path)
  is_code_file = !!(normalized_path =~ CODE_FILE_RE) && !(normalized_path =~ DECLARATION_FILE_RE)
  is_runtime_api_barrel = !!(normalized_path =~ RUNTIME_API_BARREL_RE)
  is_public_api_barrel = !!(normalized_path =~ PUBLIC_API_BARREL_RE)
  is_test_like = 
    !!(normalized_path =~ TEST_LIKE_SEGMENT_RE) ||
    !!(normalized_path =~ TEST_LIKE_FILENAME_RE) ||
    !!(normalized_path =~ TEST_SHARED_FILENAME_RE) ||
    !!(normalized_path =~ TEST_CANARY_FILENAME_RE) ||
    !!(normalized_path =~ SUFFIX_SKIP_RE) ||
    !!(normalized_path =~ SNAPSHOT_FILE_RE) ||
    !!(normalized_path =~ INFRA_NAME_RE)
  is_infra_artifact = !!(normalized_path =~ INFRA_DIR_RE)

  {
    normalizedPath: normalized_path,
    isCodeFile: is_code_file,
    isRuntimeApiBarrel: is_runtime_api_barrel,
    isPublicApiBarrel: is_public_api_barrel,
    isTestLike: is_test_like,
    isInfraArtifact: is_infra_artifact,
    isProductionSource: is_code_file && !is_runtime_api_barrel && !is_test_like && !is_infra_artifact
  }
end
