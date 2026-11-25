#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "6844d26ca20d5783c1d85d644c9dfa12364abbcf1ea7e9172de24d382fd1f769", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "powershell"}
# tm.go — portiert nach powershell
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

class TMEntry {
    [string]$CacheKey
    [string]$SegmentID
    [string]$SourcePath
    [string]$TextHash
    [string]$Text
    [string]$Translated
    [string]$Provider
    [string]$Model
    [string]$SrcLang
    [string]$TgtLang
    [string]$UpdatedAt

    TMEntry() {}

    TMEntry([PSCustomObject]$obj) {
        $this.CacheKey = $obj.cache_key
        $this.SegmentID = $obj.segment_id
        $this.SourcePath = $obj.source_path
        $this.TextHash = $obj.text_hash
        $this.Text = $obj.text
        $this.Translated = $obj.translated
        $this.Provider = $obj.provider
        $this.Model = $obj.model
        $this.SrcLang = $obj.src_lang
        $this.TgtLang = $obj.tgt_lang
        $this.UpdatedAt = $obj.updated_at
    }

    [PSCustomObject]ToPSCustomObject() {
        return [PSCustomObject]@{
            cache_key = $this.CacheKey
            segment_id = $this.SegmentID
            source_path = $this.SourcePath
            text_hash = $this.TextHash
            text = $this.Text
            translated = $this.Translated
            provider = $this.Provider
            model = $this.Model
            src_lang = $this.SrcLang
            tgt_lang = $this.TgtLang
            updated_at = $this.UpdatedAt
        }
    }
}

class TranslationMemory {
    [string]$Path
    [hashtable]$Entries

    TranslationMemory([string]$path) {
        $this.Path = $path
        $this.Entries = @{}
    }

    static [TranslationMemory]LoadTranslationMemory([string]$path) {
        $tm = [TranslationMemory]::new($path)
        
        if (-not (Test-Path $path)) {
            return $tm
        }

        try {
            $content = Get-Content -Path $path -ErrorAction Stop
            foreach ($line in $content) {
                $trimmed = $line.Trim()
                if ($trimmed -ne "") {
                    try {
                        $entryObj = $trimmed | ConvertFrom-Json -ErrorAction Stop
                        $entry = [TMEntry]::new($entryObj)
                        if ($entry.CacheKey -ne "" -and $entry.Translated.Trim() -ne "") {
                            $tm.Entries[$entry.CacheKey] = $entry
                        }
                    } catch {
                        throw "translation memory decode failed: $_"
                    }
                }
            }
        } catch {
            throw $_
        }
        
        return $tm
    }

    [TMEntry]Get([string]$cacheKey) {
        if (-not $this.Entries.ContainsKey($cacheKey)) {
            throw "Key not found"
        }
        
        $entry = $this.Entries[$cacheKey]
        if ($entry.Translated.Trim() -eq "") {
            throw "Translation is empty"
        }
        
        return $entry
    }

    [bool]TryGet([string]$cacheKey, [ref]$entry) {
        if (-not $this.Entries.ContainsKey($cacheKey)) {
            return $false
        }
        
        $foundEntry = $this.Entries[$cacheKey]
        if ($foundEntry.Translated.Trim() -eq "") {
            return $false
        }
        
        $entry.Value = $foundEntry
        return $true
    }

    [void]Put([TMEntry]$entry) {
        if ($entry.CacheKey -eq "") {
            return
        }
        $this.Entries[$entry.CacheKey] = $entry
    }

    [void]Save() {
        if ($this.Path -eq "") {
            return
        }
        
        $dir = Split-Path -Parent $this.Path
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        $tmpPath = "$($this.Path).tmp"
        
        try {
            $keys = $this.Entries.Keys | Sort-Object
            $lines = @()
            
            foreach ($key in $keys) {
                $entry = $this.Entries[$key]
                $obj = $entry.ToPSCustomObject()
                $json = $obj | ConvertTo-Json -Compress
                $lines += $json
            }
            
            $lines | Set-Content -Path $tmpPath -Force
            Move-Item -Path $tmpPath -Destination $this.Path -Force
        } catch {
            if (Test-Path $tmpPath) {
                Remove-Item -Path $tmpPath -Force
            }
            throw $_
        }
    }
}
