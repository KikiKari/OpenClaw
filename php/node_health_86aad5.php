<?php
// abstraction-provenance: {"artifact_sha256": "2e498d2407f9619597d3b8f16cc25f0be5d084387e2fdcef1085a468eba82ae7", "source_sha256": "86aad5ae0d9b77ebdb9a2aaecbf0c4875ad3a241571b573934c882ecd55df14e", "target_language": "php"}
// node_health.py — portiert nach php
// Quelle: python, workspace@local:git/skills/node-health-monitor/scripts/node_health.py
// auch in: workspace@local:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Node Health Monitor - Multi-Node Gesundheitsüberwachung
 */

// Konfiguration
$WORKSPACE = "/home/openclaw/.openclaw/workspace";
$HEALTH_DB = $WORKSPACE . "/db/health.db";
$LOG_FILE = $WORKSPACE . "/logs/node-health.log";

// Node-Definitionen
$NODES = [
    "node1" => ["name" => "Gateway", "host" => "localhost", "user" => "openclaw", "critical" => true],
    "node2" => ["name" => "Node2", "host" => "100.82.198.122", "user" => "root", "ssh_key" => "/root/.ssh/id_ed25519_openclaw_admin"],
    "node3" => ["name" => "Node3", "host" => "100.73.154.125", "user" => "root", "disk_warning" => 85],
    "node4" => ["name" => "Redmi", "host" => "100.94.134.39", "optional" => true, "ssh_enabled" => false],
    "node5" => ["name" => "Lenovo", "host" => "100.103.140.35", "optional" => true, "ssh_enabled" => false],
];

function log_message($message, $level = "INFO") {
    /** Logging */
    global $LOG_FILE;
    $timestamp = date('Y-m-d H:i:s');
    $entry = "[{$timestamp}] [{$level}] {$message}";
    echo $entry . "\n";
    
    $log_dir = dirname($LOG_FILE);
    if (!is_dir($log_dir)) {
        mkdir($log_dir, 0755, true);
    }
    
    file_put_contents($LOG_FILE, $entry . "\n", FILE_APPEND);
}

function check_ping($host, $timeout = 5) {
    /** Prüft Erreichbarkeit */
    $command = "ping -c 1 -W {$timeout} " . escapeshellarg($host);
    $result = shell_exec($command . " 2>&1");
    return strpos($result, "1 received") !== false;
}

function check_ssh($node_config) {
    /** Prüft SSH-Verbindung */
    if (!isset($node_config["ssh_enabled"]) || !$node_config["ssh_enabled"]) {
        return false;
    }
    
    $host = $node_config["host"];
    $user = isset($node_config["user"]) ? $node_config["user"] : "root";
    
    $cmd = "ssh -o ConnectTimeout=10 -o BatchMode=yes";
    if (isset($node_config["ssh_key"])) {
        $key_path = $node_config["ssh_key"];
        if (strpos($key_path, "~") === 0) {
            $key_path = str_replace("~", getenv("HOME"), $key_path);
        }
        $cmd .= " -i " . escapeshellarg($key_path) . " -o IdentitiesOnly=yes";
    }
    $cmd .= " " . escapeshellarg("{$user}@{$host}") . " echo OK 2>&1";
    
    $output = shell_exec($cmd);
    return strpos($output, "OK") !== false;
}

function get_node_metrics($node_config) {
    /** Holt Metriken via SSH */
    $metrics = [
        "timestamp" => date('c'),
        "available" => false,
        "cpu" => null,
        "ram" => null,
        "disk" => null,
        "load" => null
    ];
    
    if (!isset($node_config["ssh_enabled"]) || !$node_config["ssh_enabled"]) {
        return $metrics;
    }
    
    $host = $node_config["host"];
    $user = isset($node_config["user"]) ? $node_config["user"] : "root";
    
    // SSH-Command für alle Metriken
    $remote_cmd = '
        # CPU
        echo "CPU:$(top -bn1 | grep \"Cpu(s)\" | awk \'{print $2}\' | cut -d\"%\" -f1)"
        
        # RAM
        echo "RAM:$(free | grep Mem | awk \'{print ($3/$2) * 100.0}\')"
        
        # Disk
        echo "DISK:$(df -h / | tail -1 | awk \'{print $5}\' | tr -d \"%\")"
        
        # Load
        echo "LOAD:$(uptime | awk -F"load average:" "{print \$2}" | awk \'{print \$1}\' | tr -d ",")"
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            printf "GATEWAY:%s\n" "$(systemctl is-active openclaw-gateway 2>/dev/null || true)"
        fi
    ';
    
    $cmd = "ssh -o ConnectTimeout=10 -o BatchMode=yes";
    if (isset($node_config["ssh_key"])) {
        $key_path = $node_config["ssh_key"];
        if (strpos($key_path, "~") === 0) {
            $key_path = str_replace("~", getenv("HOME"), $key_path);
        }
        $cmd .= " -i " . escapeshellarg($key_path) . " -o IdentitiesOnly=yes";
    }
    $cmd .= " " . escapeshellarg("{$user}@{$host}") . " " . escapeshellarg($remote_cmd) . " 2>&1";
    
    $descriptorspec = [
        0 => ["pipe", "r"],
        1 => ["pipe", "w"],
        2 => ["pipe", "w"]
    ];
    
    $process = proc_open($cmd, $descriptorspec, $pipes);
    
    if (is_resource($process)) {
        fclose($pipes[0]);
        stream_set_timeout($pipes[1], 15);
        $output = stream_get_contents($pipes[1]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        
        $return_value = proc_close($process);
        
        if ($return_value === 0) {
            $metrics["available"] = true;
            
            $lines = explode("\n", trim($output));
            foreach ($lines as $line) {
                if (strpos($line, ':') !== false) {
                    list($key, $value) = explode(':', $line, 2);
                    switch ($key) {
                        case "CPU":
                            $metrics["cpu"] = floatval($value);
                            break;
                        case "RAM":
                            $metrics["ram"] = floatval($value);
                            break;
                        case "DISK":
                            $metrics["disk"] = intval($value);
                            break;
                        case "LOAD":
                            $metrics["load"] = floatval($value);
                            break;
                        case "GATEWAY":
                            $metrics["gateway_status"] = $value;
                            break;
                    }
                }
            }
        }
    }
    
    return $metrics;
}

function check_alerts($node_id, $node_config, $metrics) {
    /** Prüft Schwellwerte und generiert Alerts */
    $alerts = [];
    
    // Verfügbarkeit
    if (!$metrics["available"]) {
        if (!isset($node_config["optional"]) || !$node_config["optional"]) {
            $alerts[] = [
                "level" => "CRITICAL",
                "message" => "Node {$node_config['name']} nicht erreichbar!"
            ];
        }
    } else {
        // CPU
        if ($metrics["cpu"] && $metrics["cpu"] > 90) {
            $alerts[] = [
                "level" => "WARNING",
                "message" => "Node {$node_config['name']}: CPU bei " . number_format($metrics['cpu'], 1) . "%"
            ];
        }
        
        // RAM
        if ($metrics["ram"] && $metrics["ram"] > 90) {
            $alerts[] = [
                "level" => "WARNING", 
                "message" => "Node {$node_config['name']}: RAM bei " . number_format($metrics['ram'], 1) . "%"
            ];
        }
        
        // Disk
        $disk_threshold = isset($node_config["disk_warning"]) ? $node_config["disk_warning"] : 85;
        if ($metrics["disk"] && $metrics["disk"] > $disk_threshold) {
            $level = $metrics["disk"] > 95 ? "CRITICAL" : "WARNING";
            $alerts[] = [
                "level" => $level,
                "message" => "Node {$node_config['name']}: Disk bei {$metrics['disk']}%"
            ];
        }
        
        // Gateway
        if (isset($node_config["critical"]) && $node_config["critical"] && 
            isset($metrics["gateway_status"]) && $metrics["gateway_status"] == "inactive") {
            $alerts[] = [
                "level" => "CRITICAL",
                "message" => "Node {$node_config['name']}: OpenClaw Gateway nicht aktiv!"
            ];
        }
    }
    
    return $alerts;
}

function send_alert($alert) {
    /** Sendet Alert via channel-status-agent */
    global $WORKSPACE;
    try {
        $cmd = "python3 " . escapeshellarg($WORKSPACE . "/skills/channel-status-agent/scripts/channel_status.py") .
               " --type alert --message " . escapeshellarg("{$alert['level']}: {$alert['message']}");
        shell_exec($cmd);
        log_message("Alert sent: {$alert['message']}");
    } catch (Exception $e) {
        log_message("Failed to send alert: " . $e->getMessage(), "ERROR");
    }
}

function main() {
    /** Hauptfunktion */
    global $NODES;
    
    $options = getopt("", ["node:", "check:", "alert"]);
    
    $node_arg = isset($options["node"]) ? $options["node"] : "all";
    $check_arg = isset($options["check"]) ? $options["check"] : "all";
    $send_alerts = isset($options["alert"]);
    
    // Nodes bestimmen
    if ($node_arg === "all") {
        $nodes_to_check = $NODES;
    } else {
        if (array_key_exists($node_arg, $NODES)) {
            $nodes_to_check = [$node_arg => $NODES[$node_arg]];
        } else {
            log_message("Unknown node: {$node_arg}", "ERROR");
            exit(1);
        }
    }
    
    // Health-Checks durchführen
    $all_alerts = [];
    
    foreach ($nodes_to_check as $node_id => $node_config) {
        log_message("Checking {$node_config['name']} ({$node_id})");
        
        // Ping
        if (in_array($check_arg, ["ping", "all"])) {
            if ($node_config["host"] !== "localhost") {
                $ping_ok = check_ping($node_config["host"]);
                log_message("  Ping: " . ($ping_ok ? "OK" : "FAILED"));
            }
        }
        
        // SSH
        if (in_array($check_arg, ["ssh", "all"])) {
            if (!isset($node_config["ssh_enabled"]) || !$node_config["ssh_enabled"]) {
                log_message("  SSH: SKIPPED (nicht konfiguriert)");
            } else {
                $ssh_ok = check_ssh($node_config);
                log_message("  SSH: " . ($ssh_ok ? "OK" : "FAILED"));
            }
        }
        
        // Metriken
        if (in_array($check_arg, ["metrics", "all"])) {
            $metrics = get_node_metrics($node_config);
            
            if ($metrics["available"]) {
                log_message("  CPU: " . ($metrics["cpu"] ? number_format($metrics["cpu"], 1) . "%" : "N/A"));
                log_message("  RAM: " . ($metrics["ram"] ? number_format($metrics["ram"], 1) . "%" : "N/A"));
                log_message("  Disk: " . ($metrics["disk"] ? $metrics["disk"] . "%" : "N/A"));
                log_message("  Load: " . ($metrics["load"] ? $metrics["load"] : "N/A"));
            } else {
                log_message("  Metrics: UNAVAILABLE");
            }
            
            // Alerts prüfen
            $alerts = check_alerts($node_id, $node_config, $metrics);
            $all_alerts = array_merge($all_alerts, $alerts);
        }
    }
    
    // Alerts senden
    if ($send_alerts && count($all_alerts) > 0) {
        log_message("\nSending " . count($all_alerts) . " alerts...");
        foreach ($all_alerts as $alert) {
            send_alert($alert);
        }
    } elseif (count($all_alerts) > 0) {
        log_message("\n" . count($all_alerts) . " alerts found (use --alert to send)");
    } else {
        log_message("\nPrüfung abgeschlossen; Details und nicht verfügbare Prüfungen siehe oben.");
    }
}

main();
?>
