#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "1040e14c803076822421e5dcff7abee135b10628f7abbd1abf0a8332faff0bfc", "source_sha256": "4a2933eefa63483e06669c63463cb479ee7726e59314faa3024778c7ec79ce7e", "target_language": "powershell"}
# template.js — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/src/auto-reply/reply/export-html/template.js
# Erzeugt: 2026-11-28 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    Portiert JavaScript-Logik nach PowerShell 7.
.DESCRIPTION
    Diese Funktion liest eine JSON-Datei mit Session-Daten und gibt eine formatierte Baumstruktur sowie Nachrichten aus.
.PARAMETER Path
    Pfad zur JSON-Datei mit den Session-Daten.
.PARAMETER LeafId
    Optionale Angabe der Blatt-ID für die Navigation.
.PARAMETER TargetId
    Optionale Angabe der Ziel-ID für die Navigation.
.EXAMPLE
    .\template.ps1 -Path "session.json"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [string]$LeafId,

    [string]$TargetId
)

# Hilfsfunktionen
function ConvertFrom-Base64 {
    param([string]$InputString)
    $bytes = [Convert]::FromBase64String($InputString)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function New-TreeNode {
    param(
        [object]$Entry,
        [string]$Label,
        [array]$Children = @()
    )
    return [PSCustomObject]@{
        Entry = $Entry
        Label = $Label
        Children = $Children
    }
}

function Get-TreeNodeById {
    param(
        [array]$Nodes,
        [string]$Id
    )
    foreach ($node in $Nodes) {
        if ($node.Entry.id -eq $Id) {
            return $node
        }
        $found = Get-TreeNodeById -Nodes $node.Children -Id $Id
        if ($found) {
            return $found
        }
    }
    return $null
}

function Build-Tree {
    param([array]$Entries, [hashtable]$LabelMap)

    $nodeMap = @{}
    $roots = @()

    # Knoten erstellen
    foreach ($entry in $entries) {
        $nodeMap[$entry.id] = New-TreeNode -Entry $entry -Label $labelMap[$entry.id]
    }

    # Eltern-Kind-Beziehungen aufbauen
    foreach ($entry in $entries) {
        $node = $nodeMap[$entry.id]
        if ($entry.parentId -eq $null -or $entry.parentId -eq "" -or $entry.parentId -eq $entry.id) {
            $roots += $node
        } else {
            $parent = $nodeMap[$entry.parentId]
            if ($parent) {
                $parent.Children += $node
            } else {
                $roots += $node
            }
        }
    }

    # Kinder nach Zeitstempel sortieren
    function Sort-Children {
        param($Node)
        $Node.Children = $Node.Children | Sort-Object { [DateTime]$_.Entry.timestamp }
        foreach ($child in $Node.Children) {
            Sort-Children -Node $child
        }
    }

    foreach ($root in $roots) {
        Sort-Children -Node $root
    }

    return $roots
}

function Find-NewestLeaf {
    param([array]$Tree, [string]$NodeId)
    $node = Get-TreeNodeById -Nodes $Tree -Id $NodeId
    if (-not $node) {
        return $NodeId
    }

    $current = $node
    while ($current.Children.Count -gt 0) {
        $current = $current.Children[-1]
    }
    return $current.Entry.id
}

function Flatten-Tree {
    param([array]$Roots, [hashtable]$ActivePathIds)
    
    $result = @()
    $multipleRoots = $Roots.Count -gt 1
    
    # Aktive Zweige markieren
    $containsActive = @{}
    function Mark-Active {
        param($Node)
        $has = $ActivePathIds.ContainsKey($Node.Entry.id)
        foreach ($child in $Node.Children) {
            if (Mark-Active -Node $child) {
                $has = $true
            }
        }
        $containsActive[$Node] = $has
        return $has
    }
    
    foreach ($root in $Roots) {
        [void](Mark-Active -Node $root)
    }
    
    # Wurzeln sortieren (aktiver Zweig zuerst)
    $orderedRoots = $Roots | Sort-Object { if ($containsActive[$_]) { 0 } else { 1 } }
    
    # Stapel: [Knoten, Einzug, geradeVerzweigt, zeigeVerbinder, istLetztes, Spalten, istVirtuelleWurzelKind]
    $stack = @()
    
    for ($i = $orderedRoots.Count - 1; $i -ge 0; $i--) {
        $isLast = $i -eq ($orderedRoots.Count - 1)
        $stack += ,@($orderedRoots[$i], $(if ($multipleRoots) { 1 } else { 0 }), $multipleRoots, $multipleRoots, $isLast, @(), $multipleRoots)
    }
    
    while ($stack.Count -gt 0) {
        $item = $stack.Pop()
        $node = $item[0]
        $indent = $item[1]
        $justBranched = $item[2]
        $showConnector = $item[3]
        $isLast = $item[4]
        $gutters = $item[5]
        $isVirtualRootChild = $item[6]
        
        $result += [PSCustomObject]@{
            Node = $node
            Indent = $indent
            ShowConnector = $showConnector
            IsLast = $isLast
            Gutters = $gutters
            IsVirtualRootChild = $isVirtualRootChild
            MultipleRoots = $multipleRoots
        }
        
        $children = $node.Children
        $multipleChildren = $children.Count -gt 1
        
        # Kinder sortieren (aktiver Zweig zuerst)
        $orderedChildren = $children | Sort-Object { if ($containsActive[$_]) { 0 } else { 1 } }
        
        # Kind-Einzug berechnen
        $childIndent = 0
        if ($multipleChildren) {
            $childIndent = $indent + 1
        } elseif ($justBranched -and $indent -gt 0) {
            $childIndent = $indent + 1
        } else {
            $childIndent = $indent
        }
        
        # Spalten für Kinder erstellen
        $connectorDisplayed = $showConnector -and -not $isVirtualRootChild
        $currentDisplayIndent = if ($multipleRoots) { [Math]::Max(0, $indent - 1) } else { $indent }
        $connectorPosition = [Math]::Max(0, $currentDisplayIndent - 1)
        $childGutters = if ($connectorDisplayed) {
            $gutters + @([PSCustomObject]@{ Position = $connectorPosition; Show = -not $isLast })
        } else {
            $gutters
        }
        
        # Kinder in umgekehrter Reihenfolge zum Stapel hinzufügen
        for ($i = $orderedChildren.Count - 1; $i -ge 0; $i--) {
            $childIsLast = $i -eq ($orderedChildren.Count - 1)
            $stack += ,@($orderedChildren[$i], $childIndent, $multipleChildren, $multipleChildren, $childIsLast, $childGutters, $false)
        }
    }
    
    return $result
}

function Build-TreePrefix {
    param($FlatNode)
    
    $indent = $FlatNode.Indent
    $showConnector = $FlatNode.ShowConnector
    $isLast = $FlatNode.IsLast
    $gutters = $FlatNode.Gutters
    $isVirtualRootChild = $FlatNode.IsVirtualRootChild
    $multipleRoots = $FlatNode.MultipleRoots
    
    $displayIndent = if ($multipleRoots) { [Math]::Max(0, $indent - 1) } else { $indent }
    $connector = ""
    if ($showConnector -and -not $isVirtualRootChild) {
        $connector = if ($isLast) { "└─ " } else { "├─ " }
    }
    $connectorPosition = if ($connector) { $displayIndent - 1 } else { -1 }
    
    $totalChars = $displayIndent * 3
    $prefixChars = @()
    for ($i = 0; $i -lt $totalChars; $i++) {
        $level = [Math]::Floor($i / 3)
        $posInLevel = $i % 3
        
        $gutter = $gutters | Where-Object { $_.Position -eq $level }
        if ($gutter) {
            $prefixChars += if ($posInLevel -eq 0) { if ($gutter.Show) { "│" } else { " " } } else { " " }
        } elseif ($connector -and $level -eq $connectorPosition) {
            if ($posInLevel -eq 0) {
                $prefixChars += if ($isLast) { "└" } else { "├" }
            } elseif ($posInLevel -eq 1) {
                $prefixChars += "─"
            } else {
                $prefixChars += " "
            }
        } else {
            $prefixChars += " "
        }
    }
    return ($prefixChars -join "")
}

function Get-TreeNodeDisplayText {
    param($Entry, $Label)
    
    $labelText = if ($Label) { "[$Label] " } else { "" }
    
    switch ($Entry.type) {
        "message" {
            $msg = $Entry.message
            if ($msg.role -eq "user") {
                $content = ""
                if ($msg.content -is [string]) {
                    $content = $msg.content
                } elseif ($msg.content -is [array]) {
                    $content = ($msg.content | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }) -join ""
                }
                return "${labelText}user: $($content.Trim())"
            }
            if ($msg.role -eq "assistant") {
                $textContent = ""
                if ($msg.content -is [array]) {
                    $textContent = ($msg.content | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }) -join ""
                }
                if ($textContent) {
                    return "${labelText}assistant: $textContent"
                }
                if ($msg.stopReason -eq "aborted") {
                    return "${labelText}assistant: (aborted)"
                }
                if ($msg.errorMessage) {
                    return "${labelText}assistant: Error: $($msg.errorMessage)"
                }
                return "${labelText}assistant: (no text)"
            }
            if ($msg.role -eq "toolResult") {
                return "${labelText}[tool]"
            }
            if ($msg.role -eq "bashExecution") {
                return "${labelText}[bash]: $($msg.command)"
            }
            return "${labelText}[$($msg.role)]"
        }
        "compaction" {
            return "${labelText}[compaction: $([Math]::Round($Entry.tokensBefore / 1000))k tokens]"
        }
        "branch_summary" {
            $summary = $Entry.summary
            return "${labelText}[branch summary]: $summary"
        }
        "custom_message" {
            $content = if ($Entry.content -is [string]) { $Entry.content } else { "$($Entry.content)" }
            return "${labelText}[$($Entry.customType)]: $content"
        }
        "model_change" {
            return "${labelText}[model: $($Entry.modelId)]"
        }
        "thinking_level_change" {
            return "${labelText}[thinking: $($Entry.thinkingLevel)]"
        }
        default {
            return "${labelText}[$($Entry.type)]"
        }
    }
}

# Hauptlogik
try {
    # Daten laden
    $jsonContent = Get-Content -Path $Path -Raw
    $data = $jsonContent | ConvertFrom-Json
    
    $header = $data.header
    $entries = $data.entries
    $defaultLeafId = $data.leafId
    $systemPrompt = $data.systemPrompt
    $tools = $data.tools
    $renderedTools = $data.renderedTools
    
    # Basis64 dekodieren
    $binary = ConvertFrom-Base64 -InputString $data.sessionData
    $data = $binary | ConvertFrom-Json
    
    # URL-Parameter verarbeiten
    $leafId = if ($LeafId) { $LeafId } else { $defaultLeafId }
    $targetId = if ($TargetId) { $TargetId } else { $leafId }
    
    # Datenstrukturen aufbauen
    $byId = @{}
    foreach ($entry in $entries) {
        $byId[$entry.id] = $entry
    }
    
    # Werkzeugaufrufe (toolCallId -> {name, arguments})
    $toolCallMap = @{}
    foreach ($entry in $entries) {
        if ($entry.type -eq "message" -and $entry.message.role -eq "assistant") {
            $content = $entry.message.content
            if ($content -is [array]) {
                foreach ($block in $content) {
                    if ($block.type -eq "toolCall") {
                        $toolCallMap[$block.id] = @{ 
                            Name = $block.name
                            Arguments = $block.arguments
                        }
                    }
                }
            }
        }
    }
    
    # Beschriftungen (entryId -> Beschriftungszeichenfolge)
    $labelMap = @{}
    foreach ($entry in $entries) {
        if ($entry.type -eq "label" -and $entry.targetId -and $entry.label) {
            $labelMap[$entry.targetId] = $entry.label
        }
    }
    
    # Baumstruktur aufbauen
    $tree = Build-Tree -Entries $entries -LabelMap $labelMap
    
    # Aktiven Pfad aufbauen
    $activePathIds = @{}
    $current = $byId[$targetId]
    while ($current) {
        $activePathIds[$current.id] = $true
        if (-not $current.parentId -or $current.parentId -eq $current.id) {
            break
        }
        $current = $byId[$current.parentId]
    }
    
    # Baum abflachen
    $flatNodes = Flatten-Tree -Roots $tree -ActivePathIds $activePathIds
    
    # Baum anzeigen
    Write-Host "Baumstruktur:" -ForegroundColor Green
    foreach ($flatNode in $flatNodes) {
        $prefix = Build-TreePrefix -FlatNode $flatNode
        $displayText = Get-TreeNodeDisplayText -Entry $flatNode.Node.Entry -Label $flatNode.Node.Label
        $marker = if ($activePathIds.ContainsKey($flatNode.Node.Entry.id)) { "•" } else { " " }
        Write-Host "${prefix}${marker} ${displayText}"
    }
    
    # Header anzeigen
    Write-Host "`nHeader:" -ForegroundColor Green
    Write-Host "Session: $($header.id)"
    Write-Host "Datum: $(Get-Date $header.timestamp -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # System-Prompt anzeigen
    if ($systemPrompt) {
        Write-Host "`nSystem-Prompt:" -ForegroundColor Green
        Write-Host $systemPrompt
    }
    
    # Werkzeuge anzeigen
    if ($tools -and $tools.Count -gt 0) {
        Write-Host "`nVerfügbare Werkzeuge:" -ForegroundColor Green
        foreach ($tool in $tools) {
            Write-Host "  $($tool.name) - $($tool.description)"
        }
    }
    
    # Nachrichten anzeigen
    Write-Host "`nNachrichten:" -ForegroundColor Green
    $path = @()
    $current = $byId[$leafId]
    while ($current) {
        $path = ,$current + $path
        if (-not $current.parentId -or $current.parentId -eq $current.id) {
            break
        }
        $current = $byId[$current.parentId]
    }
    
    foreach ($entry in $path) {
        switch ($entry.type) {
            "message" {
                $msg = $entry.message
                if ($msg.role -eq "user") {
                    Write-Host "User: $($msg.content)"
                }
                elseif ($msg.role -eq "assistant") {
                    $textContent = ""
                    if ($msg.content -is [array]) {
                        $textContent = ($msg.content | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }) -join ""
                    }
                    Write-Host "Assistant: $textContent"
                    
                    # Werkzeugaufrufe anzeigen
                    if ($msg.content -is [array]) {
                        foreach ($block in $msg.content) {
                            if ($block.type -eq "toolCall") {
                                Write-Host "  [Werkzeugaufruf: $($block.name)]"
                            }
                        }
                    }
                }
            }
            "model_change" {
                Write-Host "Modellwechsel zu: $($entry.provider)/$($entry.modelId)"
            }
            "compaction" {
                Write-Host "[Komprimierung: $($entry.tokensBefore) Token]"
            }
        }
    }
    
} catch {
    Write-Error "Fehler beim Verarbeiten der Datei: $($_.Exception.Message)"
    exit 1
}
