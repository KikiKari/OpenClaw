#!/usr/bin/env pwsh
# secret-scan.mjs — portiert nach powershell
# Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

$root = Join-Path $PSScriptRoot ".."
$skipped = @(
  "node_modules"
  ".next"
  ".git"
  ".pytest_cache"
  "__pycache__"
  "media-production/raw"
  "media-production/private"
)
$patterns = @(
  "sk-(?:proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,}"
  "(?:nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,}"
  "ELEVENLABS_API_KEY\s*=\s*[`"']?[A-Za-z0-9]{20,}"
  "WAVESPEED_API_KEY\s*=\s*[`"']?[A-Za-z0-9]{20,}"
)
$findings = @()

function Walk-Directory($directory, $relative = "") {
  Get-ChildItem -Path $directory -Force | ForEach-Object {
    $rel = Join-Path $relative $_.Name
    if (
      $_.Name -eq ".env" -or
      ($_.Name.StartsWith(".env.") -and $_.Name -ne ".env.example") -or
      ($skipped | Where-Object {
        $rel -eq $_ -or
        $rel.StartsWith("$($_){[System.IO.Path]::DirectorySeparatorChar}") -or
        $rel.Split([System.IO.Path]::DirectorySeparatorChar) -contains $_
      })
    ) { return }
    
    if ($_.PSIsContainer) {
      Walk-Directory -directory $_.FullName -relative $rel
    } elseif ($_.Length -lt 2MB) {
      try {
        $content = Get-Content -Path $_.FullName -Raw -ErrorAction Stop
        foreach ($pattern in $patterns) {
          if ($content -match $pattern) {
            $findings += $rel
            break
          }
        }
      } catch {
        # Ignore files that can't be read
      }
    }
  }
}

Walk-Directory -directory $root

if ($findings.Count -gt 0) {
  $uniqueFindings = $findings | Sort-Object -Unique
  Write-Error "Secret-Scan fehlgeschlagen: $($uniqueFindings -join ', ')"
  exit 1
}

Write-Host "Secret-Scan bestanden."
