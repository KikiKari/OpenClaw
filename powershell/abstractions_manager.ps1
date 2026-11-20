#!/usr/bin/env pwsh
# abstractions_manager.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/abstractions_manager.py
# Erzeugt: 2026-11-07 durch ABSTRACTIONS_MANAGER.py

<#
Script Abstractions Manager - Multi-Node Edition
#>

param()

# Konfiguration
$WORKSPACE = [System.IO.Path]::Combine($env:HOME, ".openclaw", "workspace")
$ABSTRACTIONS_REPO = [System.IO.Path]::Combine($WORKSPACE, "git", "Abstraktionen")
$LOG_DIR = [System.IO.Path]::Combine($WORKSPACE, "logs", "abstractions-manager")
$STATE_FILE = [System.IO.Path]::Combine($WORKSPACE, "db", "abstractions_state.json")

# Node-Konfiguration mit Prioritäten
$NODES = @{
    "node1" = @{ always_available = $true; capacity = "medium"; priority = 2 }  # Gateway-Master
    "node2" = @{ always_available = $true; capacity = "medium"; priority = 3 }  # Stable Worker
    "node3" = @{ always_available = $false; capacity = "medium"; priority = 4 } # Bald verfügbar
    "node5" = @{ always_available = $false; capacity = "low"; priority = 5; device = "Redmi Note 11S"; condition = "mobile_internet" }
    "node7" = @{ always_available = $true; capacity = "high"; priority = 1 }    # Docker Hauptarbeitspferd
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
    "perl5"      = @{ ext = ".pl"; shebang = "#!/usr/bin/env perl"; header = "use strict;`nuse warnings;`n" }
    "perl6"      = @{ ext = ".raku"; shebang = "#!/usr/bin/env raku"; header = "use v6;`n" }
    "javascript"= @{ ext = ".js"; shebang = "#!/usr/bin/env node"; header = "" }
    "python"     = @{ ext = ".py"; shebang = "#!/usr/bin/env python3"; header = "" }
    "shell"      = @{ ext = ".sh"; shebang = "#!/bin/bash"; header = "set -euo pipefail`n" }
    "powershell" = @{ ext = ".ps1"; shebang = "#!/usr/bin/env pwsh"; header = "#Requires -Version 7`n" }
    "tcl"        = @{ ext = ".tcl"; shebang = "#!/usr/bin/env tclsh"; header = "package require Tcl 8.6`n" }
    "ruby"       = @{ ext = ".rb"; shebang = "#!/usr/bin/env ruby"; header = "require 'json'`nrequire 'fileutils'`n" }
    "lua"        = @{ ext = ".lua"; shebang = "#!/usr/bin/env lua"; header = "" }
    "go"         = @{ ext = ".go"; shebang = "// +build ignore"; header = "package main`n" }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $null = New-Item -ItemType Directory -Path $LOG_DIR -Force
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[${timestamp}] [${Level}] ${Message}"
    Write-Host $line
    $logFile = [System.IO.Path]::Combine($LOG_DIR, "$(Get-Date -Format 'yyyy-MM-dd').log")
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
    } elseif ($JobWeight -eq "medium") {
        # Mittlere Jobs → Stable Nodes
        $preferredOrder = @("node2", "node1", "node7")
    } else {
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
        if (Test-NodeStatus -NodeId $nodeId) {
            return $nodeId
        }
    }
    
    # Fallback zu Node 1
    return "node1"
}

function Test-NodeStatus {
    param(
        [string]$NodeId
    )
    
    try {
        $result = & openclaw nodes status $NodeId 2>$null
        return ($LASTEXITCODE -eq 0) -and (($result -like "*online*") -or ($result -like "*active*"))
    } catch {
        # Bei Timeout/Error: Prüfe letzten bekannten Status
        if ($NODES.ContainsKey($NodeId)) {
            return $NODES[$NodeId].always_available
        }
        return $false
    }
}

function Get-JobWeight {
    param(
        [int]$ScriptSize,
        [int]$TargetLangsCount
    )
    
    $totalWork = $ScriptSize * $TargetLangsCount
    
    if ($totalWork -gt 50000) {
        return "heavy"
    } elseif ($totalWork -gt 10000) {
        return "medium"
    } else {
        return "light"
    }
}

function Load-State {
    if (Test-Path $STATE_FILE) {
        try {
            return Get-Content $STATE_FILE | ConvertFrom-Json -AsHashtable
        } catch {
            # Ignoriere Fehler beim Laden
        }
    }
    
    return @{
        processed = @{}
        queue = @()
        current_priority = "high"
        stats = @{ total_scripts = 0; abstractions_created = 0 }
    }
}

function Save-State {
    param(
        [hashtable]$State
    )
    
    $parentDir = Split-Path $STATE_FILE -Parent
    $null = New-Item -ItemType Directory -Path $parentDir -Force
    $State | ConvertTo-Json -Depth 10 | Set-Content $STATE_FILE
}

function Find-ScriptsInDir {
    param(
        [string]$Directory,
        [string[]]$ExcludePatterns = @("node_modules", ".git", "__pycache__", "dist", "build")
    )
    
    $scripts = @()
    if (Test-Path $Directory) {
        $extensions = @("*.py", "*.js", "*.sh", "*.pl", "*.rb")
        foreach ($ext in $extensions) {
            Get-ChildItem -Path $Directory -Recurse -Filter $ext -File | ForEach-Object {
                $scriptPath = $_.FullName
                $shouldExclude = $false
                foreach ($pattern in $ExcludePatterns) {
                    if ($scriptPath -like "*${pattern}*") {
                        $shouldExclude = $true
                        break
                    }
                }
                if (-not $shouldExclude) {
                    $scripts += $_
                }
            }
        }
    }
    return $scripts
}

function Create-Abstraction {
    param(
        [System.IO.FileInfo]$ScriptPath,
        [string]$TargetLang
    )
    
    try {
        $originalContent = Get-Content $ScriptPath.FullName -Encoding UTF8 -Raw
        if ($null -eq $originalContent) {
            $originalContent = ""
        }
        
        $ext = $ScriptPath.Extension.TrimStart(".")
        $sourceLangMap = @{
            "py" = "Python"
            "js" = "JavaScript"
            "sh" = "Shell"
            "pl" = "Perl"
            "rb" = "Ruby"
        }
        $sourceLang = if ($sourceLangMap.ContainsKey($ext)) { $sourceLangMap[$ext] } else { $ext }
        
        $targetDir = [System.IO.Path]::Combine($ABSTRACTIONS_REPO, $TargetLang)
        $null = New-Item -ItemType Directory -Path $targetDir -Force
        
        $targetFile = [System.IO.Path]::Combine($targetDir, "$($ScriptPath.BaseName)$($TARGET_LANGUAGES[$TargetLang].ext)")
        
        if (Test-Path $targetFile) {
            return $false
        }
        
        $template = $TARGET_LANGUAGES[$TargetLang]
        $lines = ($originalContent -split "`n")[0..14] -join "`n"
        
        $content = @"
$($template.shebang)
# $($ScriptPath.BaseName) - $($TargetLang.Substring(0,1).ToUpper()+$TargetLang.Substring(1)) Version
# Portiert von $sourceLang
# Original: $($ScriptPath.FullName)
# Erstellt: $(Get-Date -Format 'yyyy-MM-dd')
#
$($template.header)

# Original-Code-Referenz:
# $($lines -replace "`n", "`n# ")

def main():
    # TODO: Implementiere $sourceLang Funktionalität in $($TargetLang.Substring(0,1).ToUpper()+$TargetLang.Substring(1))
    pass

if __name__ == "__main__":
    main()
"@
        
        Set-Content -Path $targetFile -Value $content -Encoding UTF8
        Write-Log "Created: $targetFile"
        return $true
    } catch {
        Write-Log "Failed: $($ScriptPath.Name) - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Process-OnNode {
    param(
        [string]$NodeId,
        [array]$Scripts,
        [array]$TargetLangs
    )
    
    $created = 0
    
    if ($NodeId -eq "node1") {
        # Lokale Verarbeitung
        foreach ($script in $Scripts) {
            foreach ($lang in $TargetLangs) {
                if (Create-Abstraction -ScriptPath $script -TargetLang $lang) {
                    $created++
                }
            }
        }
    } else {
        # Remote-Verarbeitung
        Write-Log "Dispatching $($Scripts.Count) jobs to $NodeId"
        # TODO: Implementiere Remote-Dispatch wenn Node-Infrastruktur bereit
        # Für jetzt: Lokale Verarbeitung mit Node-Logging
        foreach ($script in $Scripts) {
            foreach ($lang in $TargetLangs) {
                if (Create-Abstraction -ScriptPath $script -TargetLang $lang) {
                    $created++
                    Write-Log "Processed on ${NodeId}: $($script.Name) -> ${lang}"
                }
            }
        }
    }
    
    return $created
}

function Process-PriorityHigh {
    $created = 0
    $targets = @(
        @{ skill_name = "skill-creator"; scripts_dir = [System.IO.Path]::Combine($WORKSPACE, "skills", "skill-creator", "scripts") }
        @{ skill_name = "json-utils"; scripts_dir = [System.IO.Path]::Combine($WORKSPACE, "skills", "json-utils", "scripts") }
        @{ skill_name = "scripting-utils"; scripts_dir = [System.IO.Path]::Combine($WORKSPACE, "skills", "scripting-utils", "scripts") }
        @{ skill_name = "model-usage"; scripts_dir = [System.IO.Path]::Combine($WORKSPACE, "skills", "model-usage", "scripts") }
        @{ skill_name = "tiktok-live"; scripts_dir = [System.IO.Path]::Combine($WORKSPACE, "skills", "tiktok-live", "scripts") }
    )
    
    foreach ($target in $targets) {
        $scripts = Find-ScriptsInDir -Directory $target.scripts_dir -ExcludePatterns @("node_modules", ".git", "test", "tests")
        Write-Log "$($target.skill_name): $($scripts.Count) scripts found"
        
        $limit = [Math]::Min(10, $scripts.Count)
        for ($i = 0; $i -lt $limit; $i++) {
            $script = $scripts[$i]
            $scriptSize = if (Test-Path $script.FullName) { (Get-Item $script.FullName).Length } else { 0 }
            $targetLangs = @("perl5", "javascript", "python", "shell", "tcl")
            $jobWeight = Get-JobWeight -ScriptSize $scriptSize -TargetLangsCount $targetLangs.Count
            
            # Wähle Node basierend auf Job-Gewicht
            $selectedNode = Get-NodeByPriority -JobWeight $jobWeight
            Write-Log "Processing $($script.Name) (${jobWeight}) on ${selectedNode}"
            
            $created += Process-OnNode -NodeId $selectedNode -Scripts @($script) -TargetLangs $targetLangs
        }
    }
    
    return $created
}

function Process-PriorityMedium {
    $created = 0
    $targets = @(
        @{ dir_name = "workspace-scripts"; scripts_dir = [System.IO.Path]::Combine($WORKSPACE, "scripts") }
        @{ dir_name = "db-maintainer"; scripts_dir = [System.IO.Path]::Combine($WORKSPACE, "skills", "db-maintainer", "scripts") }
        @{ dir_name = "log-collector"; scripts_dir = [System.IO.Path]::Combine($WORKSPACE, "skills", "log-collector", "scripts") }
    )
    
    foreach ($target in $targets) {
        $scripts = Find-ScriptsInDir -Directory $target.scripts_dir -ExcludePatterns @("node_modules", ".git")
        
        $limit = [Math]::Min(10, $scripts.Count)
        for ($i = 0; $i -lt $limit; $i++) {
            $script = $scripts[$i]
            $scriptSize = if (Test-Path $script.FullName) { (Get-Item $script.FullName).Length } else { 0 }
            $targetLangs = @("perl5", "javascript", "powershell", "python")
            $jobWeight = Get-JobWeight -ScriptSize $scriptSize -TargetLangsCount $targetLangs.Count
            
            # Mittlere Priority → eher leichtere Jobs
            $effectiveWeight = if ($jobWeight -eq "heavy") { "medium" } else { $jobWeight }
            $selectedNode = Get-NodeByPriority -JobWeight $effectiveWeight
            Write-Log "Processing $($script.Name) (${jobWeight}) on ${selectedNode}"
            
            $created += Process-OnNode -NodeId $selectedNode -Scripts @($script) -TargetLangs $targetLangs
        }
    }
    
    return $created
}

function Git-Commit {
    param(
        [string]$Message
    )
    
    try {
        Push-Location $ABSTRACTIONS_REPO
        git add . 2>$null | Out-Null
        git commit -m $Message 2>$null | Out-Null
        Write-Log "Git commit: ${Message}"
    } catch {
        # Ignoriere Git-Fehler
    } finally {
        Pop-Location
    }
}

function Create-StatusReport {
    param(
        [hashtable]$State
    )
    
    $reportFile = [System.IO.Path]::Combine($ABSTRACTIONS_REPO, "STATUS.md")
    $langCounts = @{}
    
    if (Test-Path $ABSTRACTIONS_REPO) {
        Get-ChildItem -Path $ABSTRACTIONS_REPO -Directory | Where-Object {
            $TARGET_LANGUAGES.ContainsKey($_.Name)
        } | ForEach-Object {
            $langName = $_.Name
            $fileCount = (Get-ChildItem -Path $_.FullName -File).Count
            $langCounts[$langName] = $fileCount
        }
    }
    
    $content = @"
# Script Abstractions - Status Report

**Letzte Aktualisierung:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')

- Aktuelle Priorität: $($State.current_priority)
- Verarbeitete Scripts: $($State.processed.Count)
- Abstraktionen gesamt: $($State.stats.abstractions_created)

## Abstraktionen pro Sprache

"@
    
    $sortedKeys = $langCounts.Keys | Sort-Object
    foreach ($lang in $sortedKeys) {
        $count = $langCounts[$lang]
        $content += "- ${lang}: ${count}`n"
    }
    
    $content += @"

## Verfügbare Modelle

"@
    
    for ($i = 0; $i -lt [Math]::Min(3, $AVAILABLE_MODELS.Count); $i++) {
        $content += "- `"$($AVAILABLE_MODELS[$i])`"`n"
    }
    $remaining = $AVAILABLE_MODELS.Count - 3
    if ($remaining -gt 0) {
        $content += "- ... und ${remaining} weitere`n"
    }
    
    $content += @"

## Multi-Node Support

| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |
|------|---------------|-----------|-----------|-------|
"@
    
    $sortedNodes = $NODES.Keys | Sort-Object
    foreach ($nodeId in $sortedNodes) {
        $config = $NODES[$nodeId]
        $avail = if ($config.always_available) { "✅ Immer" } else { "📱 Bedingt" }
        $device = if ($config.device) { $config.device } else { "Server" }
        $content += "| ${nodeId} | ${avail} | $($config.capacity) | $($config.priority) | ${device} |`n"
    }
    
    $content += @"

### Job-Verteilung

- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)
- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)
- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)
"@
    
    Set-Content -Path $reportFile -Value $content -Encoding UTF8
}

function Main {
    Write-Log "Script Abstractions Manager (Multi-Node) gestartet"
    
    $state = Load-State
    Write-Log "State loaded: $($state.processed.Count) processed"
    
    $currentPriority = $state.current_priority
    $created = 0
    
    if ($currentPriority -eq "high") {
        Write-Log "Processing HIGH priority: Top 5 Skills"
        $created = Process-PriorityHigh
        if ($created -gt 0) {
            Git-Commit -Message "High priority: ${created} abstractions"
        }
        $state.current_priority = "medium"
    } elseif ($currentPriority -eq "medium") {
        Write-Log "Processing MEDIUM priority: Workspace Scripts"
        $created = Process-PriorityMedium
        if ($created -gt 0) {
            Git-Commit -Message "Medium priority: ${created} abstractions"
        }
        $state.current_priority = "high"  # Zyklus
    }
    
    $state.stats.last_run = (Get-Date).ToString("o")
    
    # Zähle Abstraktionen
    $abstractionCount = 0
    foreach ($lang in $TARGET_LANGUAGES.Keys) {
        $langPath = [System.IO.Path]::Combine($ABSTRACTIONS_REPO, $lang)
        if (Test-Path $langPath) {
            $abstractionCount += (Get-ChildItem -Path $langPath -File).Count
        }
    }
    $state.stats.abstractions_created = $abstractionCount
    
    Save-State -State $state
    Create-StatusReport -State $state
    
    Write-Log "Abgeschlossen. ${created} neue Abstraktionen erstellt."
}

# Startpunkt
Main
