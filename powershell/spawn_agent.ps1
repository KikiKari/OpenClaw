#!/usr/bin/env pwsh
# spawn_agent.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Sub-Agent spawner - Einfache CLI für sessions_spawn

.DESCRIPTION
Dieses Skript hilft beim Erstellen von Konfigurationen zum Starten von Sub-Agents.
Es generiert entweder ein Tool-Kommando, einen Slash-Befehl oder eine JSON-Konfigurationsdatei.

.PARAMETER Task
Erforderliche Aufgabenbeschreibung für den Agenten.

.PARAMETER Label
Optionaler Name/Label für den Agenten.

.PARAMETER Model
Das zu verwendende KI-Modell (muss konfiguriert sein).

.PARAMETER Thinking
Denkverhalten des Agenten: low, medium oder high.

.PARAMETER Timeout
Maximale Laufzeit in Sekunden (Standard: 900).

.PARAMETER Thread
Aktiviert Thread-Binding.

.PARAMETER Mode
Ausführungsmodus: run oder session (Standard: run).

.PARAMETER Output
Ausgabeformat: tool, slash oder json (Standard: tool).

.EXAMPLE
.\spawn_agent.ps1 -Task "Analyze logs"

.EXAMPLE
.\spawn_agent.ps1 -Task "Code review" -Model "openrouter/anthropic/claude-haiku-4.5" -Timeout 1800

.EXAMPLE
.\spawn_agent.ps1 -Task "Batch process" -Label "batch-worker" -Thread

.NOTES
Author: OpenClaw Team
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

# Workspace-Pfad setzen
$WORKSPACE = "/home/openclaw/.openclaw/workspace"
$env:PYTHONPATH = $WORKSPACE + [System.IO.Path]::PathSeparator + $env:PYTHONPATH

# Lade verfügbare Modelle (ersetzt Python-Import)
function Get-ConfiguredModels {
    try {
        # Simuliere Laden der Modelle aus openclaw_models
        # In einer echten Umgebung würde hier eine entsprechende PowerShell-Funktion oder ein Modul aufgerufen
        return @("openrouter/anthropic/claude-haiku-4.5", "openrouter/google/gemini-pro-1.5", "local/mistral-7b")
    }
    catch {
        Write-Error "Modellkonfiguration kann nicht geladen werden: $_"
        exit 1
    }
}

# Verfügbare Modelle laden
$MODELS = Get-ConfiguredModels

# Validierung des Models
if ($Model -and $MODELS -notcontains $Model) {
    Write-Warning "Modell '$Model' ist nicht in der Liste der konfigurierten Modelle."
}

class SubAgentSpawner {
    static [hashtable] GetSpawnConfig([string]$Task, [string]$Label, [string]$Model, [string]$Thinking, [int]$Timeout, [bool]$Thread, [string]$Mode) {
        $config = @{
            task = $Task
        }

        if ($Label) { $config.label = $Label }
        if ($Model -and $using:MODELS -contains $Model) { $config.model = $Model }
        if ($Thinking) { $config.thinking = $Thinking }
        if ($Timeout) { $config.runTimeoutSeconds = $Timeout }
        
        if ($Thread) {
            $config.thread = $true
            if ($Mode -eq "run") {
                $config.mode = "session"  # thread erfordert session mode
            }
        } else {
            $config.mode = $Mode
        }

        return $config
    }

    static [void] PrintSpawnCommand([hashtable]$Config) {
        Write-Host "`n🛠️  Tool-Aufruf:"
        Write-Host ("=" * 50)
        Write-Host "sessions_spawn("
        foreach ($key in $Config.Keys) {
            $value = $Config[$key]
            if ($value -is [string]) {
                Write-Host "    $key=`"$value`""
            } else {
                Write-Host "    $key=$value"
            }
        }
        Write-Host ")"
        Write-Host ("=" * 50)
    }

    static [void] PrintSlashCommand([hashtable]$Config) {
        $task = $Config["task"]
        $label = if ($Config.ContainsKey("label")) { $Config["label"] } else { "agent" }
        $model = if ($Config.ContainsKey("model")) { $Config["model"] } else { "" }

        $cmd = "/subagents spawn $label `"$task`""
        if ($model) {
            $cmd += " --model $model"
        }
        if ($Config.ContainsKey("thinking")) {
            $cmd += " --thinking $($Config["thinking"])"
        }

        Write-Host "`n💬 Slash Command:"
        Write-Host ("=" * 50)
        Write-Host $cmd
        Write-Host ("=" * 50)
    }
}

# Hauptlogik
$spawner = [SubAgentSpawner]::new()
$config = [SubAgentSpawner]::GetSpawnConfig($Task, $Label, $Model, $Thinking, $Timeout, $Thread.IsPresent, $Mode)

Write-Host "✅ Sub-Agent Konfiguration:"
$configJson = $config | ConvertTo-Json -Depth 10
Write-Host $configJson

switch ($Output) {
    "tool" {
        [SubAgentSpawner]::PrintSpawnCommand($config)
    }
    "slash" {
        [SubAgentSpawner]::PrintSlashCommand($config)
    }
    "json" {
        Write-Host "`n📄 JSON:"
        Write-Host $configJson
        
        # Speichere als Datei
        $labelForFilename = if ($config.ContainsKey("label")) { $config["label"] } else { "spawn" }
        $outputFile = Join-Path "/tmp" "subagent_$labelForFilename.json"
        $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding utf8
        Write-Host "💾 Gespeichert: $outputFile"
    }
}
