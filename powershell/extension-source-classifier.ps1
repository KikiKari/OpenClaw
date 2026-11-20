#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "8bc21347c89ef8aa4f38c4de7d76cb2a603345affbffe9b57aafe328075e4419", "source_sha256": "13d5446c5e30146c4173cad6e5ecff0482c7febec4cd8586ae04dff1eaf2417b", "target_language": "powershell"}
# extension-source-classifier.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-source-classifier.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

$CODE_FILE_RE = '\.(?:[cm]?ts|[cm]?js|tsx|jsx)$'
$DECLARATION_FILE_RE = '\.d\.ts$'
$RUNTIME_API_BARREL_RE = '(^|\/)runtime-api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$'
$PUBLIC_API_BARREL_RE = '(^|\/)api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$'
$TEST_LIKE_SEGMENT_RE = '(^|\/)(?:__tests__|fixtures|test|tests|test-fixtures|test-support|test-utils)(?:\/|$)'
$TEST_LIKE_FILENAME_RE = '(^|\/)[^/]*test-(?:support|helpers|fixtures|harness)\.(?:[cm]?ts|[cm]?js|tsx|jsx)$'
$TEST_SHARED_FILENAME_RE = '(^|\/)[^/]*\.test-[^/]*\.(?:[cm]?ts|[cm]?js|tsx|jsx)$'
$TEST_CANARY_FILENAME_RE = '(^|\/)__rootdir_boundary_canary__\.(?:[cm]?ts|[cm]?js|tsx|jsx)$'
$SNAPSHOT_FILE_RE = '\.snap$'
$SUFFIX_SKIP_RE = '\.(?:test|spec|fixture)\.'
$INFRA_DIR_RE = '(^|\/)(?:coverage|dist|node_modules)(?:\/|$)'
$INFRA_NAME_RE = '(test-harness|test-support|test-helpers|test-fixtures)'

function Normalize-ExtensionSourcePath {
    param(
        [string]$FilePath
    )
    
    return $FilePath -replace '\\', '/'
}

function Classify-BundledExtensionSourcePath {
    param(
        [string]$FilePath
    )
    
    $normalizedPath = Normalize-ExtensionSourcePath $FilePath
    $isCodeFile = [regex]::IsMatch($normalizedPath, $CODE_FILE_RE) -and -not [regex]::IsMatch($normalizedPath, $DECLARATION_FILE_RE)
    $isRuntimeApiBarrel = [regex]::IsMatch($normalizedPath, $RUNTIME_API_BARREL_RE)
    $isPublicApiBarrel = [regex]::IsMatch($normalizedPath, $PUBLIC_API_BARREL_RE)
    $isTestLike = [regex]::IsMatch($normalizedPath, $TEST_LIKE_SEGMENT_RE) -or `
                  [regex]::IsMatch($normalizedPath, $TEST_LIKE_FILENAME_RE) -or `
                  [regex]::IsMatch($normalizedPath, $TEST_SHARED_FILENAME_RE) -or `
                  [regex]::IsMatch($normalizedPath, $TEST_CANARY_FILENAME_RE) -or `
                  [regex]::IsMatch($normalizedPath, $SUFFIX_SKIP_RE) -or `
                  [regex]::IsMatch($normalizedPath, $SNAPSHOT_FILE_RE) -or `
                  [regex]::IsMatch($normalizedPath, $INFRA_NAME_RE)
    $isInfraArtifact = [regex]::IsMatch($normalizedPath, $INFRA_DIR_RE)
    
    $isProductionSource = $isCodeFile -and -not $isRuntimeApiBarrel -and -not $isTestLike -and -not $isInfraArtifact
    
    return @{
        normalizedPath = $normalizedPath
        isCodeFile = $isCodeFile
        isRuntimeApiBarrel = $isRuntimeApiBarrel
        isPublicApiBarrel = $isPublicApiBarrel
        isTestLike = $isTestLike
        isInfraArtifact = $isInfraArtifact
        isProductionSource = $isProductionSource
    }
}

Export-ModuleMember -Function Normalize-ExtensionSourcePath, Classify-BundledExtensionSourcePath
