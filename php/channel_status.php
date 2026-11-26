<?php
// abstraction-provenance: {"artifact_sha256": "da4c681f4e78f4a1e4459979f0d6c45fd29cd233502343238cafbd3ba1b10e22", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "php"}
// channel_status.py — portiert nach php
// Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Channel Status Agent - Automatische Status-Updates
 */

// Konfiguration
$WORKSPACE = "/home/openclaw/.openclaw/workspace";
$LOGS_DB = $WORKSPACE . "/db/logs.db";
$CONFIG_FILE = $WORKSPACE . "/config/channel-status.json";
$LOG_FILE = $WORKSPACE . "/logs/channel-status.log";

function logMessage($message, $level = "INFO") {
    /** Logging */
    $timestamp = date('Y-m-d H:i:s');
    $entry = "[{$timestamp}] [{$level}] {$message}";
    echo $entry . "\n";
    file_put_contents($GLOBALS['LOG_FILE'], $entry . "\n", FILE_APPEND);
}

$NODE_NAMES = [
    "node2" => ["openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122"],
    "node3" => ["openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125"],
    "node4" => ["openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39"],
    "node5" => ["openclaw-node5", "lenovo-node7", "lenovo-node7.taild25fea.ts.net", "100.103.140.35"],
];

function fetch_node_status() {
    /** Return mapped OpenClaw connection states; NULL indicates lookup failure. */
    global $NODE_NAMES;
    try {
        $process = new Process(["openclaw", "nodes", "status", "--json"]);
        $process->run();
        if (!$process->isSuccessful()) {
            throw new ProcessFailedException($process);
        }
        $payload = json_decode($process->getOutput(), true);
        if (!is_array($payload) || !isset($payload["nodes"]) || !is_array($payload["nodes"])) {
            return null;
        }
        $states = [];
        foreach (array_keys($NODE_NAMES) as $node) {
            $states[$node] = false;
        }
        foreach ($payload["nodes"] as $item) {
            if (!is_array($item)) {
                continue;
            }
            $names = [];
            foreach (["displayName", "nodeId", "remoteIp"] as $key) {
                if (isset($item[$key])) {
                    $names[] = strtolower(strval($item[$key]));
                }
            }
            foreach ($NODE_NAMES as $node => $aliases) {
                if (count(array_intersect($names, $aliases)) > 0 && isset($item["connected"]) && $item["connected"] === true) {
                    $states[$node] = true;
                }
            }
        }
        $states["node1"] = true; // successful Gateway status request
        return $states;
    } catch (Exception $e) {
        return null;
    }
}

function get_system_status() {
    /** Sammelt System-Status */
    $status = [
        "timestamp" => date('c'),
        "nodes" => [],
        "agents" => [],
        "system" => []
    ];
    
    // Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
    $states = fetch_node_status();
    $names = [
        "node1" => "Gateway",
        "node2" => "Node2",
        "node3" => "Node3",
        "node4" => "Redmi",
        "node5" => "Lenovo"
    ];
    foreach ($names as $node => $name) {
        $status["nodes"][$node] = [
            "name" => $name,
            "status" => ($states === null) ? "unknown" : (($states[$node] ?? false) ? "online" : "offline")
        ];
    }

    // Agent-Status aus Cron
    try {
        $output = shell_exec('crontab -l 2>/dev/null');
        $lines = explode("\n", $output);
        $cron_lines = 0;
        foreach ($lines as $line) {
            if (trim($line) !== '' && strpos($line, '#') !== 0) {
                $cron_lines++;
            }
        }
        $status["agents"]["active_crons"] = $cron_lines;
    } catch (Exception $e) {
        $status["agents"]["active_crons"] = "unknown";
    }
    
    // System-Metriken
    try {
        // Disk usage
        $df_output = shell_exec('df -h /');
        $df_lines = explode("\n", $df_output);
        foreach ($df_lines as $line) {
            if (strpos($line, '/') !== false && strpos($line, '%') !== false) {
                $parts = preg_split('/\s+/', trim($line));
                if (isset($parts[4])) {
                    $status["system"]["disk_used"] = $parts[4];
                    break;
                }
            }
        }
        
        // RAM usage
        $free_output = shell_exec('free -h');
        $free_lines = explode("\n", $free_output);
        foreach ($free_lines as $line) {
            if (strpos($line, 'Mem:') !== false) {
                $parts = preg_split('/\s+/', trim($line));
                if (isset($parts[1]) && isset($parts[2])) {
                    $status["system"]["ram_total"] = $parts[1];
                    $status["system"]["ram_used"] = $parts[2];
                    break;
                }
            }
        }
    } catch (Exception $e) {
        // ignore
    }
    
    return $status;
}

function format_daily_status($status) {
    /** Format daily status */
    $nodes = $status["nodes"];
    $online = 0;
    foreach ($nodes as $n) {
        if ($n["status"] == "online") {
            $online++;
        }
    }
    
    $message = "📊 **Täglicher Status-Report**\n";
    $message .= "🗓️ " . date('Y-m-d H:i') . "\n\n";
    $message .= "**🖥️ Nodes ({$online}/" . count($nodes) . " online):**\n";
    
    foreach ($nodes as $node_id => $info) {
        $emoji = "🟢";
        if ($info["status"] == "offline") {
            $emoji = "🔴";
        } elseif ($info["status"] == "unknown") {
            $emoji = "🟡";
        }
        $message .= "{$emoji} {$info['name']}: {$info['status']}";
        if (isset($info["reason"])) {
            $message .= " ({$info['reason']})";
        }
        $message .= "\n";
    }
    
    $message .= "\n**🤖 Agents:**\n";
    $message .= "Aktive Cron-Jobs: {$status['agents']['active_crons']}\n";
    
    if (isset($status["system"]["disk_used"])) {
        $message .= "\n**💾 System:**\n";
        $message .= "Disk: {$status['system']['disk_used']} belegt\n";
        $message .= "RAM: {$status['system']['ram_used']} / {$status['system']['ram_total']}\n";
    }
    
    return $message;
}

function format_weekly_status($status) {
    /** Format the weekly report from current node data. */
    $lines = [
        "📈 **Wöchentlicher Report**",
        "📅 Woche " . date('W') . " - " . date('Y'),
        "",
        "**Nodes:**"
    ];
    foreach ($status["nodes"] as $item) {
        $lines[] = "- {$item['name']}: {$item['status']}";
    }
    return implode("\n", $lines) . "\n";
}

function send_to_channel($message, $channel_type = "telegram", $channel_id = "-1002381931352") {
    /** Sendet Nachricht an Channel */
    if ($channel_type == "telegram") {
        // Nutze OpenClaw message tool
        $cmd = ["openclaw", "message", "send", "--target", $channel_id, "--message", $message];
    } else {
        logMessage("Channel type {$channel_type} not implemented", "WARN");
        return false;
    }
    
    try {
        $process = new Process($cmd);
        $process->run();
        if ($process->isSuccessful()) {
            logMessage("Message sent to {$channel_type} {$channel_id}");
            return true;
        } else {
            logMessage("Failed to send: " . $process->getErrorOutput(), "ERROR");
            return false;
        }
    } catch (Exception $e) {
        logMessage("Send error: " . $e->getMessage(), "ERROR");
        return false;
    }
}

function main() {
    /** Hauptfunktion */
    global $argv, $argc;
    
    $options = getopt("", ["type:", "message::", "channel::", "dry-run"]);
    
    if (!isset($options["type"])) {
        echo "Usage: php channel_status.php --type=daily|weekly|alert [--message=...] [--channel=...] [--dry-run]\n";
        exit(1);
    }
    
    $type = $options["type"];
    $message_opt = $options["message"] ?? null;
    $channel = $options["channel"] ?? "-1002381931352";
    $dry_run = isset($options["dry-run"]);
    
    logMessage("Starting {$type} status update");
    
    // Status sammeln
    $status = get_system_status();
    
    // Message formatieren
    $message = "";
    if ($type == 'daily') {
        $message = format_daily_status($status);
    } elseif ($type == 'weekly') {
        $message = format_weekly_status($status);
    } elseif ($type == 'alert') {
        $message = "🚨 **ALERT**\n" . ($message_opt ?: "Manual alert");
    }
    
    // Senden oder Dry-Run
    if ($dry_run) {
        echo "\n--- DRY RUN ---\n";
        echo $message . "\n";
        echo "--- END ---\n";
    } else {
        send_to_channel($message, "telegram", $channel);
    }
    
    logMessage("Status update completed");
}

// Ensure log directory exists
$log_dir = dirname($LOG_FILE);
if (!file_exists($log_dir)) {
    mkdir($log_dir, 0777, true);
}

main();

// Helper classes for process execution (since PHP doesn't have built-in subprocess like Python)
class Process {
    private $command;
    private $output = '';
    private $errorOutput = '';
    private $exitCode = 0;
    
    public function __construct($command) {
        $this->command = $command;
    }
    
    public function run() {
        $descriptorspec = [
           0 => ["pipe", "r"],  // stdin
           1 => ["pipe", "w"],  // stdout
           2 => ["pipe", "w"]   // stderr
        ];
        
        $process = proc_open(implode(' ', $this->command), $descriptorspec, $pipes);
        
        if (is_resource($process)) {
            fclose($pipes[0]);
            $this->output = stream_get_contents($pipes[1]);
            fclose($pipes[1]);
            $this->errorOutput = stream_get_contents($pipes[2]);
            fclose($pipes[2]);
            
            $this->exitCode = proc_close($process);
        }
    }
    
    public function isSuccessful() {
        return $this->exitCode === 0;
    }
    
    public function getOutput() {
        return $this->output;
    }
    
    public function getErrorOutput() {
        return $this->errorOutput;
    }
}

class ProcessFailedException extends Exception {
    public function __construct(Process $process) {
        parent::__construct("Process failed with exit code: " . $process->exitCode);
    }
}
?>
