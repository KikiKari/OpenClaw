#!/usr/bin/perl
# optimize-media.mjs — portiert nach perl5
# Quelle: javascript, Onboarding@main:scripts/optimize-media.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Find;
use File::Basename;
use Image::Magick;

# Das Verzeichnis ../public/media/ relativ zum Skript bestimmen
my $script_dir = dirname(__FILE__);
my $media_dir = "$script_dir/../public/media/";

# Überprüfen, ob das Verzeichnis existiert
unless (-d $media_dir) {
    die "Verzeichnis $media_dir nicht gefunden.\n";
}

# Alle PNG-Dateien im Verzeichnis finden
opendir(my $dh, $media_dir) or die "Konnte Verzeichnis $media_dir nicht öffnen: $!";
my @files = grep { /\.png$/i } readdir($dh);
closedir $dh;

foreach my $file (@files) {
    my $source_path = "$media_dir/$file";
    my ($stem) = $file =~ /^(.+)\.png$/i;

    # WebP erstellen
    my $webp_path = "$media_dir/${stem}.webp";
    convert_image($source_path, $webp_path, 'WEBP', 84);

    # AVIF erstellen
    my $avif_path = "$media_dir/${stem}.avif";
    convert_image($source_path, $avif_path, 'AVIF', 58);
}

print "WebP- und AVIF-Derivate erzeugt.\n";

sub convert_image {
    my ($source, $dest, $format, $quality) = @_;

    my $image = Image::Magick->new();
    my $x = $image->Read($source);
    warn "Fehler beim Lesen von $source: $x" if $x;

    $x = $image->Set(compression => 'Lossless') if $format eq 'AVIF';
    $x = $image->Write(filename => $dest, quality => $quality);
    warn "Fehler beim Schreiben von $dest: $x" if $x;
}
