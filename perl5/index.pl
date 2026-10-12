#!/usr/bin/perl
# index.html — portiert nach perl5
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Function to generate the HTML document
sub generate_html {
    return <<'EOF';
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
EOF
}

# Main execution
sub main {
    my $filename = $ARGV[0] || 'index.html';
    
    open(my $fh, '>', $filename) or die "Could not open file '$filename' for writing: $!";
    print $fh generate_html();
    close($fh);
    
    print "HTML document written to $filename\n";
}

main() if $0 eq __FILE__;
