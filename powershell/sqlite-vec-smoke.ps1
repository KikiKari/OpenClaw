#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "5348574a54f4c1026857e839861832818b9a44a9e7fe26075b27d47bd35076a9", "source_sha256": "8ec3d801d0245c44e6cd926baa89388c6e541d4fa4c4caa70ff0c0c94f6369d9", "target_language": "powershell"}
# sqlite-vec-smoke.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/sqlite-vec-smoke.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# PowerShell 7 Port of sqlite-vec-smoke.mjs

# Define helper function to convert float array to binary
function ConvertTo-VecBinary {
    param(
        [float[]]$Values
    )
    $floatArray = [System.Collections.Generic.List[float]]::new()
    foreach ($value in $Values) {
        $floatArray.Add($value)
    }
    $buffer = [System.Buffers.ArrayPool[byte]]::Shared.Rent(4 * $floatArray.Count)
    try {
        for ($i = 0; $i -lt $floatArray.Count; $i++) {
            $bytes = [System.BitConverter]::GetBytes($floatArray[$i])
            [System.Array]::Copy($bytes, 0, $buffer, $i * 4, 4)
        }
        $result = [byte[]]::new(4 * $floatArray.Count)
        [System.Array]::Copy($buffer, $result, $result.Length)
        return $result
    }
    finally {
        [System.Buffers.ArrayPool[byte]]::Shared.Return($buffer)
    }
}

# Create in-memory database
$dbPath = ":memory:"
Add-Type -AssemblyName System.Data
$connectionString = "Data Source=$dbPath"
$connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
$connection.Open()

try {
    # Load sqlite-vec extension (simulated - actual loading depends on environment)
    # This is a placeholder since PowerShell doesn't have direct equivalent to node-sqlite's extension loading
    
    # Create virtual table
    $createTableCmd = $connection.CreateCommand()
    $createTableCmd.CommandText = @"
CREATE VIRTUAL TABLE v USING vec0(
    id TEXT PRIMARY KEY,
    embedding FLOAT[4]
)
"@
    $createTableCmd.ExecuteNonQuery() | Out-Null

    # Insert data
    $insertCmd = $connection.CreateCommand()
    $insertCmd.CommandText = "INSERT INTO v (id, embedding) VALUES (@id, @embedding)"
    
    $paramId = $insertCmd.Parameters.Add((New-Object System.Data.SQLite.SQLiteParameter("@id", [System.Data.DbType]::String)))
    $paramEmbedding = $insertCmd.Parameters.Add((New-Object System.Data.SQLite.SQLiteParameter("@embedding", [System.Data.DbType]::Object)))
    
    $paramId.Value = "a"
    $paramEmbedding.Value = ConvertTo-VecBinary(@(1, 0, 0, 0))
    $insertCmd.ExecuteNonQuery() | Out-Null
    
    $paramId.Value = "b"
    $paramEmbedding.Value = ConvertTo-VecBinary(@(0, 1, 0, 0))
    $insertCmd.ExecuteNonQuery() | Out-Null
    
    $paramId.Value = "c"
    $paramEmbedding.Value = ConvertTo-VecBinary(@(0.2, 0.2, 0, 0))
    $insertCmd.ExecuteNonQuery() | Out-Null

    # Query data
    $queryCmd = $connection.CreateCommand()
    $queryCmd.CommandText = "SELECT id, vec_distance_cosine(embedding, @query) AS dist FROM v ORDER BY dist ASC"
    $queryParam = $queryCmd.Parameters.Add((New-Object System.Data.SQLite.SQLiteParameter("@query", [System.Data.DbType]::Object)))
    $queryParam.Value = ConvertTo-VecBinary(@(1, 0, 0, 0))
    
    $reader = $queryCmd.ExecuteReader()
    $rows = @()
    while ($reader.Read()) {
        $rows += [PSCustomObject]@{
            id = $reader.GetString(0)
            dist = $reader.GetFloat(1)
        }
    }
    $reader.Close()
    
    Write-Host "sqlite-vec ok"
    $rows | Format-List
    
} catch {
    Write-Error "sqlite-vec load failed:"
    Write-Error $_.Exception.Message
    Write-Error "expected extension path: <not applicable in PowerShell>"
    exit 1
} finally {
    $connection.Close()
}
