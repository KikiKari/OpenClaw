<?php
// abstraction-provenance: {"artifact_sha256": "6db866a5f8931acf3b1a4a124e9dc6dec1923487eb4b5d2931403c8e3cf37bf6", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "php"}
// serve_compare_transfer.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
// auch in: workspace@local:scripts/serve_compare_transfer.sh
// auch in: workspace@local:vscode/compare/transfer/serve_compare_transfer.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
$COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
$TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
$HOST_IP = "152.53.145.65";
$PORT = "80";
$SELF_PATH = __FILE__;

// Finde alle Dateien im Vergleichsverzeichnis, aber nicht dieses Skript selbst
$files = [];
$iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($COMPARE_DIR, RecursiveDirectoryIterator::SKIP_DOTS));
foreach ($iterator as $file) {
    if ($file->isFile() && $file->getPathname() !== $SELF_PATH) {
        $files[] = $file->getPathname();
    }
}

// Sortiere die Dateien
sort($files);

if (count($files) === 0) {
    echo "Keine Dateien in {$COMPARE_DIR} gefunden.\n";
    exit(1);
}

echo "\nBereitgestellte Dateien aus {$COMPARE_DIR}:\n";
foreach ($files as $src) {
    echo "- " . basename($src) . "\n";
}

echo "\nCopy/Paste auf anderem Gateway (Download nach {$TRANSFER_DIR}):\n";
foreach ($files as $src) {
    $file = basename($src);
    echo "curl -fL --retry 3 --connect-timeout 10 -o {$TRANSFER_DIR}/{$file} http://{$HOST_IP}:{$PORT}/{$file}\n";
}

echo "\nServer auf Port {$PORT} aktiv. Beenden mit STRG+C.\n\n";

// Starte den HTTP-Server
chdir($COMPARE_DIR);
$command = "python3 -m http.server {$PORT} --bind 0.0.0.0";
passthru($command, $return_code);
exit($return_code);
