#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "68c3bd1ba63602356e660e6d0006339f9ec1c437391e232e4a7a2e3c1bfee7a6", "source_sha256": "a1805aea1655d2760f0aa6fe9d137718ec6b67c1eb8b7d25c2b93d461eea3215", "target_language": "powershell"}
# build-docs-list.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-docs-list.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$binDir = Join-Path $root "bin"
$binPath = Join-Path $binDir "docs-list"

New-Item -ItemType Directory -Path $binDir -Force | Out-Null

$wrapper = @'
#!/usr/bin/env pwsh
$here = Split-Path $MyInvocation.MyCommand.Path
$script = Join-Path $here ".." "scripts" "docs-list.ps1"

& pwsh -File $script
'@

Set-Content -Path $binPath -Value $wrapper -Force
& chmod +x $binPath 2>$null
if ($LASTEXITCODE -ne 0) {
    # Fallback für Windows, falls chmod nicht verfügbar ist
    $fileInfo = Get-Item $binPath
    $fileInfo.Attributes = "Normal"
}
