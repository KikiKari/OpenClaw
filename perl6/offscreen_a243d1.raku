#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "7ab1d51e75a6b842c25aabb99acdcbaf393b88dc20d734794d1018eeda463ffe", "source_sha256": "a243d1fdcbd0c82c97b2771c181438428885fd9c2feaed782f7e9eb8066fed59", "target_language": "perl6"}
# offscreen.html — portiert nach perl6
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/offscreen.html
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/offscreen.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

sub create-offscreen-html($filename) {
    # Erstelle die HTML-Struktur
    my $html = qq:to/END/;
    <!doctype html>
    <html lang="de">
    <head>
      <meta charset="utf-8">
      <title>TikTok LIVE Companion Sprachausgabe</title>
    </head>
    <body>
      <script src="offscreen.js"></script>
    </body>
    </html>
    END

    # Schreibe in Datei
    spurt $filename, $html;
}

# Hauptprogramm
sub MAIN($output-file = 'offscreen.html') {
    create-offscreen-html($output-file);
    say "HTML-Datei erstellt: $output-file";
}
