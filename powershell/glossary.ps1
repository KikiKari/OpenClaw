#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "1670fdb6f53fe5d318991de9c1a5c6eff6b938f5e2226e2747a25e949d181763", "source_sha256": "969958657b3b071c8b5067af0ac0287ac68f3fbc6c5832a0339555e3a87d3357", "target_language": "powershell"}
# glossary.go — portiert nach powershell
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/glossary.go
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

class GlossaryEntry {
    [string]$Source
    [string]$Target
}

function LoadGlossary([string]$Path) {
    if (-not (Test-Path $Path)) {
        return @()
    }

    try {
        $content = Get-Content -Path $Path -Raw
        $entries = $content | ConvertFrom-Json
        $result = @()
        foreach ($entry in $entries) {
            $glossaryEntry = [GlossaryEntry]::new()
            $glossaryEntry.Source = $entry.source
            $glossaryEntry.Target = $entry.target
            $result += $glossaryEntry
        }
        return $result
    } catch {
        throw "glossary parse failed: $($_.Exception.Message)"
    }
}
