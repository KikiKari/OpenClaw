#!/usr/bin/env pwsh
# spawn_agent.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Sub-Agent spawner - Einfache CLI für sessions_spawn

.DESCRIPTION
Dieses Skript hilft beim Erstellen und Ausgeben von Konfigurationen für Sub-Agenten.
Es unterstützt verschiedene Ausgabeformate wie Tool-Aufrufe, Slash-Befehle und JSON.

.PARAMETER Task
Die Aufgabenbeschreibung für den Sub-Agenten (erforderlich).

.PARAMETER Label
Ein optionaler Label für den Sub-Agenten.

.PARAMETER Model
Das zu verwendende KI-Modell (muss in der Konfiguration vorhanden sein).

.PARAMETER Thinking
Das Denkniveau des Agenten (low, medium, high).

.PARAMETER Timeout
Timeout in Sekunden (Standard: 900).

.PARAMETER Thread
Aktiviert Thread-Binding.

.PARAMETER Mode
Der Ausführungsmodus (run oder session, Standard: run).

.PARAMETER Output
Das Ausgabeformat (tool, slash, json, Standard: tool).

.EXAMPLE
./spawn_agent.ps1 -Task "Analyze logs"
./spawn_agent.ps1 -Task "Code review" -Model "openai/gpt-5.6-sol" -Timeout 1800
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

function Load-Models {
    $configPathEnv = $env:OPENCLAW_CONFIG
    if (-not $configPathEnv) {
        $configPathEnv = "/home/openclaw/.openclaw/openclaw.json"
    }

    try {
        $configContent = Get-Content -Path $configPathEnv -Raw -Encoding UTF8
        $config = $configContent | ConvertFrom-Json
        $modelConfig = $config.agents.defaults.model
        $candidates = @($modelConfig.primary) + @($modelConfig.fallbacks)
    }
    catch {
        throw "Modellkonfiguration kann nicht geladen werden: $configPathEnv`: $_"
    }

    $models = @()
    foreach ($candidate in $candidates) {
        if ($candidate -is [string] -and $candidate -and -not $candidate.StartsWith("anthropic/")) {
            $models += $candidate
        }
    }

    $uniqueModels = $models | Select-Object -Unique
    if ($uniqueModels.Count -eq 0) {
        throw "Keine allgemein verfügbaren Modelle in $configPathEnv"
    }

    return $uniqueModels
}

$MODELS = Load-Models

if ($Model -and $MODELS -notcontains $Model) {
    Write-Error "Modell '$Model' ist nicht in der Liste der verfügbaren Modelle."
    exit 1
}

function Get-SpawnConfig {
    param(
        [string]$Task,
        [string]$Label,
        [string]$Model,
        [string]$Thinking,
        [int]$Timeout,
        [bool]$Thread,
        [string]$Mode
    )

    $config = @{
        task = $Task
    }

    if ($Label) { $config.label = $Label }
    if ($Model -and $MODELS -contains $Model) { $config.model = $Model }
    if ($Thinking) { $config.thinking = $Thinking }
    if ($Timeout) { $config.runTimeoutSeconds = $Timeout }
    if ($Thread) {
        $config.thread = $true
        if ($Mode -eq "run") {
            $config.mode = "session"
        }
    } else {
        $config.mode = $Mode
    }

    return $config
}

function Print-SpawnCommand {
    param([hashtable]$Config)

    Write-Host ""
    Write-Host "🛠️  Tool-Aufruf:"
    Write-Host "=================================================="
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
    Write-Host "=================================================="
}

function Print-SlashCommand {
    param([hashtable]$Config)

    $task = if ($Config.ContainsKey("task")) { $Config["task"] } else { "" }
    $label = if ($Config.ContainsKey("label")) { $Config["label"] } else { "agent" }
    $model = if ($Config.ContainsKey("model")) { $Config["model"] } else { "" }

    $cmd = "/subagents spawn $label `"$task`""
    if ($model) {
        $cmd += " --model $model"
    }
    if ($Config.ContainsKey("thinking")) {
        $cmd += " --thinking $($Config['thinking'])"
    }

    Write-Host ""
    Write-Host "💬 Slash Command:"
    Write-Host "=================================================="
    Write-Host $cmd
    Write-Host "=================================================="
}

$config = Get-SpawnConfig -Task $Task -Label $Label -Model $Model -Thinking $Thinking -Timeout $Timeout -Thread $Thread.IsPresent -Mode $Mode

Write-Host "✅ Sub-Agent Konfiguration:"
$configJson = $config | ConvertTo-Json -Depth 10
Write-Host $configJson

switch ($Output) {
    "tool" {
        Print-SpawnCommand -Config $config
    }
    "slash" {
        Print-SlashCommand -Config $config
    }
    "json" {
        Write-Host ""
        Write-Host "📄 JSON:"
        Write-Host $configJson

        $labelName = if ($config.ContainsKey("label")) { $config["label"] } else { "spawn" }
        $fileName = "subagent_$labelName.json"
        $outputPath = Join-Path -Path "/tmp" -ChildPath $fileName
        $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
        Write-Host "💾 Gespeichert: $outputPath"
    }
}
