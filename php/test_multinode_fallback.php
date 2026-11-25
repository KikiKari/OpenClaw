<?php
// abstraction-provenance: {"artifact_sha256": "63f0c71becb97a13587f5cbd71b52aadfa6f323c60a7d2d46d7b7271b6061374", "source_sha256": "52b3516148b12072bbff77599a6faac284607fbc005a73f93c2b7f4f349cf6f1", "target_language": "php"}
// test_multinode_fallback.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:scripts/test_multinode_fallback.py
// auch in: OpenClaw@gateway2:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * Testet Multi-Node Fallback-Logik des db-maintainer
 * Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
 */

$WORKSPACE = "/home/openclaw/.openclaw/workspace";

function check_node_reachable($node_id) {
    /** Prüft ob Node erreichbar ist */
    try {
        // Versuche Node-Status abzufragen
        $output = [];
        $return_code = 0;
        exec('openclaw nodes status 2>&1', $output, $return_code);
        $output_str = implode("\n", $output);
        return strpos($output_str, $node_id) !== false && strpos($output_str, 'connected') !== false;
    } catch (Exception $e) {
        return false;
    }
}

function spawn_on_node($node_id, $task) {
    /** Versucht Task auf Node auszuführen */
    echo "Versuche Task auf Node {$node_id} zu starten...\n";
    try {
        // Simuliert: openclaw agent spawn --node {node_id}
        $output = [];
        $return_code = 0;
        exec("echo 'Spawned on {$node_id}: {$task}' 2>&1", $output, $return_code);
        echo "✅ Erfolgreich delegiert an {$node_id}\n";
        return true;
    } catch (Exception $e) {
        echo "❌ Node {$node_id} nicht erreichbar: {$e->getMessage()}\n";
        return false;
    }
}

function execute_locally($task) {
    /** Führt Task lokal aus (Fallback) */
    global $WORKSPACE;
    echo "🔄 Fallback: Führe Task lokal aus...\n";
    try {
        if ($task === 'db_maintainer') {
            $cmd = "python3 " . escapeshellarg($WORKSPACE . '/skills/db-maintainer/scripts/db_maintainer.py');
            $output = [];
            $return_code = 0;
            exec($cmd . " 2>&1", $output, $return_code);
            $output_str = implode("\n", $output);
            if ($return_code === 0) {
                echo "✅ Lokale Ausführung erfolgreich\n";
                return true;
            } else {
                echo "❌ Fehler: " . substr($output_str, 0, 200) . "\n";
                return false;
            }
        }
    } catch (Exception $e) {
        echo "❌ Lokale Ausführung fehlgeschlagen: {$e->getMessage()}\n";
        return false;
    }
    return false;
}

function main() {
    echo str_repeat("=", 60) . "\n";
    echo "MULTI-NODE FALLBACK TEST\n";
    echo str_repeat("=", 60) . "\n\n";
    
    // Konfiguration
    $primary_node = 'v2202603104722445775';  // Node 2
    $task = 'db_maintainer';
    
    echo "Primärer Node: {$primary_node}\n";
    echo "Task: {$task}\n\n";
    
    // 1. Prüfe Node-Erreichbarkeit
    echo "--- 1. Prüfe Node-Erreichbarkeit ---\n";
    if (check_node_reachable($primary_node)) {
        echo "✅ Node {$primary_node} ist erreichbar\n";
        
        // 2. Versuche Delegation
        echo "\n--- 2. Versuche Delegation ---\n";
        if (spawn_on_node($primary_node, $task)) {
            echo "\n✅ MULTI-NODE: Task erfolgreich delegiert\n";
            return 0;
        } else {
            echo "\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...\n";
        }
    } else {
        echo "❌ Node {$primary_node} nicht erreichbar\n";
        echo "🔄 Fallback wird aktiviert...\n";
    }
    
    // 3. Lokale Ausführung (Fallback)
    echo "\n--- 3. Lokale Ausführung (Fallback) ---\n";
    if (execute_locally($task)) {
        echo "\n✅ FALLBACK: Task lokal erfolgreich ausgeführt\n";
        return 0;
    } else {
        echo "\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich\n";
        return 1;
    }
}

exit(main());
?>
