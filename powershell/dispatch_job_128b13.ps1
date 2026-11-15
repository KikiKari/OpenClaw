#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "e708f3c4ef73e9ed8ef268394a4d823eecb74be7b6f9d577bfd990e9536bafa8", "source_sha256": "128b137e5c7d86f81ea7fdb61718540c70e4ed38de4430ae6a23a5739962c024", "target_language": "powershell"}
# dispatch_job.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Job Dispatcher - Verteilt Jobs auf passende Nodes
#>

# Node-Konfiguration
$NODES = @{
    "node1" = @{ always_available = $true; capacity = "medium"; priority = 2 }
    "node2" = @{ always_available = $true; capacity = "medium"; priority = 3 }
    "node3" = @{ always_available = $false; capacity = "medium"; priority = 4 }
    "node5" = @{ always_available = $false; capacity = "low"; priority = 5; device = "Redmi Note 11S" }
    "node7" = @{ always_available = $true; capacity = "high"; priority = 1 }
}

class JobDispatcher {
    <#
    .SYNOPSIS
    Dispatches jobs to appropriate nodes based on weight
    #>
    
    [string] GetJobWeight([string]$ScriptPath, [int]$TargetLangsCount = 1) {
        <#
        .SYNOPSIS
        Bewertet Job-Gewicht
        #>
        if (-not (Test-Path $ScriptPath)) {
            return "medium"
        }
        
        $scriptSize = (Get-Item $ScriptPath).Length
        $totalWork = $scriptSize * $TargetLangsCount
        
        if ($totalWork -gt 50000) {  # > 50KB
            return "heavy"
        } elseif ($totalWork -gt 10000) {  # > 10KB
            return "medium"
        } else {
            return "light"
        }
    }
    
    [string] SelectNode([string]$JobWeight) {
        <#
        .SYNOPSIS
        Wählt besten Node basierend auf Job-Gewicht
        #>
        
        [string[]]$preferred = @()
        if ($JobWeight -eq "heavy") {
            # Schwere Jobs → Node 7 (Docker), dann Node 2, dann Node 1
            $preferred = @("node7", "node2", "node1")
        } elseif ($JobWeight -eq "medium") {
            # Mittlere Jobs → Stable Nodes
            $preferred = @("node2", "node1", "node7")
        } else {  # light
            # Leichte Jobs → Mobile/verfügbare Nodes
            $preferred = @("node5", "node1", "node2")
        }
        
        # Prüfe Verfügbarkeit
        foreach ($nodeId in $preferred) {
            if ($this.CheckNodeAvailable($nodeId)) {
                return $nodeId
            }
        }
        
        # Fallback
        return "node1"
    }
    
    [bool] CheckNodeAvailable([string]$NodeId) {
        <#
        .SYNOPSIS
        Prüft ob Node erreichbar ist
        #>
        if (-not $script:NODES.ContainsKey($NodeId)) {
            return $false
        }
        
        $node = $script:NODES[$NodeId]
        
        # Nicht immer-verfügbare Nodes nur wenn explizit requested
        if (-not $node.always_available) {
            # Für light-jobs prüfen wir ob online
            if ($NodeId -eq "node5") {  # Redmi
                return $this._CheckMobileOnline()
            }
            return $false
        }
        
        # Für immer-verfügbare Nodes: prüfe ob wirklich online
        try {
            $result = Start-Process -FilePath "openclaw" -ArgumentList "nodes", "status", $NodeId -NoNewWindow -PassThru -Wait -RedirectStandardOutput "NUL" -RedirectStandardError "NUL"
            return $result.ExitCode -eq 0
        } catch {
            return $node.always_available
        }
    }
    
    [bool] _CheckMobileOnline() {
        <#
        .SYNOPSIS
        Prüft ob Redmi (Node 5) Internet hat
        #>
        try {
            $output = & openclaw nodes status node5 2>$null
            $exitCode = $LASTEXITCODE
            return ($exitCode -eq 0) -and ($output -like "*online*")
        } catch {
            return $false
        }
    }
    
    [hashtable] Dispatch([string]$JobScript, [array]$TargetLangs = @("perl5")) {
        <#
        .SYNOPSIS
        Dispatched Job und gibt Info zurück
        #>
        $weight = $this.GetJobWeight($JobScript, $TargetLangs.Count)
        $selectedNode = $this.SelectNode($weight)
        
        return @{
            job = $JobScript
            weight = $weight
            selected_node = $selectedNode
            target_langs = $TargetLangs
            status = "dispatched"
        }
    }
}

function Main {
    param()
    
    $parser = @{
        job = ""
        langs = "perl5"
        weight = ""
        execute = $false
    }
    
    # Simple argument parsing
    $argsEnum = $args.GetEnumerator()
    for ($i = 0; $i -lt $args.Count; $i++) {
        $arg = $args[$i]
        switch ($arg) {
            {($_ -eq "--job") -or ($_ -eq "-j")} {
                if (($i + 1) -lt $args.Count) {
                    $parser.job = $args[++$i]
                }
            }
            {($_ -eq "--langs") -or ($_ -eq "-l")} {
                if (($i + 1) -lt $args.Count) {
                    $parser.langs = $args[++$i]
                }
            }
            {($_ -eq "--weight") -or ($_ -eq "-w")} {
                if (($i + 1) -lt $args.Count) {
                    $parser.weight = $args[++$i]
                }
            }
            {($_ -eq "--execute") -or ($_ -eq "-x")} {
                $parser.execute = $true
            }
            "--help" {
                Write-Host "Usage: $($MyInvocation.MyCommand.Name) --job JOB [--langs LANGS] [--weight WEIGHT] [--execute]"
                exit 0
            }
        }
    }
    
    if ([string]::IsNullOrEmpty($parser.job)) {
        Write-Host "❌ Job argument is required"
        exit 1
    }
    
    $jobPath = $parser.job
    if (-not (Test-Path $jobPath)) {
        Write-Host "❌ Job not found: $jobPath"
        exit 1
    }
    
    $dispatcher = [JobDispatcher]::new()
    $targetLangs = $parser.langs.Split(",")
    
    # Determine weight
    [string]$weight = ""
    if (-not [string]::IsNullOrEmpty($parser.weight)) {
        $weight = $parser.weight
    } else {
        $weight = $dispatcher.GetJobWeight($jobPath, $targetLangs.Count)
    }
    
    # Select node
    $selectedNode = $dispatcher.SelectNode($weight)
    
    # Output
    Write-Host "📦 Job Dispatch Information"
    Write-Host "=================================================="
    Write-Host "Job: $jobPath"
    Write-Host "Size: $((Get-Item $jobPath).Length) bytes"
    Write-Host "Target langs: $($targetLangs -join ', ')"
    Write-Host "Job weight: $weight"
    Write-Host "Selected node: $selectedNode"
    Write-Host "=================================================="
    
    if ($parser.execute) {
        Write-Host "`n🚀 Executing on $selectedNode..."
        # TODO: Implement remote execution
        Write-Host "(Remote execution not yet implemented)"
    } else {
        Write-Host "`n💡 To execute: $($MyInvocation.MyCommand.Path) --job '$($parser.job)' --execute"
    }
}

Main
