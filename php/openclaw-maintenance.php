<?php
// abstraction-provenance: {"artifact_sha256": "9f2e6f9571dc2c3bab10000400c2f989a09981bc8504f7c40f258e060c2980ff", "source_sha256": "2a9ca592fdc915cfb281aa77dde9f07ffd3de83ce5abb8d87c77d46668d75dd6", "target_language": "php"}
// openclaw-maintenance.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-maintenance.sh
// auch in: workspace@local:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
// === 1. Service-/Config-Drift ===
shell_exec('openclaw doctor');

// === 2. Plugin-Stage (aktive Varianten, NICHT plugins doctor) ===
shell_exec('openclaw plugins registry --refresh');
shell_exec('openclaw plugins update --all');

// === 3. Tasks ===
shell_exec('openclaw tasks maintenance --apply');

// === 4. Sessions – alle Agents auf einmal ===
shell_exec('openclaw sessions cleanup --enforce --all-agents');

// === 5. Memory – status/index decken alle Agents ab ===
shell_exec('openclaw memory status --deep --fix');
shell_exec('openclaw memory index --force');

// === 6. Memory promote – MUSS pro Agent ===
$agents = ['main', 'knecht', 'docs', 'ops-hub', 'cron'];
foreach ($agents as $agent) {
    shell_exec("openclaw memory promote --apply --agent \"$agent\"");
}

// === 7. Secrets ===
shell_exec('openclaw secrets reload');

?>
