#!/usr/bin/perl
# index.html — portiert nach perl5
# Quelle: html, OpenClaw@main:index.html
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Parameter: Name der Ausgabedatei
my $output_file = shift @ARGV or die "Bitte geben Sie den Namen der Ausgabedatei als Parameter an.\n";

# Öffne die Ausgabedatei zum Schreiben
open my $fh, '>', $output_file or die "Kann Datei '$output_file' nicht öffnen: $!\n";

# Schreibe das DOCTYPE
print $fh "<!DOCTYPE html>\n";

# Öffne das HTML-Tag mit dem lang-Attribut
print $fh "<html lang=\"de\">\n";

# HEAD-Bereich
print $fh "  <head>\n";
print $fh "    <meta charset=\"utf-8\" />\n";
print $fh "    <link rel=\"icon\" href=\"/favicon.ico\" />\n";
print $fh "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n";
print $fh "    <meta name=\"theme-color\" content=\"#0b1020\" />\n";
print $fh "    <meta\n";
print $fh "      name=\"description\"\n";
print $fh "      content=\"OpenClaw Startseite für Repository, Dokumentation und Frontend-Branch.\"\n";
print $fh "    />\n";
print $fh "    <link rel=\"apple-touch-icon\" href=\"/logo192.png\" />\n";

# Kommentarblock im HEAD
print $fh "    <!--\n";
print $fh "      manifest.json provides metadata used when your web app is installed on a\n";
print $fh "      user's mobile device or desktop. See https://developers.google.com/web/fundamentals/web-app-manifest/\n";
print $fh "    -->\n";

print $fh "    <link rel=\"manifest\" href=\"/manifest.json\" />\n";
print $fh "    <title>OpenClaw</title>\n";
print $fh "  </head>\n";

# BODY-Bereich
print $fh "  <body>\n";
print $fh "    <noscript>You need to enable JavaScript to run this app.</noscript>\n";
print $fh "    <div id=\"root\"></div>\n";

# Kommentarblock im BODY
print $fh "    <!--\n";
print $fh "      This HTML file is a template.\n";
print $fh "      If you open it directly in the browser, you will see an empty page.\n";
print $fh "\n";
print $fh "      You can add webfonts, meta tags, or analytics to this file.\n";
print $fh "      The build step will place the bundled scripts into the <body> tag.\n";
print $fh "\n";
print $fh "      To begin the development, run `npm start` or `yarn start`.\n";
print $fh "      To create a production bundle, use `npm run build` or `yarn build`.\n";
print $fh "    -->\n";

print $fh "  </body>\n";

# SCRIPT-Tag
print $fh "  <script type=\"module\" src=\"/src/index.jsx\"></script>\n";

# Schließe das HTML-Tag
print $fh "</html>\n";

# Schließe die Datei
close $fh;

print "HTML-Datei wurde erfolgreich erstellt: $output_file\n";
