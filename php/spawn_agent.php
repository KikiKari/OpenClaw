<?php
// abstraction-provenance: {"artifact_sha256": "56b1afc221c57acd7ad901c936f05d3ed3ff3d7218e128a67a4d9e402269e023", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "php"}
// spawn_agent.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
// auch in: workspace@local:git/skills/sub-agents-utils/scripts/spawn_agent.py
// auch in: workspace@local:skills/sub-agents-utils/scripts/spawn_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Sub-Agent spawner - Einfache CLI für sessions_spawn
 */

class SubAgentSpawnerException extends Exception {}

class SubAgentSpawner {
    private static $models = null;

    /**
     * Lädt die verfügbaren Modelle aus der Konfigurationsdatei
     */
    public static function loadModels(): array {
        $configPath = getenv('OPENCLAW_CONFIG') ?: '/home/openclaw/.openclaw/openclaw.json';
        
        if (!file_exists($configPath)) {
            throw new SubAgentSpawnerException("Modellkonfiguration kann nicht geladen werden: $configPath: File not found");
        }
        
        $content = file_get_contents($configPath);
        if ($content === false) {
            throw new SubAgentSpawnerException("Modellkonfiguration kann nicht geladen werden: $configPath: Cannot read file");
        }
        
        $config = json_decode($content, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new SubAgentSpawnerException("Modellkonfiguration kann nicht geladen werden: $configPath: " . json_last_error_msg());
        }
        
        try {
            $modelConfig = $config['agents']['defaults']['model'];
            $candidates = array_merge([$modelConfig['primary']], $modelConfig['fallbacks']);
        } catch (Exception $e) {
            throw new SubAgentSpawnerException("Modellkonfiguration kann nicht geladen werden: $configPath: Invalid structure");
        }
        
        $models = [];
        foreach ($candidates as $model) {
            if (is_string($model) && !empty($model) && !str_starts_with($model, 'anthropic/')) {
                $models[] = $model;
            }
        }
        
        $models = array_unique($models);
        
        if (empty($models)) {
            throw new SubAgentSpawnerException("Keine allgemein verfügbaren Modelle in $configPath");
        }
        
        return $models;
    }

    /**
     * Gibt die Liste der verfügbaren Modelle zurück
     */
    public static function getModels(): array {
        if (self::$models === null) {
            self::$models = self::loadModels();
        }
        return self::$models;
    }

    /**
     * Erstellt Konfiguration für sessions_spawn
     */
    public static function getSpawnConfig(
        string $task,
        ?string $label = null,
        ?string $model = null,
        ?string $thinking = null,
        ?int $timeout = null,
        bool $thread = false,
        string $mode = "run"
    ): array {
        $config = [
            "task" => $task
        ];
        
        if ($label) {
            $config["label"] = $label;
        }
        
        $models = self::getModels();
        if ($model && in_array($model, $models)) {
            $config["model"] = $model;
        }
        
        if ($thinking) {
            $config["thinking"] = $thinking;
        }
        
        if ($timeout) {
            $config["runTimeoutSeconds"] = $timeout;
        }
        
        if ($thread) {
            $config["thread"] = true;
            if ($mode === "run") {
                $config["mode"] = "session"; // thread requires session mode
            }
        } else {
            $config["mode"] = $mode;
        }
        
        return $config;
    }

    /**
     * Gibt das equivalente Tool-Kommando aus
     */
    public static function printSpawnCommand(array $config): void {
        echo "\n🛠️  Tool-Aufruf:\n";
        echo str_repeat("=", 50) . "\n";
        echo "sessions_spawn(\n";
        foreach ($config as $key => $value) {
            if (is_string($value)) {
                echo "    $key=\"$value\"\n";
            } else {
                echo "    $key=" . json_encode($value) . "\n";
            }
        }
        echo ")\n";
        echo str_repeat("=", 50) . "\n";
    }

    /**
     * Gibt das equivalente Slash-Kommando aus
     */
    public static function printSlashCommand(array $config): void {
        $task = $config['task'] ?? "";
        $label = $config['label'] ?? "agent";
        $model = $config['model'] ?? "";
        
        $cmd = "/subagents spawn $label \"$task\"";
        if ($model) {
            $cmd .= " --model $model";
        }
        if (isset($config['thinking'])) {
            $cmd .= " --thinking " . $config['thinking'];
        }
        
        echo "\n💬 Slash Command:\n";
        echo str_repeat("=", 50) . "\n";
        echo "$cmd\n";
        echo str_repeat("=", 50) . "\n";
    }
}

function main(): void {
    global $argv, $argc;
    
    // Simple argument parsing
    $args = [
        'task' => null,
        'label' => null,
        'model' => null,
        'thinking' => null,
        'timeout' => 900,
        'thread' => false,
        'mode' => 'run',
        'output' => 'tool'
    ];
    
    // Parse command line arguments
    for ($i = 1; $i < $argc; $i++) {
        $arg = $argv[$i];
        
        switch ($arg) {
            case '--task':
            case '-t':
                if (isset($argv[$i + 1])) {
                    $args['task'] = $argv[$i + 1];
                    $i++;
                }
                break;
                
            case '--label':
            case '-l':
                if (isset($argv[$i + 1])) {
                    $args['label'] = $argv[$i + 1];
                    $i++;
                }
                break;
                
            case '--model':
            case '-m':
                if (isset($argv[$i + 1])) {
                    $args['model'] = $argv[$i + 1];
                    $i++;
                }
                break;
                
            case '--thinking':
                if (isset($argv[$i + 1])) {
                    $args['thinking'] = $argv[$i + 1];
                    $i++;
                }
                break;
                
            case '--timeout':
                if (isset($argv[$i + 1]) && is_numeric($argv[$i + 1])) {
                    $args['timeout'] = (int)$argv[$i + 1];
                    $i++;
                }
                break;
                
            case '--thread':
                $args['thread'] = true;
                break;
                
            case '--mode':
                if (isset($argv[$i + 1])) {
                    $args['mode'] = $argv[$i + 1];
                    $i++;
                }
                break;
                
            case '--output':
            case '-o':
                if (isset($argv[$i + 1])) {
                    $args['output'] = $argv[$i + 1];
                    $i++;
                }
                break;
                
            case '--help':
            case '-h':
                echo "Sub-Agent Spawn Helper\n\n";
                echo "Usage: php " . basename(__FILE__) . " [options]\n\n";
                echo "Options:\n";
                echo "  -t, --task TASK          Aufgabenbeschreibung\n";
                echo "  -l, --label LABEL        Optionaler Label\n";
                echo "  -m, --model MODEL        KI-Modell\n";
                echo "  --thinking LEVEL         Thinking Level (low, medium, high)\n";
                echo "  --timeout SECONDS        Timeout in Sekunden (default: 900)\n";
                echo "  --thread                 Thread-Binding aktivieren\n";
                echo "  --mode MODE              Run mode (run, session)\n";
                echo "  -o, --output FORMAT      Output format (tool, slash, json)\n";
                echo "  -h, --help               Diese Hilfe anzeigen\n\n";
                echo "Beispiele:\n";
                echo "  php " . basename(__FILE__) . " -t \"Analyze logs\" \n";
                echo "  php " . basename(__FILE__) . " -t \"Code review\" -m openai/gpt-5.6-sol --timeout 1800\n";
                echo "  php " . basename(__FILE__) . " -t \"Batch process\" -l \"batch-worker\" --thread\n";
                exit(0);
        }
    }
    
    // Validate required arguments
    if (!$args['task']) {
        fwrite(STDERR, "Fehler: --task ist erforderlich\n");
        exit(1);
    }
    
    // Validate model if provided
    if ($args['model']) {
        $models = SubAgentSpawner::getModels();
        if (!in_array($args['model'], $models)) {
            fwrite(STDERR, "Fehler: Ungültiges Modell. Verfügbare Modelle: " . implode(', ', $models) . "\n");
            exit(1);
        }
    }
    
    // Validate thinking level
    if ($args['thinking'] && !in_array($args['thinking'], ['low', 'medium', 'high'])) {
        fwrite(STDERR, "Fehler: Ungültiges Thinking Level. Erlaubt: low, medium, high\n");
        exit(1);
    }
    
    // Validate mode
    if (!in_array($args['mode'], ['run', 'session'])) {
        fwrite(STDERR, "Fehler: Ungültiger Mode. Erlaubt: run, session\n");
        exit(1);
    }
    
    // Validate output format
    if (!in_array($args['output'], ['tool', 'slash', 'json'])) {
        fwrite(STDERR, "Fehler: Ungültiges Output Format. Erlaubt: tool, slash, json\n");
        exit(1);
    }
    
    try {
        $spawner = new SubAgentSpawner();
        $config = SubAgentSpawner::getSpawnConfig(
            $args['task'],
            $args['label'],
            $args['model'],
            $args['thinking'],
            $args['timeout'],
            $args['thread'],
            $args['mode']
        );
        
        echo "✅ Sub-Agent Konfiguration:\n";
        echo json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
        
        switch ($args['output']) {
            case 'tool':
                SubAgentSpawner::printSpawnCommand($config);
                break;
                
            case 'slash':
                SubAgentSpawner::printSlashCommand($config);
                break;
                
            case 'json':
                echo "\n📄 JSON:\n";
                echo json_encode($config) . "\n";
                
                // Speichere als Datei
                $label = $config['label'] ?? 'spawn';
                $outputFile = "/tmp/subagent_$label.json";
                file_put_contents($outputFile, json_encode($config, JSON_PRETTY_PRINT));
                echo "💾 Gespeichert: $outputFile\n";
                break;
        }
    } catch (SubAgentSpawnerException $e) {
        fwrite(STDERR, "Fehler: " . $e->getMessage() . "\n");
        exit(1);
    }
}

main();
