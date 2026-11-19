#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "ea29cdceb3e7d4286f01d4ef17f3b840f8b91968c4f5d7388471a0582f3cd8f7", "source_sha256": "2cfa301efe20d60c29e0e9f0746e5a99d405ea44a5d03839c72e6b525451fe07", "target_language": "perl6"}
# index.html — portiert nach perl6
# Quelle: html, Projects@TikTok-Live-Companion-Android:site/index.html
# auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

sub create-html-document($filename) {
    my $html = q:to/END/;
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
END

    spurt $filename, $html;
}

sub MAIN($output-file = "index.html") {
    create-html-document($output-file);
    say "HTML document created: $output-file";
}
