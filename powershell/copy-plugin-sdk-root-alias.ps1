#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "0593717991581ad27c16f7391ab2bbc1349ed81e599dc43c538a6eeaf12dbeab", "source_sha256": "5fc2c92995e4c87536b6317eba7c9959c9babc16a20ce4476804921089ee2e34", "target_language": "powershell"}
# copy-plugin-sdk-root-alias.mjs — portiert nach powershell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/copy-plugin-sdk-root-alias.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$cwd = $(Get-Location)
)

# Import shared functions
. "$PSScriptRoot/runtime-postbuild-shared.ps1"

function Copy-PluginSdkRootAlias {
    param(
        [string]$cwd = $(Get-Location)
    )
    
    $source = Join-Path $cwd "src/plugin-sdk/root-alias.cjs"
    $target = Join-Path $cwd "dist/plugin-sdk/root-alias.cjs"
    
    $content = Get-Content -Path $source -Encoding UTF8 -Raw
    Write-TextFileIfChanged -Path $target -Content $content
}

# Wenn das Skript direkt ausgeführt wird (nicht als Modul importiert)
if ($MyInvocation.InvocationName -eq '&') {
    Copy-PluginSdkRootAlias -cwd $cwd
}
