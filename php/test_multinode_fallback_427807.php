<?php
// abstraction-provenance: {"artifact_sha256": "6f7627b92fd99d35d51c6f77cdc29d656eda686ccfcd65b248945a1906b1b855", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "php"}
// test_multinode_fallback.py — portiert nach php
// Quelle: python, workspace@local:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * Testet Multi-Node Fallback-Logik des db-maintainer
 * Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
 */

$WORKSPACE = "/home/openclaw/.openclaw/workspace";

function check_node_reachable($node_id) {
    /** Prüft den Verbindungseintrag dieses Nodes, nicht die Gesamtausgabe. */
    $aliases = [strtolower($node_id)];
    $node2_names = ["openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net"];
    if (in_array(strtolower($node_id), array_map('strtolower', $node2_names))) {
        $aliases = array_merge($aliases, $node2_names);
    }
    try {
        $descriptorspec = [
           0 => ["pipe", "r"],
           1 => ["pipe", "w"],
           2 => ["pipe", "w"]
        ];
        $process = proc_open(['openclaw', 'nodes', 'status', '--json'], $descriptorspec, $pipes);
        if (is_resource($process)) {
            fclose($pipes[0]);
            $output = stream_get_contents($pipes[1]);
            fclose($pipes[1]);
            $error = stream_get_contents($pipes[2]);
            fclose($pipes[2]);
            $return_value = proc_close($process);
            if ($return_value === 0) {
                $payload = json_decode($output, true);
                if (is_array($payload) && isset($payload['nodes']) && is_array($payload['nodes'])) {
                    foreach ($payload['nodes'] as $node) {
                        if (is_array($node) && 
                            isset($node['displayName']) && 
                            in_array(strtolower($node['displayName']), array_map('strtolower', $aliases)) &&
                            isset($node['connected']) && 
                            $node['connected'] === true) {
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    } catch (Exception $e) {
        return false;
    }
}

function spawn_on_node($node_id, $task) {
    /** Versucht Task auf Node auszuführen */
    echo "Versuche Task auf Node $node_id zu starten...\n";
    try {
        // Simuliert: openclaw agent spawn --node {node_id}
        $descriptorspec = [
           0 => ["pipe", "r"],
           1 => ["pipe", "w"],
           2 => ["pipe", "w"]
        ];
        $process = proc_open(['echo', "Spawned on $node_id: $task"], $descriptorspec, $pipes);
        if (is_resource($process)) {
            fclose($pipes[0]);
            $output = stream_get_contents($pipes[1]);
            fclose($pipes[1]);
            $error = stream_get_contents($pipes[2]);
            fclose($pipes[2]);
            $return_value = proc_close($process);
            if ($return_value === 0) {
                echo "✅ Erfolgreich delegiert an $node_id\n";
                return true;
            } else {
                echo "❌ Node $node_id nicht erreichbar: $error\n";
                return false;
            }
        } else {
            echo "❌ Node $node_id nicht erreichbar\n";
            return false;
        }
    } catch (Exception $e) {
        echo "❌ Node $node_id nicht erreichbar: " . $e->getMessage() . "\n";
        return false;
    }
}

function execute_locally($task) {
    /** Führt Task lokal aus (Fallback) */
    global $WORKSPACE;
    echo "🔄 Fallback: Führe Task lokal aus...\n";
    try {
        if ($task == 'db_maintainer') {
            $script_path = $WORKSPACE . '/skills/db-maintainer/scripts/db_maintainer.py';
            $descriptorspec = [
               0 => ["pipe", "r"],
               1 => ["pipe", "w"],
               2 => ["pipe", "w"]
            ];
            $process = proc_open(['python3', $script_path], $descriptorspec, $pipes);
            if (is_resource($process)) {
                fclose($pipes[0]);
                $output = stream_get_contents($pipes[1]);
                fclose($pipes[1]);
                $error = stream_get_contents($pipes[2]);
                fclose($pipes[2]);
                $return_value = proc_close($process);
                if ($return_value === 0) {
                    echo "✅ Lokale Ausführung erfolgreich\n";
                    return true;
                } else {
                    echo "❌ Fehler: " . substr($error, 0, 200) . "\n";
                    return false;
                }
            } else {
                echo "❌ Fehler beim Starten des lokalen Prozesses\n";
                return false;
            }
        }
    } catch (Exception $e) {
        echo "❌ Lokale Ausführung fehlgeschlagen: " . $e->getMessage() . "\n";
        return false;
    }
    return false;
}

function main() {
    echo str_repeat("=", 60) . "\n";
    echo "MULTI-NODE FALLBACK TEST\n";
    echo str_repeat("=", 60) . "\n\n";
    
    // Konfiguration
    $primary_node = 'v2202604104722449961.taild25fea.ts.net';  // Node 2
    $task = 'db_maintainer';
    
    echo "Primärer Node: $primary_node\n";
    echo "Task: $task\n\n";
    
    // 1. Prüfe Node-Erreichbarkeit
    echo "--- 1. Prüfe Node-Erreichbarkeit ---\n";
    if (check_node_reachable($primary_node)) {
        echo "✅ Node $primary_node ist erreichbar\n";
        
        // 2. Versuche Delegation
        echo "\n--- 2. Versuche Delegation ---\n";
        if (spawn_on_node($primary_node, $task)) {
            echo "\n✅ MULTI-NODE: Task erfolgreich delegiert\n";
            return 0;
        } else {
            echo "\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...\n";
        }
    } else {
        echo "❌ Node $primary_node nicht erreichbar\n";
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
