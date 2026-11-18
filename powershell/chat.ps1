#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "6f4a5221ef685bfbe345c5169096f25e41cef9fb2bcf67c95334c7fa93e7bfc4", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "powershell"}
# chat.css — portiert nach powershell
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Create the content array
$content = @(
    '@import "./chat/layout.css";'
    '@import "./chat/text.css";'
    '@import "./chat/grouped.css";'
    '@import "./chat/tool-cards.css";'
    '@import "./chat/sidebar.css";'
    ''
)

# Write the content to the specified output file
$content | Out-File -FilePath $OutputPath -Encoding UTF8

# Output success message
Write-Host "CSS file created at: $OutputPath"
