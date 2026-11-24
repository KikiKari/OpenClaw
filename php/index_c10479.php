<?php
// abstraction-provenance: {"artifact_sha256": "1ff0f7dc5e3204e120dcce53d7e4e499458835b2dd25b4609ef4e44384e64a70", "source_sha256": "c10479f79ca5554fe399cf2f5d70fb5b32e837c1c7a846eb7dd7c9e9e5319c66", "target_language": "php"}
// index.html — portiert nach php
// Quelle: html, Projects@TikTok-Live-Companion:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/index.html
// auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:site/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py
function generateIndexHtml($filename = 'index.html') {
    $html = '<!doctype html>' . PHP_EOL;
    $html .= '<html lang="de">' . PHP_EOL;
    $html .= '  <head>' . PHP_EOL;
    $html .= '    <meta charset="UTF-8" />' . PHP_EOL;
    $html .= '    <meta name="viewport" content="width=device-width, initial-scale=1.0" />' . PHP_EOL;
    $html .= '    <meta name="description" content="Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser." />' . PHP_EOL;
    $html .= '    <meta name="theme-color" content="#ffffff" />' . PHP_EOL;
    $html .= '    <link rel="icon" type="image/png" href="/branding/staenderglobus-ios.png" />' . PHP_EOL;
    $html .= '    <link rel="apple-touch-icon" href="/branding/staenderglobus-ios.png" />' . PHP_EOL;
    $html .= '    <title>TikTok LIVE Companion – Dokumentation</title>' . PHP_EOL;
    $html .= '  </head>' . PHP_EOL;
    $html .= '  <body>' . PHP_EOL;
    $html .= '    <div id="root"></div>' . PHP_EOL;
    $html .= '    <script type="module" src="/src/main.tsx"></script>' . PHP_EOL;
    $html .= '  </body>' . PHP_EOL;
    $html .= '</html>' . PHP_EOL;

    return file_put_contents($filename, $html) !== false;
}

// Wenn das Skript direkt aufgerufen wird, erzeuge die Datei
if (basename(__FILE__) == basename($_SERVER['SCRIPT_FILENAME'])) {
    if (generateIndexHtml()) {
        echo "index.html erfolgreich erstellt." . PHP_EOL;
    } else {
        echo "Fehler beim Erstellen der index.html." . PHP_EOL;
    }
}
?>
