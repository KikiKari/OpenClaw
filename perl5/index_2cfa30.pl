#!/usr/bin/perl
# index.html — portiert nach perl5
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# auch in: Projects@TikTok-Live-Companion-Android:site/index.html
# auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Parameter prüfen
my $output_file = $ARGV[0] or die "Verwendung: $0 <Ausgabedatei>\n";

# HTML-Struktur erstellen
my $html = create_html_document();

# In Datei schreiben
open my $fh, '>', $output_file or die "Kann Datei '$output_file' nicht öffnen: $!\n";
print $fh $html;
close $fh or die "Fehler beim Schließen der Datei: $!\n";

# HTML-Dokument generieren
sub create_html_document {
    my $doc = '';
    
    # Doctype
    $doc .= "<!doctype html>\n";
    
    # HTML-Tag mit Sprachattribut
    $doc .= "<html lang=\"de\">\n";
    
    # Head-Bereich
    $doc .= "  <head>\n";
    
    # Meta-Tags
    $doc .= "    <meta charset=\"UTF-8\" />\n";
    $doc .= "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n";
    $doc .= "    <meta name=\"description\" content=\"Dokumentation für TikTok LIVE Companion 0.8.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.\" />\n";
    $doc .= "    <meta name=\"theme-color\" content=\"#ffffff\" />\n";
    
    # Link-Tags
    $doc .= "    <link rel=\"icon\" type=\"image/png\" href=\"/branding/staenderglobus-ios.png\" />\n";
    $doc .= "    <link rel=\"apple-touch-icon\" href=\"/branding/staenderglobus-ios.png\" />\n";
    
    # Titel
    $doc .= "    <title>TikTok LIVE Companion – Dokumentation</title>\n";
    
    $doc .= "  </head>\n";
    
    # Body-Bereich
    $doc .= "  <body>\n";
    
    # Root-Div
    $doc .= "    <div id=\"root\"></div>\n";
    
    # Script-Tag
    $doc .= "    <script type=\"module\" src=\"/src/main.tsx\"></script>\n";
    
    $doc .= "  </body>\n";
    
    # Abschließender HTML-Tag
    $doc .= "</html>\n";
    
    return $doc;
}
