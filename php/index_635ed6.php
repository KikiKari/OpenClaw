<?php
// abstraction-provenance: {"artifact_sha256": "0fe405447cdfbad754cdc895389466bd40e2ba0afa0ab36d8e76017c87932c7e", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "php"}
// index.html — portiert nach php
// Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py
// Funktion zur Erzeugung des HTML-Dokuments
function generateHTML($outputFile) {
    // Erstellen des HTML-Inhalts
    $html = <<<HTML
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
HTML;

    // Schreiben des Inhalts in die angegebene Datei
    file_put_contents($outputFile, $html);
}

// Wenn das Skript direkt aufgerufen wird, erzeuge die Datei
if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    // Standard-Ausgabedatei
    $outputFile = 'index.html';
    
    // Wenn ein Parameter übergeben wurde, verwende diesen als Dateinamen
    if (isset($argv[1])) {
        $outputFile = $argv[1];
    }
    
    generateHTML($outputFile);
}
?>
