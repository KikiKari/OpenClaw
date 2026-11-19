#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "5f5466b171ec167d706f8df0864294147b0348fa81297611636320c9680ea98a", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "perl6"}
# index.html — portiert nach perl6
# Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

use v6;

sub MAIN($output-file) {
    my $html = qq:to/END/;
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
    END

    spurt($output-file, $html);
}
