<?php
// abstraction-provenance: {"artifact_sha256": "5138a78392c70f74bae2dc792271ca2047aabae04e85080a5739e4406e6a549b", "source_sha256": "daf78be577ece366a1908ac16ff31d6e57298b1256bb88185a5bc1cf5294a804", "target_language": "php"}
// test_sync.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:scripts/test_sync.py
// auch in: OpenClaw@gateway2:scripts/test_sync.py
// auch in: workspace@local:scripts/test_sync.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * Test für Sync-Script
 */

// Füge den Pfad zum Suchpfad hinzu
set_include_path('/home/openclaw/.openclaw/workspace/scripts');

// Importiere die Funktionen aus sync_clawhub_git.php
require_once 'sync_clawhub_git.php';

// Test: db-maintainer ClawHub → Git (DRY-RUN)
echo "=== TEST: db-maintainer sync (DRY-RUN) ===\n";
$skill = "db-maintainer";
$result = sync_to_git($skill, true);
echo "Result: " . ($result ? 'SUCCESS' : 'FAILED') . "\n";
echo "\n=== LOG-Inhalt ===\n";
$logContent = file_get_contents("/home/openclaw/.openclaw/workspace/logs/sync.log");
echo $logContent;
?>
