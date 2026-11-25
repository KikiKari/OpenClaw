<?php
// abstraction-provenance: {"artifact_sha256": "f7b2f6107136bed946a6b12e21b934af82aa20942ccc76305a52075e391bd01d", "source_sha256": "f8c56b5aecfa8cd091cc5fe50697c5613148d19f0d4e0eb311bf6d129c600018", "target_language": "php"}
// test_sync_real.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
// auch in: OpenClaw@gateway2:scripts/test_sync_real.py
// auch in: workspace@local:scripts/test_sync_real.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * Test echte Synchronisation
 */

// Füge das Verzeichnis zum Include-Pfad hinzu
set_include_path('/home/openclaw/.openclaw/workspace/scripts' . PATH_SEPARATOR . get_include_path());

// Importiere die benötigten Funktionen
require_once 'sync_clawhub_git.php';

// Test: db-maintainer ClawHub → Git (ECHT)
echo "=== TEST: db-maintainer sync (REAL) ===\n";
$skill = "db-maintainer";
$result = sync_to_git($skill, false); // dry_run = false
echo "Result: " . ($result ? 'SUCCESS' : 'FAILED') . "\n";

// Prüfe Ergebnis
$target = "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer";
if (file_exists($target)) {
    echo "\n✅ Git-Repo erstellt: $target\n";
    
    // Rekursives Durchsuchen des Verzeichnisses
    function listDir($dir, $level = 0) {
        $files = scandir($dir);
        foreach ($files as $file) {
            if ($file === '.' || $file === '..') {
                continue;
            }
            
            $path = $dir . DIRECTORY_SEPARATOR . $file;
            $indent = str_repeat(' ', 2 * $level);
            
            if (is_dir($path)) {
                echo "{$indent}{$file}/\n";
                listDir($path, $level + 1);
            } else {
                $subindent = str_repeat(' ', 2 * ($level + 1));
                echo "{$subindent}{$file}\n";
            }
        }
    }
    
    listDir($target);
}
?>
