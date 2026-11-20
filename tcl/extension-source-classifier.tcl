#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "8dc5d53124b70ad7bcdf5505f1e40da28463e4035d9403c2fe15afe66e0c59ca", "source_sha256": "13d5446c5e30146c4173cad6e5ecff0482c7febec4cd8586ae04dff1eaf2417b", "target_language": "tcl"}
# extension-source-classifier.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-source-classifier.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

proc normalizeExtensionSourcePath {filePath} {
    # Ersetze Backslashes durch Slashes
    return [string map {\\ /} $filePath]
}

proc classifyBundledExtensionSourcePath {filePath} {
    set normalizedPath [normalizeExtensionSourcePath $filePath]
    
    # Definiere die regulären Ausdrücke
    set CODE_FILE_RE {\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}
    set DECLARATION_FILE_RE {\.d\.ts$}
    set RUNTIME_API_BARREL_RE {(^|/)runtime-api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}
    set PUBLIC_API_BARREL_RE {(^|/)api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}
    set TEST_LIKE_SEGMENT_RE {(^|/)(?:__tests__|fixtures|test|tests|test-fixtures|test-support|test-utils)(?:/|$)}
    set TEST_LIKE_FILENAME_RE {(^|/)[^/]*/test-(?:support|helpers|fixtures|harness)\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}
    set TEST_SHARED_FILENAME_RE {(^|/)[^/]*\.test-[^/]*\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}
    set TEST_CANARY_FILENAME_RE {(^|/)__rootdir_boundary_canary__\.(?:[cm]?ts|[cm]?js|tsx|jsx)$}
    set SNAPSHOT_FILE_RE {\.snap$}
    set SUFFIX_SKIP_RE {\.(?:test|spec|fixture)\.}
    set INFRA_DIR_RE {(^|/)(?:coverage|dist|node_modules)(?:/|$)}
    set INFRA_NAME_RE {(test-harness|test-support|test-helpers|test-fixtures)}
    
    # Prüfe ob es eine Code-Datei ist (aber keine Deklarationsdatei)
    set isCodeFile [regexp $CODE_FILE_RE $normalizedPath]
    if {$isCodeFile} {
        set isCodeFile [expr {![regexp $DECLARATION_FILE_RE $normalizedPath]}]
    }
    
    # Prüfe verschiedene Klassifikationen
    set isRuntimeApiBarrel [regexp $RUNTIME_API_BARREL_RE $normalizedPath]
    set isPublicApiBarrel [regexp $PUBLIC_API_BARREL_RE $normalizedPath]
    
    # Prüfe ob es testähnlich ist
    set isTestLike [expr {
        [regexp $TEST_LIKE_SEGMENT_RE $normalizedPath] ||
        [regexp $TEST_LIKE_FILENAME_RE $normalizedPath] ||
        [regexp $TEST_SHARED_FILENAME_RE $normalizedPath] ||
        [regexp $TEST_CANARY_FILENAME_RE $normalizedPath] ||
        [regexp $SUFFIX_SKIP_RE $normalizedPath] ||
        [regexp $SNAPSHOT_FILE_RE $normalizedPath] ||
        [regexp $INFRA_NAME_RE $normalizedPath]
    }]
    
    set isInfraArtifact [regexp $INFRA_DIR_RE $normalizedPath]
    
    # Bestimme ob es Produktionsquelle ist
    set isProductionSource [expr {$isCodeFile && !$isRuntimeApiBarrel && !$isTestLike && !$isInfraArtifact}]
    
    # Rückgabe als Dictionary
    return [dict create \
        normalizedPath $normalizedPath \
        isCodeFile $isCodeFile \
        isRuntimeApiBarrel $isRuntimeApiBarrel \
        isPublicApiBarrel $isPublicApiBarrel \
        isTestLike $isTestLike \
        isInfraArtifact $isInfraArtifact \
        isProductionSource $isProductionSource \
    ]
}
