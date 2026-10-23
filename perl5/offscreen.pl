#!/usr/bin/perl
# offscreen.html — portiert nach perl5
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/offscreen.html
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/offscreen.html
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Parameter prüfen
my $output_file = $ARGV[0] or die "Usage: $0 <output_file>\n";

# HTML-Inhalt generieren
my $html_content = <<'EOF';
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
EOF

# In Datei schreiben
open(my $fh, '>', $output_file) or die "Kann Datei '$output_file' nicht öffnen: $!";
print $fh $html_content;
close($fh);

print "HTML-Datei erfolgreich erstellt: $output_file\n";
