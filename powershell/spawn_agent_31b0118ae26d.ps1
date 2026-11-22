#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "ff1d0cd4eba0c24ad45e28419efe6a433d0af59dd71b91f7a0bc90bc7248fec6", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "powershell"}
# spawn_agent.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Sub-Agent spawner - Einfache CLI für sessions_spawn

.DESCRIPTION
Dieses Skript hilft beim Erstellen und Ausgeben von Konfigurationen für den Start von Sub-Agenten.
Es unterstützt verschiedene Ausgabeformate wie Tool-Kommando, Slash-Kommando und JSON.

.PARAMETER Task
Die Aufgabenbeschreibung für den Sub-Agenten (erforderlich).

.PARAMETER Label
Ein optionaler Label für den Sub-Agenten.

.PARAMETER Model
Das zu verwendende KI-Modell (aus einer vordefinierten Liste).

.PARAMETER Thinking
Das Denkniveau des Agenten (low, medium, high).

.PARAMETER Timeout
Timeout in Sekunden (Standard: 900).

.PARAMETER Thread
Aktiviert Thread-Binding.

.PARAMETER Mode
Der Ausführungsmodus (run oder session). Standard ist run.

.PARAMETER Output
Das Ausgabeformat (tool, slash, json). Standard ist tool.

.EXAMPLE
./spawn_agent.ps1 -Task "Analyze logs"

.EXAMPLE
./spawn_agent.ps1 -Task "Code review" -Model "openai/gpt-5.6-sol" -Timeout 1800

.EXAMPLE
./spawn_agent.ps1 -Task "Batch process" -Label "batch-worker" -Thread

.NOTES
Author: OpenClaw Team
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Task,

    [string]$Label,

    [ValidateScript({
        $models = GetModels
        if ($models -contains $_) {
            return $true
        } else {
            throw "Ungültiges Modell: $_. Gültige Modelle sind: $($models -join ', ')"
        }
    })]
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

function GetModels {
    $configPath = $env:OPENCLAW_CONFIG ?? "/home/openclaw/.openclaw/openclaw.json"
    try {
        $configContent = Get-Content -Path $configPath -Raw -Encoding UTF8
        $config = $configContent | ConvertFrom-Json
        $modelConfig = $config.agents.defaults.model
        $candidates = @($modelConfig.primary) + @($modelConfig.fallbacks)
    } catch {
        throw "Modellkonfiguration kann nicht geladen werden: $configPath : $_"
    }

    $models = @()
    foreach ($candidate in $candidates) {
        if ($candidate -is [string] -and $candidate -and -not $candidate.StartsWith("anthropic/")) {
            $models += $candidate
        }
    }

    $uniqueModels = $models | Sort-Object -Unique
    if (-not $uniqueModels) {
        throw "Keine allgemein verfügbaren Modelle in $configPath"
    }

    return $uniqueModels
}

function GetSpawnConfig {
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

    if ($Label) {
        $config.label = $Label
    }

    $availableModels = GetModels
    if ($Model -and $availableModels -contains $Model) {
        $config.model = $Model
    }

    if ($Thinking) {
        $config.thinking = $Thinking
    }

    if ($Timeout) {
        $config.runTimeoutSeconds = $Timeout
    }

    if ($Thread) {
        $config.thread = $true
        if ($Mode -eq "run") {
            $config.mode = "session" # thread requires session mode
        }
    } else {
        $config.mode = $Mode
    }

    return $config
}

function PrintSpawnCommand {
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

function PrintSlashCommand {
    param([hashtable]$Config)

    $task = $Config.task ?? ""
    $label = $Config.label ?? "agent"
    $model = $Config.model ?? ""

    $cmd = "/subagents spawn $label `"$task`""
    if ($model) {
        $cmd += " --model $model"
    }
    if ($Config.thinking) {
        $cmd += " --thinking $($Config.thinking)"
    }

    Write-Host ""
    Write-Host "💬 Slash Command:"
    Write-Host "=================================================="
    Write-Host $cmd
    Write-Host "=================================================="
}

# Hauptlogik
try {
    $config = GetSpawnConfig -Task $Task -Label $Label -Model $Model -Thinking $Thinking -Timeout $Timeout -Thread $Thread.IsPresent -Mode $Mode

    Write-Host "✅ Sub-Agent Konfiguration:"
    $jsonOutput = $config | ConvertTo-Json -Depth 10
    Write-Host $jsonOutput

    switch ($Output) {
        "tool" {
            PrintSpawnCommand -Config $config
        }
        "slash" {
            PrintSlashCommand -Config $config
        }
        "json" {
            Write-Host ""
            Write-Host "📄 JSON:"
            Write-Host $jsonOutput

            # Speichere als Datei
            $fileName = "subagent_$($config.label ?? 'spawn').json"
            $outputFile = Join-Path "/tmp" $fileName
            $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8
            Write-Host "💾 Gespeichert: $outputFile"
        }
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
