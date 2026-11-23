#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "9cc10763c0010d85288ee32c06c7680a32b984d4b7a3f75138e1175639f5e58b", "source_sha256": "f911bfbdbdc66c53e970ead9851f23e8c415a17f83d92cea3a53539f83a49ad2", "target_language": "powershell"}
# spawn_agent.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Sub-Agent spawner - Einfache CLI für sessions_spawn

.DESCRIPTION
Dieses Skript hilft beim Erstellen von Konfigurationen zum Starten von Sub-Agents
und gibt diese in verschiedenen Formaten aus.

.PARAMETER Task
Die Aufgabenbeschreibung für den Agenten (erforderlich)

.PARAMETER Label
Ein optionaler Label für den Agenten

.PARAMETER Model
Das zu verwendende KI-Modell

.PARAMETER Thinking
Das Denkniveau ("low", "medium", "high")

.PARAMETER Timeout
Timeout in Sekunden (Standard: 900)

.PARAMETER Thread
Aktiviert Thread-Binding

.PARAMETER Mode
Der Ausführungsmodus ("run", "session") Standard: "run"

.PARAMETER Output
Das Ausgabeformat ("tool", "slash", "json") Standard: "tool"

.EXAMPLE
./spawn_agent.ps1 -Task "Analyze logs"

.EXAMPLE
./spawn_agent.ps1 -Task "Code review" -Model "openrouter/anthropic/claude-haiku-4.5" -Timeout 1800

.EXAMPLE
./spawn_agent.ps1 -Task "Batch process" -Label "batch-worker" -Thread
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Task,
    
    [string]$Label,
    
    [string]$Model,
    
    [ValidateSet("low", "medium", "high")]
    [string]$Thinking,
    
    [int]$Timeout = 900,
    
    [switch]$Thread,
    
    [ValidateSet("run", "session")]
    [string]$Mode = "run",
    
    [ValidateSet("tool", "slash", "json")]
    [string]$Output = "tool"
)

# Arbeitsverzeichnis festlegen
$WORKSPACE = "/home/openclaw/.openclaw/workspace"

# Prüfen ob WORKSPACE im Pfad ist und ggf. hinzufügen
if (($env:PYTHONPATH -notlike "*$WORKSPACE*") -and ($env:PYTHONPATH -split [System.IO.Path]::PathSeparator) -notcontains $WORKSPACE) {
    $env:PYTHONPATH = "$WORKSPACE$(if($env:PYTHONPATH){[System.IO.Path]::PathSeparator + $env:PYTHONPATH}else{''})"
}

# Versuche die verfügbaren Modelle zu laden
try {
    # In PowerShell können wir Python-Module nicht direkt laden
    # Daher simulieren wir die Modelle oder verwenden einen leeren Array
    $MODELS = @() # Hier könnten echte Modelle geladen werden wenn nötig
} catch {
    Write-Error "Modellkonfiguration kann nicht geladen werden: $_"
    exit 1
}

class SubAgentSpawner {
    static [hashtable] GetSpawnConfig([string]$task, [string]$label, [string]$model, [string]$thinking, [int]$timeout, [bool]$thread, [string]$mode) {
        $config = @{
            task = $task
        }
        
        if ($label) {
            $config.label = $label
        }
        
        if ($model -and $script:MODELS -contains $model) {
            $config.model = $model
        }
        
        if ($thinking) {
            $config.thinking = $thinking
        }
        
        if ($timeout) {
            $config.runTimeoutSeconds = $timeout
        }
        
        if ($thread) {
            $config.thread = $true
            if ($mode -eq "run") {
                $config.mode = "session"  # thread erfordert session mode
            }
        } else {
            $config.mode = $mode
        }
        
        return $config
    }
    
    static [void] PrintSpawnCommand([hashtable]$config) {
        Write-Host ""
        Write-Host "🛠️  Tool-Aufruf:"
        Write-Host "=================================================="
        Write-Host "sessions_spawn("
        foreach ($key in $config.Keys) {
            $value = $config[$key]
            if ($value -is [string]) {
                Write-Host "    $key=`"$value`""
            } else {
                Write-Host "    $key=$value"
            }
        }
        Write-Host ")"
        Write-Host "=================================================="
    }
    
    static [void] PrintSlashCommand([hashtable]$config) {
        $task = if ($config.ContainsKey('task')) { $config['task'] } else { "" }
        $label = if ($config.ContainsKey('label')) { $config['label'] } else { "agent" }
        $model = if ($config.ContainsKey('model')) { $config['model'] } else { "" }
        
        $cmd = "/subagents spawn $label `"$task`""
        if ($model) {
            $cmd += " --model $model"
        }
        if ($config.ContainsKey('thinking') -and $config['thinking']) {
            $cmd += " --thinking $($config['thinking'])"
        }
        
        Write-Host ""
        Write-Host "💬 Slash Command:"
        Write-Host "=================================================="
        Write-Host $cmd
        Write-Host "=================================================="
    }
}

# Hauptprogramm
try {
    $spawner = [SubAgentSpawner]::new()
    $config = [SubAgentSpawner]::GetSpawnConfig($Task, $Label, $Model, $Thinking, $Timeout, $Thread.IsPresent, $Mode)
    
    Write-Host "✅ Sub-Agent Konfiguration:"
    $jsonConfig = $config | ConvertTo-Json -Depth 10
    Write-Host $jsonConfig
    
    switch ($Output) {
        "tool" {
            [SubAgentSpawner]::PrintSpawnCommand($config)
        }
        "slash" {
            [SubAgentSpawner]::PrintSlashCommand($config)
        }
        "json" {
            Write-Host ""
            Write-Host "📄 JSON:"
            Write-Host $jsonConfig
            
            # Speichere als Datei
            $fileName = "subagent_$($(if($config.ContainsKey('label')){$config['label']}else{'spawn'})).json"
            $outputFile = Join-Path "/tmp" $fileName
            $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding utf8
            Write-Host "💾 Gespeichert: $outputFile"
        }
    }
} catch {
    Write-Error "Fehler bei der Ausführung: $_"
    exit 1
}
