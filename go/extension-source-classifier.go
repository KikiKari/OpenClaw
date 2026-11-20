// abstraction-provenance: {"artifact_sha256": "44efda39834f26f9d84a17ac7d38fe79b2505aeb355ac9a1d19b0ac5ad2b7a45", "source_sha256": "13d5446c5e30146c4173cad6e5ecff0482c7febec4cd8586ae04dff1eaf2417b", "target_language": "go"}
// extension-source-classifier.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-source-classifier.mjs
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py


package main

import (
	"fmt"
	"path/filepath"
	"regexp"
	"strings"
)

var (
	codeFileRe           = regexp.MustCompile(`\.(?:[cm]?ts|[cm]?js|tsx|jsx)$`)
	declarationFileRe    = regexp.MustCompile(`\.d\.ts$`)
	runtimeAPIBarrelRe   = regexp.MustCompile(`(^|/)runtime-api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$`)
	publicAPIBarrelRe    = regexp.MustCompile(`(^|/)api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$`)
	testLikeSegmentRe    = regexp.MustCompile(`(^|/)(?:__tests__|fixtures|test|tests|test-fixtures|test-support|test-utils)(?:/|$)`)
	testLikeFilenameRe   = regexp.MustCompile(`(^|/)[^/]*test-(?:support|helpers|fixtures|harness)\.(?:[cm]?ts|[cm]?js|tsx|jsx)$`)
	testSharedFilenameRe = regexp.MustCompile(`(^|/)[^/]*\.test-[^/]*\.(?:[cm]?ts|[cm]?js|tsx|jsx)$`)
	testCanaryFilenameRe = regexp.MustCompile(`(^|/)__rootdir_boundary_canary__\.(?:[cm]?ts|[cm]?js|tsx|jsx)$`)
	snapshotFileRe       = regexp.MustCompile(`\.snap$`)
	suffixSkipRe         = regexp.MustCompile(`\.(?:test|spec|fixture)\.`)
	infraDirRe           = regexp.MustCompile(`(^|/)(?:coverage|dist|node_modules)(?:/|$)`)
	infraNameRe          = regexp.MustCompile(`(test-harness|test-support|test-helpers|test-fixtures)`)
)

func normalizeExtensionSourcePath(filePath string) string {
	return strings.ReplaceAll(filePath, "\\", "/")
}

type ClassificationResult struct {
	NormalizedPath      string
	IsCodeFile          bool
	IsRuntimeApiBarrel  bool
	IsPublicApiBarrel   bool
	IsTestLike          bool
	IsInfraArtifact     bool
	IsProductionSource  bool
}

func classifyBundledExtensionSourcePath(filePath string) ClassificationResult {
	normalizedPath := normalizeExtensionSourcePath(filePath)
	isCodeFile := codeFileRe.MatchString(normalizedPath) && !declarationFileRe.MatchString(normalizedPath)
	isRuntimeApiBarrel := runtimeAPIBarrelRe.MatchString(normalizedPath)
	isPublicApiBarrel := publicAPIBarrelRe.MatchString(normalizedPath)
	isTestLike := testLikeSegmentRe.MatchString(normalizedPath) ||
		testLikeFilenameRe.MatchString(normalizedPath) ||
		testSharedFilenameRe.MatchString(normalizedPath) ||
		testCanaryFilenameRe.MatchString(normalizedPath) ||
		suffixSkipRe.MatchString(normalizedPath) ||
		snapshotFileRe.MatchString(normalizedPath) ||
		infraNameRe.MatchString(normalizedPath)
	isInfraArtifact := infraDirRe.MatchString(normalizedPath)
	isProductionSource := isCodeFile && !isRuntimeApiBarrel && !isTestLike && !isInfraArtifact

	return ClassificationResult{
		NormalizedPath:      normalizedPath,
		IsCodeFile:          isCodeFile,
		IsRuntimeApiBarrel:  isRuntimeApiBarrel,
		IsPublicApiBarrel:   isPublicApiBarrel,
		IsTestLike:          isTestLike,
		IsInfraArtifact:     isInfraArtifact,
		IsProductionSource:  isProductionSource,
	}
}

func main() {
	// This is a library file, so we don't need a main function
	// but Go requires one to compile
	fmt.Println("This is a library file for classification of extension source paths")
}
