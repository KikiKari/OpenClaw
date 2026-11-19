#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "50d76c204be08e9b5965af42fd9362a89c2afddb1f969072d80d23ca768f9954", "source_sha256": "c10479f79ca5554fe399cf2f5d70fb5b32e837c1c7a846eb7dd7c9e9e5319c66", "target_language": "perl6"}
# index.html — portiert nach perl6
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:site/index.html
# auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:site/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

sub MAIN($output-file) {
    my $html = qq:to/END/;
    <!doctype html>
    <html lang="de">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="description" content="Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser." />
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

    spurt($output-file, $html);
}
