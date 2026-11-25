#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "26ae09bdb180a17930c5b3335ffed0d83d6ea45bc8b57aae1953dc22464dec7d", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "powershell"}
# test_multinode_fallback.py — portiert nach powershell
# Quelle: python, workspace@local:scripts/test_multinode_fallback.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Testet Multi-Node Fallback-Logik des db-maintainer
Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
#>

$WORKSPACE = "/home/openclaw/.openclaw/workspace"

function Check-NodeReachable {
    param (
        [string]$NodeId
    )
    <#
    .SYNOPSIS
    Prüft den Verbindungseintrag dieses Nodes, nicht die Gesamtausgabe.
    #>
    $aliases = @($NodeId.ToLower())
    $node2Names = @("openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net")
    
    if ($node2Names -contains $NodeId.ToLower()) {
        $aliases += $node2Names
    }
    
    try {
        $result = & openclaw nodes status --json 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        
        $payload = $result | ConvertFrom-Json
        foreach ($node in $payload.nodes) {
            if ($node.PSObject.Properties.Name -contains 'displayName' -and 
                $node.PSObject.Properties.Name -contains 'connected') {
                
                $displayName = $node.displayName.ToString().ToLower()
                if ($aliases -contains $displayName -and $node.connected -eq $true) {
                    return $true
                }
            }
        }
        return $false
    } catch {
        return $false
    }
}

function Spawn-OnNode {
    param (
        [string]$NodeId,
        [string]$Task
    )
    <#
    .SYNOPSIS
    Versucht Task auf Node auszuführen
    #>
    Write-Host "Versuche Task auf Node $NodeId zu starten..."
    try {
        # Simuliert: openclaw agent spawn --node {node_id}
        $result = & echo "Spawned on $NodeId`: $Task"
        Write-Host "✅ Erfolgreich delegiert an $NodeId"
        return $true
    } catch {
        Write-Host "❌ Node $NodeId nicht erreichbar: $_"
        return $false
    }
}

function Execute-Locally {
    param (
        [string]$Task
    )
    <#
    .SYNOPSIS
    Führt Task lokal aus (Fallback)
    #>
    Write-Host "🔄 Fallback: Führe Task lokal aus..."
    try {
        if ($Task -eq 'db_maintainer') {
            $scriptPath = Join-Path $WORKSPACE "skills/db-maintainer/scripts/db_maintainer.py"
            $result = & python3 $scriptPath 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Lokale Ausführung erfolgreich"
                return $true
            } else {
                $errorOutput = ($result | Out-String).Trim()
                if ($errorOutput.Length -gt 200) {
                    $errorOutput = $errorOutput.Substring(0, 200)
                }
                Write-Host "❌ Fehler: $errorOutput"
                return $false
            }
        }
    } catch {
        Write-Host "❌ Lokale Ausführung fehlgeschlagen: $_"
        return $false
    }
}

function Main {
    Write-Host ("=" * 60)
    Write-Host "MULTI-NODE FALLBACK TEST"
    Write-Host ("=" * 60)
    Write-Host ""
    
    # Konfiguration
    $primaryNode = 'v2202604104722449961.taild25fea.ts.net'  # Node 2
    $task = 'db_maintainer'
    
    Write-Host "Primärer Node: $primaryNode"
    Write-Host "Task: $task"
    Write-Host ""
    
    # 1. Prüfe Node-Erreichbarkeit
    Write-Host "--- 1. Prüfe Node-Erreichbarkeit ---"
    if (Check-NodeReachable -NodeId $primaryNode) {
        Write-Host "✅ Node $primaryNode ist erreichbar"
        
        # 2. Versuche Delegation
        Write-Host ""
        Write-Host "--- 2. Versuche Delegation ---"
        if (Spawn-OnNode -NodeId $primaryNode -Task $task) {
            Write-Host ""
            Write-Host "✅ MULTI-NODE: Task erfolgreich delegiert"
            return 0
        } else {
            Write-Host ""
            Write-Host "⚠️ Delegation fehlgeschlagen, aktiviere Fallback..."
        }
    } else {
        Write-Host "❌ Node $primaryNode nicht erreichbar"
        Write-Host "🔄 Fallback wird aktiviert..."
    }
    
    # 3. Lokale Ausführung (Fallback)
    Write-Host ""
    Write-Host "--- 3. Lokale Ausführung (Fallback) ---"
    if (Execute-Locally -Task $task) {
        Write-Host ""
        Write-Host "✅ FALLBACK: Task lokal erfolgreich ausgeführt"
        return 0
    } else {
        Write-Host ""
        Write-Host "❌ FEHLER: Weder Delegation noch Fallback erfolgreich"
        return 1
    }
}

exit (Main)
