#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "4e0392b733d6fb61b1627f06476679f322ba57bbaa404059f2f985cc3a5688d0", "source_sha256": "d563770ee41496760efbfdbb5c3e2c054ecf84de1c5e8eb2fc7cd2ad260b16ce", "target_language": "powershell"}
# docs-spellcheck.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docs-spellcheck.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$mode = $($args[0] ?? "")
$writeFlag = @()
if ($mode -eq "--write") {
    $writeFlag = @("-w")
}

$argsList = @(
    "README.md"
    "docs"
    "--skip=*.png,*.jpg,*.jpeg,*.gif,*.svg"
    "-D"
    "-"
    "-D"
    "scripts/codespell-dictionary.txt"
    "-I"
    "scripts/codespell-ignore.txt"
) + $writeFlag

if (Get-Command codespell -ErrorAction SilentlyContinue) {
    & codespell @argsList
    exit 0
}

if (Get-Command python3 -ErrorAction SilentlyContinue) {
    $installResult = python3 -m pip install --user --disable-pip-version-check --break-system-packages codespell 2>$null
    if (-not $installResult) {
        python3 -m pip install --user --disable-pip-version-check codespell 2>$null
    }

    $userBin = python3 -c "import site; print(f'{site.USER_BASE}/bin')"
    $codespellPath = Join-Path $userBin "codespell"
    if (Test-Path $codespellPath -PathType Leaf) {
        & $codespellPath @argsList
        exit 0
    }
}

Write-Error "codespell unavailable: install codespell or python3"
exit 1
