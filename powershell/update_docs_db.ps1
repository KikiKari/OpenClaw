#!/usr/bin/env pwsh
# update_docs_db.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:scripts/update_docs_db.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

<#
Scannt alle vorhandenen Dokumentationen und aktualisiert docs.db
#>

$WORKSPACE = "/home/openclaw/.openclaw/workspace"
$DB_PATH = "$WORKSPACE/db/docs.db"

function Scan-Documentations {
    <#
    Scannt alle .md Dateien im Workspace
    #>
    $docs = @()
    
    # Hauptverzeichnis
    Get-ChildItem -Path $WORKSPACE -Filter "*.md" -File | ForEach-Object {
        if (-not $_.LinkType) {
            $docs += @{
                name = $_.Name
                path = '/'
                category = 'main'
                description = Get-Description $_.FullName
                type = 'doc'
                has_symlink = $false
                symlink_path = $null
                last_update = Get-Mtime $_.LastWriteTime
            }
        }
    }
    
    # WebSearch Verzeichnis
    $websearchDir = "$WORKSPACE/websearch"
    if (Test-Path $websearchDir) {
        Get-ChildItem -Path $websearchDir -Filter "*.md" -File | ForEach-Object {
            $docs += @{
                name = $_.Name
                path = 'websearch/'
                category = 'websearch'
                description = Get-Description $_.FullName
                type = if ($_.Name -like '*GUIDE*') { 'guide' } else { 'config' }
                has_symlink = $true
                symlink_path = "websearch/$($_.Name)"
                last_update = Get-Mtime $_.LastWriteTime
            }
        }
    }
    
    # MCP Verzeichnis
    $mcpDir = "$WORKSPACE/mcp"
    if (Test-Path $mcpDir) {
        Get-ChildItem -Path $mcpDir -Filter "*.md" -File | ForEach-Object {
            $isSymlink = $_.LinkType -eq 'SymbolicLink'
            $docs += @{
                name = $_.Name
                path = 'mcp/'
                category = 'mcp'
                description = Get-Description $_.FullName
                type = if ($isSymlink) { 'symlink' } else { 'guide' }
                has_symlink = $isSymlink
                symlink_path = if ($isSymlink) { $_.Target } else { $null }
                last_update = Get-Mtime $_.LastWriteTime
            }
        }
    }
    
    # Docs-Unterverzeichnisse
    $docsDir = "$WORKSPACE/docs"
    if (Test-Path $docsDir) {
        Get-ChildItem -Path $docsDir -Directory | ForEach-Object {
            $subdir = $_
            Get-ChildItem -Path $subdir.FullName -Filter "*.md" -File | ForEach-Object {
                $docs += @{
                    name = $_.Name
                    path = "docs/$($subdir.Name)/"
                    category = $subdir.Name
                    description = Get-Description $_.FullName
                    type = 'doc'
                    has_symlink = $false
                    symlink_path = $null
                    last_update = Get-Mtime $_.LastWriteTime
                }
            }
        }
    }
    
    # Cluster, Memory, Reports, Skills
    @('cluster', 'memory', 'reports', 'skills') | ForEach-Object {
        $category = $_
        $catDir = "$WORKSPACE/$category"
        if (Test-Path $catDir) {
            Get-ChildItem -Path $catDir -Filter "*.md" -File | ForEach-Object {
                $docs += @{
                    name = $_.Name
                    path = "$category/"
                    category = $category
                    description = Get-Description $_.FullName
                    type = 'doc'
                    has_symlink = $false
                    symlink_path = $null
                    last_update = Get-Mtime $_.LastWriteTime
                }
            }
        }
    }
    
    return $docs
}

function Get-Description($filePath) {
    <#
    Extrahiert erste Zeile als Beschreibung
    #>
    try {
        $firstLine = Get-Content -Path $filePath -First 1 -ErrorAction Stop
        if ($firstLine.StartsWith('#')) {
            return $firstLine.TrimStart('#').Trim()
        }
        if ($firstLine.Length -gt 50) {
            return $firstLine.Substring(0, 50) + '...'
        }
        return $firstLine
    } catch {
        return 'Dokumentation'
    }
}

function Get-Mtime($dateTime) {
    <#
    Gibt letzte Änderung zurück
    #>
    try {
        return $dateTime.ToString('yyyy-MM-dd')
    } catch {
        return '2026-04-18'
    }
}

function Update-Database($docs) {
    <#
    Aktualisiert docs.db mit allen gefundenen Dokumenten
    #>
    # SQLite verwenden
    Add-Type -AssemblyName System.Data.SQLite
    
    $connectionString = "Data Source=$DB_PATH;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
    $connection.Open()
    
    $command = $connection.CreateCommand()
    
    # Lösche alte Einträge (außer config)
    $command.CommandText = "DELETE FROM documents WHERE category != 'config'"
    $command.ExecuteNonQuery() | Out-Null
    
    # Füge neue ein
    $inserted = 0
    foreach ($doc in $docs) {
        $command.CommandText = @"
            INSERT INTO documents 
            (name, path, category, description, type, has_symlink, symlink_path, last_update)
            VALUES (@name, @path, @category, @description, @type, @has_symlink, @symlink_path, @last_update)
"@
        $command.Parameters.Clear()
        $command.Parameters.AddWithValue("@name", $doc.name) | Out-Null
        $command.Parameters.AddWithValue("@path", $doc.path) | Out-Null
        $command.Parameters.AddWithValue("@category", $doc.category) | Out-Null
        $command.Parameters.AddWithValue("@description", $doc.description) | Out-Null
        $command.Parameters.AddWithValue("@type", $doc.type) | Out-Null
        $command.Parameters.AddWithValue("@has_symlink", $doc.has_symlink) | Out-Null
        $command.Parameters.AddWithValue("@symlink_path", $doc.symlink_path) | Out-Null
        $command.Parameters.AddWithValue("@last_update", $doc.last_update) | Out-Null
        
        $command.ExecuteNonQuery() | Out-Null
        $inserted++
    }
    
    $connection.Close()
    
    return $inserted
}

function Export-All {
    <#
    Erstellt alle Exporte
    #>
    # SQLite verwenden
    Add-Type -AssemblyName System.Data.SQLite
    
    $connectionString = "Data Source=$DB_PATH;Version=3;"
    $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
    $connection.Open()
    
    # JSON und CSV Export
    @('documents', 'skills', 'symlinks') | ForEach-Object {
        $table = $_
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT * FROM $table"
        
        $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter($command)
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        
        $rows = $dataset.Tables[0]
        
        # JSON Export
        $jsonData = @()
        foreach ($row in $rows.Rows) {
            $hash = @{}
            foreach ($col in $rows.Columns.ColumnName) {
                $hash[$col] = $row[$col]
            }
            $jsonData += $hash
        }
        
        $jsonPath = "$WORKSPACE/db_$table.json"
        $jsonData | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath
        Write-Host "✅ $jsonPath"
        
        # CSV Export
        $csvPath = "$WORKSPACE/db_$table.csv"
        $rows | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "✅ $csvPath"
    }
    
    $connection.Close()
}

function Main {
    Write-Host ("=" * 60)
    Write-Host "DOCS.DB UPDATER"
    Write-Host ("=" * 60)
    
    Write-Host "`n--- Scanne Dokumentationen ---"
    $docs = Scan-Documentations
    Write-Host "Gefunden: $($docs.Count) Dokumente"
    
    Write-Host "`n--- Aktualisiere docs.db ---"
    $inserted = Update-Database $docs
    Write-Host "✅ $inserted Dokumente in docs.db aktualisiert"
    
    Write-Host "`n--- Erstelle Exporte ---"
    Export-All
    
    Write-Host "`n" + ("=" * 60)
    Write-Host "DOCS.DB AKTUALISIERT"
    Write-Host ("=" * 60)
}

Main
