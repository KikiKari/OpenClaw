<?php
// abstraction-provenance: {"artifact_sha256": "98cf110f611db4b8574dbb8665d74b0f76d1092d6e7a114fdbffbdc7246d09d1", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "php"}
// openclaw-maintenance.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
declare(strict_types=1);

// Setzen der Umgebungsvariablen und Standardwerte
$openclawBin = getenv('OPENCLAW_BIN') ?: $_SERVER['HOME'] . '/.local/bin/openclaw';

// Prüfen ob die Binary existiert und ausführbar ist
if (!file_exists($openclawBin) || !is_executable($openclawBin)) {
    fwrite(STDERR, "ERROR: OpenClaw binary not found: $openclawBin\n");
    exit(1);
}

// Version ausgeben
echo "Using OpenClaw: " . executeCommand("$openclawBin --version") . "\n";

// === 1. Service-/Config-Drift ===
executeCommand("$openclawBin doctor");

// === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
executeCommand("$openclawBin plugins registry --refresh");

$runPluginUpdate = getenv('RUN_PLUGIN_UPDATE') ?: '0';
if ($runPluginUpdate === '1') {
    executeCommand("$openclawBin plugins update --all");
} else {
    echo "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.\n";
}

// === 3. Tasks ===
executeCommand("$openclawBin tasks maintenance --apply");

// === 4. Sessions – alle Agents auf einmal ===
executeCommand("$openclawBin sessions cleanup --enforce --all-agents");

// === 5. Memory – status/index decken alle Agents ab ===
executeCommand("$openclawBin memory status --deep --fix");
executeCommand("$openclawBin memory index --force");

// === 6. Memory promote – MUSS pro Agent ===
$agents = ['main', 'knecht', 'docs', 'ops-hub', 'cron'];
foreach ($agents as $agent) {
    executeCommand("$openclawBin memory promote --apply --agent $agent");
}

// === 7. Secrets ===
executeCommand("$openclawBin secrets reload");

/**
 * Führt einen Shell-Befehl aus und gibt die Ausgabe zurück
 *
 * @param string $command Der auszuführende Befehl
 * @return string Die Ausgabe des Befehls
 */
function executeCommand(string $command): string
{
    $output = [];
    $resultCode = 0;
    exec($command, $output, $resultCode);
    
    if ($resultCode !== 0 && strpos($command, '--version') === false) {
        fwrite(STDERR, "Command failed: $command\n");
        exit($resultCode);
    }
    
    return implode("\n", $output);
}
?>
