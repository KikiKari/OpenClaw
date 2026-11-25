<?php
// abstraction-provenance: {"artifact_sha256": "d00e39fb1c20d3bb7bc17b3ab7fa62eaf7e7a3a2ad8bbcec840ad5bd700bcbcc", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "php"}
// translation-worker-node5.ps1 — portiert nach php
// Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
// Validate action parameter
$action = $argv[1] ?? null;
if (!in_array($action, ['prepare', 'run'])) {
    fwrite(STDERR, "Usage: php translation-worker.php <prepare|run>\n");
    exit(1);
}

// Set error reporting to stop on errors
set_error_handler(function($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

// Windows does not use chmod. The Python worker and Python 3 must already be
// installed locally; no credentials are copied or placed on a command line.
$worker = $_SERVER['USERPROFILE'] . '\\.openclaw\\workers\\translation_worker.py';
$expected = '9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b';

// Check if worker exists
if (!file_exists($worker)) {
    fwrite(STDERR, "Worker missing: $worker\n");
    exit(1);
}

// Check if it's a symlink (reparse point)
if (is_link($worker)) {
    fwrite(STDERR, "Worker link rejected\n");
    exit(1);
}

// Verify checksum
$actual = hash_file('sha256', $worker);
if (strtolower($actual) !== $expected) {
    fwrite(STDERR, "Worker checksum mismatch\n");
    exit(1);
}

if ($action === 'prepare') {
    echo "Worker verified: $worker\n";
    exit(0);
}

// Find python executable
$python = trim(shell_exec('where python.exe'));
if (empty($python)) {
    fwrite(STDERR, "Python executable not found\n");
    exit(1);
}

// Execute the worker
$command = escapeshellarg($python) . ' ' . escapeshellarg($worker);
passthru($command, $return_code);
exit($return_code);
