#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "6ef6b24cc60f50935abecd9cc2d49d34d50e4dbec14b3fb93c39ca8a2a48bed2", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "powershell"}
# index.html — portiert nach powershell
# Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Create the HTML document structure
$html = @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <title>QA Lab</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
"@

# Write the HTML content to the specified output file
Set-Content -Path $OutputPath -Value $html -Encoding Utf8

Write-Host "HTML file created at: $OutputPath"
