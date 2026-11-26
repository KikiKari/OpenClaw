<?php
// abstraction-provenance: {"artifact_sha256": "666ad6ad524d4b7658b1b9175881d611099a032baa6778ec7da9e5603a184eeb", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "php"}
// node_health.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Node Health Monitor - Multi-Node Gesundheitsüberwachung
 */

// Konfiguration
define('WORKSPACE', '/home/openclaw/.openclaw/workspace');
define('HEALTH_DB', WORKSPACE . '/db/health.db');
define('LOG_FILE', WORKSPACE . '/logs/node-health.log');

// Node-Definitionen
$NODES = [
    "node1" => [
        "name" => "Gateway",
        "host" => "localhost",
        "user" => "openclaw",
        "critical" => true
    ],
    "node2" => [
        "name" => "Worker", 
        "host" => "100.92.155.34",
        "user" => "root",
        "ssh_key" => "~/.ssh/id_rsa"
    ],
    "node3" => [
        "name" => "Relay",
        "host" => "185.242.xxx.xxx",
        "user" => "root",
        "disk_warning" => 85
    ],
    "node5" => [
        "name" => "Redmi",
        "host" => "192.168.1.x",
        "user" => "openclaw",
        "optional" => true
    ]
];

function logMessage($message, $level = "INFO") {
    /** Logging */
    $timestamp = date('Y-m-d H:i:s');
    $entry = "[{$timestamp}] [{$level}] {$message}";
    echo $entry . "\n";
    
    $logDir = dirname(LOG_FILE);
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }
    
    file_put_contents(LOG_FILE, $entry . "\n", FILE_APPEND | LOCK_EX);
}

function checkPing($host, $timeout = 5) {
    /** Prüft Erreichbarkeit */
    $command = "ping -c 1 -W {$timeout} " . escapeshellarg($host);
    exec($command, $output, $returnCode);
    return $returnCode === 0;
}

function checkSSH($nodeConfig) {
    /** Prüft SSH-Verbindung */
    $host = $nodeConfig["host"];
    $user = isset($nodeConfig["user"]) ? $nodeConfig["user"] : "root";
    
    $cmd = "ssh -o ConnectTimeout=10 -o BatchMode=yes " . escapeshellarg("{$user}@{$host}") . " echo \"OK\"";
    exec($cmd, $output, $returnCode);
    $outputStr = implode("\n", $output);
    return $returnCode === 0 && strpos($outputStr, "OK") !== false;
}

function getNodeMetrics($nodeConfig) {
    /** Holt Metriken via SSH */
    $host = $nodeConfig["host"];
    $user = isset($nodeConfig["user"]) ? $nodeConfig["user"] : "root";
    
    $metrics = [
        "timestamp" => date('c'),
        "available" => false,
        "cpu" => null,
        "ram" => null,
        "disk" => null,
        "load" => null
    ];
    
    // SSH-Command für alle Metriken
    $cmd = "ssh -o ConnectTimeout=10 " . escapeshellarg("{$user}@{$host}") . " '
        # CPU
        echo \"CPU:\"$(top -bn1 | grep \"Cpu(s)\" | awk \"{print \$2}\" | cut -d\"%\" -f1)
        
        # RAM
        echo \"RAM:\"$(free | grep Mem | awk \"{print (\$3/\$2) * 100.0}\")
        
        # Disk
        echo \"DISK:\"$(df -h / | tail -1 | awk \"{print \$5}\" | tr -d \"%\")
        
        # Load
        echo \"LOAD:\"$(uptime | awk -F\"load average:\" \"{print \$2}\" | awk \"{print \$1}\" | tr -d \",\")
        
        # Gateway Status
        if command -v openclaw >/dev/null 2>&1; then
            systemctl is-active openclaw-gateway 2>/dev/null || echo \"GATEWAY:inactive\"
        fi
    '";
    
    $descriptorspec = [
        1 => ["pipe", "w"],
        2 => ["pipe", "w"]
    ];
    
    $process = proc_open($cmd, $descriptorspec, $pipes);
    
    if (is_resource($process)) {
        $output = stream_get_contents($pipes[1]);
        fclose($pipes[1]);
        
        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);
        
        $returnCode = proc_close($process);
        
        if ($returnCode === 0) {
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
    } else {
        logMessage("Failed to start process for {$nodeConfig['name']}", "ERROR");
    }
    
    return $metrics;
}

function checkAlerts($nodeId, $nodeConfig, $metrics) {
    /** Prüft Schwellwerte und generiert Alerts */
    $alerts = [];
    
    // Verfügbarkeit
    if (!$metrics["available"]) {
        if (!isset($nodeConfig["optional"]) || !$nodeConfig["optional"]) {
            $alerts[] = [
                "level" => "CRITICAL",
                "message" => "Node {$nodeConfig['name']} nicht erreichbar!"
            ];
        }
    } else {
        // CPU
        if ($metrics["cpu"] !== null && $metrics["cpu"] > 90) {
            $alerts[] = [
                "level" => "WARNING",
                "message" => "Node {$nodeConfig['name']}: CPU bei " . number_format($metrics['cpu'], 1) . "%"
            ];
        }
        
        // RAM
        if ($metrics["ram"] !== null && $metrics["ram"] > 90) {
            $alerts[] = [
                "level" => "WARNING", 
                "message" => "Node {$nodeConfig['name']}: RAM bei " . number_format($metrics['ram'], 1) . "%"
            ];
        }
        
        // Disk
        $diskThreshold = isset($nodeConfig["disk_warning"]) ? $nodeConfig["disk_warning"] : 85;
        if ($metrics["disk"] !== null && $metrics["disk"] > $diskThreshold) {
            $level = $metrics["disk"] > 95 ? "CRITICAL" : "WARNING";
            $alerts[] = [
                "level" => $level,
                "message" => "Node {$nodeConfig['name']}: Disk bei {$metrics['disk']}%"
            ];
        }
        
        // Gateway
        if (isset($nodeConfig["critical"]) && $nodeConfig["critical"] && 
            isset($metrics["gateway_status"]) && $metrics["gateway_status"] === "inactive") {
            $alerts[] = [
                "level" => "CRITICAL",
                "message" => "Node {$nodeConfig['name']}: OpenClaw Gateway nicht aktiv!"
            ];
        }
    }
    
    return $alerts;
}

function sendAlert($alert) {
    /** Sendet Alert via channel-status-agent */
    global $WORKSPACE;
    
    $cmd = "python3 " . escapeshellarg($WORKSPACE . "/skills/channel-status-agent/scripts/channel_status.py") . 
           " --type alert --message " . escapeshellarg("{$alert['level']}: {$alert['message']}");
    
    exec($cmd, $output, $returnCode);
    
    if ($returnCode === 0) {
        logMessage("Alert sent: {$alert['message']}");
    } else {
        logMessage("Failed to send alert: " . implode("\n", $output), "ERROR");
    }
}

function main() {
    global $NODES;
    
    // Argumente parsen
    $options = getopt("", ["node:", "check:", "alert"]);
    $nodeArg = isset($options["node"]) ? $options["node"] : "all";
    $checkArg = isset($options["check"]) ? $options["check"] : "all";
    $sendAlerts = isset($options["alert"]);
    
    // Gültige Check-Werte
    $validChecks = ["ping", "ssh", "metrics", "all"];
    if (!in_array($checkArg, $validChecks)) {
        $checkArg = "all";
    }
    
    // Nodes bestimmen
    if ($nodeArg === "all") {
        $nodesToCheck = $NODES;
    } else {
        if (array_key_exists($nodeArg, $NODES)) {
            $nodesToCheck = [$nodeArg => $NODES[$nodeArg]];
        } else {
            logMessage("Unknown node: {$nodeArg}", "ERROR");
            exit(1);
        }
    }
    
    // Health-Checks durchführen
    $allAlerts = [];
    
    foreach ($nodesToCheck as $nodeId => $nodeConfig) {
        logMessage("Checking {$nodeConfig['name']} ({$nodeId})");
        
        // Ping
        if (in_array($checkArg, ["ping", "all"])) {
            if ($nodeConfig["host"] !== "localhost") {
                $pingOk = checkPing($nodeConfig["host"]);
                logMessage("  Ping: " . ($pingOk ? "OK" : "FAILED"));
            }
        }
        
        // SSH
        if (in_array($checkArg, ["ssh", "all"])) {
            $sshOk = checkSSH($nodeConfig);
            logMessage("  SSH: " . ($sshOk ? "OK" : "FAILED"));
        }
        
        // Metriken
        if (in_array($checkArg, ["metrics", "all"])) {
            $metrics = getNodeMetrics($nodeConfig);
            
            if ($metrics["available"]) {
                logMessage("  CPU: " . ($metrics["cpu"] !== null ? number_format($metrics["cpu"], 1) . "%" : "N/A"));
                logMessage("  RAM: " . ($metrics["ram"] !== null ? number_format($metrics["ram"], 1) . "%" : "N/A"));
                logMessage("  Disk: " . ($metrics["disk"] !== null ? $metrics["disk"] . "%" : "N/A"));
                logMessage("  Load: " . ($metrics["load"] !== null ? $metrics["load"] : "N/A"));
            } else {
                logMessage("  Metrics: UNAVAILABLE");
            }
            
            // Alerts prüfen
            $alerts = checkAlerts($nodeId, $nodeConfig, $metrics);
            $allAlerts = array_merge($allAlerts, $alerts);
        }
    }
    
    // Alerts senden
    if ($sendAlerts && count($allAlerts) > 0) {
        logMessage("\nSending " . count($allAlerts) . " alerts...");
        foreach ($allAlerts as $alert) {
            sendAlert($alert);
        }
    } elseif (count($allAlerts) > 0) {
        logMessage("\n" . count($allAlerts) . " alerts found (use --alert to send)");
    } else {
        logMessage("\nAll nodes healthy!");
    }
}

main();
?>
