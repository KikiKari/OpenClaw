#!/usr/bin/env pwsh
# update_docs_db.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:scripts/update_docs_db.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Scan documentation files and refresh docs.db for the mounted workspace.
#>

$WORKSPACE = "/workspace"
$DB_PATH = "$WORKSPACE/db/docs.db"

function Get-DocFiles {
    Get-ChildItem -Path $WORKSPACE -Recurse -Filter "*.md" | Where-Object {
        $_.PSIsContainer -eq $false -and $_.LinkType -ne "SymbolicLink"
    } | Where-Object {
        $relParts = $_.FullName.Replace($WORKSPACE, "").TrimStart("\").Split("\")
        -not ($relParts | Where-Object { @("node_modules", ".git", "backups") -contains $_ })
    }
}

function Get-FileHashMD5 {
    param (
        [string]$Path
    )
    $hash = Get-FileHash -Path $Path -Algorithm MD5
    return $hash.Hash.ToLower()
}

function Get-WordCount {
    param (
        [string]$Path
    )
    try {
        $content = Get-Content -Path $Path -Raw -Encoding UTF8
        return ($content -split '\s+').Count
    }
    catch {
        return 0
    }
}

function Build-Rows {
    $indexed = Get-Date -UFormat %s
    $rows = @()
    $docFiles = Get-DocFiles
    foreach ($file in $docFiles) {
        $relativePath = Resolve-Path -Path $file.FullName -Relative
        # Entferne ".\" am Anfang, falls vorhanden
        if ($relativePath.StartsWith(".\")) {
            $relativePath = $relativePath.Substring(2)
        }
        $rows += @{
            path          = $relativePath
            content_hash  = Get-FileHashMD5 -Path $file.FullName
            last_indexed  = [double]$indexed
            word_count    = Get-WordCount -Path $file.FullName
        }
    }
    return $rows
}

function Ensure-Schema {
    param (
        [System.Data.SQLite.SQLiteConnection]$Conn
    )
    $cmd = $Conn.CreateCommand()
    $cmd.CommandText = @"
CREATE TABLE IF NOT EXISTS documents (
    path TEXT PRIMARY KEY,
    content_hash TEXT,
    last_indexed REAL,
    word_count INTEGER
)
"@
    $cmd.ExecuteNonQuery() | Out-Null

    $cmd.CommandText = @"
CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT,
    tag TEXT
)
"@
    $cmd.ExecuteNonQuery() | Out-Null
}

function Update-Database {
    param (
        [array]$Rows
    )
    Add-Type -AssemblyName System.Data.SQLite
    $connStr = "Data Source=$DB_PATH;Version=3;"
    $conn = New-Object System.Data.SQLite.SQLiteConnection($connStr)
    $conn.Open()
    try {
        Ensure-Schema -Conn $conn
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "DELETE FROM documents"
        $cmd.ExecuteNonQuery() | Out-Null

        foreach ($row in $Rows) {
            $insertCmd = $conn.CreateCommand()
            $insertCmd.CommandText = "INSERT INTO documents (path, content_hash, last_indexed, word_count) VALUES (@path, @content_hash, @last_indexed, @word_count)"
            $insertCmd.Parameters.AddWithValue("@path", $row.path) | Out-Null
            $insertCmd.Parameters.AddWithValue("@content_hash", $row.content_hash) | Out-Null
            $insertCmd.Parameters.AddWithValue("@last_indexed", $row.last_indexed) | Out-Null
            $insertCmd.Parameters.AddWithValue("@word_count", $row.word_count) | Out-Null
            $insertCmd.ExecuteNonQuery() | Out-Null
        }
        $conn.Close()
    }
    catch {
        $conn.Close()
        throw $_
    }
}

function Export-Table {
    param (
        [string]$Table
    )
    Add-Type -AssemblyName System.Data.SQLite
    $connStr = "Data Source=$DB_PATH;Version=3;"
    $conn = New-Object System.Data.SQLite.SQLiteConnection($connStr)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT * FROM $Table"
        $adapter = New-Object System.Data.SQLite.SQLiteDataAdapter($cmd)
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        $data = $dataset.Tables[0]

        $jsonPath = "$WORKSPACE/db_$Table.json"
        $csvPath = "$WORKSPACE/db_$Table.csv"

        $data | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Force

        if ($data.Rows.Count -gt 0) {
            $data | Export-Csv -Path $csvPath -NoTypeInformation -Force
        }
        else {
            "" | Out-File -FilePath $csvPath -Force
        }
    }
    finally {
        $conn.Close()
    }
}

function Main {
    Write-Host ("=" * 60)
    Write-Host "DOCS.DB UPDATER"
    Write-Host ("=" * 60)
    $rows = Build-Rows
    Write-Host "Gefunden: $($rows.Count) Dokumente"
    Update-Database -Rows $rows
    Write-Host "✅ $($rows.Count) Dokumente in docs.db aktualisiert"
    Export-Table -Table "documents"
    Export-Table -Table "tags"
    Write-Host "✅ Exporte aktualisiert"
    Write-Host ""
    Write-Host ("=" * 60)
    Write-Host "DOCS.DB AKTUALISIERT"
    Write-Host ("=" * 60)
}

Main
