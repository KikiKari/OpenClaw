#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "acb644b1256d21bf60c4f10262ab3036c61bcfc6fbd3211a78f94f11bd9b003e", "source_sha256": "daf22c296c801d3d533083361cc59fbdc22e5bfe528aa4bad1973b54cc5448a4", "target_language": "perl6"}
# index.css — portiert nach perl6
# Quelle: css, OpenClaw@main:src/index.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

use v6;

sub create-css-content() {
    my $css = q:to/END_CSS/;
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
END_CSS

    return $css;
}

sub write-css-to-file(Str $filename) {
    my $content = create-css-content();
    
    # Schreibe den Inhalt in die Datei
    spurt $filename, $content;
    
    say "CSS file '$filename' successfully created.";
}

# Hauptprogramm
sub MAIN(Str $output-file = "index.css") {
    write-css-to-file($output-file);
}
