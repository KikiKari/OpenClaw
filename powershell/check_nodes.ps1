#!/usr/bin/env pwsh
# check_nodes.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/multi-nodes-utils/scripts/check_nodes.py
# auch in: OpenClaw@gateway2:skills/multi-nodes-utils/scripts/check_nodes.py
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

<#
Node-Status Checker - Prüft Verfügbarkeit aller Nodes
#>

$NODES = @{
    "node1" = @{
        "always_available" = $true
        "capacity" = "medium"
        "priority" = 2
        "description" = "Gateway-Master"
    }
    "node2" = @{
        "always_available" = $true
        "capacity" = "medium"
        "priority" = 3
        "description" = "Stable Worker"
    }
    "node3" = @{
        "always_available" = $false
        "capacity" = "medium"
        "priority" = 4
        "description" = "Bald verfügbar (nach Reorganisation)"
    }
    "node5" = @{
        "always_available" = $false
        "capacity" = "low"
        "priority" = 5
        "device" = "Redmi Note 11S"
        "description" = "Mobile (bei Internet verfügbar)"
    }
    "node7" = @{
        "always_available" = $true
        "capacity" = "high"
        "priority" = 1
        "description" = "Docker Hauptarbeitspferd (bald verfügbar)"
    }
}

function Check-NodeStatus {
    param (
        [string]$node_id
    )

    try {
        $process = Start-Process -FilePath "openclaw" -ArgumentList "nodes", "status", $node_id -NoNewWindow -PassThru
        $success = $process.WaitForExit(5000)
        $output = $process.StandardOutput.ReadToEnd()

        $is_online = $success -and ($output -match "online" -or $output -match "active")

        $result = @{
            "id" = $node_id
            "online" = $is_online
            "available" = $NODES[$node_id].always_available
            "response" = if ($output) { $output.Substring(0, [Math]::Min(100, $output.Length)) } else { "No response" }
        }
    }
    catch {
        $result = @{
            "id" = $node_id
            "online" = $false
            "available" = $NODES[$node_id].always_available
            "response" = "Timeout"
        }
    }

    return $result
}

function Print-Table {
    param (
        [array]$nodes_status
    )

    Write-Host "`n" + "=" * 90
    Write-Host -NoNewline "Node     "
    Write-Host -NoNewline "Status       "
    Write-Host -NoNewline "Verfügbar    "
    Write-Host -NoNewline "Kapazität  "
    Write-Host -NoNewline "Priorität "
    Write-Host "Gerät/Beschreibung"
    Write-Host "=" * 90

    foreach ($status in $nodes_status) {
        $node_id = $status.id
        $config = $NODES[$node_id]

        $status_icon = if ($status.online) { "🟢 Online" } else { "🔴 Offline" }
        $avail_icon = if ($status.available) { "✅ Immer" } else { "📱 Bedingt" }
        $capacity = if ($config.capacity) { $config.capacity } else { "unknown" }
        $priority = if ($config.priority) { $config.priority } else { "-" }
        $device = if ($config.device) { $config.device } else { if ($config.description) { $config.description } else { "" } }

        Write-Host -NoNewline "$node_id`t"
        Write-Host -NoNewline "$status_icon`t"
        Write-Host -NoNewline "$avail_icon`t"
        Write-Host -NoNewline "$capacity`t"
        Write-Host -NoNewline "$priority`t"
        Write-Host $device
    }

    Write-Host "=" * 90
    Write-Host "`nGeprüft am: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
}

function Print-Json {
    param (
        [array]$nodes_status
    )

    $output = @{
        "timestamp" = (Get-Date).ToString("o")
        "nodes" = @{}
    }

    foreach ($status in $nodes_status) {
        $node_id = $status.id
        $output.nodes[$node_id] = @{
            "status" = $status
            "config" = $NODES[$node_id]
        }
    }

    $output | ConvertTo-Json -Depth 4
}

function Main {
    param (
        [string]$format = "table",
        [string]$save
    )

    Write-Host "🔍 Prüfe Node-Status..."

    # Prüfe alle Nodes
    $nodes_status = @()
    foreach ($node_id in ($NODES.Keys | Sort-Object)) {
        Write-Host -NoNewline "  → $node_id... "
        $status = Check-NodeStatus -node_id $node_id
        $nodes_status += $status
        Write-Host -NoNewline (if ($status.online) { "✓" } else { "✗" })
    }

    # Ausgabe
    if ($format -eq "table") {
        Print-Table -nodes_status $nodes_status
    } else {
        Print-Json -nodes_status $nodes_status
    }

    # Speichern
    if ($save) {
        $output = @{
            "timestamp" = (Get-Date).ToString("o")
            "nodes" = @{}
        }

        foreach ($status in $nodes_status) {
            $output.nodes[$status.id] = $status
        }

        $output | ConvertTo-Json -Depth 4 | Out-File -FilePath $save
        Write-Host "`n💾 Gespeichert: $save"
    }

    # Zusammenfassung
    $online_count = ($nodes_status | Where-Object { $_.online }).Count
    Write-Host "`n📊 Zusammenfassung: $online_count/$($nodes_status.Count) Nodes online"
}

if ((Get-Command -Name "Main" -ErrorAction SilentlyContinue)) {
    Main @args
}
