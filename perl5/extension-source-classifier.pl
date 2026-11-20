#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "3807e0e11f3a91a8e25ec1b75feb1027262a0ad315b36e4342d87f3dfcd33551", "source_sha256": "13d5446c5e30146c4173cad6e5ecff0482c7febec4cd8586ae04dff1eaf2417b", "target_language": "perl5"}
# extension-source-classifier.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/extension-source-classifier.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Reguläre Ausdrücke
my $CODE_FILE_RE = qr/\.(?:[cm]?ts|[cm]?js|tsx|jsx)$/u;
my $DECLARATION_FILE_RE = qr/\.d\.ts$/u;
my $RUNTIME_API_BARREL_RE = qr/(^|\/)runtime-api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$/u;
my $PUBLIC_API_BARREL_RE = qr/(^|\/)api\.(?:[cm]?ts|[cm]?js|tsx|jsx)$/u;
my $TEST_LIKE_SEGMENT_RE = qr/(^|\/)(?:__tests__|fixtures|test|tests|test-fixtures|test-support|test-utils)(?:\/|$)/u;
my $TEST_LIKE_FILENAME_RE = qr/(^|\/)[^\/]*test-(?:support|helpers|fixtures|harness)\.(?:[cm]?ts|[cm]?js|tsx|jsx)$/u;
my $TEST_SHARED_FILENAME_RE = qr/(^|\/)[^\/]*\.test-[^\/]*\.(?:[cm]?ts|[cm]?js|tsx|jsx)$/u;
my $TEST_CANARY_FILENAME_RE = qr/(^|\/)__rootdir_boundary_canary__\.(?:[cm]?ts|[cm]?js|tsx|jsx)$/u;
my $SNAPSHOT_FILE_RE = qr/\.snap$/u;
my $SUFFIX_SKIP_RE = qr/\.(?:test|spec|fixture)\./u;
my $INFRA_DIR_RE = qr/(^|\/)(?:coverage|dist|node_modules)(?:\/|$)/u;
my $INFRA_NAME_RE = qr/(test-harness|test-support|test-helpers|test-fixtures)/u;

sub normalizeExtensionSourcePath {
    my ($filePath) = @_;
    $filePath =~ s/\\/\//g;
    return $filePath;
}

sub classifyBundledExtensionSourcePath {
    my ($filePath) = @_;
    my $normalizedPath = normalizeExtensionSourcePath($filePath);
    
    my $isCodeFile = ($normalizedPath =~ /$CODE_FILE_RE/) && !($normalizedPath =~ /$DECLARATION_FILE_RE/);
    my $isRuntimeApiBarrel = $normalizedPath =~ /$RUNTIME_API_BARREL_RE/;
    my $isPublicApiBarrel = $normalizedPath =~ /$PUBLIC_API_BARREL_RE/;
    my $isTestLike = 
        ($normalizedPath =~ /$TEST_LIKE_SEGMENT_RE/) ||
        ($normalizedPath =~ /$TEST_LIKE_FILENAME_RE/) ||
        ($normalizedPath =~ /$TEST_SHARED_FILENAME_RE/) ||
        ($normalizedPath =~ /$TEST_CANARY_FILENAME_RE/) ||
        ($normalizedPath =~ /$SUFFIX_SKIP_RE/) ||
        ($normalizedPath =~ /$SNAPSHOT_FILE_RE/) ||
        ($normalizedPath =~ /$INFRA_NAME_RE/);
    my $isInfraArtifact = $normalizedPath =~ /$INFRA_DIR_RE/;
    
    my $isProductionSource = $isCodeFile && !$isRuntimeApiBarrel && !$isTestLike && !$isInfraArtifact;
    
    return {
        normalizedPath => $normalizedPath,
        isCodeFile => $isCodeFile,
        isRuntimeApiBarrel => $isRuntimeApiBarrel,
        isPublicApiBarrel => $isPublicApiBarrel,
        isTestLike => $isTestLike,
        isInfraArtifact => $isInfraArtifact,
        isProductionSource => $isProductionSource,
    };
}

# Export-Funktionen (simuliert)
sub get_normalizeExtensionSourcePath { \&normalizeExtensionSourcePath }
sub get_classifyBundledExtensionSourcePath { \&classifyBundledExtensionSourcePath }

1;
