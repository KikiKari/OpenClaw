#!/usr/bin/perl
# index.html — portiert nach perl5
# Quelle: html, Projects@Program-Derivation:public/index.html
# auch in: Projects@Vision-Check:public/index.html
# auch in: Projects@Weather-Check:public/index.html
# auch in: Projects@abstractions:public/index.html
# auch in: 5 weiteren Fundstellen
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Parameter: Name der Ausgabedatei
my $output_file = $ARGV[0] or die "Usage: $0 <output_file>\n";

open my $fh, '>', $output_file or die "Cannot write to '$output_file': $!";

print $fh <<'HTML_HEAD';
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="0; url=3d.html">
<title>Weiterleitung zur 3D-Ansicht</title>
<link rel="canonical" href="3d.html">
<script>location.replace('3d.html');</script>
</head>
<body>
<p><a href="3d.html">3D-Ansicht öffnen</a></p>
</body>
</html>
HTML_HEAD

close $fh;
print "File '$output_file' created successfully.\n";
