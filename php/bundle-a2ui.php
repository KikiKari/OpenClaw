<?php
// abstraction-provenance: {"artifact_sha256": "e1d113afbf8a659ddd49f1163e48d5c8f1fd938dbcf6eb664074aebf9849337e", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "php"}
// bundle-a2ui.sh — portiert nach php
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
$rootDir = dirname(__DIR__);
$scriptPath = $rootDir . '/scripts/bundle-a2ui.mjs';

// Forward all arguments to the Node.js script
$args = implode(' ', array_map('escapeshellarg', array_slice($argv, 1)));
$command = "node " . escapeshellarg($scriptPath) . " " . $args;

passthru($command, $returnCode);
exit($returnCode);
