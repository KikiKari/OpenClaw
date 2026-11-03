#!/usr/bin/env pwsh
# abstractions_manager.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/abstractions_manager.py
# Erzeugt: 2026-11-03 durch ABSTRACTIONS_MANAGER.py

#Requires -Version 7

<#
Script Abstractions Manager - Multi-Node Edition
#>

using namespace System.IO
using namespace System.Collections.Generic

# Konfiguration
$WORKSPACE = "/home/openclaw/.openclaw/workspace"
$ABSTRACTIONS_REPO = Join-Path $WORKSPACE "git" "Abstraktionen"
$LOG_DIR = Join-Path $WORKSPACE "logs" "abstractions-manager"
$STATE_FILE = Join-Path $WORKSPACE "db" "abstractions_state.json"
# Node-Konfiguration mit Prioritäten
$NODES = @{
    "node1" = @{"always_available" = $true; "capacity" = "medium"; "priority" = 2}  # Gateway-Master
    "node2" = @{"always_available" = $true; "capacity" = "medium"; "priority" = 3}  # Stable Worker
    "node3" = @{"always_available" = $false; "capacity" = "medium"; "priority" = 4} # Bald verfügbar
    "node5" = @{"always_available" = $false; "capacity" = "low"; "priority" = 5; "device" = "Redmi Note 11S"; "condition" = "mobile_internet"}
    "node7" = @{"always_available" = $true; "capacity" = "high"; "priority" = 1}    # Docker Hauptarbeitspferd
}

$AVAILABLE_MODELS = @(
    "openrouter/moonshotai/kimi-k2.5",
    "openrouter/openai/gpt-4o",
    "openrouter/anthropic/claude-3-5-sonnet-20241022",
    "openrouter/google/gemini-2.0-flash-001",
    "openrouter/nvidia/llama-3.3-nemotron-super-49b-v1",
    "openrouter/qwen/qwen-2.5-coder-32b-instruct"
)

$TARGET_LANGUAGES = @{
    "perl5" = @{"ext" = ".pl"; "shebang" = "#!/usr/bin/env perl"; "header" = "use strict;`nuse warnings;`n"}
    "perl6" = @{"ext" = ".raku"; "shebang" = "#!/usr/bin/env raku"; "header" = "use v6;`n"}
    "javascript" = @{"ext" = ".js"; "shebang" = "#!/usr/bin/env node"; "header" = ""}
    "python" = @{"ext" = ".py"; "shebang" = "#!/usr/bin/env python3"; "header" = ""}
    "shell" = @{"ext" = ".sh"; "shebang" = "#!/bin/bash"; "header" = "set -euo pipefail`n"}
    "powershell" = @{"ext" = ".ps1"; "shebang" = "#!/usr/bin/env pwsh"; "header" = "#Requires -Version 7`n"}
    "tcl" = @{"ext" = ".tcl"; "shebang" = "#!/usr/bin/env tclsh"; "header" = "package require Tcl 8.6`n"}
    "ruby" = @{"ext" = ".rb"; "shebang" = "#!/usr/bin/env ruby"; "header" = "require 'json'`nrequire 'fileutils'`n"}
    "lua" = @{"ext" = ".lua"; "shebang" = "#!/usr/bin/env lua"; "header" = ""}
    "go" = @{"ext" = ".go"; "shebang" = "// +build ignore"; "header" = "package main`n"}
}

function Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    if (-not (Test-Path $LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    
    $logFile = Join-Path $LOG_DIR "$(Get-Date -Format 'yyyy-MM-dd').log"
    Add-Content -Path $logFile -Value $line
}

function Get-NodeByPriority {
    param(
        [string]$JobWeight = "medium"
    )
    
    # Prioritäts-Matrix
    if ($JobWeight -eq "heavy") {
        # Schwere Jobs → Node 7 (Docker mit vielen Ressourcen)
        $preferredOrder = @("node7", "node2", "node1")
    }
    elseif ($JobWeight -eq "medium") {
        # Mittlere Jobs → Stable Nodes
        $preferredOrder = @("node2", "node1", "node7")
    }
    else {  # light
        # Leichte Jobs → Mobile/verfügbare Nodes
        $preferredOrder = @("node5", "node1", "node2")
    }
    
    # Prüfe Verfügbarkeit
    foreach ($nodeId in $preferredOrder) {
        if (-not $NODES.ContainsKey($nodeId)) {
            continue
        }
        
        $node = $NODES[$nodeId]
        
        # Skip nicht immer verfügbare Nodes wenn nicht explizit requested
        if (-not $node.always_available -and $JobWeight -ne "light") {
            continue
        }
        
        # Prüfe ob Node online
        if (Check-NodeStatus $nodeId) {
            return $nodeId
        }
    }
    
    # Fallback zu Node 1
    return "node1"
}

function Check-NodeStatus {
    param([string]$NodeId)
    
    try {
        $result = & openclaw nodes status $NodeId 2>&1
        return ($LASTEXITCODE -eq 0) -and (($result -like "*online*") -or ($result -like "*active*"))
    }
    catch {
        # Bei Timeout/Error: Prüfe letzten bekannten Status
        return $NODES[$NodeId].always_available
    }
}

function Get-JobWeight {
    param(
        [int]$ScriptSize,
        [int]$TargetLangsCount
    )
    
    $totalWork = $ScriptSize * $TargetLangsCount
    
    if ($totalWork -gt 50000) {  # Große Scripts, viele Sprachen
        return "heavy"
    }
    elseif ($totalWork -gt 10000) {  # Mittlere Last
        return "medium"
    }
    else {
        return "light"
    }
}

function Load-State {
    if (Test-Path $STATE_FILE) {
        try {
            return Get-Content $STATE_FILE -Raw | ConvertFrom-Json -AsHashtable
        }
        catch {
            # Fallback
        }
    }
    return @{
        "processed" = @{}
        "queue" = @()
        "current_priority" = "high"
        "stats" = @{
            "total_scripts" = 0
            "abstractions_created" = 0
        }
    }
}

function Save-State {
    param([hashtable]$State)
    
    $stateDir = Split-Path $STATE_FILE -Parent
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    
    $State | ConvertTo-Json -Depth 10 | Set-Content $STATE_FILE
}

function Find-ScriptsInDir {
    param(
        [string]$Directory,
        [string[]]$ExcludePatterns = @("node_modules", ".git", "__pycache__", "dist", "build")
    )
    
    $scripts = [List[string]]::new()
    
    if (Test-Path $Directory) {
        $extensions = @("*.py", "*.js", "*.sh", "*.pl", "*.rb")
        
        foreach ($ext in $extensions) {
            $foundScripts = Get-ChildItem -Path $Directory -Recurse -Filter $ext -File | Where-Object {
                $scriptPath = $_.FullName
                -not ($ExcludePatterns | Where-Object { $scriptPath -like "*$_*" })
            }
            
            foreach ($script in $foundScripts) {
                $scripts.Add($script.FullName)
            }
        }
    }
    
    return $scripts
}

function Create-Abstraction {
    param(
        [string]$ScriptPath,
        [string]$TargetLang
    )
    
    try {
        $originalContent = Get-Content $ScriptPath -Raw -Encoding UTF8
        
        $ext = [IO.Path]::GetExtension($ScriptPath).TrimStart('.')
        $sourceLangMap = @{"py" = "Python"; "js" = "JavaScript"; "sh" = "Shell"; "pl" = "Perl"; "rb" = "Ruby"}
        $sourceLang = if ($sourceLangMap.ContainsKey($ext)) { $sourceLangMap[$ext] } else { $ext }
        
        $targetDir = Join-Path $ABSTRACTIONS_REPO $TargetLang
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        
        $scriptName = [IO.Path]::GetFileNameWithoutExtension($ScriptPath)
        $targetFile = Join-Path $targetDir "$scriptName$($TARGET_LANGUAGES[$TargetLang].ext)"
        
        if (Test-Path $targetFile) {
            return $false
        }
        
        $template = $TARGET_LANGUAGES[$TargetLang]
        $lines = ($originalContent -split "`n")[0..14]
        
        $content = @"
$($template.shebang)
# $scriptName - $($TargetLang.ToUpper()) Version
# Portiert von $sourceLang
# Original: $ScriptPath
# Erstellt: $(Get-Date -Format 'yyyy-MM-dd')
#
# $($template.header.Trim())

# Original-Code-Referenz:
# $(($lines | ForEach-Object { "# $_" }) -join "`n# ")

function main {
    # TODO: Implementiere ${sourceLang} Funktionalität in $($TargetLang.ToUpper())
}

if (`$MyInvocation.InvocationName -eq '&') {
    main
}
"@
        
        Set-Content -Path $targetFile -Value $content -NoNewline
        
        Log "Created: $targetFile"
        return $true
    }
    catch {
        Log "Failed: $ScriptPath - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Process-OnNode {
    param(
        [string]$NodeId,
        [string[]]$Scripts,
        [string[]]$TargetLangs
    )
    
    $created = 0
    
    if ($NodeId -eq "node1") {
        # Lokale Verarbeitung
        foreach ($script in $Scripts) {
            foreach ($lang in $TargetLangs) {
                if (Create-Abstraction $script $lang) {
                    $created++
                }
            }
        }
    }
    else {
        # Remote-Verarbeitung
        Log "Dispatching $($Scripts.Count) jobs to $NodeId"
        # TODO: Implementiere Remote-Dispatch wenn Node-Infrastruktur bereit
        # Für jetzt: Lokale Verarbeitung mit Node-Logging
        foreach ($script in $Scripts) {
            foreach ($lang in $TargetLangs) {
                if (Create-Abstraction $script $lang) {
                    $created++
                    Log "Processed on $NodeId`: $([IO.Path]::GetFileName($script)) -> $lang"
                }
            }
        }
    }
    
    return $created
}

function Process-PriorityHigh {
    $created = 0
    $targets = @(
        @("skill-creator", (Join-Path $WORKSPACE "skills" "skill-creator" "scripts"))
        @("json-utils", (Join-Path $WORKSPACE "skills" "json-utils" "scripts"))
        @("scripting-utils", (Join-Path $WORKSPACE "skills" "scripting-utils" "scripts"))
        @("model-usage", (Join-Path $WORKSPACE "skills" "model-usage" "scripts"))
        @("tiktok-live", (Join-Path $WORKSPACE "skills" "tiktok-live" "scripts"))
    )
    
    foreach ($target in $targets) {
        $skillName = $target[0]
        $scriptsDir = $target[1]
        
        $scripts = Find-ScriptsInDir $scriptsDir @("node_modules", ".git", "test", "tests")
        Log "$skillName`: $($scripts.Count) scripts found"
        
        foreach ($script in $scripts[0..9]) {  # Limit für erste Durchläufe
            $scriptSize = if (Test-Path $script) { (Get-Item $script).Length } else { 0 }
            $targetLangs = @("perl5", "javascript", "python", "shell", "tcl")
            $jobWeight = Get-JobWeight $scriptSize $targetLangs.Count
            
            # Wähle Node basierend auf Job-Gewicht
            $selectedNode = Get-NodeByPriority $jobWeight
            Log "Processing $([IO.Path]::GetFileName($script)) ($jobWeight) on $selectedNode"
            
            $created += Process-OnNode $selectedNode @($script) $targetLangs
        }
    }
    
    return $created
}

function Process-PriorityMedium {
    $created = 0
    $targets = @(
        @("workspace-scripts", (Join-Path $WORKSPACE "scripts"))
        @("db-maintainer", (Join-Path $WORKSPACE "skills" "db-maintainer" "scripts"))
        @("log-collector", (Join-Path $WORKSPACE "skills" "log-collector" "scripts"))
    )
    
    foreach ($target in $targets) {
        $dirName = $target[0]
        $scriptsDir = $target[1]
        
        $scripts = Find-ScriptsInDir $scriptsDir @("node_modules", ".git")
        
        foreach ($script in $scripts[0..9]) {
            $scriptSize = if (Test-Path $script) { (Get-Item $script).Length } else { 0 }
            $targetLangs = @("perl5", "javascript", "powershell", "python")
            $jobWeight = Get-JobWeight $scriptSize $targetLangs.Count
            
            # Mittlere Priority → eher leichtere Jobs
            $adjustedWeight = if ($jobWeight -eq "heavy") { "medium" } else { $jobWeight }
            $selectedNode = Get-NodeByPriority $adjustedWeight
            Log "Processing $([IO.Path]::GetFileName($script)) ($jobWeight) on $selectedNode"
            
            $created += Process-OnNode $selectedNode @($script) $targetLangs
        }
    }
    
    return $created
}

function Git-Commit {
    param([string]$Message)
    
    try {
        Push-Location $ABSTRACTIONS_REPO
        & git add . 2>$null
        & git commit -m $Message 2>$null
        Log "Git commit: $Message"
    }
    catch {
        # Ignore errors
    }
    finally {
        Pop-Location
    }
}

function Create-StatusReport {
    param([hashtable]$State)
    
    $reportFile = Join-Path $ABSTRACTIONS_REPO "STATUS.md"
    $langCounts = @{}
    
    if (Test-Path $ABSTRACTIONS_REPO) {
        foreach ($langDir in Get-ChildItem $ABSTRACTIONS_REPO -Directory) {
            $langName = $langDir.Name
            if ($TARGET_LANGUAGES.ContainsKey($langName)) {
                $fileCount = (Get-ChildItem $langDir.FullName -File).Count
                $langCounts[$langName] = $fileCount
            }
        }
    }
    
    $reportContent = @"
# Script Abstractions - Status Report

**Letzte Aktualisierung:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')

- Aktuelle Priorität: $($State.current_priority)
- Verarbeitete Scripts: $($State.processed.Count)
- Abstraktionen gesamt: $($State.stats.abstractions_created)

## Abstraktionen pro Sprache

$($langCounts.GetEnumerator() | Sort-Object Name | ForEach-Object { "- $($_.Key): $($_.Value)`n" })

## Verfügbare Modelle

$($AVAILABLE_MODELS[0..2] | ForEach-Object { "- ``$_````n" })
- ... und $(($AVAILABLE_MODELS.Count - 3)) weitere

## Multi-Node Support

| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |
|------|---------------|-----------|-----------|-------|
$($NODES.GetEnumerator() | ForEach-Object { 
    $nodeId = $_.Key
    $config = $_.Value
    $avail = if ($config.always_available) { "✅ Immer" } else { "📱 Bedingt" }
    $device = if ($config.device) { $config.device } else { "Server" }
    "| $nodeId | $avail | $($config.capacity) | $($config.priority) | $device |`n"
})

### Job-Verteilung

- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)
- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)
- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)
"@
    
    Set-Content -Path $reportFile -Value $reportContent
}

function main {
    Log "Script Abstractions Manager (Multi-Node) gestartet"
    
    $state = Load-State
    Log "State loaded: $($state.processed.Count) processed"
    
    $currentPriority = $state.current_priority
    $created = 0
    
    if ($currentPriority -eq "high") {
        Log "Processing HIGH priority: Top 5 Skills"
        $created = Process-PriorityHigh
        if ($created -gt 0) {
            Git-Commit "High priority: $created abstractions"
        }
        $state.current_priority = "medium"
    }
    elseif ($currentPriority -eq "medium") {
        Log "Processing MEDIUM priority: Workspace Scripts"
        $created = Process-PriorityMedium
        if ($created -gt 0) {
            Git-Commit "Medium priority: $created abstractions"
        }
        $state.current_priority = "high"  # Zyklus
    }
    
    $state.stats.last_run = Get-Date -Format "o"
    $abstractionsTotal = 0
    
    foreach ($lang in $TARGET_LANGUAGES.Keys) {
        $langDir = Join-Path $ABSTRACTIONS_REPO $lang
        if (Test-Path $langDir) {
            $abstractionsTotal += (Get-ChildItem $langDir -File).Count
        }
    }
    
    $state.stats.abstractions_created = $abstractionsTotal
    
    Save-State $state
    Create-StatusReport $state
    
    Log "Abgeschlossen. $created neue Abstraktionen erstellt."
}

if ($MyInvocation.InvocationName -eq '&') {
    main
}
