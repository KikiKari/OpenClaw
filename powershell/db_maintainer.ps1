#!/usr/bin/env pwsh
# db_maintainer.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:scripts/db_maintainer.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Database Maintainer Sub-Agent
.DESCRIPTION
Automated database maintenance with 30min checks, hourly backups (3 days retention),
band tree command execution for important/openclaw-tree.txt
#>

param()

$ErrorActionPreference = "Stop"

# Determine workspace path
$scriptPath = $MyInvocation.MyCommand.Path
$workspace = if ($env:OPENCLAW_WORKSPACE) { 
    [System.IO.Path]::GetFullPath($env:OPENCLAW_WORKSPACE) 
} else { 
    [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..")) 
}

$dbDir = $workspace
$backupDir = [System.IO.Path]::Combine($workspace, "db", "backups")
$logDir = [System.IO.Path]::Combine($workspace, "logs", "db-maintainer")
$importantDir = [System.IO.Path]::Combine($workspace, "important")

# Create directories
@($backupDir, $logDir, $importantDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

class Logger {
    [string]$LogFile
    
    Logger() {
        $today = Get-Date -Format "yyyy-MM-dd"
        $this.LogFile = [System.IO.Path]::Combine($script:logDir, "$today.log")
    }
    
    [void]Log([string]$Level, [string]$Message) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $line = "[${timestamp}] [${Level}] ${Message}"
        Write-Host $line
        Add-Content -Path $this.LogFile -Value $line
    }
    
    [void]Info([string]$Msg) { $this.Log('INFO', $Msg) }
    [void]Warn([string]$Msg) { $this.Log('WARN', $Msg) }
    [void]Error([string]$Msg) { $this.Log('ERROR', $Msg) }
}

class DatabaseMaintainer {
    [Logger]$Logger
    [string]$StateFile
    [int]$RetentionDays = 3
    
    DatabaseMaintainer() {
        $this.Logger = [Logger]::new()
        $this.StateFile = [System.IO.Path]::Combine($script:dbDir, "maintainer_state.json")
    }
    
    [hashtable]LoadState() {
        if (Test-Path $this.StateFile) {
            $content = Get-Content -Path $this.StateFile -Raw
            if ($content) {
                return $content | ConvertFrom-Json -AsHashtable
            }
        }
        return @{
            last_check = $null
            last_backup = $null
            last_tree_update = $null
            file_hashes = @{}
        }
    }
    
    [void]SaveState([hashtable]$State) {
        $State | ConvertTo-Json -Depth 10 | Set-Content -Path $this.StateFile
    }
    
    [string]GetFileHash([string]$FilePath) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($FilePath)
            $hash = [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
            return -join ($hash | ForEach-Object { "{0:x2}" -f $_ })
        } catch {
            return $null
        }
    }
    
    [string]_PythonTreeFallback([int]$MaxDepth = 8) {
        $root = $script:workspace
        $lines = @($root)
        
        function Walk([string]$dirpath, [string]$prefix, [int]$depth) {
            if ($depth -gt $MaxDepth) { return }
            try {
                $entries = Get-ChildItem -Path $dirpath | Sort-Object { if ($_.PSIsContainer) { 0 } else { 1 } }, Name
            } catch {
                return
            }
            
            for ($i = 0; $i -lt $entries.Count; $i++) {
                $entry = $entries[$i]
                $connector = if ($i -eq $entries.Count - 1) { "└── " } else { "├── " }
                $lines.Add("$prefix$connector$($entry.Name)")
                
                if ($entry.PSIsContainer -and -not $entry.LinkType) {
                    $extension = if ($i -eq $entries.Count - 1) { "    " } else { "│   " }
                    Walk $entry.FullName "$prefix$extension" ($depth + 1)
                }
            }
        }
        
        $linesList = [System.Collections.Generic.List[string]]::new()
        $linesList.AddRange($lines)
        Walk $root "" 1
        return ($linesList -join "`n") + "`n"
    }
    
    [string]RunTreeCommand() {
        try {
            $result = Start-Process -FilePath "tree" -ArgumentList "-a", "-L", "8", $script:workspace -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\tree_output.txt" -RedirectStandardError "$env:TEMP\tree_error.txt"
            if ($result.ExitCode -eq 0) {
                $output = Get-Content "$env:TEMP\tree_output.txt" -Raw
                $this.Logger.Info("tree -a -L 8 erfolgreich ausgeführt")
                return $output
            } else {
                $stderr = Get-Content "$env:TEMP\tree_error.txt" -Raw
                $this.Logger.Warn("tree command fehlgeschlagen: $($stderr.Trim()) – nutze Python-Fallback")
                return $this._PythonTreeFallback()
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            $this.Logger.Warn("tree-Binary nicht installiert – nutze Python-Fallback")
            return $this._PythonTreeFallback()
        } catch {
            $this.Logger.Error("tree command Exception: $_")
            return $null
        }
    }
    
    [bool]UpdateTreeFile([string]$TreeOutput) {
        if (-not $TreeOutput) {
            return $false
        }
        
        $treeFile = [System.IO.Path]::Combine($script:importantDir, "openclaw-tree.txt")
        
        $header = @"
# OpenClaw Workspace Tree
# Generiert: $(Get-Date -Format s)
# Befehl: tree -a -L 8 $script:workspace
# Diese Datei wird automatisch von db-maintainer aktualisiert

"@
        
        try {
            $header + $TreeOutput | Set-Content -Path $treeFile -Encoding UTF8
            $this.Logger.Info("openclaw-tree.txt aktualisiert: $treeFile")
            return $true
        } catch {
            $this.Logger.Error("Fehler beim Schreiben von openclaw-tree.txt: $_")
            return $false
        }
    }
    
    [array]ScanDocumentations() {
        $docs = @()
        
        Get-ChildItem -Path $script:workspace -Include "*.md" -Recurse -File | Where-Object {
            $_.FullName -notlike "*db/backups*" -and 
            $_.FullName -notlike "*node_modules*" -and
            -not $_.LinkType
        } | ForEach-Object {
            $relativePath = $_.FullName.Substring($script:workspace.Length + 1)
            $docs += @{
                path = $relativePath
                hash = $this.GetFileHash($_.FullName)
                mtime = $_.LastWriteTimeUtc.Ticks
            }
        }
        
        return $docs
    }
    
    [object]CheckForChanges() {
        $state = $this.LoadState()
        $currentDocs = $this.ScanDocumentations()
        
        $changes = @()
        $currentHashes = @{}
        
        foreach ($doc in $currentDocs) {
            $path = $doc.path
            $currentHashes[$path] = $doc.hash
            
            if (-not $state.file_hashes.ContainsKey($path)) {
                $changes += "NEW: $path"
            } elseif ($state.file_hashes[$path] -ne $doc.hash) {
                $changes += "CHANGED: $path"
            }
        }
        
        # Check for deleted files
        foreach ($oldPath in $state.file_hashes.Keys) {
            if (-not $currentHashes.ContainsKey($oldPath)) {
                $changes += "DELETED: $oldPath"
            }
        }
        
        return @{ changes = $changes; hashes = $currentHashes }
    }
    
    [bool]UpdateDatabases() {
        try {
            $scriptPath = [System.IO.Path]::Combine($script:workspace, "scripts", "update_docs_db.py")
            $result = Start-Process -FilePath "python3" -ArgumentList $scriptPath -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\db_update_out.txt" -RedirectStandardError "$env:TEMP\db_update_err.txt"
            
            if ($result.ExitCode -eq 0) {
                $this.Logger.Info("docs.db aktualisiert")
                return $true
            } else {
                $stderr = Get-Content "$env:TEMP\db_update_err.txt" -Raw
                $this.Logger.Error("DB-Update fehlgeschlagen: $stderr")
                return $false
            }
        } catch {
            $this.Logger.Error("DB-Update Exception: $_")
            return $false
        }
    }
    
    [bool]UpdateTreeDbV2() {
        try {
            $scriptPath = [System.IO.Path]::Combine($script:workspace, "scripts", "tree_indexer_v2.py")
            $result = Start-Process -FilePath "python3" -ArgumentList $scriptPath -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\tree_db_out.txt" -RedirectStandardError "$env:TEMP\tree_db_err.txt"
            
            if ($result.ExitCode -eq 0) {
                $this.Logger.Info("tree.db v2 aktualisiert")
                return $true
            } else {
                $stderr = Get-Content "$env:TEMP\tree_db_err.txt" -Raw
                $this.Logger.Error("Tree-DB v2 fehlgeschlagen: $stderr")
                return $false
            }
        } catch {
            $this.Logger.Error("Tree-DB v2 Exception: $_")
            return $false
        }
    }
    
    [string]CreateBackup() {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
        
        @("docs.db", "tree.db") | ForEach-Object {
            $dbName = $_
            $source = [System.IO.Path]::Combine($script:dbDir, $dbName)
            if (Test-Path $source) {
                $backupName = "${timestamp}_${dbName}.bak"
                $backupPath = [System.IO.Path]::Combine($script:backupDir, $backupName)
                Copy-Item -Path $source -Destination $backupPath -Force
                $this.Logger.Info("Backup erstellt: $backupName")
            }
        }
        
        return $timestamp
    }
    
    [void]CleanupOldBackups() {
        $cutoff = (Get-Date).AddDays(-$this.RetentionDays)
        $deleted = 0
        
        @("docs.db", "tree.db") | ForEach-Object {
            $dbName = $_
            $backups = Get-ChildItem -Path $script:backupDir -Filter "*_${dbName}.bak"
            
            foreach ($backup in $backups) {
                try {
                    # Extract date from filename (Format: YYYY-MM-DD_HH-MM)
                    $parts = $backup.Name.Split('_')
                    $dateStr = $parts[0]
                    $timeStr = $parts[1]
                    $backupTime = [DateTime]::ParseExact("${dateStr}_${timeStr}", 'yyyy-MM-dd_HH-mm', $null)
                    
                    if ($backupTime -lt $cutoff) {
                        Remove-Item -Path $backup.FullName -Force
                        $deleted++
                        $this.Logger.Info("Altes Backup gelöscht: $($backup.Name)")
                    }
                } catch {
                    $this.Logger.Warn("Konnte Backup-Datum nicht parsen: $($backup.Name)")
                }
            }
        }
        
        if ($deleted -eq 0) {
            $this.Logger.Info("Keine alten Backups zum Löschen")
        } else {
            $this.Logger.Info("${deleted} alte Backups gelöscht (< 3 Tage)")
        }
    }
    
    [void]RunCycle() {
        $this.Logger.Info("=" * 60)
        $this.Logger.Info("DB MAINTAINER CYCLE START")
        $this.Logger.Info("=" * 60)
        
        $state = $this.LoadState()
        
        # 1. Run tree command and write to openclaw-tree.txt
        $this.Logger.Info("Führe tree -a -L 8 aus...")
        $treeOutput = $this.RunTreeCommand()
        if ($treeOutput) {
            $this.UpdateTreeFile($treeOutput)
            $state.last_tree_update = (Get-Date).ToString("o")
        }
        
        # 2. Update tree.db (internal v2)
        $this.Logger.Info("Aktualisiere tree.db v2...")
        $this.UpdateTreeDbV2()
        
        # 3. Check for changes
        $this.Logger.Info("Prüfe auf Dokumentations-Änderungen...")
        $changeResult = $this.CheckForChanges()
        $changes = $changeResult.changes
        $currentHashes = $changeResult.hashes
        
        if ($changes.Count -gt 0) {
            $this.Logger.Info("$($changes.Count) Änderungen gefunden:")
            $displayCount = [Math]::Min(10, $changes.Count)
            for ($i = 0; $i -lt $displayCount; $i++) {
                $this.Logger.Info("  - $($changes[$i])")
            }
            if ($changes.Count -gt 10) {
                $this.Logger.Info("  ... und $($changes.Count - 10) weitere")
            }
            
            # 4. Update docs.db
            $this.Logger.Info("Aktualisiere docs.db...")
            if ($this.UpdateDatabases()) {
                $state.last_check = (Get-Date).ToString("o")
                $state.file_hashes = $currentHashes
            }
        } else {
            $this.Logger.Info("Keine Dokumentations-Änderungen gefunden")
        }
        
        # 5. Check if backup is due (hourly)
        $lastBackup = $state.last_backup
        
        if ($lastBackup) {
            $lastBackupTime = [DateTime]::Parse($lastBackup)
            $doBackup = (Get-Date) - $lastBackupTime -ge (New-TimeSpan -Hours 1)
        } else {
            $doBackup = $true
        }
        
        if ($doBackup) {
            $this.Logger.Info("Erstelle stündliches Backup...")
            $timestamp = $this.CreateBackup()
            $state.last_backup = (Get-Date).ToString("o")
            
            # 6. Clean up old backups (3 days retention)
            $this.Logger.Info("Räume alte Backups auf (3 Tage Retention)...")
            $this.CleanupOldBackups()
        } else {
            $this.Logger.Info("Backup nicht nötig (letztes < 1h)")
        }
        
        $this.SaveState($state)
        
        $this.Logger.Info("=" * 60)
        $this.Logger.Info("DB MAINTAINER CYCLE END")
        $this.Logger.Info("=" * 60)
    }
}

function Main() {
    $maintainer = [DatabaseMaintainer]::new()
    
    try {
        $maintainer.RunCycle()
    } catch {
        $maintainer.Logger.Error("CRITICAL ERROR: $_")
        exit 1
    }
}

Main
