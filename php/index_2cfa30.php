<?php
// abstraction-provenance: {"artifact_sha256": "328b8381df64fc4a50986c395e82d3b110755f175ba620187e2f3971a4b1d589", "source_sha256": "2cfa301efe20d60c29e0e9f0746e5a99d405ea44a5d03839c72e6b525451fe07", "target_language": "php"}
// index.html — portiert nach php
// Quelle: html, Projects@TikTok-Live-Companion-Android:site/index.html
// auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py
function generateIndexHtml($outputFile) {
    $html = <<<HTML
<!doctype html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="Dokumentation für TikTok LIVE Companion 0.8.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser." />
    <meta name="theme-color" content="#ffffff" />
    <link rel="icon" type="image/png" href="/branding/staenderglobus-ios.png" />
    <link rel="apple-touch-icon" href="/branding/staenderglobus-ios.png" />
    <title>TikTok LIVE Companion – Dokumentation</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
HTML;

    file_put_contents($outputFile, $html);
}

// Wenn das Skript direkt aufgerufen wird
if (basename(__FILE__) == basename($_SERVER['SCRIPT_NAME'])) {
    $outputFile = isset($argv[1]) ? $argv[1] : 'index.html';
    generateIndexHtml($outputFile);
    echo "HTML file generated: " . $outputFile . "\n";
}
?>
