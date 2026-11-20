#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "766376ff40d54f2c0f72d86a906f0a7660f05e86ac2577f1da2ecb702760f9b2", "source_sha256": "17d9118c74c9951b6bd9c5e3475b496be57f796a591823384aa44dbdad5a115d", "target_language": "powershell"}
# styles.css — portiert nach powershell
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles.css
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Ensure the output directory exists
$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Create the content of the CSS file as a list of lines
$cssContent = @(
    '@import "./styles/base.css";',
    '@import "./styles/layout.css";',
    '@import "./styles/layout.mobile.css";',
    '@import "./styles/components.css";',
    '@import "./styles/chat.css";',
    '@import "./styles/config.css";',
    '@import "./styles/usage.css";',
    '@import "./styles/dreams.css";',
    '@import "@create-markdown/preview/themes/system.css";',
    '',
    '.cm-preview {',
    '  --cm-mono: var(--mono);',
    '  --cm-link: var(--accent);',
    '  --cm-info: var(--info);',
    '  --cm-warning: var(--warn);',
    '  --cm-success: var(--ok);',
    '  --cm-danger: var(--danger);',
    '}'
)

# Write the content to the specified output path
$cssContent | Set-Content -Path $OutputPath -Encoding Utf8

Write-Host "CSS file written to $OutputPath"
