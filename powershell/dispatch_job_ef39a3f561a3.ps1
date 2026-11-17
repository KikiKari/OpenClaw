#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "80c81e22baeb968ce57d48b3fa0fce8595795983cc6af8c43b29a2f5acb2bac2", "source_sha256": "748c0fc07a58caf07d4983d358cf0e1ce57c4e180b87ae617d598f53c61efcec", "target_language": "powershell"}
# dispatch_job.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/dispatch_job.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Job Dispatcher - Verteilt Jobs auf passende Nodes
#>

function Get-JobWeightBytes {
    param(
        [System.IO.FileInfo]$ScriptPath,
        [int]$TargetLangsCount
    )
    # Arbeitsvolumen: Dateigröße × Anzahl der Zielsprachen
    return $ScriptPath.Length * $TargetLangsCount
}

# Node-Konfiguration
$NODES = @{
    "node1" = @{always_available = $true; capacity = "medium"; priority = 3; description = "Gateway"}
    "node2" = @{always_available = $false; capacity = "high"; priority = 1; description = "ARM Server"}
    "node3" = @{always_available = $false; capacity = "medium"; priority = 4; description = "AMD Server"}
    "node4" = @{always_available = $false; capacity = "low"; priority = 5; device = "Redmi Note 11S"}
    "node5" = @{always_available = $false; capacity = "high"; priority = 2; device = "Lenovo"}
    "node6" = @{always_available = $false; device = "Lenovo (Docker)"}
}

$NODE_NAMES = @{
    "node2" = @("openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122")
    "node3" = @("openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125")
    "node4" = @("openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39")
    "node5" = @("openclaw-node5", "windows node (lenovo-7)")
    "node6" = @("openclaw-node6")
}

function Fetch-NodeStatus {
    <#
    .SYNOPSIS
    Return mapped OpenClaw connection states; $null indicates lookup failure.
    #>
    try {
        $result = & openclaw nodes status --json 2>$null | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $result -or $result.PSObject.Properties.Name -notcontains "nodes") {
            return $null
        }
        $states = @{}
        foreach ($node in $NODE_NAMES.Keys) {
            $states[$node] = $false
        }
        foreach ($item in $result.nodes) {
            if ($null -eq $item) { continue }
            $names = @($item.displayName, $item.nodeId, $item.remoteIp) | ForEach-Object { if ($_ -is [string]) { $_.ToLower() } else { "" } }
            foreach ($node in $NODE_NAMES.Keys) {
                $aliases = $NODE_NAMES[$node]
                $found = $false
                foreach ($alias in $aliases) {
                    if ($names -contains $alias.ToLower()) {
                        $found = $true
                        break
                    }
                }
                if ($found -and $item.connected -eq $true) {
                    $states[$node] = $true
                }
            }
        }
        $states["node1"] = $true  # successful Gateway status request
        return $states
    }
    catch {
        return $null
    }
}

class JobDispatcher {
    <#
    .SYNOPSIS
    Dispatches jobs to appropriate nodes based on weight
    #>
    
    [string] GetJobWeight([System.IO.FileInfo]$scriptPath, [int]$targetLangsCount = 1) {
        <#
        .SYNOPSIS
        Bewertet Job-Gewicht
        #>
        if (-not (Test-Path $scriptPath)) {
            return "medium"
        }
        
        $totalWork = Get-JobWeightBytes -ScriptPath $scriptPath -TargetLangsCount $targetLangsCount
        
        if ($totalWork -gt 50000) {  # > 50KB
            return "heavy"
        }
        elseif ($totalWork -gt 10000) {  # > 10KB
            return "medium"
        }
        else {
            return "light"
        }
    }
    
    [string] SelectNode([string]$jobWeight) {
        <#
        .SYNOPSIS
        Wählt besten Node basierend auf Job-Gewicht
        #>
        $preferred = @()
        switch ($jobWeight) {
            "heavy" { $preferred = @("node1", "node2", "node5", "node6") }
            "medium" { $preferred = @("node1", "node2", "node3", "node6") }
            "light" { $preferred = @("node2", "node1", "node3", "node4") }
            Default { throw "Unknown job weight: $jobWeight" }
        }

        $states = Fetch-NodeStatus
        foreach ($node_id in $preferred) {
            if ($null -ne $states -and $states.ContainsKey($node_id) -and $states[$node_id]) {
                return $node_id
            }
        }
        return $null  # no verified reachable node
    }

    [bool] CheckNodeAvailable([string]$node_id) {
        <#
        .SYNOPSIS
        Use the live connection state rather than static availability.
        #>
        $states = Fetch-NodeStatus
        return ($null -ne $states -and $states.ContainsKey($node_id) -and $states[$node_id])
    }

    [string] ExecuteTranslation([hashtable]$job, [scriptblock]$transport) {
        return Execute-Translation -Job $job -Transport $transport
    }

    [bool] CheckMobileOnline() {
        <#
        .SYNOPSIS
        Check Node4 (Redmi).
        #>
        return $this.CheckNodeAvailable("node4")
    }

    [hashtable] Dispatch([System.IO.FileInfo]$job_script, [array]$target_langs = @("perl5"), [string]$source_text = $null, [string]$source_language = $null) {
        <#
        .SYNOPSIS
        Dispatched Job und gibt Info zurück
        #>
        if ($null -eq $target_langs) {
            $target_langs = @("perl5")
        }
        
        $weight = $this.GetJobWeight($job_script, $target_langs.Count)
        $selected_node = $this.SelectNode($weight)
        $translation_jobs = @()
        foreach ($language in $target_langs) {
            $job = @{
                job_id = [System.Guid]::NewGuid().ToString()
                source = $job_script.FullName
                target_language = $language
                selected_node = $selected_node
            }
            if ($null -ne $source_text) {
                $job.source_text = $source_text
            }
            if ($null -ne $source_language) {
                $job.source_language = $source_language
            }
            $translation_jobs += $job
        }
        
        return @{
            job = $job_script.FullName
            weight = $weight
            selected_node = $selected_node
            target_langs = $target_langs
            translation_jobs = $translation_jobs
            status = if ($selected_node) { "selected" } else { "unavailable" }
        }
    }
}

function Execute-Translation {
    param(
        [hashtable]$Job,
        [scriptblock]$Transport
    )
    <#
    .SYNOPSIS
    Execute via a supplied transport and verify its result belongs to the job.
    #>
    if (-not $Job.selected_node -or $null -eq $Transport) {
        throw "no verified node or authorized translation transport"
    }
    $response = & $Transport $Job
    if ($response -isnot [hashtable] -and $response -isnot [PSCustomObject]) {
        throw "invalid transport response"
    }
    $responseObject = if ($response -is [hashtable]) { $response } else { $response | ConvertTo-Hashtable }
    
    foreach ($key in @("job_id", "selected_node", "target_language")) {
        if ($responseObject[$key] -ne $Job[$key]) {
            throw "transport response does not match job"
        }
    }
    $code = $responseObject.code
    if ($responseObject.status -ne "ok" -or $code -isnot [string] -or [string]::IsNullOrWhiteSpace($code)) {
        throw "translation did not complete with code"
    }
    return $code
}

function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline=$true)]$InputObject)
    process {
        if ($null -eq $InputObject) { return @{} }
        $output = @{}
        $InputObject.PSObject.Properties | ForEach-Object {
            $output[$_.Name] = $_.Value
        }
        return $output
    }
}

function Dispatch-AbstractionJob {
    param(
        [System.IO.FileInfo]$JobScript,
        [array]$TargetLangs
    )
    <#
    .SYNOPSIS
    Erstellt eine Node-Auswahl und je (Skript, Sprache) einen Auftrag.
    #>
    $dispatcher = [JobDispatcher]::new()
    return $dispatcher.Dispatch($JobScript, $TargetLangs)
}

function Main {
    param(
        [string]$Job,
        [string]$Langs = "perl5",
        [ValidateSet("light", "medium", "heavy")]
        [string]$Weight,
        [switch]$Execute
    )
    
    $jobPath = Get-Item $Job -ErrorAction SilentlyContinue
    if (-not $jobPath) {
        Write-Host "❌ Job not found: $Job" -ForegroundColor Red
        exit 1
    }
    
    $dispatcher = [JobDispatcher]::new()
    $target_langs = $Langs.Split(",")
    
    # Determine weight
    if ($Weight) {
        $weight = $Weight
    }
    else {
        $weight = $dispatcher.GetJobWeight($jobPath, $target_langs.Count)
    }
    
    # Select node
    $selected_node = $dispatcher.SelectNode($weight)
    
    # Output
    Write-Host "📦 Job Dispatch Information"
    Write-Host ("=" * 50)
    Write-Host "Job: $($jobPath.FullName)"
    Write-Host "Size: $($jobPath.Length) bytes"
    Write-Host "Target langs: $($target_langs -join ', ')"
    Write-Host "Job weight: $weight"
    Write-Host "Selected node: $selected_node"
    Write-Host ("=" * 50)
    
    if ($Execute) {
        Write-Error "Translation dispatch on $selected_node is not implemented."
        return 1
    }
    else {
        Write-Host "`n💡 To execute: $($MyInvocation.MyCommand.Path) --Job '$Job' --Execute"
    }
    return 0
}

# Parameter parsing
param(
    [Parameter(Mandatory=$true)]
    [string]$Job,
    
    [string]$Langs = "perl5",
    
    [ValidateSet("light", "medium", "heavy")]
    [string]$Weight,
    
    [switch]$Execute
)

exit (Main -Job $Job -Langs $Langs -Weight $Weight -Execute:$Execute)
