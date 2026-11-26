<?php
// abstraction-provenance: {"artifact_sha256": "962b9f696e5d4a14ecced47f169ecaee73866471086027610ac0a01643c7e669", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "php"}
// run_sync_agent.py — portiert nach php
// Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Sandbox-Wrapper für sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace.
 */

// Setze die Pfade in die Include-Pfadliste
set_include_path("/workspace/scripts" . PATH_SEPARATOR . 
                 "/workspace/skills/clawhub-git-sync-agent/scripts" . PATH_SEPARATOR . 
                 get_include_path());

// Definiere die Konstanten für das sync_agent-Skript
define('CLAWHUB_DIR', '/workspace/skills');
define('GIT_DIR', '/workspace/git/skills');
define('STATE_FILE', '/workspace/db/sync_state.json');

// Führe die Hauptfunktion aus
// In PHP müsste das entsprechende Skript eingebunden werden
require_once 'sync_agent.php';

// Da PHP keine direkte Übersetzung von Python-Modulen ist,
// wird hier angenommen, dass sync_agent.php eine main()-Funktion enthält
if (function_exists('main')) {
    main();
}
?>
