#!/usr/bin/env pwsh
# index.html — portiert nach powershell
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Erstelle das HTML-Dokument mit den gleichen Inhalten wie die Vorlage
$htmlContent = @"
<!doctype html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="Dokumentation f&uuml;r TikTok LIVE Companion 0.8.2 &ndash; Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser." />
    <meta name="theme-color" content="#ffffff" />
    <link rel="icon" type="image/png" href="/branding/staenderglobus-ios.png" />
    <link rel="apple-touch-icon" href="/branding/staenderglobus-ios.png" />
    <title>TikTok LIVE Companion &ndash; Dokumentation</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
"@

# Schreibe den Inhalt in die angegebene Datei
$htmlContent | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "HTML file generated at: $OutputPath"
